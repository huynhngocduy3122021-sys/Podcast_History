"""Real HTTP regression suite against an isolated PostgreSQL database and local S3 stub.

Python standard library only. Never connects the application to Podcast_History.
Run from Backend: python scripts/api_regression.py [--skip-build]
Database credentials are read from .env/environment; tokens are never written to reports.
"""
import argparse
import base64
import concurrent.futures
import hashlib
import hmac
import http.server
import json
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "target" / "api-regression"
PASSWORD = "RegressionPassword123!"
JWT_SECRET = "isolated-regression-secret-at-least-32-bytes"
PNG = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6gAAAAABJRU5ErkJggg==")
# ISO BMFF ftyp signature, enough for storage/API tests, not a decode/transcoding test.
VIDEO = bytes.fromhex("000000186674797069736f6d0000020069736f6d69736f32") + b"regression-video-fixture"
PDF = b"%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\n%%EOF\n"
NOTE = {"note": "Regression fixture, verified locally"}


def unused_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


class S3Stub(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    objects = {}
    def handle(self):
        try:
            super().handle()
        except (ConnectionResetError, BrokenPipeError):
            pass
    def log_message(self, *args):
        pass
    def send(self, status, payload=b"", content_type="application/octet-stream"):
        self.send_response(status)
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Content-Type", content_type)
        self.send_header("ETag", '"regression"')
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(payload)
    def do_PUT(self):
        content = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        self.objects[urllib.parse.urlparse(self.path).path] = (content, self.headers.get("Content-Type"))
        self.send(200)
    def do_DELETE(self):
        self.objects.pop(urllib.parse.urlparse(self.path).path, None)
        self.send(204)
    def do_GET(self):
        key = urllib.parse.urlparse(self.path).path
        if key not in self.objects:
            self.send(404)
        else:
            content, kind = self.objects[key]
            self.send(200, content, kind or "application/octet-stream")
    do_HEAD = do_GET


class Regression:
    def __init__(self, env, psql, db, port):
        self.env, self.psql, self.db = env, psql, db
        self.base = f"http://127.0.0.1:{port}"
        self.results, self.routes, self.covered, self.success = [], [], set(), set()
        self.accounts, self.ids = {}, {}
        self.guard = threading.Lock()
    def sql(self, query, database=None):
        p = subprocess.run([self.psql, "-X", "-w", "-h", self.env["PGHOST"], "-p", self.env["PGPORT"],
                "-U", self.env["PGUSER"], "-d", database or self.db, "-v", "ON_ERROR_STOP=1", "-At"],
                input=query, text=True, encoding="utf-8", capture_output=True, env=self.env)
        if p.returncode:
            raise AssertionError("Fixture SQL failed: " + p.stderr[-2000:])
        return p.stdout.strip()
    def identify(self, method, path):
        path = urllib.parse.urlparse(path).path
        for m, template in sorted(self.routes, key=lambda route: route[1].count('{')):
            if m == method and re.fullmatch(re.sub(r"\{[^}]+\}", "[^/]+", template), path):
                return m + " " + template
        return method + " " + path
    def call(self, method, path, actor=None, body=None, expected=200, upload=None, headers=None, label=None):
        request_headers = dict(headers or {})
        if actor:
            token = self.accounts[actor]["accessToken"] if actor in self.accounts else actor
            request_headers["Authorization"] = "Bearer " + token
        data = None
        if upload:
            filename, kind, content = upload
            boundary = "regression-" + uuid.uuid4().hex
            data = (f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{filename}"\r\nContent-Type: {kind}\r\n\r\n'.encode()
                    + content + f"\r\n--{boundary}--\r\n".encode())
            request_headers["Content-Type"] = "multipart/form-data; boundary=" + boundary
        elif body is not None:
            data = json.dumps(body, ensure_ascii=False).encode("utf-8")
            request_headers["Content-Type"] = "application/json"
        start = time.perf_counter()
        try:
            response = urllib.request.urlopen(urllib.request.Request(self.base + path, data=data, headers=request_headers, method=method), timeout=25)
        except urllib.error.HTTPError as error:
            response = error
        status = response.code
        raw = response.read()
        response_headers = dict(response.headers)
        response.close()
        elapsed = round((time.perf_counter() - start) * 1000, 2)
        try:
            result = json.loads(raw) if raw else None
        except (ValueError, UnicodeDecodeError):
            result = raw
        accepted = status in ([expected] if isinstance(expected, int) else expected)
        route = self.identify(method, path)
        with self.guard:
            self.covered.add(route)
            if 200 <= status < 300:
                self.success.add(route)
            self.results.append({"case": label or method + " " + path, "route": route, "expected": expected,
                "status": status, "passed": accepted, "milliseconds": elapsed})
        if not accepted:
            safe = result if isinstance(result, dict) else str(result)[:300]
            if isinstance(safe, dict):
                safe = {k: v for k, v in safe.items() if k not in {"accessToken", "refreshToken", "password"}}
            raise AssertionError(f"{method} {path}: expected {expected}, got {status}: {safe}")
        return result, response_headers
    def check(self, condition, label):
        self.results.append({"case": label, "passed": bool(condition)})
        if not condition:
            raise AssertionError(label)
    def get(self, path, actor, **kwargs):
        return self.call("GET", path, actor, **kwargs)[0]
    def post(self, path, actor, body=None, **kwargs):
        return self.call("POST", path, actor, body, **kwargs)[0]
    def login(self, name):
        result = self.post("/api/auth/login", None, {"identifier": name, "password": PASSWORD})
        self.accounts[name] = result
        return result
    def register(self, name):
        user = self.post("/api/auth/register", None, {"username": name, "email": name + "@example.test", "password": PASSWORD,
            "displayName": name}, expected=201)
        self.ids[name] = user["id"]
        self.login(name)
        return user["id"]
    def creator(self, name, channel):
        self.register(name)
        application = self.post("/api/creator-applications", name, {"channelName": channel, "introduction": "Regression channel"}, expected=201)
        profile_id = application["applicationId"]
        self.ids[name + "Profile"] = profile_id
        self.get("/api/creator-applications/me", name)
        self.get("/api/admin/creator-applications/" + profile_id, "admin_test")
        self.post("/api/admin/creator-applications/" + profile_id + "/approve", "admin_test", NOTE)
        rotated = self.post("/api/auth/refresh", None, {"refreshToken": self.accounts[name]["refreshToken"]})
        self.accounts[name] = rotated
        self.check(rotated["user"]["role"] == "CREATOR", "Approval refresh grants CREATOR")
        return profile_id
    def create_podcast(self, visibility="PUBLIC", actor="creator_test", title="Vietnam history"):
        podcast = self.post("/api/creator/podcasts", actor, {"categoryId": self.ids["categoryId"], "title": title,
            "description": "Historical recording", "durationSeconds": 120, "episodeNumber": 1, "visibility": visibility}, expected=201)
        pid = podcast["podcastId"]
        self.post(f"/api/creator/podcasts/{pid}/video", actor, upload=("clip.mp4", "video/mp4", VIDEO), expected=201)
        return pid
    def publish(self, pid, reviewer="admin_test"):
        self.post(f"/api/creator/podcasts/{pid}/submit", "creator_test")
        prefix = "/api/staff" if reviewer.startswith("staff") else "/api/admin"
        self.post(f"{prefix}/podcasts/{pid}/approve", reviewer, NOTE)
    def setup(self):
        spec = self.get("/v3/api-docs", None)
        self.routes = [(method.upper(), path) for path, methods in spec["paths"].items() for method in methods if method in {"get","post","put","patch","delete"}]
        print(f"OpenAPI: {len(self.routes)} operations", flush=True)
        self.register("admin_test")
        self.sql(f'''UPDATE "User" SET role_id=(SELECT role_id FROM "Role" WHERE role_code='ADMIN') WHERE user_id='{self.ids['admin_test']}';''')
        self.login("admin_test")
        for name in ["listener_test", "other_test", "candidate_test"]:
            self.register(name)
        for name in ["staff_test", "staff_other"]:
            user = self.post("/api/admin/staff", "admin_test", {"username": name, "email": name+"@example.test", "password": PASSWORD, "displayName": name}, expected=201)
            self.ids[name] = user["userId"]
            self.login(name)
        self.creator("creator_test", "History regression")
        self.creator("creator_other", "Other regression")
        self.check(self.accounts['listener_test']['expiresIn']==600 and self.accounts['listener_test']['refreshExpiresIn']==604800,'JWT lifetimes are 10 minutes and one week')
        password_hash=self.sql(f'''SELECT password_hash FROM "User" WHERE user_id='{self.ids['listener_test']}';''')
        self.check(password_hash.startswith(('$2a$','$2b$','$2y$')) and password_hash != PASSWORD,'Database contains BCrypt hash, not password')
        self.post('/api/auth/login',None,{'identifier':'listener_test','password':'incorrect'},expected=401)
        barrier=threading.Barrier(4)
        def register_race(index):
            barrier.wait()
            return self.post('/api/auth/register',None,{'username':'RaceUser' if index%2 else 'raceuser','email':f'race{index}@example.test','password':PASSWORD,'displayName':'Race'},expected=[201,409])
        with concurrent.futures.ThreadPoolExecutor(4) as pool:
            list(pool.map(register_race,range(4)))
        self.check(self.sql('''SELECT count(*) FROM "User" WHERE lower(username)='raceuser';''')=='1','Concurrent registration is case insensitive and unique')
        print("Roles and isolated accounts ready", flush=True)
    def categories_and_sources(self):
        category = self.post("/api/admin/categories", "admin_test", {"name":"History", "slug":"history", "active":True}, expected=201)
        cid = self.ids["categoryId"] = category["categoryId"]
        self.get("/api/categories", None)
        self.call("PUT", f"/api/admin/categories/{cid}", "admin_test", {"name":"History", "slug":"history", "active":True})
        pid = self.ids["podcastId"] = self.create_podcast()
        self.post(f"/api/creator/podcasts/{pid}/submit", "creator_other", expected=404)
        series = self.post("/api/creator/series", "creator_test", {"categoryId":cid,"title":"Dynasties", "slug":"dynasties"}, expected=201)
        sid = self.ids["seriesId"] = series["seriesId"]
        self.call("PUT", f"/api/creator/series/{sid}", "creator_test", {"categoryId":cid,"title":"Vietnam dynasties","slug":"dynasties"})
        self.call("PUT", f"/api/creator/podcasts/{pid}/series", "creator_test", {"seriesId":sid})
        self.get(f"/api/creator/series/{sid}/podcasts", "creator_test")
        self.call("DELETE", f"/api/creator/podcasts/{pid}/series", "creator_test")
        self.call("PUT", f"/api/creator/podcasts/{pid}", "creator_test", {"categoryId":cid,"title":"Vietnam history","durationSeconds":120,"visibility":"PUBLIC"})
        self.post("/api/uploads", "creator_test", upload=("cover.png","image/png",PNG), expected=201)
        self.post('/api/uploads','creator_test',upload=('fake.png','image/png',b'<script>alert(1)</script>'),expected=400)
        self.post(f'/api/creator/podcasts/{pid}/video','creator_test',upload=('fake.mp4','video/mp4',b'not a video'),expected=400)
        previous = {key for key in S3Stub.objects if f'/podcasts/{pid}/' in key}
        video=self.post(f'/api/creator/podcasts/{pid}/video','creator_test',upload=('replacement.mp4','video/mp4',VIDEO),expected=201)
        self.check(all(key not in S3Stub.objects for key in previous),'Replacing video deletes previous object after commit')
        self.check(video['media']['publicUrl'] is None,'Podcast video does not expose permanent public URL')
        source = self.post(f"/api/creator/podcasts/{pid}/references", "creator_test", {"referenceType":"PDF","title":"History source"}, expected=201)
        rid = self.ids["referenceId"] = source["referenceId"]
        rp = f"/api/creator/podcasts/{pid}/references/{rid}"
        self.call("PUT", rp, "creator_test", {"referenceType":"PDF","title":"Updated source"})
        self.post(rp+"/file", "creator_test", upload=("source.pdf","application/pdf",PDF))
        for prefix, actor in [('admin','admin_test'),('staff','staff_test')]:
            self.get(f'/api/{prefix}/podcasts/{pid}/references/{rid}/file', actor)
        self.get(rp, "creator_test")
        self.get(rp+"/file", "creator_test")
        self.get(rp+"/file", "creator_other", expected=404)
        self.publish(pid, "staff_test")
        self.get(f"/api/admin/podcasts/{pid}/preview", "admin_test")
        self.get(f"/api/staff/podcasts/{pid}/preview", "staff_test")
        self.post(f"/api/admin/podcasts/{pid}/approve", "admin_test", NOTE, expected=409)
        playback = self.get(f"/api/podcasts/{pid}/playback", "listener_test")
        self.check("X-Amz-Signature" in playback["playbackUrl"], "Private R2 playback is signed")
        with urllib.request.urlopen(playback["playbackUrl"]) as media:
            self.check(media.read() == VIDEO, "Signed media points to correct stored file")
        private = self.ids["privateId"] = self.create_podcast("MEMBERS_ONLY", title="Exclusive history")
        self.publish(private)
        self.get(f"/api/podcasts/{private}/playback", "listener_test", expected=403)
        self.get(f"/api/podcasts/{private}/playback", "creator_test")
        self.post("/api/creator/podcasts", "creator_test", {"categoryId":cid,"title":"Bad visibility","durationSeconds":120,"visibility":"PUBLIC","exclusive":True}, expected=400)
        print("Podcast, series, video and source flow passed", flush=True)
    def listener(self):
        pid = self.ids["podcastId"]
        self.get("/api/podcasts?q=history&page=0&size=20", "listener_test")
        self.get(f"/api/podcasts/{pid}/references", "listener_test")
        self.get(f"/api/podcasts/{pid}/references/{self.ids['referenceId']}/file", "listener_test")
        self.call("PUT", f"/api/podcasts/{pid}/listening-progress", "listener_test", {"progressSeconds":30,"completed":False})
        self.call("PUT", f"/api/podcasts/{pid}/listening-progress", "listener_test", {"progressSeconds":-1,"completed":False}, expected=400)
        self.call("PUT", f"/api/podcasts/{pid}/like", "listener_test")
        self.call("PUT", f"/api/podcasts/{pid}/like", "listener_test")
        self.check(self.get(f"/api/podcasts/{pid}/likes", "listener_test")["likeCount"] == 1, "Repeated like is idempotent")
        self.call("DELETE", f"/api/podcasts/{pid}/like", "listener_test")
        comment = self.post(f"/api/podcasts/{pid}/comments", "listener_test", {"content":"Interesting history"}, expected=201)
        self.ids["commentId"] = comment["commentId"]
        self.call("PUT", f"/api/comments/{comment['commentId']}", "other_test", {"content":"Not mine"}, expected=403)
        self.call("PUT", f"/api/comments/{comment['commentId']}", "listener_test", {"content":"Updated comment"})
        # SSE has no finite response; read the connection event and one published comment.
        path=f"/api/podcasts/{pid}/comments/stream"
        request=urllib.request.Request(self.base+path,headers={"Authorization":"Bearer "+self.accounts['listener_test']['accessToken'],"Accept":"text/event-stream"})
        with urllib.request.urlopen(request,timeout=10) as stream:
            lines=[stream.readline().decode() for _ in range(3)]
            self.check(any("connected" in line for line in lines), "SSE connected event")
            self.post(f"/api/podcasts/{pid}/comments", "creator_test", {"content":"Thanks for listening"}, expected=201)
            lines=[stream.readline().decode() for _ in range(3)]
            self.check(any("comment-created" in line for line in lines), "SSE comment-created event")
        self.success.add("GET /api/podcasts/{podcastId}/comments/stream")
        self.covered.add("GET /api/podcasts/{podcastId}/comments/stream")
        creator=self.ids["creator_testProfile"]
        self.call("PUT", f"/api/creators/{creator}/follow", "listener_test")
        self.call("PUT", f"/api/me/saved-podcasts/{pid}", "listener_test")
        self.get("/api/me/follows", "listener_test")
        self.get("/api/me/saved-podcasts", "listener_test")
        report=self.post("/api/reports", "listener_test", {"targetType":"COMMENT","targetId":comment['commentId'],"reasonCode":"SPAM"}, expected=201)
        self.ids["reportId"]=report["reportId"]
        self.call("PATCH",f"/api/me/reports/{report['reportId']}","listener_test",{"reasonCode":"SPAM","description":"Please check"})
        self.get("/api/me/reports", "listener_test")
        self.post(f"/api/staff/reports/{report['reportId']}/claim", "staff_test")
        self.post(f"/api/staff/reports/{report['reportId']}/resolve", "staff_other", {"action":"DISMISS",**NOTE},expected=409)
        self.post(f"/api/staff/reports/{report['reportId']}/resolve", "staff_test", {"action":"DISMISS",**NOTE})
        self.call("DELETE",f"/api/me/reports/{report['reportId']}","listener_test",expected=409)
        withdrawn=self.post("/api/reports","listener_test",{"targetType":"PODCAST","targetId":pid,"reasonCode":"SPAM"},expected=201)
        self.call("DELETE",f"/api/me/reports/{withdrawn['reportId']}","listener_test",expected=204)
        self.call("DELETE",f"/api/comments/{comment['commentId']}","listener_test",expected=204)
        self.call("DELETE",f"/api/creators/{creator}/follow","listener_test",expected=204)
        self.call("DELETE",f"/api/me/saved-podcasts/{pid}","listener_test",expected=204)
        self.get(f"/api/me/listening-history/{pid}","listener_test")
        self.call("DELETE",f"/api/me/listening-history/{pid}","listener_test",expected=204)
        def concurrent_put(path,body=None):
            barrier=threading.Barrier(4)
            def invoke(_):
                barrier.wait()
                return self.call('PUT',path,'other_test',body)
            with concurrent.futures.ThreadPoolExecutor(4) as pool:
                list(pool.map(invoke,range(4)))
        concurrent_put(f'/api/podcasts/{pid}/like')
        concurrent_put(f'/api/creators/{creator}/follow')
        concurrent_put(f'/api/me/saved-podcasts/{pid}')
        concurrent_put(f'/api/podcasts/{pid}/listening-progress',{'progressSeconds':40,'completed':False})
        self.check(self.get(f'/api/podcasts/{pid}/likes','other_test')['likeCount']==1,'Concurrent likes stay idempotent')
        print("Listener CRUD, ownership and SSE passed",flush=True)
    def membership(self):
        creator=self.ids['creator_testProfile']
        body={"creatorId":creator,"name":"Channel supporter","description":"Exclusive episodes","price":50000,"currency":"VND","durationDays":30,"status":"ACTIVE"}
        plan=self.post("/api/admin/membership-plans","admin_test",body,expected=201)
        self.ids['planId']=plan['planId']
        self.call("PUT",f"/api/admin/membership-plans/{plan['planId']}","admin_test",body)
        self.get(f"/api/creators/{creator}/membership-plans","listener_test")
        checkout=self.post("/api/me/subscriptions","listener_test",{"membershipPlanId":plan['planId']},expected=202)
        self.ids.update(subscriptionId=checkout['subscriptionId'],paymentId=checkout['paymentId'])
        self.post("/api/me/subscriptions","listener_test",{"membershipPlanId":plan['planId']},expected=409)
        self.post(f"/api/admin/payments/{checkout['paymentId']}/reconcile","admin_test",{"result":"PAID","providerTransactionId":"BANK-TEST-001",**NOTE})
        self.get(f"/api/podcasts/{self.ids['privateId']}/playback","listener_test")
        self.post(f"/api/admin/payments/{checkout['paymentId']}/reconcile","admin_test",{"result":"PAID","providerTransactionId":"BANK-TEST-001",**NOTE},expected=409)
        request=self.post(f"/api/creators/{creator}/series-requests","listener_test",{"requestedTitle":"New episode","description":"Please cover another era"},expected=201)
        self.ids['requestId']=request['seriesRequestId']
        self.call("PUT",f"/api/me/series-requests/{request['seriesRequestId']}","listener_test",{"requestedTitle":"Edited title","description":"More detail"})
        self.get("/api/me/series-requests","listener_test")
        self.call("DELETE",f"/api/me/series-requests/{request['seriesRequestId']}","listener_test",expected=204)
        self.post(f"/api/admin/payments/{checkout['paymentId']}/refund","admin_test",{"refundReference":"REFUND-TEST-001",**NOTE})
        self.get(f"/api/podcasts/{self.ids['privateId']}/playback","listener_test",expected=403)
        self.post(f"/api/admin/payments/{checkout['paymentId']}/refund","admin_test",{"refundReference":"REFUND-TEST-001",**NOTE},expected=409)
        pending=self.post("/api/me/subscriptions","other_test",{"membershipPlanId":plan['planId']},expected=202)
        self.call("DELETE",f"/api/me/subscriptions/{pending['subscriptionId']}","other_test",expected=204)
        self.post(f"/api/admin/payments/{pending['paymentId']}/reconcile","admin_test",{"result":"PAID","providerTransactionId":"BANK-CANCELLED",**NOTE},expected=409)
        self.call("DELETE",f"/api/admin/membership-plans/{plan['planId']}","admin_test",NOTE)
        self.call("PUT",f"/api/admin/membership-plans/{plan['planId']}","admin_test",body)
        print("Membership reconciliation, cancellation and refund passed",flush=True)
    def moderation(self):
        pid=self.ids['podcastId']
        self.post(f"/api/staff/podcasts/{pid}/hide","staff_test",NOTE,expected=204)
        self.get(f"/api/podcasts/{pid}/playback","listener_test",expected=404)
        appeal=self.post(f"/api/creator/podcasts/{pid}/appeals","creator_test",NOTE,expected=201)
        self.ids['appealId']=appeal['appealId']
        self.post(f"/api/creator/podcasts/{pid}/appeals","creator_test",NOTE,expected=409)
        self.post(f"/api/admin/podcast-appeals/{appeal['appealId']}/resolve","admin_test",{"decision":"REJECT",**NOTE})
        appeal=self.post(f"/api/creator/podcasts/{pid}/appeals","creator_test",NOTE,expected=201)
        self.ids['appealId']=appeal['appealId']
        self.post(f"/api/staff/podcast-appeals/{appeal['appealId']}/resolve","staff_test",{"decision":"ACCEPT",**NOTE})
        self.post(f"/api/staff/podcasts/{pid}/reject","staff_test",NOTE)
        self.post(f"/api/creator/podcasts/{pid}/submit","creator_test")
        self.post(f"/api/admin/podcasts/{pid}/approve","admin_test",NOTE)
        self.post(f"/api/admin/podcasts/{pid}/hide","admin_test",NOTE,expected=204)
        self.post(f"/api/admin/podcasts/{pid}/restore","admin_test",NOTE,expected=204)
        self.post(f"/api/admin/podcasts/{pid}/reject","admin_test",NOTE)
        self.get(f"/api/creator/podcasts/{pid}/reviews","creator_test")
        self.get(f"/api/creator/podcasts/{pid}/appeals","creator_test")
        # Exercise remaining source deletion while the podcast is editable.
        rp=f"/api/creator/podcasts/{pid}/references/{self.ids['referenceId']}"
        self.call("DELETE",rp+"/file","creator_test",expected=204)
        self.call("DELETE",rp,"creator_test",expected=204)
        app=self.post("/api/creator-applications","candidate_test",{"channelName":"Rejected candidate","introduction":"Please review"},expected=201)
        self.post(f"/api/admin/creator-applications/{app['applicationId']}/reject","admin_test",NOTE)
        self.publish(pid)
        report=self.post('/api/reports','listener_test',{'targetType':'PODCAST','targetId':pid,'reasonCode':'OTHER','description':'Admin check'},expected=201)
        self.post(f"/api/admin/reports/{report['reportId']}/claim",'admin_test',NOTE)
        self.post(f"/api/admin/reports/{report['reportId']}/resolve",'admin_test',{'action':'DISMISS',**NOTE})
        print("Moderation, appeals and application rejection passed",flush=True)
    def finance_fixtures(self):
        wallet=str(uuid.uuid4()); self.ids['walletId']=wallet
        user=self.ids['creator_test']; creator=self.ids['creator_testProfile']
        self.sql(f'''INSERT INTO "User_wallet"(user_wallet_id,user_id,balance,currency,status,created_at,updated_at)
            VALUES('{wallet}','{user}',1000000,'VND','ACTIVE',now(),now());''')
        withdrawals=[]
        for amount in [100000,200000,2000000,100000,100000]:
            wid=str(uuid.uuid4());withdrawals.append(wid)
            self.sql(f'''INSERT INTO "Withdrawal_request"(withdrawal_request_id,producer_profile_id,user_wallet_id,amount,currency,payout_method,payout_account_masked,status,requested_at,created_at,updated_at,funds_reserved)
                VALUES('{wid}','{creator}','{wallet}',{amount},'VND','BANK','***1234','PENDING',now(),now(),now(),false);''')
        self.ids['withdrawalId']=withdrawals[0]
        approve={"payoutAccountVerified":True,**NOTE}
        base="/api/admin/withdrawals/"
        self.post(base+withdrawals[0]+"/approve","admin_test",approve)
        self.check(self.sql(f'''SELECT balance FROM "User_wallet" WHERE user_wallet_id='{wallet}';''')=='900000.00',"Approval reserves money once")
        self.post(base+withdrawals[0]+"/approve","admin_test",approve,expected=409)
        self.post(base+withdrawals[0]+"/fail","admin_test",NOTE)
        self.post(base+withdrawals[0]+"/fail","admin_test",NOTE,expected=409)
        self.check(self.sql(f'''SELECT balance FROM "User_wallet" WHERE user_wallet_id='{wallet}';''')=='1000000.00',"Failure returns reserved amount once")
        self.post(base+withdrawals[1]+"/approve","admin_test",approve)
        self.post(base+withdrawals[1]+"/complete","admin_test",{"payoutReference":"PAYOUT-001",**NOTE})
        self.post(base+withdrawals[1]+"/complete","admin_test",{"payoutReference":"PAYOUT-001",**NOTE},expected=409)
        self.check(self.sql(f'''SELECT balance FROM "User_wallet" WHERE user_wallet_id='{wallet}';''')=='800000.00',"Complete does not deduct twice")
        self.post(base+withdrawals[2]+"/approve","admin_test",approve,expected=409)
        self.post(base+withdrawals[3]+"/reject","admin_test",NOTE)
        # Concurrent same request must have exactly one successful reservation.
        def reserve():return self.post(base+withdrawals[4]+"/approve","admin_test",approve,expected=[200,409])
        with concurrent.futures.ThreadPoolExecutor(2) as pool:
            outcomes=list(pool.map(lambda _:reserve(),range(2)))
        self.check(self.sql(f'''SELECT balance FROM "User_wallet" WHERE user_wallet_id='{wallet}';''')=='700000.00',"Concurrent approvals reserve once")
        self.post(base+withdrawals[4]+"/fail","admin_test",NOTE)
        # Existing contracts are fixture data, not created through unsupported Creator APIs.
        contract_ids=[]
        for _ in range(3):
            request_id,response_id,contract_id,stage_id=[str(uuid.uuid4()) for _ in range(4)]
            contract_ids.append(contract_id)
            self.sql(f'''INSERT INTO "Series_request"(series_request_id,user_id,producer_profile_id,requested_title,description,request_fee,currency,status,created_at,updated_at)
                VALUES('{request_id}','{self.ids['listener_test']}','{creator}','Contract fixture','Details',0,'VND','ACCEPTED',now(),now());
                INSERT INTO "Series_response"(series_response_id,series_request_id,producer_profile_id,response_text,response_status,created_at,updated_at)
                VALUES('{response_id}','{request_id}','{creator}','Accepted','ACCEPTED',now(),now());
                INSERT INTO "Contract"(contract_id,user_id,producer_profile_id,series_response_id,status,created_at,updated_at)
                VALUES('{contract_id}','{self.ids['listener_test']}','{creator}','{response_id}','ACTIVE',now(),now());
                INSERT INTO "Contract_stage"(contract_stage_id,contract_id,stage_name,stage_order,status,created_at,updated_at)
                VALUES('{stage_id}','{contract_id}','Final',1,'APPROVED',now(),now());''')
        self.ids['contractId']=contract_ids[0]
        self.post(f'/api/contracts/{contract_ids[0]}/disputes','other_test',NOTE,expected=403)
        for i,decision in enumerate(["RESUME_CONTRACT","CANCEL_CONTRACT","COMPLETE_CONTRACT"]):
            cid=contract_ids[i]
            prefix="/api/contracts" if i==0 else "/api/admin/contracts"
            actor="listener_test" if i==0 else "admin_test"
            dispute=self.post(f"{prefix}/{cid}/disputes",actor,NOTE,expected=201)
            self.ids['disputeId']=dispute['disputeId']
            self.post(f"/api/admin/disputes/{dispute['disputeId']}/resolve","admin_test",{"decision":decision,**NOTE})
        print("Withdrawal balances, concurrency and disputes passed",flush=True)
    def user_access(self):
        uid=self.ids['other_test']
        self.call("PATCH",f"/api/admin/users/{uid}","admin_test",{"displayName":"Other listener","bio":"Test"})
        self.call("PATCH",f"/api/admin/users/{uid}/verification","admin_test",{"verified":True,**NOTE})
        old=self.accounts['other_test'].copy()
        self.call("PATCH",f"/api/admin/users/{uid}/access","admin_test",{"active":False,**NOTE})
        self.get("/api/auth/me",old['accessToken'],expected=401)
        self.post("/api/auth/refresh",None,{"refreshToken":old['refreshToken']},expected=401)
        self.call("PATCH",f"/api/admin/users/{uid}/access","admin_test",{"active":True,**NOTE})
        self.login('other_test')
        self.call("PATCH",f"/api/admin/users/{uid}/role","admin_test",{"role":"STAFF",**NOTE})
        self.get("/api/auth/me",'other_test',expected=401)
        self.login('other_test')
        self.call("PATCH",f"/api/admin/users/{uid}/role","admin_test",{"role":"LISTENER",**NOTE})
        self.login('other_test')
        self.post(f"/api/admin/users/{uid}/revoke-sessions","admin_test",NOTE)
        self.get('/api/auth/me','other_test',expected=401)
        self.login('other_test')
        self.call("PATCH",f"/api/admin/users/{self.ids['admin_test']}/access","admin_test",{"active":False,**NOTE},expected=403)
        notifications=self.get('/api/me/notifications','creator_test')
        self.check(bool(notifications['content']),"Moderation and finance generate notifications")
        self.ids['notificationId']=notifications['content'][0]['notificationId']
        self.call('PUT',f"/api/me/notifications/{self.ids['notificationId']}/read",'creator_test',expected=204)
        self.call('PUT',f"/api/me/notifications/{self.ids['notificationId']}/read",'listener_test',expected=404)
        # Expired but correctly signed JWT and signature tampering.
        original=self.accounts['listener_test']['accessToken']
        header,payload,_=original.split('.')
        claims=json.loads(base64.urlsafe_b64decode(payload+'='*(-len(payload)%4)))
        claims['exp']=int(time.time())-120
        body=base64.urlsafe_b64encode(json.dumps(claims).encode()).decode().rstrip('=')
        encoded=header+'.'+body
        sig=base64.urlsafe_b64encode(hmac.new(JWT_SECRET.encode(),encoded.encode(),hashlib.sha256).digest()).decode().rstrip('=')
        self.get('/api/auth/me',encoded+'.'+sig,expected=401)
        self.get('/api/auth/me',original[:-4]+'AAAA',expected=401)
        refresh=self.login('other_test')['refreshToken']
        rotated=self.post('/api/auth/refresh',None,{"refreshToken":refresh})
        self.accounts['other_test']=rotated
        self.post('/api/auth/refresh',None,{"refreshToken":refresh},expected=401)
        self.post('/api/auth/refresh',None,{"refreshToken":rotated['refreshToken']},expected=401)
        self.login('other_test')
        self.post('/api/auth/logout',None,{"refreshToken":self.accounts['other_test']['refreshToken']},expected=204)
        print("User access, token expiry/replay and revocation passed",flush=True)
    def template_path(self, template):
        values={**self.ids,"userId":self.ids['listener_test'],"creatorId":self.ids['creator_testProfile'],
            "applicationId":self.ids['creator_testProfile'],"planId":self.ids['planId']}
        return re.sub(r'\{([^}]+)\}',lambda m:values.get(m.group(1),str(uuid.uuid4())),template)
    def matrix_and_read_catalog(self):
        public={'GET /api/categories','GET /api/health','POST /api/auth/login','POST /api/auth/register','POST /api/auth/refresh','POST /api/auth/logout'}
        for method,template in self.routes:
            route=method+' '+template;path=self.template_path(template)
            if route not in public:
                self.call(method,path,None,{} if method in {'POST','PUT','PATCH','DELETE'} else None,expected=401,label='anonymous: '+route)
            if template.startswith(('/api/admin/','/api/staff/','/api/creator/')):
                self.call(method,path,'listener_test',{} if method in {'POST','PUT','PATCH','DELETE'} else None,expected=403,label='wrong-role: '+route)
            if template.startswith('/api/admin/'):
                self.call(method,path,'staff_test',{} if method in {'POST','PUT','PATCH','DELETE'} else None,expected=403,label='staff cannot administer: '+route)
            if method=='GET' and not template.endswith('/comments/stream'):
                actor='admin_test' if template.startswith('/api/admin/') else 'staff_test' if template.startswith('/api/staff/') else 'creator_test' if template.startswith('/api/creator/') else 'listener_test'
                # Sources were intentionally deleted earlier; fetching missing detail/file should be 404.
                expected=[200,404] if '/references' in template or template.endswith('/listening-history/{podcastId}') or template == '/api/creator-applications/me' else 200
                self.get(path,actor,expected=expected,label='read-catalog: '+route)
        _,headers=self.call('OPTIONS','/api/podcasts',headers={'Origin':'http://localhost:5173','Access-Control-Request-Method':'GET','Access-Control-Request-Headers':'authorization'})
        self.check(headers.get('Access-Control-Allow-Origin')=='http://localhost:5173','Allowed frontend CORS preflight')
        self.get('/api/podcasts/not-a-uuid','listener_test',expected=400)
        self.get('/api/podcasts/'+str(uuid.uuid4()),'listener_test',expected=404)
        self.post('/api/admin/withdrawals/'+self.ids['withdrawalId']+'/approve','admin_test',{'payoutAccountVerified':False,**NOTE},expected=400)
        self.call('OPTIONS','/api/podcasts',headers={'Origin':'https://untrusted.example','Access-Control-Request-Method':'GET'},expected=403)
        print("All OpenAPI routes checked for authentication and role boundaries",flush=True)
    def cleanup_api(self):
        # Remaining mutation routes, on isolated disposable records only.
        pid=self.ids['privateId']
        self.call('DELETE',f'/api/staff/podcasts/{pid}','staff_test',NOTE,expected=204)
        pid=self.ids['podcastId']
        self.post(f'/api/staff/podcasts/{pid}/hide','staff_test',NOTE,expected=204)
        self.post(f'/api/staff/podcasts/{pid}/restore','staff_test',NOTE,expected=204)
        self.call('DELETE',f'/api/admin/podcasts/{pid}','admin_test',NOTE,expected=204)
        self.call('DELETE',f'/api/creator/podcasts/{pid}','creator_test')
        self.call('DELETE',f"/api/creator/series/{self.ids['seriesId']}",'creator_test')
        self.call('DELETE',f"/api/admin/categories/{self.ids['categoryId']}",'admin_test')
    def query_workload(self):
        for index in range(20):
            cid, pid = str(uuid.uuid4()), str(uuid.uuid4())
            self.sql(f'''INSERT INTO "Category"(category_id,name,slug,is_active,created_at,updated_at) VALUES('{cid}','Benchmark {index}','benchmark-{index}',true,now(),now());
                INSERT INTO "Podcast"(podcast_id,producer_profile_id,category_id,title,description,status,media_url,media_type,duration_seconds,is_exclusive,published_at,created_at,updated_at,row_version)
                VALUES('{pid}','{self.ids['creator_testProfile']}','{cid}','query-workload-{index}','Fixture','PUBLISHED','test-key','video/mp4',120,false,now(),now(),now(),0);''')
        offset=(TARGET/'server.log').stat().st_size
        result=self.get('/api/podcasts?q=query-workload&page=0&size=20','listener_test')
        time.sleep(.1)
        with (TARGET/'server.log').open('rb') as log:
            log.seek(offset); statements=log.read().count(b'Hibernate:')
        self.check(len(result['content'])==20,'Search workload returns 20 podcasts')
        self.check(all(item['title'].startswith('query-workload-') for item in result['content']),'Search filters workload correctly')
        self.check(0 < statements <= 4,'Search does not issue one category query per podcast')
        first=self.get('/api/podcasts?q=query-workload&page=0&size=10','listener_test')
        second=self.get('/api/podcasts?q=query-workload&page=1&size=10','listener_test')
        self.check(len({item['podcastId'] for item in first['content']+second['content']})==20,'Stable pagination has no duplicates')
        self.results.append({'case':'search SQL count (20 distinct categories)','passed':True,'sql_statements':statements})
    def run(self):
        for phase in [self.setup,self.categories_and_sources,self.listener,self.membership,self.moderation,
                self.finance_fixtures,self.user_access,self.matrix_and_read_catalog,self.query_workload,self.cleanup_api]:
            phase()
        self.post('/api/uploads','creator_test',upload=('fake.png','image/png',b'<script>alert(1)</script>'),expected=400,label='Reject spoofed image signature')
        self.post('/api/auth/register',None,{'username':'listener_test@example.test','email':'collision@example.test','password':PASSWORD,'displayName':'collision'},expected=409,label='Reject username colliding with existing email')
    def report(self,error=None):
        operations={m+' '+p for m,p in self.routes}
        summary={"date":"2026-10-13","operations":len(operations),"cases":len(self.results),
            "passed":sum(r['passed'] for r in self.results),"failed":sum(not r['passed'] for r in self.results),
            "routes_exercised":len(operations & self.covered),"routes_with_2xx":len(operations & self.success),
            "uncovered":sorted(operations-self.covered),"no_2xx":sorted(operations-self.success),"error":error,
            "storage":"local S3 stub; no real Cloudflare or bank calls","database":"isolated disposable PostgreSQL 18"}
        (TARGET/'results.json').write_text(json.dumps({"summary":summary,"cases":self.results},ensure_ascii=False,indent=2),encoding='utf-8')
        print(json.dumps(summary,ensure_ascii=False,indent=2),flush=True)


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--skip-build',action='store_true');args=parser.parse_args()
    env=os.environ.copy()
    config={}
    if (ROOT/'.env').exists():
        for line in (ROOT/'.env').read_text(encoding='utf-8-sig').splitlines():
            if line.strip() and not line.lstrip().startswith('#') and '=' in line:
                k,v=line.split('=',1);config[k.strip()]=v.strip().strip('"').strip("'")
    dburl=urllib.parse.urlparse(env.get('DB_URL',config.get('DB_URL','jdbc:postgresql://localhost:5432/Podcast_History')).removeprefix('jdbc:'))
    env.update(PGHOST=dburl.hostname or 'localhost',PGPORT=str(dburl.port or 5432),PGUSER=env.get('DB_USERNAME',config.get('DB_USERNAME','postgres')),
        PGPASSWORD=env.get('DB_PASSWORD',config.get('DB_PASSWORD','123456')))
    psql=env.get('PSQL_PATH') or shutil.which('psql') or r'C:\Program Files\PostgreSQL\18\bin\psql.exe'
    if not Path(psql).exists():raise SystemExit('Set PSQL_PATH to PostgreSQL 18 psql executable.')
    if not args.skip_build:
        subprocess.run([shutil.which('mvn') or 'mvn','-DskipTests','package'],cwd=ROOT,check=True)
    TARGET.mkdir(parents=True,exist_ok=True)
    db='podcast_history_api_test_'+uuid.uuid4().hex[:12]
    if not re.fullmatch(r'podcast_history_api_test_[a-f0-9]{12}',db):raise RuntimeError('Unsafe test database name')
    test=Regression(env,psql,db,unused_port());process=None;log=None;created=False
    storage=http.server.ThreadingHTTPServer(('127.0.0.1',0),S3Stub)
    threading.Thread(target=storage.serve_forever,daemon=True).start()
    try:
        test.sql(f'CREATE DATABASE "{db}";',database='postgres');created=True
        # Command-line properties override .env; no production datasource/storage configuration is used.
        appenv=env.copy();appenv['DB_PASSWORD']=env['PGPASSWORD'];appenv['JWT_SECRET']=JWT_SECRET
        command=['java','-jar',str(ROOT/'target/podcast-history-backend-0.0.1-SNAPSHOT.jar'),
            '--server.port='+test.base.rsplit(':',1)[1],'--spring.profiles.active=api-test',
            f'--spring.datasource.url=jdbc:postgresql://{env["PGHOST"]}:{env["PGPORT"]}/{db}',
            '--spring.datasource.username='+env['PGUSER'],'--spring.jpa.hibernate.ddl-auto=create',
            '--r2.endpoint=http://127.0.0.1:'+str(storage.server_port),'--r2.access-key-id=test-key',
            '--r2.secret-access-key=test-secret','--r2.bucket-name=regression','--r2.public-base-url=http://127.0.0.1:'+str(storage.server_port)+'/regression',
            '--spring.jpa.properties.hibernate.generate_statistics=true','--spring.jpa.show-sql=true','--logging.level.org.hibernate.stat=OFF',
            '--APP_CORS_ALLOWED_ORIGINS=http://localhost:*,http://127.0.0.1:*']
        log=(TARGET/'server.log').open('w',encoding='utf-8')
        process=subprocess.Popen(command,cwd=ROOT,env=appenv,stdout=log,stderr=subprocess.STDOUT)
        deadline=time.time()+90
        while time.time()<deadline:
            if process.poll() is not None:raise AssertionError('Application startup failed; see target/api-regression/server.log')
            try:
                with urllib.request.urlopen(test.base+'/api/health',timeout=2) as response:
                    if response.status==200:break
            except (urllib.error.URLError,TimeoutError):time.sleep(.5)
        else:raise AssertionError('Application readiness timed out')
        test.run();test.report()
        return 0
    except Exception as error:
        test.report(str(error));return 1
    finally:
        if process is not None:
            process.terminate()
            try:process.wait(timeout=15)
            except subprocess.TimeoutExpired:process.kill();process.wait(timeout=5)
        if log:log.close()
        storage.shutdown();storage.server_close()
        if created:test.sql(f'DROP DATABASE "{db}" WITH (FORCE);',database='postgres')

if __name__=='__main__':sys.exit(main())

