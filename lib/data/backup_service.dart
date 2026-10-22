import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/trigger.dart';

/// Thư mục sao lưu người dùng chọn (Storage Access Framework).
class BackupFolder {
  const BackupFolder(this.uri, this.name);

  final String uri;
  final String name;
}

/// Một bản sao lưu đọc được từ thư mục.
class FoundBackup {
  const FoundBackup({
    required this.slot,
    required this.exportedAt,
    required this.events,
    required this.tags,
    required this.json,
  });

  final String slot;
  final DateTime exportedAt;
  final int events;
  final int tags;
  final Map<String, dynamic> json;
}

enum BackupResult { ok, noFolder, skippedEmpty, error }

/// Sao lưu tự động ra thư mục NGOÀI app, để gỡ/cài lại app vẫn còn dữ liệu.
///
/// - Người dùng chọn thư mục một lần (mỗi lần cài lại phải chọn lại: Android
///   thu hồi quyền khi gỡ app).
/// - Ghi luân phiên 2 file (a/b): lỡ app bị tắt giữa lúc ghi thì file kia vẫn
///   nguyên vẹn. Khôi phục dùng file hợp lệ mới nhất.
/// - KHÔNG BAO GIỜ ghi đè bản sao lưu có dữ liệu bằng database trống.
class BackupService extends ChangeNotifier {
  BackupService(this._db);

  static const _channel = MethodChannel('chamcong/backup');
  static const _slots = ['chamcong_backup_a.json', 'chamcong_backup_b.json'];
  static const _delay = Duration(seconds: 3);

  final Database _db;
  BackupFolder? _folder;
  DateTime? _lastBackupAt;
  String? _lastError;
  Timer? _timer;
  bool _busy = false;
  bool _again = false;
  bool _disposed = false;

  BackupFolder? get folder => _folder;
  bool get hasFolder => _folder != null;
  DateTime? get lastBackupAt => _lastBackupAt;
  String? get lastError => _lastError;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  static BackupFolder? _parseFolder(Map<Object?, Object?>? r) {
    if (r == null) return null;
    final uri = r['uri'];
    if (uri is! String || uri.isEmpty) return null;
    final name = r['name'];
    return BackupFolder(uri, name is String ? name : '');
  }

  static const _notPatched =
      'Chưa vá MainActivity: chạy scripts\\bootstrap_android.ps1 rồi chạy lại app.';

  /// Kiểm tra thư mục đã chọn còn quyền truy cập không (mất sau khi gỡ app).
  Future<void> refreshFolder() async {
    try {
      final r = await _channel.invokeMethod<Map<Object?, Object?>>('getFolder');
      _folder = _parseFolder(r);
    } on MissingPluginException {
      _folder = null;
      _lastError = _notPatched;
    } on PlatformException catch (e) {
      _folder = null;
      _lastError = e.message;
    }
    _notify();
  }

  /// Mở bộ chọn thư mục của Android. Trả true nếu người dùng đã chọn.
  Future<bool> pickFolder() async {
    try {
      final r = await _channel.invokeMethod<Map<Object?, Object?>>('pickFolder');
      final f = _parseFolder(r);
      if (f == null) return false;
      _folder = f;
      _lastError = null;
      _notify();
      return true;
    } on MissingPluginException {
      _lastError = _notPatched;
      _notify();
      return false;
    } on PlatformException catch (e) {
      _lastError = e.message;
      _notify();
      return false;
    }
  }

  Future<int> eventCount() async =>
      Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM event')) ??
      0;

  Future<Map<String, dynamic>> _buildJson() async {
    final tags = await _db.query('tag', orderBy: 'id ASC');
    final events = await _db.query('event', orderBy: 'ts ASC, id ASC');
    return {
      'app': 'chamcong',
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'tags': [
        for (final r in tags)
          {
            'id': r['id'],
            'name': r['name'],
            'trigger': r['trigger_type'],
            'uid': r['uid'],
            'active': r['active'],
          },
      ],
      'events': [
        for (final r in events)
          {
            'trigger': r['trigger_type'],
            'ts': r['ts'],
            'tagId': r['tag_id'],
          },
      ],
    };
  }

  Future<Map<String, dynamic>?> _readSlot(String name) async {
    final text = await _channel.invokeMethod<String>('readText', {'name': name});
    if (text == null || text.isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic> &&
          decoded['app'] == 'chamcong' &&
          decoded['events'] is List &&
          decoded['tags'] is List) {
        return decoded;
      }
    } catch (_) {
      // file hỏng (ghi dở): bỏ qua, dùng file còn lại
    }
    return null;
  }

  /// Bản sao lưu hợp lệ mới nhất trong thư mục, hoặc null nếu chưa có.
  /// Ném lỗi nếu không đọc được thư mục (mất quyền...).
  Future<FoundBackup?> latestBackup() async {
    FoundBackup? best;
    for (final slot in _slots) {
      final json = await _readSlot(slot);
      if (json == null) continue;
      final at = DateTime.tryParse('${json['exportedAt']}');
      if (at == null) continue;
      if (best == null || at.isAfter(best.exportedAt)) {
        best = FoundBackup(
          slot: slot,
          exportedAt: at.toLocal(),
          events: (json['events'] as List).length,
          tags: (json['tags'] as List).length,
          json: json,
        );
      }
    }
    return best;
  }

  /// Ghi sao lưu ngay. Có debounce riêng ở [schedule] cho sao lưu tự động.
  Future<BackupResult> backupNow() async {
    if (_folder == null) return BackupResult.noFolder;
    if (_busy) {
      _again = true;
      return BackupResult.ok;
    }
    _busy = true;
    try {
      final json = await _buildJson();
      final eventCount = (json['events'] as List).length;
      final existing = await latestBackup();
      if (eventCount == 0 && existing != null && existing.events > 0) {
        // Điện thoại trống mà bản sao lưu có dữ liệu: có thể vừa cài lại.
        // Không ghi đè, chờ người dùng khôi phục.
        _lastError = null;
        return BackupResult.skippedEmpty;
      }
      // Ghi vào file KHÁC file hợp lệ mới nhất.
      final slot = existing?.slot == _slots[0] ? _slots[1] : _slots[0];
      await _channel.invokeMethod<void>(
        'writeText',
        {'name': slot, 'text': jsonEncode(json)},
      );
      _lastBackupAt = DateTime.now();
      _lastError = null;
      return BackupResult.ok;
    } on MissingPluginException {
      _lastError = _notPatched;
      return BackupResult.error;
    } catch (e) {
      _lastError = '$e';
      unawaited(refreshFolder()); // có thể đã mất quyền thư mục
      return BackupResult.error;
    } finally {
      _busy = false;
      _notify();
      if (_again) {
        _again = false;
        schedule();
      }
    }
  }

  /// Lên lịch sao lưu 3 giây sau thay đổi cuối cùng.
  void schedule() {
    if (_folder == null || _disposed) return;
    _timer?.cancel();
    _timer = Timer(_delay, () => unawaited(backupNow()));
  }

  /// Nhập bản sao lưu vào database: sự kiện trùng (cùng loại, cùng giờ) được
  /// bỏ qua, thẻ được cập nhật theo bản sao lưu. Trả về số sự kiện đã thêm.
  Future<int> restore(FoundBackup backup) async {
    final tags = backup.json['tags'] as List;
    final events = backup.json['events'] as List;
    var inserted = 0;

    await _db.transaction((txn) async {
      final tagIds = <String>{
        for (final r in await txn.query('tag', columns: ['id']))
          r['id'] as String,
      };

      for (final t in tags) {
        if (t is! Map) continue;
        final id = t['id'];
        final trigger = t['trigger'];
        if (id is! String || trigger is! String) continue;
        if (Trigger.fromName(trigger) == null) continue;

        final rawUid = t['uid'];
        final uid = rawUid is String && rawUid.isNotEmpty ? rawUid : null;
        if (uid != null) {
          // UID là duy nhất: gỡ khỏi thẻ khác trước khi gán.
          await txn.update('tag', {'uid': null},
              where: 'uid = ? AND id != ?', whereArgs: [uid, id]);
        }
        final name = t['name'];
        final values = <String, Object?>{
          'name': name is String ? name : id,
          'trigger_type': trigger,
          'uid': uid,
          'active': t['active'] == 0 ? 0 : 1,
        };
        final updated =
            await txn.update('tag', values, where: 'id = ?', whereArgs: [id]);
        if (updated == 0) {
          await txn.insert('tag', {'id': id, ...values});
        }
        tagIds.add(id);
      }

      final existing = <String>{
        for (final r
            in await txn.query('event', columns: ['trigger_type', 'ts']))
          '${r['trigger_type']}|${r['ts']}',
      };
      for (final e in events) {
        if (e is! Map) continue;
        final trigger = e['trigger'];
        final ts = e['ts'];
        if (trigger is! String || ts is! int) continue;
        if (Trigger.fromName(trigger) == null) continue;
        final key = '$trigger|$ts';
        if (existing.contains(key)) continue;
        final tagId = e['tagId'];
        await txn.insert('event', {
          'tag_id': tagId is String && tagIds.contains(tagId) ? tagId : null,
          'trigger_type': trigger,
          'ts': ts,
        });
        existing.add(key);
        inserted++;
      }
    });
    _notify();
    return inserted;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
