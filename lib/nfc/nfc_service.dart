import 'dart:typed_data';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:ndef_record/ndef_record.dart';

/// Chuyển bytes UID sang chuỗi hex dạng 53:27:B3:B1:02:00:01.
String uidToHex(List<int> bytes) => bytes
    .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
    .join(':');

/// Đọc/Ghi thẻ NFC.
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
    } catch (_) {}
  }

  /// Ghi MIME record để Android tự kích hoạt app.
  Future<void> writeCheckInRecord(String mimeData) async {
    await NfcManager.instance.stopSession();
    await NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443},
      onDiscovered: (NfcTag tag) async {
        try {
          final ndef = NdefAndroid.from(tag);
          if (ndef == null) {
            throw Exception("Thẻ không hỗ trợ NDEF");
          }
          final record = NdefRecord(
            typeNameFormat: TypeNameFormat.media,
            type: Uint8List.fromList('application/vnd.chamcongflu.checkin'.codeUnits),
            identifier: Uint8List(0),
            payload: Uint8List.fromList(mimeData.codeUnits),
          );
          await ndef.writeNdefMessage(NdefMessage(records: [record]));
          await NfcManager.instance.stopSession();
        } catch (e) {
          await NfcManager.instance.stopSession();
        }
      },
    );
  }
}
