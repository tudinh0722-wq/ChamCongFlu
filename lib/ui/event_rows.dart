import 'package:flutter/material.dart';

import '../domain/trigger.dart';

/// Trạng thái một "làn" (tiến trình) tại một dòng lịch sử.
class LaneCell {
  const LaneCell({
    this.up = false,
    this.down = false,
    this.dot = false,
    this.hollow = false,
  });

  /// Đường nối đi lên (về phía sự kiện mới hơn) và đi xuống (cũ hơn).
  final bool up;
  final bool down;

  /// Dòng này là sự kiện của tiến trình này: vẽ chấm.
  final bool dot;

  /// Chấm rỗng = sự kiện kết thúc, chấm đặc = bắt đầu.
  final bool hollow;
}

class EventRow {
  const EventRow(this.event, this.lanes, this.duration);

  final TriggerEvent event;
  final Map<ProcessType, LaneCell> lanes;

  /// Thời lượng lần chạy vừa kết thúc ở dòng này (null nếu không phải dòng kết thúc).
  final Duration? duration;
}

/// Dựng các dòng lịch sử, MỚI NHẤT Ở TRÊN. Mỗi tiến trình có một đường mảnh
/// nối sự kiện bắt đầu với sự kiện kết thúc; lần chạy đang mở được kéo lên
/// tới đầu danh sách. Quy tắc ghép giống `buildIntervals`.
List<EventRow> buildEventRows(List<TriggerEvent> events) {
  final sorted = [...events]..sort((a, b) {
      final c = a.time.compareTo(b.time);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  final n = sorted.length;

  final segments = <ProcessType, List<(int, int)>>{};
  final durations = <int, Duration>{};
  for (final p in ProcessType.values) {
    final list = <(int, int)>[];
    int? open;
    for (var k = 0; k < n; k++) {
      final e = sorted[k];
      if (e.trigger.process != p) continue;
      if (e.trigger.isStart) {
        open = k; // bắt đầu lại khi chưa kết thúc: lần trước không có đường nối
      } else if (open != null) {
        list.add((open, k));
        durations[k] = e.time.difference(sorted[open].time);
        open = null;
      }
    }
    if (open != null) list.add((open, n)); // đang chạy
    segments[p] = list;
  }

  final rows = <EventRow>[];
  for (var k = n - 1; k >= 0; k--) {
    final e = sorted[k];
    final lanes = <ProcessType, LaneCell>{};
    for (final p in ProcessType.values) {
      var up = false;
      var down = false;
      for (final s in segments[p]!) {
        if (k >= s.$1 && k <= s.$2) {
          if (k < s.$2) up = true;
          if (k > s.$1) down = true;
        }
      }
      final own = e.trigger.process == p;
      lanes[p] = LaneCell(
        up: up,
        down: down,
        dot: own,
        hollow: own && !e.trigger.isStart,
      );
    }
    rows.add(EventRow(e, lanes, durations[k]));
  }
  return rows;
}

/// Vẽ 3 làn cho một dòng: làn Làm việc ngoài cùng bên trái, làn Thiết kế
/// kế bên, chữ ở giữa, làn CNC ở mép phải.
class LanePainter extends CustomPainter {
  LanePainter(this.row, this.background);

  final EventRow row;
  final Color background;

  /// Chừa chỗ cho 2 làn bên trái / 1 làn bên phải khi đặt chữ.
  static const leftInset = 54.0;
  static const rightInset = 34.0;

  static double laneX(ProcessType p, double width) => switch (p) {
        ProcessType.work => 14,
        ProcessType.design => 32,
        ProcessType.cnc => width - 14,
      };

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    for (final p in ProcessType.values) {
      final cell = row.lanes[p]!;
      final x = laneX(p, size.width);
      final line = Paint()
        ..color = p.color
        ..strokeWidth = 1.5;
      if (cell.up) canvas.drawLine(Offset(x, 0), Offset(x, cy), line);
      if (cell.down) {
        canvas.drawLine(Offset(x, cy), Offset(x, size.height), line);
      }
      if (cell.dot) {
        if (cell.hollow) {
          canvas.drawCircle(Offset(x, cy), 5.5, Paint()..color = background);
          canvas.drawCircle(
            Offset(x, cy),
            4.5,
            Paint()
              ..color = p.color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        } else {
          canvas.drawCircle(Offset(x, cy), 5.5, Paint()..color = p.color);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant LanePainter oldDelegate) => true;
}
