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
- [x] **2026-10-18** — `flutter analyze`: bỏ import thừa ở `app_services.dart`; `DropdownButtonFormField` dùng `initialValue` thay `value` ở `history_page.dart`.

## UI Home — vòng 1 (2026-10-17)
- [x] Timeline mặc định 7:00-19:00, tự mở rộng theo sự kiện; vẽ lại mỗi 5 phút và khi có sự kiện mới.
- [x] Bảng nút 2 hàng x 3 cột, ô Kết thúc CNC chia đôi (6 tại máy / 7 tại bàn).
- [x] Lịch sử có 3 làn đường mảnh nối bắt đầu - kết thúc (Làm việc ngoài cùng trái, Thiết kế kế bên, CNC mép phải).

## UI — vòng 2 (2026-10-18)
- [x] **AppBar**: trang Hôm nay hiện "Thứ + ngày" thay tên app; trang Lịch sử / Thẻ NFC hiện tên trang. Thêm `weekdayVi`, `dayTitle` vào `util/time_utils.dart`.
- [x] **Chỉ báo NFC**: chỉ còn icon (xanh = sẵn sàng, đỏ = không khả dụng), bấm để xem giải thích.
- [x] **Block 1**: timeline cao 170, chữ 12-13, thanh dày hơn, nhãn giờ chẵn; tổng giờ dưới biểu đồ, chỉ có số, màu theo tiến trình.
- [x] **Block 2**: nút cao 50, hàng 2 là nút đặc cùng tông đậm hơn, không viền.
- [x] **Block 3**: card cùng lề/bo góc với block 1; giờ bỏ giây, chữ giờ 18, tên sự kiện 14, mỗi dòng cao 48.
- [x] **Thanh điều hướng nổi** (bo 28, bóng đổ) và **vuốt đổi trang** (`PageView`, giữ trạng thái từng trang).
- [x] `HistoryPage` tự nạp lại khi Hôm nay có sự kiện mới.

## Mất thẻ NFC mỗi lần build/run + quét khi app ở nền (2026-10-20)

### 1. Mất 7 thẻ đã gán mỗi lần run
- Quan sát: thư mục database chỉ có `chamcong_v2.db` và `chamcong_v2.db-journal`. File `-journal` là bình thường trên Android (chế độ journal mặc định), **không phải** dấu hiệu hỏng. Không thấy file `.broken-*` nên không phải do cơ chế "đổi tên database lỗi".
- Nguyên nhân khả dĩ nhất: mỗi lần run, Flutter **gỡ rồi cài lại** app (ví dụ lỗi `INSTALL_FAILED_UPDATE_INCOMPATIBLE` do APK trước ký bằng khóa debug khác, như APK từ GitHub Actions), nên dữ liệu app bị xóa. **Chưa xác nhận**, xem cách kiểm tra bên dưới.
- [x] Biện pháp bất kể nguyên nhân: `lib/data/default_tags.dart` chứa UID 7 thẻ; database nạp sẵn khi tạo mới. Database nâng lên **v2**: bản cài cũ (v1) được điền UID cho thẻ còn trống, không ghi đè UID đã gán.
- [x] `AppDatabase.open()` ghi log `[AppDatabase] mở <đường dẫn>` và lỗi nếu phải đổi tên file.
- [ ] Cần bạn: xác định có bị gỡ cài đặt mỗi lần run không (lệnh bên dưới).
  ```powershell
  adb shell dumpsys package com.example.chamcong_v2 | findstr firstInstallTime
  ```
  Chạy trước và sau một lần Run. `firstInstallTime` đổi nghĩa là app bị gỡ và cài lại. Cũng xem dòng `Uninstalling old version...` trong cửa sổ Run.
  (applicationId mặc định `com.example.chamcong_v2` khi tạo bằng `scripts/bootstrap_android.ps1`; kiểm tra lại trong `android/app/build.gradle*` nếu khác.)

### 2. Chạm thẻ khi khóa màn hình / ở app khác / ở màn hình chính
- Nguyên nhân: phiên quét của `nfc_manager` chỉ hoạt động khi app ở foreground. Khi app ở nền không có phiên quét, và manifest chưa khai báo intent-filter nên Android không biết phải mở app nào.
- [x] `scripts/bootstrap_android.ps1` (chạy lại được nhiều lần): thêm `intent-filter` `TECH_DISCOVERED` (NfcA) + `res/xml/nfc_tech_filter.xml`, `showWhenLocked`/`turnScreenOn` cho `MainActivity`, và ghi `MainActivity.kt` để lấy UID từ intent rồi gửi sang Dart qua `MethodChannel("chamcong/nfc_launch")`.
- [x] `lib/nfc/nfc_launch.dart` (mới): nhận UID từ native.
- [x] `lib/app_services.dart`: xử lý UID từ native như quét thường (dùng chung hàng đợi, chống đọc lặp), tắt phiên quét khi app ra nền và **bật lại khi quay về** (trước đây không bật lại sau lần thoát đầu), và tự đưa app về nền ~1,6 giây sau khi ghi xong nếu thẻ chạm lúc app ở nền (`AppServices.returnToPreviousApp`, đặt `false` để tắt).
- Giới hạn: màn hình **tắt hẳn** thì NFC của điện thoại không đọc thẻ. Khi khóa màn hình (màn hình sáng) trên Samsung cần tắt "Yêu cầu mở khóa thiết bị để dùng NFC" trong Cài đặt > Kết nối > NFC và thanh toán không tiếp xúc. Nếu có app khác cũng nhận thẻ NTAG, Android có thể hiện hộp chọn app.
- [ ] Cần bạn: `git pull`, chạy lại `scripts\bootstrap_android.ps1`, rồi `flutter run`; thử 4 tình huống (đang mở app, app khác, màn hình chính, khóa màn hình sáng).

## Còn cần làm trên máy phát triển
- [ ] `flutter pub get`, `flutter analyze`, `flutter test`.
- [ ] Chạy thử trên Galaxy S23 và xác nhận NFC thật.
- [ ] `flutter build apk --debug`.

Mã nguồn được chuyển từ nhánh `flutter-testable` của repo cũ. Các bản sửa nfc_manager 4.x, UI và NFC nền **chưa được biên dịch** ở môi trường viết; cần `flutter analyze` và chạy thật để xác nhận.
