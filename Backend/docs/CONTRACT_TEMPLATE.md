# HỢP ĐỒNG CUNG CẤP VÀ SẢN XUẤT NỘI DUNG SỐ

> Bản đã điền các điều khoản được chốt từ [mẫu gốc do người dùng cung cấp](CONTRACT_TEMPLATE_SOURCE.md). Backend đóng gói nội dung tại `src/main/resources/contracts/contract-v1.md` để tạo snapshot và lưu hai lần ký riêng. Bản mẫu này chưa phải một hợp đồng đã ký; bản ký cụ thể lấy từ `GET /api/requests/{requestId}/contract`.

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
- Loại sản phẩm: [AUDIO]
- Mô tả yêu cầu: [REQUEST_DESCRIPTION]
- Định dạng bàn giao: [FILE_FORMAT]
- Thời lượng hoặc khối lượng: [DURATION]
- Tiêu chí chất lượng tối thiểu: [ACCEPTANCE_CRITERIA]

2.2. Bên B thực hiện sản phẩm đúng yêu cầu, tiến độ và tiêu chí nghiệm thu đã được hai bên xác nhận.

2.3. Mọi thay đổi nội dung, phạm vi hoặc thời hạn phải được hai bên xác nhận trên hệ thống.

## ĐIỀU 3. GIÁ TRỊ HỢP ĐỒNG VÀ NGÂN SÁCH

3.1. Tổng giá trị hợp đồng là **[TOTAL_BUDGET] VND**.

3.2. Bên A tự lựa chọn ngân sách và dành toàn bộ ngân sách này cho hợp đồng.

3.3. Khi yêu cầu được tạo thành công, ngân sách sẽ được nền tảng tạm giữ để xử lý yêu cầu.
     
3.4. Tổng giá trị các đợt phải bằng đúng ngân sách đã giữ.

3.5. Mọi khoản trả Bên B và phí nền tảng được trích từ ngân sách; Bên A không trả thêm phí.

## ĐIỀU 4. PHÂN CHIA GIAI ĐOẠN

Hợp đồng có từ 01 đến 03 đợt (có thể thêm hoặc bớt) do Bên B đề xuất và Bên A xác nhận.

| Đợt | Nội dung bàn giao | Thời hạn | Giá trị |
|---|---|---|---|
| 1 | [MILESTONE_1_DESCRIPTION] | [DUE_DATE_1] | [AMOUNT_1] |
| 2 | [MILESTONE_2_DESCRIPTION] | [DUE_DATE_2] | [AMOUNT_2] |
| 3 | [MILESTONE_3_DESCRIPTION] | [DUE_DATE_3] | [AMOUNT_3] |

Các đợt không sử dụng được bỏ qua. Bên B chỉ bắt đầu sau khi Bên A xác nhận toàn bộ đề xuất.

## ĐIỀU 5. BÀN GIAO VÀ NGHIỆM THU

5.1. Bên B tải tệp lên hệ thống trước hạn đã thỏa thuận.

5.2. Bên A có **03 ngày** kể từ bàn giao hợp lệ để phản hồi.

5.3. Bên A có thể chấp thuận và giải ngân; từ chối lần bàn giao hiện tại kèm lý do để Bên B làm lại trong phạm vi 03 lượt sửa mỗi đợt, tiền của đợt sẽ tiếp tục được giữ; hoặc yêu cầu dừng để thương lượng hay tranh chấp. Từ chối một lần bàn giao không tự động chấm dứt hợp đồng.

5.4. Tối đa **03 lần** yêu cầu chỉnh sửa mỗi đợt, trừ khi hai bên có thỏa thuận khác về lỗi không đạt tiêu chí tối thiểu.

## ĐIỀU 6. THANH TOÁN VÀ PHÍ NỀN TẢNG

6.1. Đợt nghiệm thu: Bên B hưởng 80% giá trị đợt; nền tảng hưởng 20% phí dịch vụ.

6.2. Phí khấu trừ từ phần thanh toán Bên B, không thu thêm Bên A.

6.3. Ví dụ đợt 20.000 VND: Bên B nhận 16.000 VND; nền tảng nhận 4.000 VND.

6.4. Mỗi đợt chỉ giải ngân một lần; không tính phí lại cho khoản đã giải ngân.

6.5. Rút tiền từ ví Creator theo quy trình payout của nền tảng.

## ĐIỀU 7. CHẤM DỨT TRƯỚC HẠN

7.1. Hai bên có thể đề nghị chấm dứt khi không thể tiếp tục.

7.2. Nếu Bên B đã bàn giao sản phẩm đạt tiêu chí tối thiểu của đợt đang làm, khoản đền công có thể bằng 30% giá trị đợt theo quyết định chấm dứt hợp lệ.

7.3. Nền tảng khấu trừ 10% **khoản đền công của Bên B**, thay phí 20% thông thường trên cùng khoản đó.

7.4. Phần ngân sách chưa giải ngân được hoàn cho Bên A. Phí 10% nằm trong khoản đền công, không thu thêm Bên A.

7.5. Các đợt đã nghiệm thu và giải ngân giữ nguyên, không tính lại phí.

7.6. Chưa bàn giao hoặc sản phẩm không đạt tiêu chí tối thiểu thì khoản đền công 30% không tự động phát sinh; hoàn tiền theo thỏa thuận hoặc quyết định tranh chấp.

7.7. Nhấn “Từ chối” không tự động chấm dứt hoặc trả đền công.

## ĐIỀU 8. TRANH CHẤP

8.1. Tiền phần việc đang tranh chấp tiếp tục được giữ.

8.2. Hai bên ưu tiên thương lượng trong 03 ngày.

8.3. Admin xem yêu cầu, tiêu chí nghiệm thu, sản phẩm, lịch sử sửa, thời gian và bằng chứng hai bên.

8.4. Phân bổ tiền theo chính sách đã chấp thuận và ghi lý do, bằng chứng.

8.5. Quyết định nội bộ không làm mất quyền khiếu nại, khởi kiện hoặc yêu cầu cơ quan có thẩm quyền.

## ĐIỀU 9. QUYỀN SỞ HỮU TRÍ TUỆ

9.1. Bên B cam kết sản phẩm không xâm phạm quyền bên thứ ba.

9.2. Sau khi đợt tương ứng đã được nghiệm thu và thanh toán đủ, Bên A được sử dụng và đăng tải sản phẩm được bàn giao của đợt đó cho mục đích phi thương mại. Việc chỉnh sửa, phân phối lại, sử dụng thương mại hoặc chuyển giao quyền tài sản ngoài phạm vi này phải được hai bên thỏa thuận riêng và xác nhận trên hệ thống.

9.3. Quyền sử dụng quy định tại khoản 9.2 phát sinh sau khi đợt tương ứng được nghiệm thu và thanh toán đủ.

9.4. Sản phẩm chưa nghiệm thu hoặc chưa thanh toán phải tuân theo thỏa thuận riêng và quy định pháp luật.

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
