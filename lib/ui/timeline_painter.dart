import 'package:flutter/material.dart';

import '../domain/day_logic.dart';
import '../domain/trigger.dart';

/// 3 thanh song song (làm việc, thiết kế, CNC) trên trục 6:00 -> 22:00.
/// Lần chạy đang mở được vẽ dài tới "bây giờ"; vạch đỏ là thời điểm hiện tại.
class TimelinePainter extends CustomPainter {
  TimelinePainter(this.events, this.now, this.textColor, this.gridColor);

  final List<TriggerEvent> events;
  final DateTime now;
  final Color textColor;
  final Color gridColor;

  static const startHour = 6;
  static const endHour = 22;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 56.0;
    const top = 4.0;
    const axisH = 18.0;
    final w = size.width - left - 8;
    final rowH = (size.height - top - axisH) / 3;
    final day = DateTime(now.year, now.month, now.day);
    final t0 = day.add(const Duration(hours: startHour));
    final span = const Duration(hours: endHour - startHour).inSeconds;

    double x(DateTime t) {
      final s = t.difference(t0).inSeconds.clamp(0, span).toDouble();
      return left + w * s / span;
    }

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var h = startHour; h <= endHour; h += 2) {
      final gx = left + w * (h - startHour) / (endHour - startHour);
      canvas.drawLine(Offset(gx, top), Offset(gx, size.height - axisH), grid);
      _text(canvas, '$h', Offset(gx - 6, size.height - axisH + 2), 11);
    }

    for (var i = 0; i < ProcessType.values.length; i++) {
      final p = ProcessType.values[i];
      final y = top + rowH * i;
      _text(canvas, p.label, Offset(2, y + rowH / 2 - 7), 11);
      final paint = Paint()..color = p.color;
      for (final it in buildIntervals(events, p)) {
        final a = x(it.start);
        final b = x(it.displayEnd(now));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(a, y + 6, b < a + 2 ? a + 2 : b, y + rowH - 6),
            const Radius.circular(4),
          ),
          paint,
        );
      }
    }

    final nx = x(now);
    canvas.drawLine(
      Offset(nx, top),
      Offset(nx, size.height - axisH),
      Paint()
        ..color = Colors.red
        ..strokeWidth = 1.5,
    );
  }

  void _text(Canvas c, String s, Offset o, double size) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: textColor, fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, o);
  }

  @override
  bool shouldRepaint(covariant TimelinePainter oldDelegate) => true;
}
