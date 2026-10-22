# ChamCongFlu — Chấm công NFC

Ứng dụng Flutter chấm công offline cho xưởng CNC. Ghi mốc thời gian bằng nút bấm hoặc thẻ NFC, theo dõi ba tiến trình độc lập: làm việc, thiết kế và CNC. Ứng dụng không tính tiền.

## Chức năng trong source

- Hôm nay: 7 trigger và timeline cho ba tiến trình.
- Lịch sử: xem, thêm, sửa, xóa sự kiện; tổng hợp thời lượng và cảnh báo chuỗi event bất thường.
- Thẻ NFC: gán UID, đổi tên và bật/tắt tag.
- SQLite cục bộ.
- Đọc UID NFC ở foreground, tra tag trong database và chống đọc lặp cùng UID trong 2 giây.
- Có code native NFC background trong scripts/bootstrap_android.ps1; cần chạy script và xác minh trên thiết bị, chưa mặc định là đã hoạt động.
- Backup/restore JSON vào thư mục người dùng chọn qua Android Storage Access Framework.

## Clone và chạy trên Windows

Cần Flutter stable, Android Studio, Android SDK và JDK phù hợp Android Gradle Plugin của repo. Mở PowerShell tại thư mục gốc có pubspec.yaml.

    flutter doctor
    flutter pub get
    powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap_android.ps1
    flutter analyze
    flutter test
    flutter build apk --debug
    flutter run

Script tạo Android host nếu chưa có. Nếu android/ đã tồn tại, script vá cấu hình NFC/backup và ghi lại MainActivity.kt. Sau khi chạy, kiểm tra thay đổi bằng:

    git status --short
    git diff -- android

Trong Android Studio, mở thư mục repository chứa pubspec.yaml. Kết nối thiết bị Android có NFC, bật USB debugging và chọn thiết bị.

## Thẻ mặc định và dữ liệu

Source hiện có 7 UID cụ thể trong lib/data/default_tags.dart; các thẻ mặc định được nạp cùng database mới. Nếu repo để public, UID này cũng công khai. Đối chiếu từng thẻ vật lý với trigger trong tab Thẻ trước khi dùng thật.

Dữ liệu SQLite nằm trong vùng riêng của app và có thể mất khi gỡ cài đặt. Bật backup bằng cách chọn thư mục ngoài app và thử khôi phục trước khi lưu dữ liệu quan trọng. Android có thể yêu cầu chọn lại thư mục sau khi cài lại.

## Checklist kiểm thử thiết bị

1. Kiểm tra cả 7 trigger và quy tắc ba tiến trình độc lập.
2. Xác nhận thẻ chưa đăng ký/thẻ bị tắt không ghi event; đọc lặp không nhân đôi.
3. Sửa/xóa event và xác nhận tổng thời lượng cùng cảnh báo cập nhật.
4. Thử NFC khi app mở, app khác foreground, Home và màn hình khóa đang sáng.
5. Xác nhận không có app chooser ngoài dự kiến hoặc ảnh hưởng ứng dụng NFC khác.
6. Chọn thư mục backup, tạo dữ liệu, restore vào database trống và database đã có dữ liệu.
7. Thử backup lỗi/mất quyền và cài lại app.

**Lưu ý NFC:** filter Android dựa trên TECH_DISCOVERED + NfcA, khá rộng. Từ chối UID lạ ở tầng Dart không ngăn Android mở app do một thẻ không liên quan. Phải kiểm tra hành vi thực tế trước khi coi tương thích NFC đạt.

## CI và kiểm thử

Workflow GitHub Actions hiện chạy flutter pub get, flutter analyze và flutter test trên Ubuntu. Nó chưa thay thế bootstrap PowerShell, build Android trên máy phát triển hoặc test NFC/backup trên thiết bị thật.

test/widget_test.dart hiện là placeholder; độ phủ cho UI, backup/restore và NFC native còn cần bổ sung.

## Tài liệu

- [PROGRESS.md](PROGRESS.md) — những gì có trong source và cần xác minh.
- [PROJECT.md](PROJECT.md) — quy tắc nghiệp vụ, kiến trúc và rủi ro kỹ thuật.
- [ROADMAP.md](ROADMAP.md) — milestone và tiêu chí hoàn tất.
