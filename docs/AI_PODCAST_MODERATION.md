# AI kiểm duyệt lời nói trong podcast

## Thiết lập

1. Chạy migration `Backend/db/migrations/2026-10-21_ai_podcast_moderation.sql`, sau đó `Backend/db/migrations/2026-10-21_podcast_transcript.sql`.
2. Điền `GEMINI_API_KEY` và `WHISPER_SERVICE_URL` trong `Backend/.env`. Mặc định Whisper chạy tại `http://127.0.0.1:8092`.
3. Cài và chạy `whisper-service` theo [hướng dẫn](../whisper-service/README.md). Backend và Whisper phải dùng cùng `WHISPER_SERVICE_TOKEN` nếu đặt token.
4. Cấu hình R2 và upload media bằng API hiện tại. Whisper chỉ nhận media lưu với object key R2.

## Luồng

1. Creator gọi `POST /api/creator/podcasts/{podcastId}/video` để upload video hoặc audio. Sau khi transaction lưu media thành công, backend tạo `Podcast_Transcript` trạng thái `PENDING`, rồi gọi Whisper ở tác vụ nền. API upload không chờ quá trình phiên âm.
2. Whisper tải file từ signed URL R2, phiên âm lời nói và trả về `fullText`, `segments` có thời điểm bắt đầu/kết thúc, ngôn ngữ và tên model. Backend lưu kết quả đúng với `media_key`. Upload file khác sẽ tạo transcript khác; transcript cũ không được dùng cho file mới.
3. Creator gọi `POST /api/creator/podcasts/{podcastId}/submit`. Backend tạo bản ghi AI `PENDING`. Nếu transcript đang chạy, AI đợi sự kiện Whisper hoàn tất. Khi transcript đã có, Gemini nhận tiêu đề, mô tả và transcript có timestamp; **không nhận video/audio**.
4. Admin/Staff gọi `GET /api/admin/podcasts/{podcastId}/transcript` để xem transcript hiện tại, và `GET /api/admin/podcasts/{podcastId}/ai-moderation?page=0&size=20` để xem feedback. Có thể thay `/api/admin/` bằng `/api/staff/`. `current=true` ở kết quả AI cho biết cả dữ liệu bài và transcript vẫn khớp.
5. Nếu Whisper lỗi, gọi `POST /api/admin/podcasts/{podcastId}/transcript` để thử lại. Nếu AI đã ghi `FAILED` hoặc `SKIPPED`, gọi tiếp `POST /api/admin/podcasts/{podcastId}/ai-moderation` sau khi transcript `COMPLETED`.
6. Admin nghe/xem media qua API preview rồi quyết định bằng approve/reject hiện có. Bản ghi `Moderation_Review` liên kết với feedback AI hoàn tất và còn khớp transcript.

## Trạng thái và giới hạn

- Transcript: `PENDING`, `PROCESSING`, `COMPLETED`, `FAILED`. Transcript rỗng tạo AI `SKIPPED` để Admin xử lý thủ công.
- AI: `PENDING`, `PROCESSING`, `COMPLETED`, `SKIPPED`, `FAILED`. `overallLabel` là `SAFE`, `UNSAFE` hoặc `UNCERTAIN`; `recommendation` là `APPROVE`, `REJECT` hoặc `REVIEW`.
- AI lần này **chỉ duyệt nội dung lời nói**. Nó không kiểm tra hình ảnh, chữ trong khung hình, nhạc hay âm thanh không phải lời nói. Admin vẫn là người quyết định cuối cùng.
- Tác vụ chạy trong tiến trình backend; sau khi backend khởi động lại giữa lúc xử lý, Admin có thể dùng các API retry nêu trên.
