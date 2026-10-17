# Tiến độ chuyển sang repo Flutter sạch

## Đã chuyển
- [x] Entry point và điều hướng 3 tab.
- [x] Services, NFC UID flow, chống đọc lặp cùng UID trong 2 giây.
- [x] SQLite schema, repository, 7 tag mặc định.
- [x] Domain logic/controller và unit test.
- [x] Home/timeline, lịch sử, quản lý thẻ.
- [x] Loại bỏ khỏi repo mới các file Android native ở root và Gradle config xung đột.

## Còn cần làm trên máy phát triển
- [ ] Tạo Android host bằng `flutter create --platforms=android .`.
- [ ] Thêm permission/feature NFC vào AndroidManifest.
- [ ] `flutter pub get`, `flutter analyze`, `flutter test`.
- [ ] Chạy thử trên Galaxy S23 và xác nhận NFC thật.
- [ ] `flutter build apk --debug`.

Mã nguồn được chuyển từ nhánh `flutter-testable` của repo cũ. Việc chuyển file chưa thay thế cho kiểm thử compile/runtime trên máy.
