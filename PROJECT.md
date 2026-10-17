# Cấu trúc và quy tắc nghiệp vụ

## Ba tiến trình độc lập, bảy trigger

| Tiến trình | Bắt đầu | Kết thúc |
|---|---|---|
| Làm việc | Trigger 1 | Trigger 2 |
| Thiết kế file | Trigger 3 | Trigger 4 |
| Máy CNC | Trigger 5 | Trigger 6 (tại máy) hoặc 7 (xác nhận tại bàn) |

- Các tiến trình chạy song song, không tự đóng lẫn nhau.
- Một lần bắt đầu cần có sự kiện kết thúc tương ứng; trong ngày có thể lặp nhiều lần.
- Trigger 6 và 7 đều kết thúc tiến trình CNC.
- Trạng thái suy ra từ sự kiện trong database, không giữ riêng trong RAM.
- Ngoại lệ như quên kết thúc hoặc sai giờ được xử lý ở Lịch sử.
- Không tính tiền; chỉ tổng hợp thời gian.

## Kiến trúc

- `lib/domain/`: luật nghiệp vụ thuần Dart, trigger và controller.
- `lib/data/`: SQLite và repository.
- `lib/nfc/`: đọc UID qua nfc_manager.
- `lib/ui/`: Home/timeline, Lịch sử, quản lý thẻ.
- `test/`: unit test luật nghiệp vụ.

## Database

Database offline tên `chamcong_v2.db`.

Bảng `tag`: id, name, trigger_type, uid, active. UID là duy nhất nếu đã gán; thẻ hỏng có thể thay UID mà không đổi Tag ID.

Bảng `event`: id tự tăng, tag_id (có thể null), trigger_type, ts (epoch milliseconds).

Bảy tag mặc định chưa có UID:

| Tag | Trigger mặc định |
|---|---|
| TAG-001 | Bắt đầu làm việc |
| TAG-002 | Kết thúc làm việc |
| TAG-003 | Bắt đầu thiết kế |
| TAG-004 | Kết thúc thiết kế |
| TAG-005 | Bắt đầu máy CNC |
| TAG-006 | Kết thúc CNC (vị trí 1) |
| TAG-007 | Kết thúc CNC (vị trí 2) |

Trigger mặc định của TAG-001 đến TAG-005 dựa trên thứ tự thường gặp, cần kiểm tra khi gán thẻ.

## Giới hạn cần kiểm thử

- Tiến trình bắt đầu hôm trước mà chưa kết thúc: Home ngày mới coi như chưa chạy; xử lý ở Lịch sử.
- Timeline cố định 06:00–22:00.
- Quét thẻ chỉ hoạt động khi app đang mở.
- Thời gian sửa trong Lịch sử chọn đến phút.
