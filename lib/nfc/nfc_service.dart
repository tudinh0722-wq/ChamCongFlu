import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';

/// Chuyển bytes UID sang chuỗi hex dạng 53:27:B3:B1:02:00:01.
String uidToHex(List<int> bytes) => bytes
    .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
    .join(':');

/// Đọc UID thẻ NFC (NTAG213 = NfcA) bằng nfc_manager 3.x.
/// Chỉ quét khi app đang mở (foreground).
class NfcService {
  bool _running = false;

  bool get isRunning => _running;

  Future<bool> isAvailable() async {
    try {
      return await NfcManager.instance.isAvailable();
    } catch (_) {
      return false;
    }
  }

  /// Bắt đầu phiên quét; [onUid] được gọi mỗi lần chạm thẻ.
  Future<void> start(void Function(String uid) onUid) async {
    if (_running) return;
    if (!await isAvailable()) return;
    _running = true;
    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          final uid = _uidOf(tag);
          if (uid != null) onUid(uid);
        },
      );
    } catch (_) {
      _running = false;
    }
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {
      // phiên đã đóng
    }
  }

  static String? _uidOf(NfcTag tag) {
    final nfcA = NfcA.from(tag);
    if (nfcA != null) return uidToHex(nfcA.identifier);
    final ultralight = MifareUltralight.from(tag);
    if (ultralight != null) return uidToHex(ultralight.identifier);
    // Dự phòng: tìm trường identifier trong dữ liệu thô của thẻ.
    for (final v in tag.data.values) {
      if (v is Map && v['identifier'] is List) {
        return uidToHex((v['identifier'] as List).cast<int>());
      }
    }
    return null;
  }
}
