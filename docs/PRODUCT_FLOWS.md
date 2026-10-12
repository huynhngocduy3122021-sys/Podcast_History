# Luồng nghiệp vụ Podcast History

> Tài liệu này ghi lại các luồng nghiệp vụ do người dùng mô tả để làm căn cứ thiết kế API, database và giao diện. Nội dung mô tả nghiệp vụ hiện tại; trạng thái chi tiết và quy tắc triển khai sẽ được chốt khi xây dựng từng chức năng.

## Vai trò

- **Người dùng (Listener):** nghe podcast, tương tác, theo dõi creator, đăng ký hội viên kênh và gửi yêu cầu podcast.
- **Quản trị viên (Admin):** xem dashboard, quản lý người dùng, xử lý báo cáo/yêu cầu và duyệt nội dung cần can thiệp.
- **Nhà sáng tạo nội dung (CC / Content Creator):** đăng podcast, tương tác với người nghe, nhận yêu cầu làm podcast và quản lý thu nhập.

## 1. Người dùng

1. Đăng ký hoặc đăng nhập.
2. Vào trang chủ, tìm kiếm và khám phá podcast.
3. Phát và nghe podcast.
4. Tương tác với podcast: thích, bình luận (bao gồm bình luận theo thời gian thực) hoặc gửi báo cáo.
5. Theo dõi các nhà sáng tạo yêu thích.
6. Lưu podcast yêu thích vào playlist.
7. Có thể mua **gói thành viên của một kênh cụ thể** để ủng hộ creator. Quyền lợi thành viên gồm nghe nội dung độc quyền và gửi yêu cầu cho creator của kênh đó.

## 2. Quản trị viên

1. Đăng nhập bằng tài khoản Admin.
2. Xem các dashboard.
3. Quản lý người dùng và duyệt người dùng/đơn đăng ký trở thành Content Creator.
4. Xử lý báo cáo do người dùng gửi và các yêu cầu cần Admin giải quyết.
5. Podcast được AI kiểm duyệt tự động trước. Admin xem xét những podcast mà AI không duyệt được.

## 3. Nhà sáng tạo nội dung (CC)

1. Đăng nhập tài khoản CC.
2. Tạo và đăng podcast, sau đó chờ Admin duyệt podcast.
3. Tương tác với người dùng qua phần bình luận.
4. Có thể mua **gói Premium dành cho CC** để mở các quyền lợi: đăng podcast không giới hạn, tạo biểu mẫu tương tác với người dùng và livestream.

Gói Premium dành cho CC là gói của creator; gói thành viên ở mục Người dùng là gói hỗ trợ một kênh cụ thể. Đây là hai luồng gói dịch vụ khác nhau theo mô tả nghiệp vụ.

## 4. Podcast theo yêu cầu

1. Người dùng gửi yêu cầu podcast cho CC.
2. CC chấp nhận yêu cầu và thực hiện podcast.
3. Người dùng xem và đánh giá podcast được bàn giao.
4. Nếu người dùng phê duyệt một mốc, tiến hành thanh toán cho mốc đó.
5. Nếu podcast chưa đúng yêu cầu, người dùng có thể yêu cầu CC chỉnh sửa.
6. Kết thúc quy trình khi hoàn tất; Admin giải quyết trường hợp cần xử lý/tranh chấp.

## 5. Ví và rút tiền của CC

1. **Release Funds:** chuyển khoản thu nhập đã kiếm được sang số dư ví có thể rút.
2. CC kiểm tra số dư khả dụng.
3. Hệ thống ghi nhận giao dịch chuyển tiền vào ví.
4. CC gửi yêu cầu rút tiền.
5. Hệ thống xác thực số dư khả dụng và tài khoản thanh toán:
   - Nếu số dư hoặc tài khoản không hợp lệ, từ chối yêu cầu.
   - Nếu hợp lệ, giữ số tiền yêu cầu và bắt đầu xử lý thanh toán.
6. Ghi nhận kết quả chuyển tiền:
   - Thành công: ghi nhận giao dịch rút tiền thành công.
   - Thất bại: hoàn lại số tiền đang giữ vào số dư khả dụng và lưu kết quả thất bại.

## Ghi chú nghiệp vụ

- Chỉ giải ngân từng mốc podcast theo yêu cầu sau khi người dùng phê duyệt mốc đó.
- Khi rút tiền thất bại, số tiền đã giữ phải được hoàn lại để không làm mất số dư của CC.
- Luồng kiểm duyệt podcast có bước AI trước, Admin xử lý các trường hợp AI không duyệt được.
