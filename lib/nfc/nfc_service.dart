import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

/// Chuyển bytes UID sang chuỗi hex dạng 53:27:B3:B1:02:00:01.
String uidToHex(List<int> bytes) => bytes
    .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
    .join(':');

/// Đọc UID thẻ NFC (NTAG213) bằng nfc_manager 4.x.
/// UID lấy từ `Tag#id` của Android, không phụ thuộc loại công nghệ thẻ.
/// Chỉ quét khi app đang mở (foreground).
class NfcService {
  bool _running = false;

  bool get isRunning => _running;

  Future<bool> isAvailable() async {
    try {
      final availability = await NfcManager.instance.checkAvailability();
      return availability == NfcAvailability.enabled;
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
        pollingOptions: {NfcPollingOption.iso14443},
        onDiscovered: (NfcTag tag) async {
          final id = NfcTagAndroid.from(tag)?.id;
          if (id != null) onUid(uidToHex(id));
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
}
