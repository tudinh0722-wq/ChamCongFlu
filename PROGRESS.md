# PROGRESS — ChamCongFlu

> Cập nhật tài liệu: 2026-10-22. Đây là trạng thái dựa trên source hiện có và lịch sử kiểm thử trước đây; clone mới nhất vẫn cần được kiểm tra lại.

## Đã có trong source

- [x] Flutter app với ba tab: Hôm nay, Lịch sử, Thẻ NFC.
- [x] Ba tiến trình độc lập: làm việc, thiết kế, CNC; 7 trigger.
- [x] SQLite repository cho event/tag và nâng schema database lên v2.
- [x] Thêm/sửa/xóa sự kiện, xem ngày, tính thời lượng và phát hiện chuỗi sự kiện bất thường.
- [x] Quản lý tag: UID, tên, trigger, trạng thái active.
- [x] NFC foreground qua nfc_manager; chống đọc lặp cùng UID trong 2 giây.
- [x] Luồng NFC native và backup được tạo/vá bởi scripts/bootstrap_android.ps1; Dart có nhận UID native qua lib/nfc/nfc_launch.dart.
- [x] Backup JSON ra thư mục người dùng chọn, hai slot luân phiên, debounce tự động và restore/loại event trùng.
- [x] CI chạy flutter pub get, flutter analyze và flutter test.

## Đã xác minh bằng thao tác trước đây

- [x] Thêm/sửa sự kiện thủ công và xem ngày khác.
- [x] SQLite còn dữ liệu sau khi đóng rồi mở lại app.
- [x] Thẻ đã đăng ký khi app mở tạo sự kiện.
- [x] Thẻ chưa đăng ký không tạo sự kiện.
- [x] Đọc lặp cùng thẻ không tạo event trùng trong cửa sổ chống trùng.
- [x] Sửa/xóa event cập nhật phép tính.
- [x] Cảnh báo thiếu cặp bắt đầu/kết thúc xuất hiện như thiết kế.

Các mục trên là lịch sử kiểm thử, không thay thế việc chạy lại trên clone mới nhất.

## Chưa xác minh trên clone mới

- [ ] Clone sạch, bootstrap Android, build/run thành công.
- [ ] flutter analyze và flutter test; ghi số test thực tế.
- [ ] flutter build apk --debug trên toolchain hiện tại.
- [ ] Đủ 7 thẻ NFC foreground.
- [ ] NFC nền trong bốn trạng thái: app mở, app khác, Home, màn hình khóa đang sáng.
- [ ] Không mở app/hiện chooser ngoài dự kiến với thẻ NFC không liên quan.
- [ ] Backup/restore sau cài mới, restore merge, file lỗi và mất quyền thư mục.
- [ ] Xác minh không mất dữ liệu khi cài đè/gỡ cài lại.
- [ ] Test widget có ý nghĩa; hiện test/widget_test.dart là placeholder.

## Vấn đề kỹ thuật ưu tiên

1. Repo có android/, còn bootstrap script vá Android và ghi đè MainActivity.kt. Chạy script sau khi pull rồi kiểm tra diff trước khi sửa native thủ công.
2. Bộ lọc NFC nền TECH_DISCOVERED + NfcA rộng; cần xác minh định tuyến trên thiết bị và thu hẹp nếu nhận thẻ không liên quan.
3. android/settings.gradle.kts đang chứa đường dẫn tuyệt đối C:\Users\admin\.android; cần loại bỏ để dự án chạy trên máy khác.
4. lib/data/default_tags.dart chứa UID cụ thể cho 7 tag; README/PROJECT cũ nói chưa có UID nên đã lỗi thời.
5. Backup có implementation nhưng chưa đủ test thực tế; quyền thư mục có thể mất sau khi gỡ app.

## Quy trình xác nhận

Chạy tại thư mục repo:

    git status -sb
    flutter doctor
    flutter pub get
    powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap_android.ps1
    flutter analyze
    flutter test
    flutter build apk --debug
    flutter run

Sau bootstrap, kiểm tra git diff -- android để biết script thay đổi gì. Không đánh dấu milestone hoàn tất chỉ vì lệnh đã chạy; ghi kết quả thực tế và lỗi nếu có.
