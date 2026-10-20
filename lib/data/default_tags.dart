import '../domain/trigger.dart';

/// Thẻ mặc định, nạp vào database khi database được tạo mới (hoặc nâng lên v2).
/// Nhờ vậy cài lại app hoặc database bị tạo lại thì 7 thẻ tự có đủ UID,
/// không phải quét gán lại từng thẻ.
///
/// - Muốn đổi UID khi thay thẻ hỏng: làm ở màn Thẻ (dữ liệu trong database
///   được ưu tiên, file này chỉ là giá trị khởi tạo).
/// - Trigger của TAG-001..005 là theo thứ tự thường gặp; kiểm tra lại ở màn Thẻ.
/// - Repo public thì UID nằm công khai trong file này; nếu muốn giấu, để repo
///   ở chế độ private hoặc đặt `uid` về null rồi gán bằng cách quét.
class DefaultTag {
  const DefaultTag(this.id, this.name, this.trigger, this.uid);

  final String id;
  final String name;
  final Trigger trigger;
  final String? uid;
}

const defaultTags = <DefaultTag>[
  DefaultTag('TAG-001', 'Bắt đầu làm việc', Trigger.workStart, '53:27:B3:B1:02:00:01'),
  DefaultTag('TAG-002', 'Kết thúc làm việc', Trigger.workEnd, '53:3D:AC:B1:02:00:01'),
  DefaultTag('TAG-003', 'Bắt đầu thiết kế', Trigger.designStart, '53:1A:9D:B1:02:00:01'),
  DefaultTag('TAG-004', 'Kết thúc thiết kế', Trigger.designEnd, '53:E6:A3:B1:02:00:01'),
  DefaultTag('TAG-005', 'Bắt đầu máy CNC', Trigger.cncStart, '53:B6:ED:B3:02:00:01'),
  DefaultTag('TAG-006', 'Kết thúc máy CNC (vị trí 1)', Trigger.cncEnd, '53:83:7B:B1:02:00:01'),
  DefaultTag('TAG-007', 'Kết thúc máy CNC (vị trí 2)', Trigger.cncEnd, '53:F2:74:B1:02:00:01'),
];
