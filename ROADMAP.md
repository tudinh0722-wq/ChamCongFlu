# Roadmap — ChamCongFlu

Roadmap đưa repo hiện tại đến trạng thái có thể dùng hằng ngày an toàn. Code có sẵn không đồng nghĩa tính năng đã được xác minh trên thiết bị. Chỉ đánh dấu hoàn tất khi có kết quả test/log thực tế.

## M0 — Dựng lại môi trường từ GitHub

**Mục tiêu:** clone sạch có thể tạo Android host và chạy trên Galaxy S23.

- [ ] Clone/pull main; kiểm tra git status -sb.
- [ ] Chạy flutter doctor và flutter pub get.
- [ ] Chạy script từ thư mục gốc: powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap_android.ps1
- [ ] Chạy flutter analyze, flutter test, flutter build apk --debug và flutter run.

**Đạt khi:** analyze/test/build thành công, app mở được và có đủ ba tab. Ghi số test thực tế, không dùng con số cũ.

**Lưu ý:** script tạo Android host nếu thiếu; nếu android/ đã tồn tại, script vá cấu hình và ghi đè MainActivity.kt. Sau đó kiểm tra git diff -- android.

## M1 — Xác minh nghiệp vụ chấm công

- [ ] Xác nhận trigger 1–7 tương ứng đúng sự kiện.
- [ ] Ba tiến trình làm việc, thiết kế, CNC chạy độc lập.
- [ ] Chặn bắt đầu lại khi tiến trình đang chạy.
- [ ] Kết thúc không có bắt đầu bị chặn trong luồng chấm công bình thường.
- [ ] Nhiều lượt trong ngày cộng đúng; lượt đang chạy hôm nay tính đến hiện tại.
- [ ] Sửa/xóa/thêm sự kiện ngày cũ cập nhật lịch sử, tổng thời lượng và cảnh báo.
- [ ] Dữ liệu còn sau khi đóng/mở lại app.

**Đạt khi:** kết quả từng ca khớp với dữ liệu và tổng thời lượng hiển thị.

## M2 — Xác minh 7 thẻ NFC foreground

- [ ] Đối chiếu từng thẻ vật lý với TAG-001…TAG-007.
- [ ] UID chưa đăng ký không tạo sự kiện.
- [ ] Tag inactive không tạo sự kiện.
- [ ] Đọc lặp cùng UID trong 2 giây chỉ ghi một event.
- [ ] Thay UID thẻ hỏng không đổi Tag ID; UID cũ không còn được nhận.
- [ ] Một UID không được gán đồng thời cho hai tag.

**Đạt khi:** đủ 7 thẻ tạo đúng trigger; các ca âm tính không ghi event.

## M3 — NFC khi app nền

**Đây là milestone rủi ro cao. Source/script có phần triển khai nhưng chưa coi là đạt nếu chưa xác minh trên thiết bị.**

- [ ] Chạy bootstrap, kiểm tra Manifest, nfc_tech_filter.xml và MainActivity.kt sau khi vá.
- [ ] Thử app đang mở, app khác ở foreground, Home, màn hình khóa nhưng vẫn sáng.
- [ ] Xác minh UID native được chuyển sang Dart khi Activity đang tồn tại và khi được tạo lại.
- [ ] Mỗi lần chạm hợp lệ chỉ ghi một event; UID lạ và tag inactive không ghi.
- [ ] Kiểm tra tự lùi về app trước khi returnToPreviousApp bật.
- [ ] Kiểm tra app chooser của Android/Samsung và ảnh hưởng đến ứng dụng NFC khác.
- [ ] Thử NFC tắt, tag không đọc được, app bị kill và chạm liên tiếp nhanh.

**Rủi ro đã biết:** TECH_DISCOVERED với công nghệ NfcA khá rộng. Tra UID trong Dart có thể ngăn ghi event không hợp lệ nhưng không ngăn Android khởi chạy app khi thẻ NfcA không liên quan được chạm. Nếu xảy ra, cần thu hẹp bộ lọc/đổi thiết kế. Không giả định UID không thể bị sao chép.

**Giới hạn:** không yêu cầu NFC hoạt động khi màn hình tắt hẳn; phạm vi mục tiêu là màn hình khóa đang sáng.

## M4 — Kiểm chứng backup/restore

- [ ] Chọn thư mục bằng Android system picker.
- [ ] Sau khi sửa dữ liệu, kiểm tra backup tự động sau debounce cập nhật hai file JSON luân phiên.
- [ ] Sao lưu thủ công khi có dữ liệu.
- [ ] Khôi phục vào database sạch, đối chiếu tag, UID, active, event, timestamp và tổng giờ.
- [ ] Khôi phục vào database đã có dữ liệu; xác nhận merge/dedupe không nhân đôi event.
- [ ] Thử file JSON hỏng/rỗng/thiếu trường/phiên bản không hỗ trợ và quyền thư mục bị mất.
- [ ] Gỡ/cài lại app, chọn lại thư mục, khôi phục; xác nhận database trống không ghi đè backup cũ.

**Đạt khi:** dữ liệu không bị âm thầm mất và lỗi có thông báo rõ ràng.

## M5 — Sửa vấn đề kỹ thuật trước khi dùng lâu dài

- [ ] Bỏ đường dẫn tuyệt đối theo máy cá nhân khỏi android/settings.gradle.kts.
- [ ] Cập nhật tài liệu về UID: default_tags.dart hiện chứa UID cụ thể cho 7 tag; quyết định có muốn công khai UID trong repo hay không.
- [ ] Thêm test thực chất cho BackupService, Repository, UID dedupe và UI; test/widget_test.dart hiện chỉ là placeholder.
- [ ] Mở rộng CI để kiểm tra build Android và kiểm tra script PowerShell trên Windows.
- [ ] Kiểm tra version/schema backup khi đọc và restore.
- [ ] Quyết định quy tắc tiến trình còn mở qua nửa đêm: chỉ cảnh báo, đóng theo giờ người dùng chọn, hay tính xuyên ngày.

## M6 — Dùng hằng ngày và phát hành

- [ ] Hoàn tác nhanh sau khi chạm nhầm.
- [ ] Phản hồi NFC bằng rung/âm báo có thể cấu hình.
- [ ] Trạng thái NFC tự làm mới khi quay lại app sau khi bật NFC trong Settings.
- [ ] Màn tổng kết cuối ngày và sao chép báo cáo nếu đã thống nhất định dạng đầu ra.
- [ ] Tạo signing key release riêng; cập nhật bản cài đè lên bản trước mà không gỡ app.
- [ ] Thực hiện backup/restore cuối cùng trước khi dùng dữ liệu thật.

## Thứ tự đề xuất

M0 → M1 → M2 → M3 → M4 → M5 → M6.

Ưu tiên trước mắt: dựng được bản mới, xác minh 7 thẻ, kiểm thử NFC nền và kiểm chứng backup. Không sửa logic nghiệp vụ đang hoạt động chỉ vì cảnh báo dữ liệu bất thường xuất hiện đúng thiết kế.
