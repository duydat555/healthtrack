# Kế hoạch kiểm thử

## Cấp độ
| Cấp | Công cụ | Phạm vi | Chủ trì |
|---|---|---|---|
| Unit / Widget | pytest, flutter_test | Hàm, service, widget | Từng dev |
| Integration | pytest + httpx, PostgreSQL | Endpoint với CSDL thật | Tân, Tài |
| E2E | Flutter integration_test trên iOS Simulator | Luồng đăng ký, ghi chỉ số, xem biểu đồ | Tài |
| Thiết bị | Thủ công trên Simulator iOS 26 và iOS 18 | Liquid Glass, bản dự phòng, Reduce Transparency | Tài |
| UAT | Thủ công với stakeholder | Luồng lõi theo Acceptance Criteria | Tài, Đạt |

## Ma trận kiểm thử (mẫu)
| Chức năng | Acceptance Criteria | Loại test | Trạng thái |
|---|---|---|---|
| Health check | `GET /health` trả 200 | Unit | Đạt |
| Đăng ký | Email trùng bị từ chối, mật khẩu được băm | Integration | Chưa làm |
| Ghi cân nặng | Chỉ thấy dữ liệu của chính mình | Integration | Chưa làm |
| Liquid Glass | iOS 26 hiện kính native, iOS cũ hiện bản dự phòng | Thiết bị | Chưa làm |
| Widget LiquidGlass | Không có channel thì dùng BackdropFilter | Widget | Đạt |

## Mục tiêu
Độ phủ backend từ 70%; CI chạy lint, test, build trên mọi PR. Ma trận đầy đủ do Tài hoàn thiện ở issue Phase 0.
