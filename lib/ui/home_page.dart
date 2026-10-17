import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/day_controller.dart';
import '../domain/day_logic.dart';
import '../domain/trigger.dart';
import '../util/time_utils.dart';
import 'event_rows.dart';
import 'timeline_painter.dart';

const _weekdays = [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ Nhật',
];

String _dayTitle(DateTime d) => '${_weekdays[d.weekday - 1]}, ${dmy(d)}';

/// Home: 3 block dọc.
/// 1) Timeline + tổng giờ trong ngày
/// 2) Bảng nút: hàng 1 = Bắt đầu, hàng 2 = Kết thúc; cột = Làm việc | Thiết kế | CNC
///    (ô Kết thúc CNC chia đôi: tại máy / tại bàn)
/// 3) Lịch sử trigger, chữ lớn, có đường nối bắt đầu - kết thúc theo tiến trình.
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
  Timer? _tick;
  DateTime _now = DateTime.now();
  bool _reloading = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    // Vẽ lại 5 phút một lần (thanh đang chạy dài ra, vạch "bây giờ" dịch chuyển).
    _tick = Timer.periodic(const Duration(minutes: 5), (_) {
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
    _tick?.cancel();
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  /// Có sự kiện mới / vừa nạp lại: vẽ lại ngay với giờ hiện tại.
  void _onControllerChanged() {
    if (mounted) setState(() => _now = DateTime.now());
  }

  Future<void> _press(Trigger t) async {
    HapticFeedback.mediumImpact();
    final r = await widget.controller.press(t);
    widget.onMessage(r.message, error: !r.ok);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final events = widget.controller.events;
    final rows = buildEventRows(events);
    final summary = summarize(events, _now);

    return SafeArea(
      child: Column(
        children: [
          // ---------- Block 1: timeline + tổng giờ ----------
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _dayTitle(widget.controller.day),
                        style: tt.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (final p in ProcessType.values)
                      Expanded(child: _total(p, summary.of(p), cs)),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 104,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: TimelinePainter(
                      events: events,
                      now: _now,
                      textColor: cs.onSurface,
                      gridColor: cs.outlineVariant,
                      trackColor: cs.surfaceContainerHigh,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ---------- Block 2: bảng nút 2 hàng x 3 cột ----------
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _startButton(Trigger.workStart)),
                    const SizedBox(width: 8),
                    Expanded(child: _startButton(Trigger.designStart)),
                    const SizedBox(width: 8),
                    Expanded(child: _startButton(Trigger.cncStart)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _endButton(Trigger.workEnd, 'Kết thúc')),
                    const SizedBox(width: 8),
                    Expanded(child: _endButton(Trigger.designEnd, 'Kết thúc')),
                    const SizedBox(width: 8),
                    // Ô thứ 6: chia đôi cho trigger 6 và 7
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _endButton(
                              Trigger.cncEnd,
                              'Kết thúc',
                              bottom: 'tại máy',
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _endButton(
                              Trigger.cncConfirm,
                              'Xác nhận',
                              bottom: 'tại bàn',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ---------- Block 3: lịch sử ----------
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 2),
            child: Row(
              children: [
                Text(
                  'Lịch sử hôm nay',
                  style: tt.titleSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const Spacer(),
                Text(
                  '${events.length} mốc',
                  style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text(
                      'Chưa có sự kiện hôm nay',
                      style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: rows.length,
                    itemExtent: 58,
                    itemBuilder: (context, i) =>
                        _EventTile(row: rows[i], background: cs.surface),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _total(ProcessType p, Duration d, ColorScheme cs) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 4, backgroundColor: p.color),
          const SizedBox(width: 6),
          Text(
            '${p.label} ',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          Text(
            hhmm(d),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _caption(String top, String bottom, {double bottomSize = 17}) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(top, style: const TextStyle(fontSize: 12, height: 1.1)),
          Text(
            bottom,
            style: TextStyle(
              fontSize: bottomSize,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Hàng 1: nút đặc màu tiến trình.
  Widget _startButton(Trigger t) {
    final p = t.process;
    final fg = ThemeData.estimateBrightnessForColor(p.color) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    return SizedBox(
      height: 62,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: p.color,
          foregroundColor: fg,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: () => _press(t),
        child: _caption(p.label, 'Bắt đầu'),
      ),
    );
  }

  /// Hàng 2: nút viền màu tiến trình, nền nhạt.
  Widget _endButton(Trigger t, String top, {String? bottom}) {
    final cs = Theme.of(context).colorScheme;
    final p = t.process;
    final split = bottom != null;
    return SizedBox(
      height: 62,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: Color.alphaBlend(p.color.withAlpha(46), cs.surface),
          foregroundColor: cs.onSurface,
          side: BorderSide(color: p.color, width: 1.5),
          padding: EdgeInsets.symmetric(horizontal: split ? 2 : 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(split ? 12 : 16),
          ),
        ),
        onPressed: () => _press(t),
        child: split
            ? _caption(top, bottom, bottomSize: 14)
            : _caption(p.label, top),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.row, required this.background});

  final EventRow row;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return CustomPaint(
      painter: LanePainter(row, background),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          LanePainter.leftInset,
          0,
          LanePainter.rightInset,
          0,
        ),
        child: Row(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hms(row.event.time),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (row.duration != null)
                  Text(
                    'chạy ${hhmm(row.duration!)}',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.2,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                row.event.trigger.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.bodyLarge
                    ?.copyWith(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
