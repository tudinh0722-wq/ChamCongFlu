import 'dart:async';
import 'package:flutter/material.dart';

import '../domain/day_controller.dart';
import '../domain/trigger.dart';
import '../util/time_utils.dart';
import 'timeline_painter.dart';

/// Home: 3 block dọc, mỗi block rộng 100%.
/// 1) Timeline 6:00-22:00  2) 7 nút trigger  3) Lịch sử trigger trong ngày.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.onMessage,
  });

  final DayController controller;

  /// Hiện Snackbar phản hồi (do AppServices cung cấp).
  final void Function(String text, {bool error}) onMessage;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Timer _tick;
  DateTime _now = DateTime.now();
  bool _reloading = false;

  @override
  void initState() {
    super.initState();
    // 1 giây/lần: thanh đang chạy dài ra theo thời gian thực.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      setState(() => _now = now);
      if (!sameDay(now, widget.controller.day) && !_reloading) {
        _reloading = true;
        widget.controller.load().whenComplete(() => _reloading = false);
      }
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  Future<void> _press(Trigger t) async {
    final r = await widget.controller.press(t);
    widget.onMessage(r.message, error: !r.ok);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final events = widget.controller.events;
          return Column(
            children: [
              // Block 1: timeline
              SizedBox(
                height: 150,
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: CustomPaint(
                    painter: TimelinePainter(
                        events, _now, cs.onSurface, cs.outlineVariant),
                  ),
                ),
              ),
              // Block 2: 7 nút trigger
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _row(Trigger.workStart, Trigger.workEnd),
                    _row(Trigger.designStart, Trigger.designEnd),
                    _row(Trigger.cncStart, Trigger.cncEnd),
                    _row(Trigger.cncConfirm, null),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Block 3: lịch sử, mới nhất ở trên
              Expanded(
                child: events.isEmpty
                    ? Center(
                        child: Text('Chưa có sự kiện hôm nay',
                            style: TextStyle(color: cs.onSurfaceVariant)),
                      )
                    : ListView.builder(
                        itemCount: events.length,
                        itemBuilder: (context, i) {
                          final e = events[events.length - 1 - i];
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 6,
                              backgroundColor: e.trigger.process.color,
                            ),
                            title: Text(e.trigger.label),
                            trailing: Text(
                              hms(e.time),
                              style: const TextStyle(
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(Trigger a, Trigger? b) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(child: _btn(a)),
          if (b != null) ...[
            const SizedBox(width: 8),
            Expanded(child: _btn(b)),
          ],
        ]),
      );

  Widget _btn(Trigger t) => SizedBox(
        height: 60,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: t.process.color,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () => _press(t),
          child: Text(t.label, textAlign: TextAlign.center),
        ),
      );
}
