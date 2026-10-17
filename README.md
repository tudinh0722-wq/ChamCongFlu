# Chấm công NFC — Flutter

Ứng dụng chấm công offline cho xưởng CNC, ghi các mốc thời gian bằng nút bấm hoặc thẻ NFC. Ba tiến trình độc lập: làm việc, thiết kế và máy CNC. Không tính tiền.

## Tình trạng repo

Repo này chỉ chứa mã nguồn Flutter/Dart và test được chuyển từ dự án cũ. Không mang theo Android project native ở thư mục gốc hoặc các cấu hình Gradle cũ gây xung đột. Thư mục Android host sẽ được tạo bằng Flutter SDK trên máy phát triển.

## Tạo Android host và chạy trên Windows

Cần Flutter stable, Android Studio, Android SDK và Java 17. Mở PowerShell tại thư mục đã clone repo:

```powershell
flutter doctor
flutter pub get
flutter create --platforms=android .
```

Sau khi Flutter tạo thư mục `android/`, mở `android/app/src/main/AndroidManifest.xml` và thêm các quyền NFC bên trong thẻ `<manifest>`, phía trên `<application>`:

```xml
<uses-permission android:name="android.permission.NFC" />
<uses-feature android:name="android.hardware.nfc" android:required="false" />
```

Sau đó chạy:

```powershell
flutter analyze
flutter test
flutter run
```

Trong Android Studio, mở thư mục repo có `pubspec.yaml`, không mở một thư mục Android con. Kết nối Galaxy S23, bật USB debugging và chọn thiết bị để chạy.

Tạo APK debug:

```powershell
flutter build apk --debug
```

## Chức năng hiện có trong mã nguồn

- Tab **Hôm nay**: 7 trigger, timeline cho ba tiến trình.
- Tab **Lịch sử**: xem/sửa/thêm/xóa sự kiện và xem tổng thời gian/cảnh báo.
- Tab **Thẻ NFC**: gán UID bằng cách quét, gỡ UID, đổi tên, bật/tắt thẻ.
- SQLite offline, file database `chamcong_v2.db`; 7 tag được tạo sẵn nhưng chưa có UID.
- NFC chỉ xử lý khi app đang mở. Các tiến trình độc lập, không tự kết thúc lẫn nhau.

## Lưu ý

Mã nguồn đã được chuyển; cần chạy `flutter pub get`, `flutter analyze`, `flutter test` và build trên máy phát triển để xác nhận trạng thái thực tế. Không copy Gradle files từ repo cũ vào đây.
