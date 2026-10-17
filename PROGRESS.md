# Tiến độ chuyển sang repo Flutter sạch

## Đã chuyển
- [x] Entry point và điều hướng 3 tab.
- [x] Services, NFC UID flow, chống đọc lặp cùng UID trong 2 giây.
- [x] SQLite schema, repository, 7 tag mặc định.
- [x] Domain logic/controller và unit test.
- [x] Home/timeline, lịch sử, quản lý thẻ.
- [x] Loại bỏ khỏi repo mới các file Android native ở root và Gradle config xung đột.

## Sửa lỗi build
- [x] **2026-10-17** — Lỗi `nfc_manager is currently compiled against android-31`: bản 3.5.x biên dịch với SDK 31, thấp hơn mức các thư viện androidx hiện tại yêu cầu. Đã nâng `nfc_manager` lên `^4.1.1` (có namespace, hỗ trợ SDK mới) và viết lại `lib/nfc/nfc_service.dart` theo API 4.x: `checkAvailability()`, `startSession(pollingOptions: {NfcPollingOption.iso14443}, ...)`, UID lấy từ `NfcTagAndroid.from(tag)?.id`. API công khai của `NfcService` (`isAvailable`, `start`, `stop`, `isRunning`, `uidToHex`) giữ nguyên nên các file khác không phải sửa.

## Còn cần làm trên máy phát triển
- [ ] Tạo Android host bằng `flutter create --platforms=android .`.
- [ ] Thêm permission/feature NFC vào AndroidManifest.
- [ ] `flutter pub get`, `flutter analyze`, `flutter test`.
- [ ] Chạy thử trên Galaxy S23 và xác nhận NFC thật.
- [ ] `flutter build apk --debug`.

Mã nguồn được chuyển từ nhánh `flutter-testable` của repo cũ. Việc chuyển file chưa thay thế cho kiểm thử compile/runtime trên máy. Bản sửa nfc_manager 4.x cũng **chưa được biên dịch**, cần `flutter pub get` rồi `flutter analyze` để xác nhận.
