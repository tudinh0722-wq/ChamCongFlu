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
- [x] **2026-10-17** — `Build failed due to use of deleted Android v1 embedding`: thư mục `android/` cũ. Xóa `android/`, chạy lại `scripts/bootstrap_android.ps1`.

## UI Home — vòng 1 (2026-10-17)
- [x] Timeline mặc định 7:00-19:00, tự mở rộng theo sự kiện; vẽ lại mỗi 5 phút và khi có sự kiện mới.
- [x] Bảng nút 2 hàng x 3 cột, ô Kết thúc CNC chia đôi (6 tại máy / 7 tại bàn).
- [x] Lịch sử có 3 làn đường mảnh nối bắt đầu - kết thúc (Làm việc ngoài cùng trái, Thiết kế kế bên, CNC mép phải).

## UI — vòng 2 (2026-10-18)
- [x] **AppBar**: trang Hôm nay hiện "Thứ + ngày" thay tên app; trang Lịch sử / Thẻ NFC hiện tên trang. Thêm `weekdayVi`, `dayTitle` vào `util/time_utils.dart`.
- [x] **Chỉ báo NFC**: chỉ còn icon (xanh = sẵn sàng, đỏ = không khả dụng), bấm để xem giải thích. Trạng thái lấy từ `AppServices.nfcAvailable` (phiên quét NFC có đang chạy không), được kiểm tra một lần lúc mở app.
- [x] **Block 1**: timeline cao 170 (trước 104), chữ 12-13, thanh dày hơn, nhãn giờ rơi vào giờ chẵn; tổng giờ nằm dưới biểu đồ, chỉ có số, màu theo tiến trình.
- [x] **Block 2**: nút cao 50 (trước 62), chữ nhỏ hơn, khoảng cách 6; hàng 2 là nút đặc cùng tông đậm hơn, không viền.
- [x] **Block 3**: nằm trong card cùng lề/bo góc với block 1; giờ bỏ giây, chữ giờ 18, tên sự kiện 14, mỗi dòng cao 48.
- [x] **Thanh điều hướng nổi**: bo tròn 28, cách mép 16, có bóng đổ.
- [x] **Vuốt đổi trang**: `PageView` thay `IndexedStack`; bấm thanh điều hướng thì trượt tới trang; mỗi trang giữ trạng thái khi vuốt đi.
- [x] **Sửa kèm theo**: `HistoryPage` tự nạp lại khi Hôm nay có sự kiện mới (trước đây chỉ nạp một lần lúc mở, vuốt sang sẽ thấy dữ liệu cũ).
- File: `lib/main.dart`, `lib/ui/home_page.dart`, `lib/ui/timeline_painter.dart`, `lib/ui/history_page.dart`, `lib/util/time_utils.dart`.
- [ ] Cần bạn chạy thử: chiều cao các block trên S23, thanh điều hướng nổi có che nội dung Lịch sử/Thẻ không, vuốt có xung đột với thao tác nào không.

## Còn cần làm trên máy phát triển
- [ ] `flutter pub get`, `flutter analyze`, `flutter test`.
- [ ] Chạy thử trên Galaxy S23 và xác nhận NFC thật.
- [ ] `flutter build apk --debug`.

Mã nguồn được chuyển từ nhánh `flutter-testable` của repo cũ. Các bản sửa nfc_manager 4.x và UI **chưa được biên dịch** ở môi trường viết; cần `flutter analyze` để xác nhận.
