# Tài khoản dùng cho phát triển

> Các thông tin dưới đây chỉ dùng cho database local của nhóm. Không dùng những mật khẩu này trên môi trường thật.

Khi khởi động backend với profile `dev` (profile mặc định), `DatabaseSeeder` tạo các role và chạy script [development_accounts.sql](../Backend/src/main/resources/db/seeds/development_accounts.sql). Script dùng `ON CONFLICT DO NOTHING`, nên chạy lại mỗi lần khởi động không tạo bản ghi trùng và không ghi đè tài khoản đã tồn tại.

| Vai trò | Username | Email đăng nhập | Mật khẩu |
|---|---|---|---|
| ADMIN | `ph_admin` | `admin.podcasthistory@gmail.com` | `PhAdmin-7Qv3Kx2p!` |
| STAFF | `ph_staff01` | `staff01@podcasthistory.local` | `PhStaff01-t9Lq5R!x` |
| STAFF | `ph_staff02` | `staff02@podcasthistory.local` | `PhStaff02-z4Mn8C!v` |
| STAFF | `ph_staff03` | `staff03@podcasthistory.local` | `PhStaff03-K8v2LpQ!` |
| STAFF | `ph_staff04` | `staff04@podcasthistory.local` | `PhStaff04-H6x9RbD!` |
| STAFF | `ph_staff05` | `staff05@podcasthistory.local` | `PhStaff05-P3w7NcT!` |

Email Admin là địa chỉ mẫu dùng làm định danh đăng nhập trong database; đây không phải hộp thư Gmail đã được đăng ký. Email staff thuộc domain local. Tất cả tài khoản có `is_active=true`, mật khẩu được lưu dưới dạng BCrypt, và `is_verified=false` vì email chưa được xác minh.

Tài khoản `STAFF` đăng nhập qua `POST /api/auth/login` giống các role khác. Role này không có quyền gọi `/api/admin/**`; chỉ role `ADMIN` được phép. Đăng nhập bằng username hoặc email cùng mật khẩu ở bảng trên.

Chạy backend local từ thư mục `Backend`:

```powershell
mvn spring-boot:run
```

Nếu đã đặt `SPRING_PROFILES_ACTIVE` trong `Backend/.env`, dùng `dev` để bật tài khoản mẫu. Môi trường thật cần đặt profile `prod` để seeder không tạo các tài khoản phát triển.
