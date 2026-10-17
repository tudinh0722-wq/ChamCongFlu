import 'package:chamcong_v2/domain/day_logic.dart';
import 'package:chamcong_v2/domain/trigger.dart';
import 'package:flutter_test/flutter_test.dart';

int _id = 0;

TriggerEvent ev(Trigger t, int h, int m) => TriggerEvent(
      id: ++_id,
      trigger: t,
      time: DateTime(2026, 10, 17, h, m),
    );

void main() {
  setUp(() => _id = 0);

  group('validate', () {
    test('cho phép bắt đầu lần đầu trong ngày', () {
      expect(validate([], Trigger.workStart), isNull);
    });

    test('chặn bắt đầu khi tiến trình đang chạy', () {
      final events = [ev(Trigger.workStart, 8, 0)];
      expect(validate(events, Trigger.workStart), isNotNull);
    });

    test('chặn kết thúc khi chưa bắt đầu, trừ xác nhận CNC', () {
      expect(validate([], Trigger.workEnd), isNotNull);
      expect(validate([], Trigger.cncEnd), isNotNull);
      expect(validate([], Trigger.cncConfirm), isNull);
    });

    test('3 tiến trình độc lập, chạy chồng lấn được', () {
      final events = [ev(Trigger.workStart, 8, 0)];
      expect(validate(events, Trigger.designStart), isNull);
      expect(validate(events, Trigger.cncStart), isNull);
    });

    test('bắt đầu lại được sau khi đã kết thúc', () {
      final events = [
        ev(Trigger.cncStart, 9, 0),
        ev(Trigger.cncEnd, 9, 30),
      ];
      expect(validate(events, Trigger.cncStart), isNull);
    });
  });

  group('summarize', () {
    final now = DateTime(2026, 10, 17, 18, 0);

    test('cộng nhiều lần chạy trong ngày', () {
      final events = [
        ev(Trigger.workStart, 8, 0),
        ev(Trigger.workEnd, 12, 0),
        ev(Trigger.workStart, 13, 0),
        ev(Trigger.workEnd, 17, 0),
        ev(Trigger.cncStart, 9, 0),
        ev(Trigger.cncEnd, 9, 30),
        ev(Trigger.cncStart, 10, 0),
        ev(Trigger.cncEnd, 11, 0),
      ];
      final s = summarize(events, now);
      expect(s.work, const Duration(hours: 8));
      expect(s.cnc, const Duration(minutes: 90));
      expect(s.cncRuns, 2);
      expect(s.design, Duration.zero);
    });

    test('xác nhận CNC sau khi đã kết thúc không đổi thời lượng', () {
      final events = [
        ev(Trigger.cncStart, 9, 0),
        ev(Trigger.cncEnd, 9, 30),
        ev(Trigger.cncConfirm, 9, 40),
      ];
      expect(summarize(events, now).cnc, const Duration(minutes: 30));
    });

    test('lần chạy đang mở: tính đến now, hoặc 0 khi countOpen=false', () {
      final events = [ev(Trigger.designStart, 17, 0)];
      expect(summarize(events, now).design, const Duration(hours: 1));
      expect(summarize(events, now, countOpen: false).design, Duration.zero);
    });

    test('bắt đầu lại khi chưa kết thúc: lần trước tính 0', () {
      final events = [
        ev(Trigger.workStart, 8, 0),
        ev(Trigger.workStart, 9, 0),
        ev(Trigger.workEnd, 10, 0),
      ];
      expect(summarize(events, now).work, const Duration(hours: 1));
    });
  });

  group('findIssues', () {
    test('ngày cũ có lần chạy chưa kết thúc thì cảnh báo', () {
      final events = [ev(Trigger.workStart, 8, 0)];
      expect(findIssues(events, isToday: false), hasLength(1));
    });

    test('hôm nay đang chạy là bình thường', () {
      final events = [ev(Trigger.workStart, 8, 0)];
      expect(findIssues(events, isToday: true), isEmpty);
    });

    test('kết thúc không có bắt đầu bị cảnh báo, xác nhận CNC thì không', () {
      final events = [
        ev(Trigger.designEnd, 8, 0),
        ev(Trigger.cncConfirm, 9, 0),
      ];
      expect(findIssues(events, isToday: true), hasLength(1));
    });

    test('hai lần bắt đầu liên tiếp bị cảnh báo', () {
      final events = [
        ev(Trigger.workStart, 8, 0),
        ev(Trigger.workStart, 9, 0),
        ev(Trigger.workEnd, 10, 0),
      ];
      expect(findIssues(events, isToday: true), hasLength(1));
    });
  });
}
