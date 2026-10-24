# Tài khoản test trên backend local

Các tài khoản này chỉ dành cho database phát triển. Backend mặc định dùng profile `dev` (`spring.profiles.default=dev`); khi khởi động, `DatabaseSeeder` chạy `Backend/src/main/resources/db/seeds/development_accounts.sql` để thêm tài khoản mẫu. Profile khác `dev` không nạp các tài khoản này.

| Role | Username | Email | Mật khẩu |
| --- | --- | --- | --- |
| ADMIN | `ph_admin` | `admin.podcasthistory@gmail.com` | `PhAdmin-7Qv3Kx2p!` |
| STAFF | `ph_staff01` | `staff01@podcasthistory.local` | `PhStaff01-t9Lq5R!x` |
| STAFF | `ph_staff02` | `staff02@podcasthistory.local` | `PhStaff02-z4Mn8C!v` |
| STAFF | `ph_staff03` | `staff03@podcasthistory.local` | `PhStaff03-K8v2LpQ!` |
| STAFF | `ph_staff04` | `staff04@podcasthistory.local` | `PhStaff04-H6x9RbD!` |
| STAFF | `ph_staff05` | `staff05@podcasthistory.local` | `PhStaff05-P3w7NcT!` |

Email Admin trong bảng là định danh đăng nhập mẫu, không khẳng định có hộp thư Gmail thật. Mật khẩu được lưu trong database dưới dạng BCrypt. Script seed dùng `ON CONFLICT DO NOTHING`, nên nếu tài khoản đã tồn tại và mật khẩu đã đổi, khởi động lại backend sẽ **không** đặt lại mật khẩu theo bảng này.

## Cách đăng nhập

Gọi `POST /api/auth/login` với `Content-Type: application/json`:

```json
{
  "identifier": "ph_staff01",
  "password": "PhStaff01-t9Lq5R!x"
}
```

Có thể dùng username hoặc email trong `identifier`. Lấy `accessToken` từ response rồi gửi `Authorization: Bearer <accessToken>` cho các API được bảo vệ. Gọi `GET /api/auth/me` để kiểm tra role trong token. Staff gọi các API dùng chung tại `/api/admin/dashboard`, `/api/admin/podcasts/**`, `/api/admin/reports/**` và `/api/admin/podcast-appeals/**`; các API `/api/admin/**` khác vẫn yêu cầu Admin. Khi nhận `401`, kiểm tra profile backend, database đang kết nối và mật khẩu tài khoản đã tồn tại; khi nhận `403`, kiểm tra role trong token.

Tài khoản `LISTENER` không được seed: tạo qua `POST /api/auth/register`. Muốn thử role `CREATOR`, dùng Listener nộp `POST /api/creator-applications`, Admin duyệt đơn, rồi đăng nhập lại để lấy token có role mới.

Không dùng các tài khoản/mật khẩu này trên môi trường public hoặc production. Nếu backend được đưa qua ngrok để người khác thử, hãy dùng database test riêng và không mở các tài khoản mẫu Admin/Staff ra ngoài.
