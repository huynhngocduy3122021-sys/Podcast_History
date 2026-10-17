"""Focused HTTP + PostgreSQL comment regression; isolated database and local S3 stub.
Run: python scripts/comment_regression.py [--skip-build] from Backend.
"""
from pathlib import Path
import sys
import api_regression as suite
suite.TARGET = Path(__file__).resolve().parents[1] / 'target/comment-regression'

def comments(self):
    self.setup()
    category = self.post('/api/admin/categories', 'admin_test', {'name': 'Comment fixtures', 'slug': 'comment-fixtures', 'active': True}, expected=201)
    self.ids['categoryId'] = category['categoryId']
    pid = self.create_podcast()
    self.publish(pid)
    self.sql('UPDATE public."Podcast" SET duration_seconds=1200 WHERE podcast_id=\'' + pid + "';")
    path = f'/api/podcasts/{pid}/comments'
    created = self.post(path, 'listener_test', {'content': 'Database persistence at minute 18', 'timestampSeconds': 1080}, expected=201)
    cid = created['commentId']
    persisted = self.sql('SELECT content||\'|\'||timestamp_seconds::text FROM public."Comment" WHERE comment_id=\'' + cid + "';")
    self.check(persisted == 'Database persistence at minute 18|1080', 'POST persists content and 1080 seconds in PostgreSQL')
    listing = self.get(path, 'listener_test')['content']
    self.check(any((c['commentId'] == cid and c['timestampSeconds'] == 1080 for c in listing)), 'Fresh GET returns persisted comment and timestamp')
    self.call('PUT', f'/api/comments/{cid}', 'listener_test', {'content': 'Edited text'})
    self.check(self.sql('SELECT timestamp_seconds FROM public."Comment" WHERE comment_id=\'' + cid + "';") == '1080', 'Editing text preserves saved video position')
    self.post(path, 'listener_test', {'content': 'negative', 'timestampSeconds': -1}, expected=400)
    self.post(path, 'listener_test', {'content': 'too far', 'timestampSeconds': 1201}, expected=400)
    self.post(path, 'listener_test', {'content': '   ', 'timestampSeconds': 0}, expected=400)
    self.post(path, 'listener_test', {'content': 'No timestamp'}, expected=201)
    self.post(path, None, {'content': 'Anonymous'}, expected=401)
    self.call('DELETE', f'/api/comments/{cid}', 'listener_test', expected=204)
    self.check(self.sql('SELECT status FROM public."Comment" WHERE comment_id=\'' + cid + "';") == 'DELETED', 'Delete soft-deletes the persisted DB row')
if __name__ == '__main__':
    suite.Regression.run = comments
    sys.exit(suite.main())
