import 'package:flutter/foundation.dart';

import '../data/repository.dart';
import '../util/time_utils.dart';
import 'day_logic.dart';
import 'trigger.dart';

class TriggerResult {
  const TriggerResult(this.ok, this.message);

  final bool ok;
  final String message;
}

/// State của ngày hiện tại (Home). Mọi sự kiện lưu database; trạng thái
/// "đang chạy" luôn suy ra từ danh sách sự kiện nên mở lại app vẫn đúng.
class DayController extends ChangeNotifier {
  DayController(this._repo);

  final Repository _repo;

  DateTime _day = startOfDay(DateTime.now());
  List<TriggerEvent> _events = const [];
  Future<void> _queue = Future.value();

  DateTime get day => _day;
  List<TriggerEvent> get events => _events;

  /// Nạp lại sự kiện của hôm nay (gọi khi mở app, sang ngày mới, hoặc sau khi
  /// sửa ở màn Lịch sử).
  Future<void> load() async {
    _day = startOfDay(DateTime.now());
    _events = await _repo.eventsBetween(_day, nextDay(_day));
    notifyListeners();
  }

  /// Bấm trigger. Các lần bấm được xếp hàng để hai thao tác gần nhau
  /// (nút + quét thẻ) không vượt qua kiểm tra cùng lúc.
  Future<TriggerResult> press(
    Trigger t, {
    DateTime? at,
    String? tagId,
  }) {
    final result = _queue.then((_) => _press(t, at: at, tagId: tagId));
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<TriggerResult> _press(
    Trigger t, {
    DateTime? at,
    String? tagId,
  }) async {
    final time = at ?? DateTime.now();
    try {
      if (!sameDay(time, _day)) await load(); // sang ngày mới
      final error = validate(_events, t);
      if (error != null) return TriggerResult(false, error);

      final event = await _repo.insertEvent(t, time, tagId: tagId);
      _events = [..._events, event];
      notifyListeners();
      return TriggerResult(true, 'Đã ${_lowerFirst(t.label)} lúc ${hm(time)}');
    } catch (e) {
      return TriggerResult(false, 'Không ghi được sự kiện: $e');
    }
  }

  static String _lowerFirst(String s) =>
      s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);
}
