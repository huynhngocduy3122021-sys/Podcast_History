# whisper-service

Dịch vụ HTTP nội bộ nhận signed URL R2 từ backend, phiên âm audio/video bằng `faster-whisper` và trả JSON. Mặc định chỉ lắng nghe `127.0.0.1:8092`.

Trong PowerShell ở thư mục gốc dự án:

```powershell
.\whisper-service\.venv\Scripts\python.exe -m pip install -r .\whisper-service\requirements.txt
$env:WHISPER_MEDIA_HOST = "<ACCOUNT_ID>.r2.cloudflarestorage.com"
$env:WHISPER_SERVICE_TOKEN = "chuoi-bi-mat-dung-chung-voi-backend"
.\whisper-service\.venv\Scripts\python.exe .\whisper-service\server.py
```

`WHISPER_MEDIA_HOST` là hostname trong `R2_ENDPOINT`, không có `https://`. Token tương ứng với `WHISPER_SERVICE_TOKEN` trong `Backend/.env`. Nếu backend và Whisper cùng máy, `WHISPER_SERVICE_URL=http://127.0.0.1:8092`. Nếu chạy khác máy, cần cấu hình địa chỉ mạng riêng và giới hạn truy cập phù hợp trước khi đổi địa chỉ bind trong `server.py`.

Có thể đổi `WHISPER_MODEL` (mặc định `small`) và `WHISPER_LANGUAGE` (mặc định `vi`; đặt rỗng để tự phát hiện). File media giới hạn 100 MB. Máy chạy service cần có khả năng tải model trong lần chạy đầu.
