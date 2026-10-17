import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/trigger.dart';

/// Database offline `chamcong_v2.db` (tên riêng, tách khỏi app cũ).
class AppDatabase {
  static const fileName = 'chamcong_v2.db';
  static const schemaVersion = 1;

  /// 7 thẻ mặc định, CHƯA có UID: gán bằng cách quét ở màn Thẻ.
  /// Trigger của TAG-001..005 là theo thứ tự thường gặp, có thể kiểm tra lại.
  static const _defaultTags = <(String, String, Trigger)>[
    ('TAG-001', 'Bắt đầu làm việc', Trigger.workStart),
    ('TAG-002', 'Kết thúc làm việc', Trigger.workEnd),
    ('TAG-003', 'Bắt đầu thiết kế', Trigger.designStart),
    ('TAG-004', 'Kết thúc thiết kế', Trigger.designEnd),
    ('TAG-005', 'Bắt đầu máy CNC', Trigger.cncStart),
    ('TAG-006', 'Kết thúc máy CNC (vị trí 1)', Trigger.cncEnd),
    ('TAG-007', 'Kết thúc máy CNC (vị trí 2)', Trigger.cncEnd),
  ];

  /// Mở database. Nếu file hỏng hoặc sai schema thì ĐỔI TÊN thành
  /// `.broken-<mốc thời gian>` (không xóa) rồi tạo database mới.
  static Future<Database> open() async {
    final path = p.join(await getDatabasesPath(), fileName);
    try {
      return await _open(path);
    } catch (_) {
      await _moveAside(path);
      return _open(path);
    }
  }

  static Future<Database> _open(String path) {
    return openDatabase(
      path,
      version: schemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onDowngrade: (db, oldVersion, newVersion) => throw StateError(
          'Database (v$oldVersion) mới hơn app (v$newVersion)'),
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
CREATE TABLE tag (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  trigger_type TEXT NOT NULL,
  uid TEXT,
  active INTEGER NOT NULL DEFAULT 1
)''');
    await db.execute(
        'CREATE UNIQUE INDEX idx_tag_uid ON tag(uid) WHERE uid IS NOT NULL');
    await db.execute('''
CREATE TABLE event (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tag_id TEXT REFERENCES tag(id) ON DELETE SET NULL,
  trigger_type TEXT NOT NULL,
  ts INTEGER NOT NULL
)''');
    await db.execute('CREATE INDEX idx_event_ts ON event(ts)');

    final batch = db.batch();
    for (final t in _defaultTags) {
      batch.insert('tag', {
        'id': t.$1,
        'name': t.$2,
        'trigger_type': t.$3.name,
        'uid': null,
        'active': 1,
      });
    }
    await batch.commit(noResult: true);
  }

  static Future<void> _moveAside(String path) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final f = File('$path$suffix');
      if (await f.exists()) {
        await f.rename('$path.broken-$stamp$suffix');
      }
    }
  }
}
