import 'package:flutter/material.dart';

import '../domain/day_logic.dart';
import '../domain/trigger.dart';

/// 3 thanh song song (làm việc, thiết kế, CNC).
/// Trục mặc định 7:00 -> 19:00; có sự kiện sớm hơn hoặc muộn hơn thì trục tự
/// mở rộng tới giờ đó. Lần chạy đang mở được vẽ tới "bây giờ" (vạch đỏ).
class TimelinePainter extends CustomPainter {
  TimelinePainter({
    required this.events,
    required this.now,
    required this.textColor,
    required this.gridColor,
    required this.trackColor,
  });

  final List<TriggerEvent> events;
  final DateTime now;
  final Color textColor;
  final Color gridColor;
  final Color trackColor;

  static const defaultStartHour = 7;
  static const defaultEndHour = 19;

  /// Khoảng giờ hiển thị (giờ đầu, giờ cuối), mở rộng theo sự kiện thực tế.
  static (int, int) hourRange(List<TriggerEvent> events, DateTime now) {
    var start = defaultStartHour;
    var end = defaultEndHour;

    void include(DateTime t) {
      if (t.hour < start) start = t.hour;
      final endHour = (t.minute == 0 && t.second == 0) ? t.hour : t.hour + 1;
      if (endHour > end) end = endHour;
    }

    for (final e in events) {
      include(e.time);
    }
    // Có tiến trình đang chạy thì thanh dài tới bây giờ.
    if (ProcessType.values.any((p) => isRunning(events, p))) include(now);

    if (end > 24) end = 24;
    if (end <= start) end = start + 1;
    return (start, end);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 56.0;
    const right = 6.0;
    const top = 2.0;
    const axisH = 18.0;
    const gap = 6.0;

    final (startHour, endHour) = hourRange(events, now);
    final plotW = size.width - left - right;
    final rowH = (size.height - top - axisH) / 3;
    final day = DateTime(now.year, now.month, now.day);
    final t0 = day.add(Duration(hours: startHour));
    final span = (endHour - startHour) * 3600;
    final plotBottom = size.height - axisH;

    double x(DateTime t) {
      final s = t.difference(t0).inSeconds.clamp(0, span);
      return left + plotW * s / span;
    }

    // Nền từng hàng
    final track = Paint()..color = trackColor;
    for (var i = 0; i < 3; i++) {
      final y = top + rowH * i;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, y + gap / 2, left + plotW, y + rowH - gap / 2),
          const Radius.circular(6),
        ),
        track,
      );
    }

    // Vạch giờ + nhãn giờ
    final hours = endHour - startHour;
    final step = hours <= 14 ? 1 : 2;
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var h = startHour; h <= endHour; h += step) {
      final gx = left + plotW * (h - startHour) / hours;
      canvas.drawLine(Offset(gx, top), Offset(gx, plotBottom), grid);
      _text(canvas, '$h', Offset(gx, plotBottom + 3), 10, center: true);
    }

    // Thanh tiến trình
    for (var i = 0; i < ProcessType.values.length; i++) {
      final p = ProcessType.values[i];
      final y = top + rowH * i;
      _text(canvas, p.label, Offset(4, y + (rowH - 13) / 2), 11);
      final paint = Paint()..color = p.color;
      for (final it in buildIntervals(events, p)) {
        final a = x(it.start);
        final b = x(it.displayEnd(now));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              a,
              y + gap / 2,
              b < a + 3 ? a + 3 : b,
              y + rowH - gap / 2,
            ),
            const Radius.circular(5),
          ),
          paint,
        );
      }
    }

    // Vạch "bây giờ"
    if (!now.isBefore(t0) && now.difference(t0).inSeconds <= span) {
      final nx = x(now);
      final red = Paint()
        ..color = Colors.red
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(nx, top), Offset(nx, plotBottom), red);
      canvas.drawCircle(Offset(nx, top + 1), 3, red);
    }
  }

  void _text(Canvas c, String s, Offset o, double fontSize,
      {bool center = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(color: textColor, fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center ? Offset(o.dx - tp.width / 2, o.dy) : o);
  }

  @override
  bool shouldRepaint(covariant TimelinePainter oldDelegate) => true;
}
