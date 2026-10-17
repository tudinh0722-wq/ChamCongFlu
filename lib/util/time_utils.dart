// Hàm định dạng và mốc thời gian dùng chung.

String two(int n) => n.toString().padLeft(2, '0');

String hm(DateTime t) => '${two(t.hour)}:${two(t.minute)}';

String hms(DateTime t) => '${hm(t)}:${two(t.second)}';

String dmy(DateTime t) => '${two(t.day)}/${two(t.month)}/${t.year}';

/// Ví dụ 2h 05p
String hhmm(Duration d) {
  final m = d.inMinutes;
  return '${m ~/ 60}h ${two(m % 60)}p';
}

DateTime startOfDay(DateTime t) => DateTime(t.year, t.month, t.day);

DateTime nextDay(DateTime t) => DateTime(t.year, t.month, t.day + 1);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
