import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/day_controller.dart';
import '../domain/day_logic.dart';
import '../domain/trigger.dart';
import '../util/time_utils.dart';
import 'event_rows.dart';
import 'timeline_painter.dart';

/// Đổi độ sáng (HSL) của một màu.
Color _shade(Color c, double delta) {
  final h = HSLColor.fromColor(c);
  final l = h.lightness + delta;
  return h.withLightness(l < 0 ? 0.0 : (l > 1 ? 1.0 : l)).toColor();
}

/// Màu tiến trình dùng cho chữ: tối đi trên nền sáng, sáng lên trên nền tối
/// để vẫn đọc được (vàng CNC thuần gần như vô hình trên nền sáng).
Color _readable(Color c, Brightness brightness) {
  final h = HSLColor.fromColor(c);
  final double l;
  if (brightness == Brightness.light) {
    l = h.lightness < 0.42 ? h.lightness : 0.42;
  } else {
    l = h.lightness > 0.68 ? h.lightness : 0.68;
  }
  return h.withLightness(l).toColor();
}

Color _onColor(Color bg) =>
    ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
        ? Colors.white
        : Colors.black87;

/// Home: 3 block dọc, cùng lề 12 và cùng bo góc. (Ngày hôm nay nằm trên AppBar.)
/// 1) Card timeline lớn + tổng giờ (màu theo tiến trình) bên dưới
/// 2) Bảng nút gọn: hàng 1 = Bắt đầu, hàng 2 = Kết thúc; cột = Làm việc | Thiết kế | CNC
///    (ô Kết thúc CNC chia đôi: tại máy / tại bàn). Tất cả là nút đặc.
/// 3) Card lịch sử: chữ nhỏ gọn, 3 làn đường mảnh nối bắt đầu - kết thúc.
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
  static const _margin = 12.0;
  static const _radius = 20.0;
  static const _buttonRadius = 14.0;
  static const _buttonHeight = 50.0;

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
    final brightness = Theme.of(context).brightness;
    final events = widget.controller.events;
    final rows = buildEventRows(events);
    final summary = summarize(events, _now);
    final cardColor = cs.surfaceContainerLow;

    return Column(
      children: [
        // ---------- Block 1: timeline lớn, tổng giờ bên dưới ----------
        Container(
          margin: const EdgeInsets.fromLTRB(_margin, 4, _margin, 0),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(_radius),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 170,
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
              const SizedBox(height: 10),
              // Tổng giờ: chỉ số, màu = màu tiến trình (Làm việc, Thiết kế, CNC)
              Row(
                children: [
                  for (final p in ProcessType.values)
                    Expanded(
                      child: Text(
                        hhmm(summary.of(p)),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _readable(p.color, brightness),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // ---------- Block 2: bảng nút 2 hàng x 3 cột (gọn) ----------
        Padding(
          padding: const EdgeInsets.fromLTRB(_margin, 8, _margin, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _startButton(Trigger.workStart)),
                  const SizedBox(width: 6),
                  Expanded(child: _startButton(Trigger.designStart)),
                  const SizedBox(width: 6),
                  Expanded(child: _startButton(Trigger.cncStart)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: _endButton(Trigger.workEnd, 'Kết thúc')),
                  const SizedBox(width: 6),
                  Expanded(child: _endButton(Trigger.designEnd, 'Kết thúc')),
                  const SizedBox(width: 6),
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
                        const SizedBox(width: 3),
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

        // ---------- Block 3: card lịch sử ----------
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(_margin, 8, _margin, 4),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(_radius),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
                  child: Row(
                    children: [
                      Text(
                        'Lịch sử hôm nay',
                        style:
                            tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Text(
                        '${events.length} mốc',
                        style: tt.labelMedium
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: rows.isEmpty
                      ? Center(
                          child: Text(
                            'Chưa có sự kiện hôm nay',
                            style: tt.bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 6),
                          itemCount: rows.length,
                          itemExtent: 48,
                          itemBuilder: (context, i) => _EventTile(
                            row: rows[i],
                            background: cardColor,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _caption(String top, String bottom, {double bottomSize = 15}) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(top, style: const TextStyle(fontSize: 11, height: 1.1)),
          Text(
            bottom,
            style: TextStyle(
              fontSize: bottomSize,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  ButtonStyle _solid(Color bg, {double hPad = 4}) => FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: _onColor(bg),
        padding: EdgeInsets.symmetric(horizontal: hPad),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_buttonRadius),
        ),
      );

  /// Hàng 1: nút đặc, màu tiến trình.
  Widget _startButton(Trigger t) {
    final p = t.process;
    return SizedBox(
      height: _buttonHeight,
      child: FilledButton(
        style: _solid(p.color),
        onPressed: () => _press(t),
        child: _caption(p.label, 'Bắt đầu'),
      ),
    );
  }

  /// Hàng 2: nút đặc, cùng tông màu tiến trình nhưng đậm hơn (không viền).
  Widget _endButton(Trigger t, String top, {String? bottom}) {
    final p = t.process;
    final split = bottom != null;
    return SizedBox(
      height: _buttonHeight,
      child: FilledButton(
        style: _solid(_shade(p.color, -0.14), hPad: split ? 2 : 4),
        onPressed: () => _press(t),
        child: split
            ? _caption(top, bottom, bottomSize: 12)
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
                  hm(row.event.time),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (row.duration != null)
                  Text(
                    'chạy ${hhmm(row.duration!)}',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.15,
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
