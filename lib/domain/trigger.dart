import 'package:flutter/material.dart';

/// 3 tiến trình độc lập, có thể chạy song song hoặc chồng lấn.
enum ProcessType {
  work('Làm việc', Color(0xFF3B82F6)),
  design('Thiết kế', Color(0xFF8B5CF6)),
  cnc('CNC', Color(0xFFF59E0B));

  const ProcessType(this.label, this.color);
  final String label;
  final Color color;
}

/// 7 trigger. Trigger 6 (cncEnd) và 7 (cncConfirm) đều KẾT THÚC tiến trình CNC.
enum Trigger {
  workStart(ProcessType.work, true, 'Bắt đầu làm việc'),
  workEnd(ProcessType.work, false, 'Kết thúc làm việc'),
  designStart(ProcessType.design, true, 'Bắt đầu thiết kế'),
  designEnd(ProcessType.design, false, 'Kết thúc thiết kế'),
  cncStart(ProcessType.cnc, true, 'Bắt đầu máy CNC'),
  cncEnd(ProcessType.cnc, false, 'Kết thúc máy CNC'),
  cncConfirm(ProcessType.cnc, false, 'Xác nhận xong CNC tại bàn');

  const Trigger(this.process, this.isStart, this.label);
  final ProcessType process;
  final bool isStart;
  final String label;

  /// Đọc từ database; trả null nếu tên lạ.
  static Trigger? fromName(String name) {
    for (final t in Trigger.values) {
      if (t.name == name) return t;
    }
    return null;
  }
}

class TriggerEvent {
  TriggerEvent({
    required this.id,
    required this.trigger,
    required this.time,
    this.tagId,
  });

  final int id;
  final Trigger trigger;
  final DateTime time;

  /// Thẻ NFC tạo ra sự kiện; null nếu bấm nút hoặc nhập tay.
  final String? tagId;
}

/// Một lần chạy của tiến trình.
/// - end != null: đã kết thúc
/// - end == null && !broken: đang chạy (hoặc quên kết thúc nếu là ngày cũ)
/// - broken: bị bắt đầu lại khi chưa kết thúc, tính thời lượng 0
class Interval {
  Interval(this.process, this.start);

  final ProcessType process;
  final DateTime start;
  DateTime? end;
  bool broken = false;

  bool get isOpen => end == null && !broken;

  /// Thời lượng. Lần chạy chưa kết thúc chỉ được tính (đến [now]) khi [countOpen].
  Duration duration(DateTime now, {bool countOpen = true}) {
    final e = end;
    if (e != null) return e.difference(start);
    if (broken || !countOpen) return Duration.zero;
    return now.difference(start);
  }

  /// Mốc cuối để vẽ timeline.
  DateTime displayEnd(DateTime now) => end ?? (broken ? start : now);
}
