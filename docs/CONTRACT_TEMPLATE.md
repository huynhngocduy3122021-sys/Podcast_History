# HỢP ĐỒNG CUNG CẤP VÀ SẢN XUẤT NỘI DUNG SỐ

> Mẫu hợp đồng phiên bản 6 dùng cho hợp đồng tạo mới. Backend lưu bản nội dung và hash riêng khi tạo hợp đồng; hợp đồng đã tạo giữ nguyên bản đã ký. FE hiển thị `contentSnapshot` từ `GET /api/requests/{requestId}/contract` khi ký.

**Mã hợp đồng:** [CONTRACT_ID]  
**Ngày lập:** [CREATED_AT]  
**Hình thức giao kết:** Hợp đồng điện tử thông qua nền tảng [APP_NAME]

## ĐIỀU 1. THÔNG TIN CÁC BÊN

**BÊN A – NGƯỜI ĐẶT HÀNG (LISTENER)**

- Họ và tên: [LISTENER_NAME]
- Mã tài khoản: [LISTENER_ID]
- Email: [LISTENER_EMAIL]

**BÊN B – NGƯỜI SÁNG TẠO NỘI DUNG (CONTENT CREATOR)**

- Họ và tên: [CREATOR_NAME]
- Mã tài khoản: [CREATOR_ID]
- Email: [CREATOR_EMAIL]
- Kênh sáng tạo nội dung: [CREATOR_CHANNEL]

Hai bên tự nguyện thống nhất giao kết hợp đồng với các điều khoản sau.

## ĐIỀU 2. NỘI DUNG CÔNG VIỆC

2.1. Bên A thuê Bên B thực hiện sản phẩm nội dung số theo yêu cầu đã thống nhất.

- Tên dự án: [PROJECT_NAME]
- Loại sản phẩm: [AUDIO/VIDEO]
- Mô tả yêu cầu: [REQUEST_DESCRIPTION]
- Định dạng bàn giao: [FILE_FORMAT]
- Thời lượng hoặc khối lượng: [DURATION]
- Tiêu chí chất lượng tối thiểu: [ACCEPTANCE_CRITERIA]

2.2. Bên B thực hiện sản phẩm đúng yêu cầu, tiến độ và tiêu chí nghiệm thu đã được hai bên xác nhận.

2.3. Mọi thay đổi nội dung, phạm vi hoặc thời hạn phải được hai bên xác nhận trên hệ thống.

## ĐIỀU 3. GIÁ TRỊ HỢP ĐỒNG VÀ NGÂN SÁCH

3.1. Tổng giá trị hợp đồng là **[TOTAL_BUDGET] VND**.

3.2. Bên A tự lựa chọn ngân sách và dành toàn bộ ngân sách này cho hợp đồng.

3.3. Khi Bên B chấp nhận yêu cầu bằng cách gửi đề xuất các đợt, nền tảng tạm giữ toàn bộ ngân sách từ ví Bên A trong cùng giao dịch tạo đề xuất. Nếu số dư khả dụng không đủ, đề xuất không được tạo và yêu cầu tiếp tục chờ. Khoản đã giữ chỉ được giải ngân hoặc hoàn trả theo hợp đồng.

3.4. Tổng giá trị các đợt phải bằng đúng ngân sách đã giữ.

3.5. Mọi khoản trả Bên B và phí nền tảng được trích từ ngân sách; Bên A không trả thêm phí.

## ĐIỀU 4. PHÂN CHIA GIAI ĐOẠN

Hợp đồng có [MILESTONE_COUNT] đợt do Bên B đề xuất và Bên A xác nhận bằng chữ ký trên bản hợp đồng này.

| Đợt | Tên đợt | Nội dung bàn giao | Thời hạn | Giá trị |
|---|---|---|---|---|
[MILESTONE_ROWS]

Bên B chỉ bắt đầu sau khi Bên A xác nhận toàn bộ đề xuất.

## ĐIỀU 5. BÀN GIAO VÀ NGHIỆM THU

5.1. Bên B tải bản nháp audio/video lên hệ thống trước hạn đã thỏa thuận. Bản nháp phải được AI kiểm duyệt an toàn lời nói từ bản phiên âm trước khi Bên B xác nhận bàn giao cho Bên A. AI không đánh giá hình ảnh, âm nhạc, chất lượng kỹ thuật hoặc mức độ đáp ứng yêu cầu; các nội dung này do Bên A nghiệm thu. Thời điểm bàn giao được tính từ lúc Bên B xác nhận bàn giao, không tính từ lúc tải bản nháp.

5.2. Bên A có **03 ngày** kể từ bàn giao hợp lệ để phản hồi.

5.3. Bên A có thể chấp thuận và giải ngân; từ chối lần bàn giao hiện tại kèm lý do để Bên B làm lại trong phạm vi 03 lượt sửa mỗi đợt, tiền của đợt tiếp tục được giữ; hoặc yêu cầu dừng để thương lượng hay tranh chấp. Từ chối một lần bàn giao không tự động chấm dứt hợp đồng.

5.4. Bên A được yêu cầu chỉnh sửa tối đa **03 lần** cho mỗi đợt trên hệ thống. Khi hết lượt, hai bên có thể mở tranh chấp để xử lý bất đồng.

5.5. Chỉ được tự nghiệm thu sau 03 ngày khi Bên A đã chọn đồng ý điều kiện này lúc tạo yêu cầu, không phản hồi bản bàn giao trong thời hạn và không có tranh chấp mở.

5.6. Bên A đã từ chối hoặc yêu cầu sửa đúng hạn thì không được tự nghiệm thu chỉ vì hết giờ.

## ĐIỀU 6. THANH TOÁN VÀ PHÍ NỀN TẢNG

6.1. Đợt nghiệm thu: Bên B hưởng 80% giá trị đợt; nền tảng hưởng 20% phí dịch vụ.

6.2. Phí khấu trừ từ phần thanh toán Bên B, không thu thêm Bên A.

6.3. Ví dụ đợt 20.000 VND: Bên B nhận 16.000 VND; nền tảng nhận 4.000 VND.

6.4. Mỗi đợt chỉ giải ngân một lần; không tính phí lại cho khoản đã giải ngân.

6.5. Rút tiền từ ví Creator theo quy trình payout của nền tảng.

## ĐIỀU 7. HỦY YÊU CẦU VÀ CHẤM DỨT HỢP ĐỒNG

7.1. Trước khi cả hai bên ký và hợp đồng có hiệu lực, Bên A được hủy yêu cầu. Nếu ngân sách đã được tạm giữ khi Bên B gửi đề xuất, nền tảng hoàn toàn bộ khoản còn giữ cho Bên A; hợp đồng chưa có hiệu lực và các đợt đề xuất bị hủy.

7.2. Sau khi hợp đồng có hiệu lực, bất đồng về việc thực hiện hoặc nghiệm thu được xử lý theo Điều 8. Kết luận bên thắng làm chấm dứt toàn bộ hợp đồng, kể cả khi tranh chấp chỉ liên quan một đợt. Không áp dụng khoản đền công cố định 30% hoặc phí 10% cho kết luận tranh chấp theo hợp đồng này.

7.3. Các đợt đã nghiệm thu và giải ngân trước khi chấm dứt giữ nguyên; không giải ngân hoặc khấu trừ phí lần thứ hai. Nhấn “Từ chối” bản bàn giao không tự động hủy hợp đồng hoặc quyết toán ngân sách.

## ĐIỀU 8. TRANH CHẤP

8.1. Toàn bộ ngân sách chưa giải ngân tiếp tục được giữ trong thời gian tranh chấp; không nghiệm thu hoặc giải ngân đợt đang tranh chấp cho đến khi vụ việc được rút hoặc giải quyết.

8.2. Listener hoặc CC có thể mở tranh chấp cho toàn hợp đồng hoặc một đợt. Hệ thống thông báo cho bên còn lại; bên đó có 03 ngày để xác nhận. Bên mở có thể rút tranh chấp trước khi bên còn lại xác nhận và trước khi hết hạn; khi đó hợp đồng tiếp tục theo trạng thái trước tranh chấp. Nếu bên còn lại không xác nhận đúng hạn, bên mở thắng. Nếu xác nhận, Staff xử lý trên hồ sơ và chứng cứ; Admin được xem và có thể xử lý khi cần.

8.3. Người xử lý xem yêu cầu, tiêu chí nghiệm thu, sản phẩm, lịch sử sửa, thời gian và bằng chứng hai bên. Khi có quyết định bên thắng, hợp đồng chấm dứt kể cả tranh chấp chỉ liên quan một đợt. Nếu Listener thắng, toàn bộ số tiền còn giữ trong ngân sách hợp đồng, gồm phần đợt đang làm và các đợt chưa làm, được hoàn vào ví Listener, không khấu trừ phí. Các đợt đã giải ngân trước đó không bị thu hồi.

8.4. Nếu CC thắng, toàn bộ số tiền còn giữ trong ngân sách hợp đồng, gồm phần đợt đang làm và các đợt chưa làm, được quyết toán một lần: CC nhận 80%, nền tảng ghi nhận phí 20% từ khoản này. Hợp đồng chấm dứt, các đợt chưa hoàn thành bị hủy. Khoản đã giải ngân trước đó không được giải ngân hoặc tính phí lại. Quyết định và giao dịch được ghi vào lịch sử.

8.5. Quyết định nội bộ không làm mất quyền khiếu nại, khởi kiện hoặc yêu cầu cơ quan có thẩm quyền.

## ĐIỀU 9. QUYỀN SỞ HỮU TRÍ TUỆ

9.1. Bên B cam kết sản phẩm không xâm phạm quyền bên thứ ba.

9.2. Sau khi đợt tương ứng đã được nghiệm thu và thanh toán đủ, Bên A được sử dụng và đăng tải sản phẩm được bàn giao của đợt đó cho mục đích phi thương mại. Việc chỉnh sửa, phân phối lại, sử dụng thương mại hoặc chuyển giao quyền tài sản ngoài phạm vi này phải được hai bên thỏa thuận riêng và xác nhận trên hệ thống.

9.3. Quyền sử dụng quy định tại khoản 9.2 phát sinh sau khi đợt tương ứng được nghiệm thu và thanh toán đủ.

9.4. Việc CC nhận tiền do thắng tranh chấp không tự động được coi là Bên A đã nghiệm thu sản phẩm chưa được duyệt. Quyền sử dụng sản phẩm chưa nghiệm thu hoặc chưa thanh toán tuân theo thỏa thuận riêng và quy định pháp luật.

## ĐIỀU 10. TRÁCH NHIỆM

Bên A cung cấp yêu cầu rõ ràng, bảo đảm ngân sách, phản hồi đúng hạn và không sử dụng trái phép sản phẩm chưa được cấp quyền.

Bên B thực hiện, bàn giao, chỉnh sửa đúng thỏa thuận và bảo đảm quyền sử dụng hợp pháp tài nguyên.

## ĐIỀU 11. HIỆU LỰC VÀ XÁC NHẬN ĐIỆN TỬ

11.1. Hợp đồng có hiệu lực khi cả hai bên xác nhận trên hệ thống và ngân sách đã được giữ.

11.2. Hệ thống ghi thời điểm xác nhận, mã tài khoản, phiên bản và bằng chứng giao kết.

11.3. Sửa đổi hợp đồng phải được cả hai bên xác nhận.

11.4. Hợp đồng kết thúc khi mọi nghĩa vụ và ngân sách đã được phân bổ hoặc hoàn trả.

**XÁC NHẬN BÊN A – LISTENER:** [LISTENER_ID], [LISTENER_SIGNED_AT]

**XÁC NHẬN BÊN B – CONTENT CREATOR:** [CREATOR_ID], [CREATOR_SIGNED_AT]

**Mã phiên bản hợp đồng:** [CONTRACT_VERSION]
