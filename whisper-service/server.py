"""Local HTTP adapter for faster-whisper. Start with: python server.py"""

import json
import os
import tempfile
import threading
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from faster_whisper import WhisperModel

MODEL_NAME = os.getenv("WHISPER_MODEL", "small")
LANGUAGE = os.getenv("WHISPER_LANGUAGE", "vi") or None
MEDIA_HOST = os.getenv("WHISPER_MEDIA_HOST", "").lower()
TOKEN = os.getenv("WHISPER_SERVICE_TOKEN", "")
MAX_BYTES = 100 * 1024 * 1024
model = None
model_lock = threading.Lock()


def transcribe(url):
    parsed = urllib.parse.urlparse(url)
    if not MEDIA_HOST or parsed.scheme != "https" or parsed.hostname != MEDIA_HOST:
        raise ValueError("Media URL must use the configured HTTPS R2 host")
    global model
    with tempfile.TemporaryDirectory(prefix="whisper-media-") as directory:
        media = Path(directory) / "media"
        request = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(request, timeout=60) as source, media.open("wb") as target:
            size = 0
            while chunk := source.read(1024 * 1024):
                size += len(chunk)
                if size > MAX_BYTES:
                    raise ValueError("Media exceeds 100 MB")
                target.write(chunk)
        if size == 0:
            raise ValueError("Media is empty")
        with model_lock:
            if model is None:
                model = WhisperModel(MODEL_NAME, device="cpu", compute_type="int8")
            segments, info = model.transcribe(
                str(media), language=LANGUAGE, beam_size=3, vad_filter=True
            )
            parts = [
                {"start": round(item.start, 3), "end": round(item.end, 3), "text": item.text.strip()}
                for item in segments if item.text.strip()
            ]
        return {
            "fullText": "\n".join(item["text"] for item in parts),
            "segments": parts,
            "language": info.language,
            "modelName": "faster-whisper-" + MODEL_NAME,
        }


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != "/transcribe":
            return self.reply(404, {"error": "Not found"})
        if TOKEN and self.headers.get("Authorization") != "Bearer " + TOKEN:
            return self.reply(401, {"error": "Unauthorized"})
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length <= 0 or length > 4096:
                raise ValueError("Invalid request size")
            payload = json.loads(self.rfile.read(length))
            return self.reply(200, transcribe(payload["mediaUrl"]))
        except (ValueError, KeyError) as error:
            return self.reply(400, {"error": str(error)})
        except Exception as error:
            return self.reply(500, {"error": str(error)})

    def reply(self, status, payload):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", int(os.getenv("WHISPER_PORT", "8092"))), Handler).serve_forever()
