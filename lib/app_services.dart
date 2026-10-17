import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'data/app_database.dart';
import 'data/repository.dart';
import 'domain/day_controller.dart';
import 'domain/trigger.dart';
import 'nfc/nfc_service.dart';

/// Vòng đời dùng chung của database, controller và NFC.
class AppServices extends ChangeNotifier {
  AppServices._(this.database, this.repository, this.dayController, this.nfc);

  final Database database;
  final Repository repository;
  final DayController dayController;
  final NfcService nfc;

  void Function(String message, {bool error})? onMessage;
  String? _assigningTagId;
  String? _lastUid;
  DateTime? _lastUidAt;
  Future<void> _uidQueue = Future<void>.value();

  bool get waitingForTag => _assigningTagId != null;
  String? get assigningTagId => _assigningTagId;
  bool get nfcAvailable => nfc.isRunning;

  static Future<AppServices> create() async {
    final db = await AppDatabase.open();
    final repo = Repository(db);
    final controller = DayController(repo);
    final nfc = NfcService();
    final services = AppServices._(db, repo, controller, nfc);
    await controller.load();
    final available = await nfc.isAvailable();
    if (available) {
      await nfc.start((uid) {
        final next = services._uidQueue.then((_) => services._handleUid(uid));
        services._uidQueue = next.catchError((_) {});
      });
    }
    return services;
  }

  /// Chờ chạm thẻ tiếp theo để gán UID cho tag đã chọn.
  void beginAssignTag(String tagId) {
    _assigningTagId = tagId;
    notifyListeners();
    onMessage?.call('Đang chờ thẻ NFC. Hãy chạm thẻ vào điện thoại.');
  }

  void cancelAssignTag() {
    _assigningTagId = null;
    notifyListeners();
  }

  Future<void> _handleUid(String uid) async {
    final now = DateTime.now();
    if (_lastUid == uid &&
        _lastUidAt != null &&
        now.difference(_lastUidAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastUid = uid;
    _lastUidAt = now;

    final targetId = _assigningTagId;
    if (targetId != null) {
      try {
        await repository.setTagUid(targetId, uid);
        _assigningTagId = null;
        notifyListeners();
        onMessage?.call('Đã gán UID $uid cho $targetId.');
      } catch (e) {
        onMessage?.call('Không gán được thẻ: $e', error: true);
      }
      return;
    }

    try {
      final tag = await repository.tagByUid(uid);
      if (tag == null) {
        onMessage?.call('Thẻ $uid chưa được gán. Mở tab Thẻ để gán.', error: true);
        return;
      }
      if (!tag.active) {
        onMessage?.call('Thẻ ${tag.name} đang tắt.', error: true);
        return;
      }
      final result = await dayController.press(tag.trigger, tagId: tag.id);
      onMessage?.call(result.message, error: !result.ok);
    } catch (e) {
      onMessage?.call('Lỗi khi xử lý thẻ NFC: $e', error: true);
    }
  }

  @override
  void dispose() {
    unawaited(nfc.stop());
    dayController.dispose();
    unawaited(database.close());
    super.dispose();
  }
}
