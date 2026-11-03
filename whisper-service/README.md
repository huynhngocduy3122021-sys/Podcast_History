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

## Cấu hình CPU hiện tại

Mặc định dùng model `small`, CPU `int8`, 4 luồng và `beam_size=1` để phù hợp máy Ryzen 3 5300U (4 nhân). So với `beam_size=3` trước đây, cách này có thể nhanh hơn nhưng cũng có thể giảm độ chính xác của transcript. Service ghi thời gian tải media và phiên âm vào console sau mỗi lần xử lý; kiểm tra hai số này trước khi tiếp tục tối ưu.

Nếu cần ưu tiên độ chính xác như cũ, đặt `$env:WHISPER_BEAM_SIZE = "3"` rồi khởi động lại service. Nếu muốn thử model nhẹ hơn, đặt `$env:WHISPER_MODEL = "base"` và đối chiếu transcript cùng một video trước khi dùng cho kiểm duyệt. Có thể đổi số luồng qua `WHISPER_CPU_THREADS`; không nên đặt quá số nhân vật lý khi chạy một job.

## Chạy bằng GPU

Trên máy có GPU NVIDIA tương thích CUDA, cài CUDA/cuDNN theo [hướng dẫn của faster-whisper](https://github.com/SYSTRAN/faster-whisper#gpu), rồi khởi động service với:

```powershell
$env:WHISPER_DEVICE = "cuda"
$env:WHISPER_COMPUTE_TYPE = "float16"
python .\whisper-service\server.py
```

`WHISPER_DEVICE` mặc định là `cpu`; `WHISPER_COMPUTE_TYPE` mặc định là `int8` trên CPU và `float16` khi chọn CUDA. Có thể dùng `int8_float16` trên GPU nếu cần giảm bộ nhớ. Khởi động lại whisper-service sau khi đổi biến môi trường. Kiểm tra CUDA trước bằng `nvidia-smi`; nếu không có GPU tương thích, giữ cấu hình CPU. Backend vẫn gọi service qua `WHISPER_SERVICE_URL` như cũ.
