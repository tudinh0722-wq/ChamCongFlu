import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'default_tags.dart';

/// Database offline `chamcong_v2.db` (tên riêng, tách khỏi app cũ).
///
/// v1: bảng tag + event, 7 thẻ mặc định chưa có UID.
/// v2: 7 thẻ mặc định có sẵn UID (xem default_tags.dart); nâng cấp từ v1 chỉ
///     điền UID cho thẻ còn trống, không ghi đè UID đã gán.
class AppDatabase {
  static const fileName = 'chamcong_v2.db';
  static const schemaVersion = 2;

  /// Mở database. Nếu file hỏng hoặc sai schema thì ĐỔI TÊN thành
  /// `.broken-<mốc thời gian>` (không xóa) rồi tạo database mới.
  static Future<Database> open() async {
    final path = p.join(await getDatabasesPath(), fileName);
    debugPrint('[AppDatabase] mở $path');
    try {
      return await _open(path);
    } catch (e) {
      debugPrint('[AppDatabase] mở lỗi ($e), đổi tên file cũ và tạo mới');
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
      onUpgrade: _onUpgrade,
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
    for (final t in defaultTags) {
      batch.insert('tag', {
        'id': t.id,
        'name': t.name,
        'trigger_type': t.trigger.name,
        'uid': t.uid,
        'active': 1,
      });
    }
    await batch.commit(noResult: true);
  }

  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Điền UID mặc định cho thẻ còn trống, bỏ qua nếu UID đã dùng ở thẻ khác.
      for (final t in defaultTags) {
        final uid = t.uid;
        if (uid == null) continue;
        await db.rawUpdate(
          'UPDATE tag SET uid = ? WHERE id = ? AND uid IS NULL '
          'AND NOT EXISTS (SELECT 1 FROM tag WHERE uid = ?)',
          [uid, t.id, uid],
        );
      }
    }
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
