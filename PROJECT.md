# PROJECT — ChamCongFlu

## Mục đích

Ứng dụng chấm công offline cho xưởng CNC. Ghi nhận mốc thời gian bằng nút bấm hoặc thẻ NFC, tổng hợp thời lượng theo ba tiến trình độc lập. Ứng dụng không tính tiền lương.

## Quy tắc nghiệp vụ

| Tiến trình | Bắt đầu | Kết thúc |
|---|---|---|
| Làm việc | Trigger 1 | Trigger 2 |
| Thiết kế file | Trigger 3 | Trigger 4 |
| Máy CNC | Trigger 5 | Trigger 6 (tại máy) hoặc 7 (xác nhận tại bàn) |

- Ba tiến trình có thể chạy song song; bắt đầu/kết thúc tiến trình này không tự động đổi trạng thái tiến trình khác.
- Một tiến trình không được bắt đầu lần nữa khi đang chạy.
- Trigger 6 và 7 đều kết thúc CNC; trigger 7 là xác nhận tại bàn theo thiết kế nghiệp vụ.
- Trạng thái và thời lượng được suy ra từ event trong database.
- Chuỗi event thiếu cặp bắt đầu/kết thúc phải được cảnh báo. Đây là hành vi đúng; không tự động xóa hoặc sửa dữ liệu chỉ để bỏ cảnh báo.
- Sự kiện có thể được chỉnh trong Lịch sử để sửa giờ hoặc xử lý chấm nhầm.
- Lượt đang chạy trong ngày có thể được tính đến thời điểm hiện tại.

## Kiến trúc

- lib/domain/: trigger, quy tắc tính khoảng, kiểm tra hợp lệ và controller.
- lib/data/: SQLite, repository, tag mặc định và backup/restore.
- lib/nfc/: đọc UID bằng nfc_manager và nhận sự kiện từ Android native.
- lib/ui/: Hôm nay/timeline, Lịch sử, quản lý thẻ và backup.
- android/: Android host.
- scripts/bootstrap_android.ps1: tạo Android host nếu thiếu; vá Manifest, tech filter, MainActivity và MethodChannel cho NFC/backup.
- test/: unit/widget tests; độ phủ hiện chưa đủ cho backup, native NFC và UI.

## Dữ liệu

Database SQLite offline: chamcong_v2.db.

- tag: ID ổn định, tên, trigger, UID và active. UID đã gán cần duy nhất.
- event: ID, tag ID có thể null, loại trigger và timestamp epoch milliseconds.
- lib/data/default_tags.dart hiện có UID mặc định cụ thể cho TAG-001…TAG-007. Vì UID nằm trong source công khai, cần quyết định giữ repo public với UID này hay bỏ UID khỏi source và gán thẻ trên thiết bị.
- Dữ liệu vùng riêng của app bị Android xóa khi gỡ app. Backup ra thư mục người dùng chọn giúp khôi phục, nhưng quyền thư mục cần chọn lại sau khi cài lại.

## NFC

Luồng foreground dùng nfc_manager đọc UID, tra tag trong SQLite, kiểm tra tag active và chuyển trigger vào controller. Cùng UID được chống lặp trong cửa sổ 2 giây.

Bootstrap script thiết lập TECH_DISCOVERED với công nghệ NfcA, nhận UID trong MainActivity.kt và chuyển qua MethodChannel chamcong/nfc_launch. Cần chạy script sau khi pull để đảm bảo Android host có patch tương ứng.

**Rủi ro:** bộ lọc theo công nghệ NfcA rộng hơn lọc theo một ứng dụng/thẻ cụ thể. UID lạ có thể bị từ chối ở tầng nghiệp vụ nhưng Android vẫn có thể khởi chạy app khi chạm thẻ phù hợp bộ lọc. Phải kiểm tra định tuyến trên thiết bị trước khi kết luận không ảnh hưởng ứng dụng NFC khác.

UID không phải cơ chế xác thực chống sao chép. Nếu cần chống giả mạo mạnh, cần thẻ và giao thức có xác thực mật mã, không chỉ UID.

## Backup/restore

- JSON chứa phiên bản, thời điểm xuất, tags và events.
- Hai file luân phiên để giữ lại bản hợp lệ trước đó nếu lần ghi mới bị gián đoạn.
- Tự lên lịch backup sau thay đổi dữ liệu.
- Restore hợp nhất tags và thêm event chưa có, dựa trên trigger + timestamp.
- Cần kiểm thử file hỏng, version/schema không tương thích, restore lặp và quyền truy cập thư mục mất.

## Giới hạn và điểm cần cải thiện

1. NFC nền và vòng đời Activity chưa được xác nhận trên clone/build hiện tại.
2. Bộ lọc NfcA rộng, có thể nhận thẻ không liên quan.
3. android/settings.gradle.kts có đường dẫn tuyệt đối Windows cần loại bỏ.
4. Test widget là placeholder; thiếu test tự động cho backup/restore, repository và NFC native.
5. Backup có trường version nhưng cần xử lý version/schema không tương thích tường minh.
6. Tiến trình còn mở qua nửa đêm cần quy tắc rõ: chỉ cảnh báo, đóng theo giờ người dùng chọn, hay tính xuyên ngày.
7. Tài liệu phải khớp UID mặc định và hành vi sau bootstrap.

## Kiểm tra chất lượng

    flutter pub get
    flutter analyze
    flutter test
    flutter build apk --debug

Chạy trên clone mới và thiết bị thật trước khi kết luận thay đổi ổn định.
