# Lộ trình (milestone) từng bước

Cách đọc: mỗi bước có **Mục tiêu**, **Việc cần làm**, **Xong khi** (cách kiểm tra cụ thể) và **Ai làm**.
Trạng thái ghi trong `PROGRESS.md`. Nguyên tắc: **chưa qua bước trước thì chưa làm bước sau**, vì phần lớn code hiện tại chưa được chạy thử trên máy thật.

Tóm tắt: A (xác nhận cái đang có) -> B (không mất dữ liệu) -> C (dùng hằng ngày thoải mái) -> D (hoàn thiện).

---

## Giai đoạn A — Xác nhận cái đang có chạy thật

### M1. Nền tảng chạy được
- **Mục tiêu:** code trên GitHub biên dịch, test qua, chạy được trên S23.
- **Việc cần làm:**
  1. `git pull`
  2. `powershell -ExecutionPolicy Bypass -File scripts\bootstrap_android.ps1`
  3. `flutter pub get`, `flutter analyze`, `flutter test`, `flutter run`
- **Xong khi:** `flutter analyze` không lỗi, `flutter test` qua hết (13 ca), app mở được trên S23 và thấy 3 trang.
- **Ai làm:** bạn chạy, gửi lỗi (nếu có) cho tôi sửa.

### M2. Hiểu và chặn lỗi mất dữ liệu mỗi lần Run
- **Mục tiêu:** biết vì sao dữ liệu mất, để lịch sử sự kiện không còn bị xóa.
- **Việc cần làm:**
  1. Chạy `adb shell dumpsys package com.example.chamcong_v2 | findstr firstInstallTime` trước và sau một lần Run.
  2. Xem cửa sổ Run có dòng `Uninstalling old version` không.
  3. Nếu app bị gỡ: tìm nguyên nhân (khóa debug khác với APK cài từ GitHub Actions? `applicationId` đổi?) rồi sửa.
- **Xong khi:** chấm một sự kiện, Run lại, sự kiện vẫn còn.
- **Ai làm:** bạn đo, hai bên cùng sửa.
- **Ghi chú:** 7 thẻ đã có UID mặc định trong code, nhưng lịch sử sự kiện vẫn mất nếu app bị gỡ.

### M3. Kiểm tra 7 thẻ
- **Mục tiêu:** mỗi thẻ vật lý tạo đúng sự kiện.
- **Việc cần làm:** mở app, chạm lần lượt từng thẻ, đối chiếu sự kiện hiện ra với tên thẻ. TAG-001 đến TAG-005 đang là **giả định** về thứ tự.
- **Xong khi:** 7 thẻ đều ghi đúng sự kiện. Thẻ nào sai thì sửa ở trang Thẻ (gán lại hoặc đổi sự kiện).
- **Ai làm:** bạn.

### M4. Chạm thẻ khi app ở nền
- **Mục tiêu:** chạm thẻ khi không mở app vẫn ghi được.
- **Việc cần làm:** thử 4 tình huống, mỗi tình huống chạm 1 thẻ: (a) đang mở app, (b) đang ở app khác, (c) ở màn hình chính, (d) khóa màn hình nhưng màn hình sáng (đã tắt "Yêu cầu mở khóa thiết bị để dùng NFC").
- **Xong khi:** cả 4 tình huống ghi đúng sự kiện, không hiện hộp chọn app, app tự lùi về nền sau khoảng 1,6 giây.
- **Ai làm:** bạn thử, tôi sửa theo kết quả (các điểm hay hỏng: hộp chọn app của Samsung, `MainActivity.kt`, intent-filter).
- **Giới hạn đã biết:** màn hình tắt hẳn thì điện thoại không đọc được thẻ.

### M5. Kiểm tra giao diện trên máy thật
- **Mục tiêu:** UI hôm nay, lịch sử, thẻ dùng thoải mái trên S23.
- **Việc cần làm:** xem 3 block vừa màn hình không, chữ nút 6 và 7 có bị bé hoặc cắt không, thanh điều hướng nổi có che nội dung không, vuốt có nhầm với thao tác khác không.
- **Xong khi:** bạn chấp nhận bố cục, hoặc liệt kê chỗ cần chỉnh để sửa một vòng.
- **Ai làm:** bạn xem, tôi chỉnh.

---

## Giai đoạn B — Dữ liệu không bị mất

### M6. Xuất và nhập dữ liệu ra file
- **Mục tiêu:** có bản sao dữ liệu ngoài điện thoại.
- **Việc cần làm:** nút xuất toàn bộ sự kiện (CSV hoặc JSON) ra thư mục tải về / chia sẻ; nút nhập lại từ file; nhập thì bỏ qua sự kiện trùng.
- **Xong khi:** xuất, gỡ app, cài lại, nhập, thấy đủ lịch sử.
- **Ai làm:** tôi viết, bạn thử.
- **Phụ thuộc:** M2.

### M7. Màn tổng kết cuối ngày
- **Mục tiêu:** có chỗ xem một lần số giờ để nhập lên hệ thống xưởng.
- **Việc cần làm:** hiện tổng giờ làm việc, thiết kế, CNC của ngày (đã có ở card timeline và lịch sử) trên một màn gọn; thêm số lần CNC chạy; nút sao chép văn bản.
- **Xong khi:** bạn nhập đúng số liệu lên hệ thống chỉ bằng cách đọc từ màn này.
- **Ai làm:** tôi viết, bạn xác nhận định dạng số liệu hệ thống xưởng cần.

---

## Giai đoạn C — Dùng hằng ngày thoải mái

### M8. Hoàn tác ngay trên Hôm nay
- **Mục tiêu:** bấm nhầm không phải sang trang Lịch sử để xóa.
- **Việc cần làm:** thông báo sau mỗi lần ghi có nút "Hoàn tác" xóa sự kiện vừa ghi.
- **Xong khi:** bấm nhầm, bấm Hoàn tác, sự kiện biến mất khỏi timeline và danh sách.

### M9. Quên kết thúc qua đêm
- **Mục tiêu:** quên kết thúc CNC hay thiết kế hôm trước không làm hỏng số liệu ngày sau.
- **Việc cần làm:** khi mở sang ngày mới mà còn việc chưa kết thúc từ hôm trước, hiện lời nhắc đóng nhanh (chọn giờ kết thúc); hiện huy hiệu cảnh báo ở tab Lịch sử.
- **Xong khi:** để một việc mở qua đêm, sáng hôm sau app nhắc và đóng được trong 2 thao tác.
- **Quyết định cần bạn:** có việc nào được phép chạy xuyên đêm (ví dụ CNC chạy qua đêm) không? Nếu có thì phải tính giờ xuyên ngày thay vì cảnh báo.

### M10. Phản hồi khi chạm thẻ ở nền
- **Mục tiêu:** biết ngay đã ghi xong mà không cần nhìn màn hình.
- **Việc cần làm:** rung khác nhau cho thành công và lỗi; tùy chọn âm báo.
- **Xong khi:** chạm thẻ khi điện thoại trong túi áo thì cảm nhận được rung xác nhận.
- **Phụ thuộc:** M4.

### M11. Trạng thái NFC tự làm mới
- **Mục tiêu:** bật NFC sau khi mở app không phải mở lại app.
- **Việc cần làm:** kiểm tra lại NFC mỗi khi quay về app và khi bấm biểu tượng NFC.
- **Xong khi:** tắt NFC, mở app (icon đỏ), bật NFC, quay lại app, icon xanh và quét được.

---

## Giai đoạn D — Hoàn thiện

### M12. Cài đặt nhỏ
- **Việc cần làm:** bật tắt việc tự lùi về nền (hiện là hằng số trong code), giờ mặc định của timeline (7 đến 19), làm tròn phút khi tổng kết.
- **Xong khi:** đổi cài đặt, thoát app, mở lại, cài đặt vẫn giữ.

### M13. Bản cài ổn định để dùng thật
- **Mục tiêu:** cài một lần, dùng lâu, cập nhật không mất dữ liệu.
- **Việc cần làm:** tạo khóa ký riêng (không dùng khóa debug), build bản release, cài lên S23, ghi cách cập nhật mà không gỡ app.
- **Xong khi:** cài bản mới đè lên bản cũ, dữ liệu vẫn còn.
- **Phụ thuộc:** M2, M6.

---

## Thứ tự làm đề xuất

`M1 -> M2 -> M3 -> M4 -> M5 -> M6 -> M7 -> M8 -> M9 -> M10 -> M11 -> M12 -> M13`

Nếu thời gian ít: **M1, M2, M4, M6** là bốn bước quan trọng nhất (biết chạy được, không mất dữ liệu, thẻ ở nền hoạt động, có bản sao lưu).
