import 'package:sqflite/sqflite.dart';

import '../domain/tag_info.dart';
import '../domain/trigger.dart';

/// Đọc/ghi Event và Tag. UI không đụng SQL trực tiếp.
class Repository {
  Repository(this._db);

  final Database _db;

  // ---------- Event ----------

  /// Sự kiện trong khoảng [from, to), sắp theo giờ.
  Future<List<TriggerEvent>> eventsBetween(DateTime from, DateTime to) async {
    final rows = await _db.query(
      'event',
      where: 'ts >= ? AND ts < ?',
      whereArgs: [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
      orderBy: 'ts ASC, id ASC',
    );
    final result = <TriggerEvent>[];
    for (final r in rows) {
      final trigger = Trigger.fromName(r['trigger_type'] as String);
      if (trigger == null) continue; // dữ liệu lạ: bỏ qua
      result.add(TriggerEvent(
        id: r['id'] as int,
        trigger: trigger,
        time: DateTime.fromMillisecondsSinceEpoch(r['ts'] as int),
        tagId: r['tag_id'] as String?,
      ));
    }
    return result;
  }

  Future<TriggerEvent> insertEvent(
    Trigger trigger,
    DateTime time, {
    String? tagId,
  }) async {
    final id = await _db.insert('event', {
      'tag_id': tagId,
      'trigger_type': trigger.name,
      'ts': time.millisecondsSinceEpoch,
    });
    return TriggerEvent(id: id, trigger: trigger, time: time, tagId: tagId);
  }

  Future<void> updateEvent(int id, Trigger trigger, DateTime time) async {
    await _db.update(
      'event',
      {'trigger_type': trigger.name, 'ts': time.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteEvent(int id) async {
    await _db.delete('event', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Tag ----------

  static TagInfo? _tag(Map<String, Object?> r) {
    final trigger = Trigger.fromName(r['trigger_type'] as String);
    if (trigger == null) return null;
    return TagInfo(
      id: r['id'] as String,
      name: r['name'] as String,
      trigger: trigger,
      uid: r['uid'] as String?,
      active: (r['active'] as int) == 1,
    );
  }

  Future<List<TagInfo>> tags() async {
    final rows = await _db.query('tag', orderBy: 'id ASC');
    return rows.map(_tag).whereType<TagInfo>().toList();
  }

  Future<TagInfo?> tagByUid(String uid) async {
    final rows =
        await _db.query('tag', where: 'uid = ?', whereArgs: [uid], limit: 1);
    return rows.isEmpty ? null : _tag(rows.first);
  }

  /// Gán UID cho thẻ. UID đang gắn ở thẻ khác sẽ được gỡ khỏi thẻ đó
  /// (UID là duy nhất, thay thẻ hỏng chỉ cần gán UID mới vào Tag cũ).
  Future<void> setTagUid(String tagId, String uid) async {
    await _db.transaction((txn) async {
      await txn.update('tag', {'uid': null},
          where: 'uid = ? AND id != ?', whereArgs: [uid, tagId]);
      await txn.update('tag', {'uid': uid},
          where: 'id = ?', whereArgs: [tagId]);
    });
  }

  Future<void> clearTagUid(String tagId) async {
    await _db.update('tag', {'uid': null}, where: 'id = ?', whereArgs: [tagId]);
  }

  Future<void> renameTag(String tagId, String name) async {
    await _db.update('tag', {'name': name}, where: 'id = ?', whereArgs: [tagId]);
  }

  Future<void> setTagActive(String tagId, bool active) async {
    await _db.update('tag', {'active': active ? 1 : 0},
        where: 'id = ?', whereArgs: [tagId]);
  }
}
