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

## Làm lại UI Home (2026-10-17)
- [x] **Timeline**: trục mặc định 7:00-19:00; có sự kiện sớm hơn hoặc muộn hơn (hoặc tiến trình đang chạy tới "bây giờ") thì trục tự mở rộng tới giờ đó. Vẽ lại mỗi **5 phút** và ngay khi có sự kiện mới (không còn vẽ mỗi giây). Thêm nền từng hàng, nhãn giờ, ngày trong tuần và tổng giờ từng tiến trình trong ngày.
- [x] **Bảng nút**: 2 hàng x 3 cột. Hàng 1 = Bắt đầu (Làm việc | Thiết kế | CNC, nút đặc), hàng 2 = Kết thúc (nút viền). Ô Kết thúc CNC chia đôi: trigger 6 "tại máy" và trigger 7 "tại bàn". Có rung nhẹ khi bấm.
- [x] **Lịch sử**: chữ lớn (giờ 20sp, tên 16sp), mới nhất ở trên. Thêm 3 làn đường mảnh nối sự kiện bắt đầu - kết thúc: làn 1 (Làm việc) ngoài cùng bên trái, làn 2 (Thiết kế) kế bên, chữ ở giữa dùng chung, làn 3 (CNC) ở mép phải. Chấm đặc = bắt đầu, chấm rỗng = kết thúc; lần chạy đang mở kéo đường lên đầu danh sách; dòng kết thúc hiện thời lượng ("chạy 1h 05p").
- File: `lib/ui/home_page.dart`, `lib/ui/timeline_painter.dart`, `lib/ui/event_rows.dart` (mới).
- [ ] Cần bạn chạy thử: bố cục trên S23 (chữ có bị cắt không), độ rõ của đường nối, nút 6/7 có đủ lớn để bấm không.

## Còn cần làm trên máy phát triển
- [ ] `flutter pub get`, `flutter analyze`, `flutter test`.
- [ ] Chạy thử trên Galaxy S23 và xác nhận NFC thật.
- [ ] `flutter build apk --debug`.

Mã nguồn được chuyển từ nhánh `flutter-testable` của repo cũ. Các bản sửa nfc_manager 4.x và UI mới **chưa được biên dịch**, cần `flutter analyze` để xác nhận.
