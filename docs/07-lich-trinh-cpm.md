# Phụ thuộc task và đường găng (CPM)

Dự án không ràng buộc theo lịch. Thứ tự làm việc xác định bởi phụ thuộc giữa các task, theo dõi bằng Velocity (story point hoàn thành mỗi lượt) và biểu đồ Burndown trên GitHub Projects.

```mermaid
flowchart LR
    P0[Phase 0<br/>Khởi tạo] --> P1[Phase 1<br/>Xác thực]
    P1 --> P2[Phase 2<br/>API chỉ số]
    P0 --> P3[Phase 3<br/>App iOS + Liquid Glass]
    P1 --> P3
    P2 --> P4[Phase 4<br/>Dashboard, nhắc nhở]
    P3 --> P4
    P4 --> P5[Phase 5<br/>Kiểm thử, deploy]
    P5 --> P6[Phase 6<br/>Nghiệm thu]
```

**Đường găng:** Phase 0 → 1 → 2 → 4 → 5 → 6. Phase 3 (giao diện) làm song song với Phase 2 và nối vào Phase 4.

Mỗi task ghi phụ thuộc trong mục "Phụ thuộc" của issue. Cần bổ sung Story Points qua Planning Poker và Velocity thực tế khi các lượt làm việc hoàn thành.
