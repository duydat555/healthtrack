# Kế hoạch UAT với stakeholder — Issue #83

## Mục tiêu và phạm vi

Xác nhận người dùng mục tiêu có thể hoàn thành các luồng cốt lõi của HealthTrack, hiểu dữ liệu hiển thị và nêu được vấn đề trước nghiệm thu. Kịch bản dựa trên Project Charter, ma trận `docs/09-ke-hoach-kiem-thu.md` và acceptance criteria của issue #83.

UAT cần ít nhất 10 người dùng thử bằng bản TestFlight hoặc máy demo. Bản app và backend phải cùng là phiên bản dự kiến nghiệm thu, đã có đủ tính năng trong phạm vi buổi thử (đặc biệt dashboard và nhắc nhở). Nếu TestFlight chưa sẵn sàng, dùng máy demo theo đúng phương án thay thế trong issue; không coi Simulator hay test tự động là thay thế cho 10 người thử thật.

## Chuẩn bị buổi thử

1. Chọn 10 người dùng mục tiêu/stakeholder; lưu mã `P01`–`P10`, không ghi tên thật hoặc thông tin liên hệ trong repo.
2. Ghi phiên bản app/commit, URL môi trường backend, ngày giờ và loại thiết bị. Đảm bảo backend hoạt động trước buổi thử.
3. Tạo tài khoản demo riêng cho từng người. Chỉ dùng email thử nghiệm và dữ liệu sức khỏe giả; không yêu cầu người tham gia nhập số liệu sức khỏe thật.
4. Giải thích mục tiêu, thời lượng khoảng 20–30 phút, cách ghi phản hồi và việc người tham gia có thể bỏ qua câu hỏi hoặc dừng thử.
5. Nhắc người tham gia không gửi mật khẩu, token, ảnh chứa thông tin cá nhân hoặc dữ liệu sức khỏe thật. Chụp màn hình lỗi chỉ khi đã loại bỏ thông tin định danh.
6. Điều phối viên quan sát, không hướng dẫn thao tác trừ khi người tham gia bị kẹt; ghi bước xảy ra lỗi và mã kịch bản.

## Kịch bản và kết quả mong đợi

| Mã | Thao tác người dùng | Kết quả mong đợi | AC liên quan | Trạng thái |
|---|---|---|---|---|
| UAT-01 | Đăng ký tài khoản thử với thông tin giả lập hợp lệ | Tài khoản được tạo và vào được app; lỗi nhập liệu có hướng dẫn dễ hiểu | Đăng ký / xác thực | Chưa thực hiện |
| UAT-02 | Đăng xuất rồi đăng nhập lại; thử nhập sai mật khẩu một lần | Đăng nhập đúng thành công; sai thông tin không vào app và có thông báo rõ | Đăng nhập / xác thực | Chưa thực hiện |
| UAT-03 | Mở Hồ sơ, cập nhật chiều cao giả lập | Thông tin được lưu và hiển thị lại sau khi tải lại màn hình | Hồ sơ | Chưa thực hiện |
| UAT-04 | Ghi cân nặng giả lập | Lưu thành công; cân nặng mới xuất hiện trên Tổng quan/Chỉ số và BMI chỉ hiện khi có chiều cao | Ghi chỉ số | Chưa thực hiện |
| UAT-05 | Ghi lượng nước giả lập | Tổng nước trong ngày cập nhật; biểu đồ 7 ngày phản ánh dữ liệu vừa ghi | Ghi chỉ số / dashboard | Chưa thực hiện |
| UAT-06 | Ghi giấc ngủ giả lập | Nhật ký xuất hiện trong danh sách/chỉ số; thời lượng hiển thị hợp lý | Ghi chỉ số | Chưa thực hiện |
| UAT-07 | Ghi số bước giả lập | Bản ghi được lưu và hiển thị trong danh sách bước chân | Ghi chỉ số | Chưa thực hiện |
| UAT-08 | Ghi một bữa ăn giả lập | Bữa ăn xuất hiện trong danh sách và tổng calories được cập nhật | Ghi chỉ số | Chưa thực hiện |
| UAT-09 | Tạo thuốc thử nghiệm rồi ghi nhận đã uống | Thuốc và nhật ký được lưu, hiển thị đúng trạng thái | Ghi chỉ số | Chưa thực hiện |
| UAT-10 | Đặt nhắc uống nước/thuốc, tắt rồi bật lại | Giờ và trạng thái bật/tắt được lưu; nếu quyền thông báo được cấp, thông báo thử đến đúng lịch | Nhắc nhở | Chưa thực hiện |
| UAT-11 | Xem Tổng quan và Chỉ số, tìm một giá trị vừa nhập | Người dùng tìm được số liệu và hiểu được nhãn/đơn vị/biểu đồ | Dashboard / biểu đồ | Chưa thực hiện |
| UAT-12 | Đăng xuất và kết thúc buổi thử | Phiên đăng nhập được đóng; người tham gia không còn thấy màn hình tài khoản | Bảo mật / hoàn tất | Chưa thực hiện |

Điều phối viên ghi **Đạt / Không đạt / Bỏ qua** cho từng kịch bản. Nếu một tính năng không có trong build UAT, chọn “Bỏ qua”, ghi rõ phiên bản/phụ thuộc còn thiếu và không tính kịch bản đó là đạt.

## Câu hỏi phản hồi sau khi thử

Chấm từ 1 (rất khó/không đồng ý) đến 5 (rất dễ/đồng ý):

1. Bạn thấy đăng ký và đăng nhập dễ thực hiện không?
2. Bạn có dễ tìm cách ghi cân nặng, nước, giấc ngủ, bước chân, bữa ăn và thuốc không?
3. Dashboard và biểu đồ có giúp bạn hiểu thay đổi theo thời gian không?
4. Nội dung, đơn vị và thông báo lỗi có dễ hiểu không?
5. Bạn có tin tưởng cách ứng dụng xử lý thông tin tài khoản và dữ liệu thử không?
6. Bạn có sẵn sàng dùng lại ứng dụng không?

Câu hỏi mở: thao tác khó nhất là gì; điều hữu ích nhất; điều cần sửa trước khi phát hành; lỗi hoặc nội dung gây nhầm lẫn nào đã gặp?

## Biểu mẫu ghi nhận 10 người dùng

Chỉ điền mã người dùng, không điền tên/email hoặc dữ liệu sức khỏe. Mỗi lượt có thể ghi thêm bảng phản hồi mở và bug log phía dưới.

| Mã | Ngày / giờ | Build / commit | Thiết bị / kênh | Kịch bản không đạt / bỏ qua | Mã lỗi | Hoàn tất? | Kết luận stakeholder |
|---|---|---|---|---|---|---|---|
| P01 | Chưa thực hiện | Chưa thực hiện | Chưa thực hiện | — | — | — | Chưa có ý kiến |
| P02 | Chưa thực hiện | Chưa thực hiện | Chưa thực hiện | — | — | — | Chưa có ý kiến |
| P03 | Chưa thực hiện | Chưa thực hiện | Chưa thực hiện | — | — | — | Chưa có ý kiến |
| P04 | Chưa thực hiện | Chưa thực hiện | Chưa thực hiện | — | — | — | Chưa có ý kiến |
| P05 | Chưa thực hiện | Chưa thực hiện | Chưa thực hiện | — | — | — | Chưa có ý kiến |
| P06 | Chưa thực hiện | Chưa thực hiện | Chưa thực hiện | — | — | — | Chưa có ý kiến |
| P07 | Chưa thực hiện | Chưa thực hiện | Chưa thực hiện | — | — | — | Chưa có ý kiến |
| P08 | Chưa thực hiện | Chưa thực hiện | Chưa thực hiện | — | — | — | Chưa có ý kiến |
| P09 | Chưa thực hiện | Chưa thực hiện | Chưa thực hiện | — | — | — | Chưa có ý kiến |
| P10 | Chưa thực hiện | Chưa thực hiện | Chưa thực hiện | — | — | — | Chưa có ý kiến |

## Nhật ký phản hồi và lỗi

| Mã | Người dùng | Kịch bản | Phản hồi / bước tái hiện | Mức độ | Issue theo dõi | Trạng thái |
|---|---|---|---|---|---|---|
| Chưa có | — | — | Chưa có phản hồi thực tế | — | — | Chưa thực hiện |

Mức độ lỗi: **P0** chặn sử dụng/nguy cơ dữ liệu; **P1** luồng cốt lõi hỏng; **P2** có cách tránh nhưng gây khó khăn; **P3** lỗi nhỏ hoặc góp ý. Khi phát hiện lỗi có thể tái hiện, tạo GitHub issue riêng, liên kết mã log ở đây và không ghi thông tin cá nhân vào issue.

## Tiêu chí tổng kết

- Có kết quả của ít nhất 10 người dùng thử, mỗi lượt ghi build, thiết bị/kênh và các kịch bản đã thử.
- Tổng hợp điểm phản hồi theo câu hỏi (số phản hồi, trung bình và ý kiến mở), nêu rõ số kịch bản đạt/không đạt/bỏ qua.
- Mọi lỗi tìm thấy có issue theo dõi hoặc có quyết định xử lý/không sửa được stakeholder ghi nhận.
- Kết luận nghiệm thu là **Chấp nhận**, **Chấp nhận có điều kiện** hoặc **Chưa chấp nhận**; đính kèm biên bản ký hoặc email xác nhận theo Project Charter.
- Không đổi các trạng thái “Chưa thực hiện” thành “Đạt” nếu chưa có phản hồi thật. Kết quả cuối cùng cần bổ sung sau các buổi UAT, không thể suy ra từ kế hoạch này.
