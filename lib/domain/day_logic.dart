import '../util/time_utils.dart';
import 'trigger.dart';

List<TriggerEvent> _sortedFor(List<TriggerEvent> events, ProcessType p) {
  final list = events.where((e) => e.trigger.process == p).toList();
  list.sort((a, b) {
    final c = a.time.compareTo(b.time);
    return c != 0 ? c : a.id.compareTo(b.id);
  });
  return list;
}

/// Dựng các lần chạy của một tiến trình từ danh sách sự kiện.
/// Trạng thái luôn suy ra từ sự kiện nên lưu database là đủ.
List<Interval> buildIntervals(List<TriggerEvent> events, ProcessType p) {
  final result = <Interval>[];
  Interval? open;
  for (final e in _sortedFor(events, p)) {
    if (e.trigger.isStart) {
      // Bắt đầu lại khi chưa kết thúc: lần trước bị đánh dấu hỏng.
      if (open != null) open.broken = true;
      open = Interval(p, e.time);
      result.add(open);
    } else if (open != null) {
      open.end = e.time;
      open = null;
    }
    // Sự kiện kết thúc khi không có lần chạy mở (ví dụ xác nhận CNC sau khi
    // đã kết thúc): bỏ qua, chỉ nằm trong lịch sử.
  }
  return result;
}

bool isRunning(List<TriggerEvent> events, ProcessType p) {
  final list = buildIntervals(events, p);
  return list.isNotEmpty && list.last.isOpen;
}

/// Kiểm tra bấm trigger [t]. Trả về thông báo lỗi, hoặc null nếu hợp lệ.
String? validate(List<TriggerEvent> events, Trigger t) {
  final running = isRunning(events, t.process);
  if (t.isStart && running) {
    return '${t.process.label} đang chạy, cần kết thúc trước khi bắt đầu lại';
  }
  if (!t.isStart && !running && t != Trigger.cncConfirm) {
    return '${t.process.label} chưa bắt đầu';
  }
  return null;
}

class DaySummary {
  const DaySummary(this.work, this.design, this.cnc, this.cncRuns);

  final Duration work;
  final Duration design;
  final Duration cnc;
  final int cncRuns;

  Duration of(ProcessType p) => switch (p) {
        ProcessType.work => work,
        ProcessType.design => design,
        ProcessType.cnc => cnc,
      };
}

/// Tổng thời gian từng tiến trình trong ngày (để nhập lên hệ thống xưởng).
/// [countOpen] = false cho ngày cũ: lần chạy chưa kết thúc tính 0 (và được
/// cảnh báo bởi [findIssues]) thay vì chạy mãi đến [now].
DaySummary summarize(
  List<TriggerEvent> events,
  DateTime now, {
  bool countOpen = true,
}) {
  Duration total(ProcessType p) => buildIntervals(events, p).fold(
        Duration.zero,
        (sum, i) => sum + i.duration(now, countOpen: countOpen),
      );
  return DaySummary(
    total(ProcessType.work),
    total(ProcessType.design),
    total(ProcessType.cnc),
    buildIntervals(events, ProcessType.cnc).length,
  );
}

class DayIssue {
  const DayIssue(this.message, this.eventId);

  final String message;

  /// Sự kiện liên quan để làm nổi bật trong danh sách.
  final int? eventId;
}

/// Tìm bất thường trong một ngày để màn Lịch sử cảnh báo.
/// [isToday] = true: lần chạy cuối chưa kết thúc là bình thường (đang chạy).
List<DayIssue> findIssues(List<TriggerEvent> events, {required bool isToday}) {
  final issues = <DayIssue>[];
  for (final p in ProcessType.values) {
    TriggerEvent? open;
    for (final e in _sortedFor(events, p)) {
      if (e.trigger.isStart) {
        if (open != null) {
          issues.add(DayIssue(
              '${p.label}: bắt đầu ${hm(open.time)} chưa có kết thúc', open.id));
        }
        open = e;
      } else if (open != null) {
        open = null;
      } else if (e.trigger != Trigger.cncConfirm) {
        issues.add(DayIssue(
            '${p.label}: kết thúc ${hm(e.time)} không có bắt đầu', e.id));
      }
    }
    if (open != null && !isToday) {
      issues.add(DayIssue(
          '${p.label}: bắt đầu ${hm(open.time)} chưa có kết thúc', open.id));
    }
  }
  return issues;
}
