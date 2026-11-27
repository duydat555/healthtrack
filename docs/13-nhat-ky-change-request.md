# Quy trình Change Request và nhật ký

Mọi thay đổi **phạm vi** (thêm, bớt, đổi tính năng đã chốt trong Charter hoặc AC của task P0) đều phải qua Change Request (CR). Sửa lỗi và việc nằm sẵn trong AC thì không cần CR.

## Ban kiểm soát thay đổi (CCB)
| Vai trò | Thành viên | Quyền |
|---|---|---|
| Chủ trì | Lê Duy Đạt (PM) | Triệu tập, ghi quyết định |
| Thành viên | Đặng Ngọc Tân, Huỳnh Thanh Thuận, Nguyễn Văn Tài | Phân tích ảnh hưởng, bỏ phiếu |
| Đại diện stakeholder (PO) | Người của CLB (cần bổ sung tên) | Xác nhận giá trị nghiệp vụ, có quyền phủ quyết với CR do mình đề xuất |

Hợp lệ khi có ít nhất 3 thành viên nhóm, trong đó có PM, và có ý kiến của PO. Quyết định theo đa số; hòa thì PM quyết, nhưng phải ghi rõ lý do.

## Quy trình
1. **Đề xuất:** ai cũng tạo issue bằng mẫu *Change Request* (`.github/ISSUE_TEMPLATE/change_request.yml`), tiêu đề bắt đầu bằng `CR:`, nhãn `change-request`, mặc định quyết định là "Chờ duyệt".
2. **Phân tích ảnh hưởng:** người đề xuất cùng Tech Lead ghi vào issue: task nào bị ảnh hưởng, thêm hay bớt bao nhiêu story point, rủi ro mới, tác động tới WBS (`docs/06`).
3. **Họp CCB:** PM triệu tập ngắn (có thể trao đổi trong chính issue). Mỗi thành viên ghi một bình luận `Đồng ý` hoặc `Từ chối` kèm lý do.
4. **Quyết định:** PM cập nhật trường *Quyết định của CCB* thành **Chấp thuận** hoặc **Từ chối**, ghi ngày và lý do vào bình luận cuối.
5. **Thực hiện:** nếu chấp thuận, PM tạo hoặc sửa task, cập nhật WBS và bảng rủi ro, gắn nhãn `change-request` cho task liên quan. Nếu từ chối, đóng issue với lý do.
6. **Ghi nhật ký:** PM thêm một dòng vào bảng bên dưới trong cùng PR cập nhật tài liệu.

## Quy tắc
- Mọi CR phải có quyết định ghi rõ (Chấp thuận hoặc Từ chối). CR ở trạng thái "Chờ duyệt" không được bắt đầu làm.
- CR làm tăng phạm vi phải nói rõ bỏ việc nào, hoặc chấp nhận kéo dài Phase, vì nhóm chỉ có 4 người.
- Task P0 đã đóng không được tự ý đổi AC; muốn đổi phải có CR.

## Nhật ký
> Lưu ý CR-01: CCB hợp lệ cần có ý kiến của PO (xem phần trên). Đến ngày cập nhật chưa có ý kiến đó, nên quyết định mới là của PM; không ghi là CCB đã duyệt.

| Mã CR | Ngày | Nội dung | Ảnh hưởng | Quyết định | Issue |
|---|---|---|---|---|---|
| CR-01 | 27/11/2026 | Thêm nhóm tính năng hoạt động ngoài trời: ghi quãng đường bằng Apple Maps, ảnh ghép chia sẻ, lịch sử, API, huy hiệu vận động | Thêm Phase 8 (14 task, 68 SP), nhánh WBS 7.0, rủi ro R16 đến R19 | **PM chấp thuận** (Lê Duy Đạt, 27/11/2026) và đã bắt đầu thực hiện; **chưa có ý kiến của Product Owner**, cần bổ sung vào issue #237 trước khi coi CCB đã đủ điều kiện | #237 |
