import 'package:flutter/services.dart';

/// Thẻ chạm khi app KHÔNG ở foreground (màn hình khóa, đang ở app khác, màn
/// hình chính). Android mở app bằng intent NFC; MainActivity (Kotlin, do
/// scripts/bootstrap_android.ps1 ghi vào) lấy UID rồi chuyển sang đây.
class LaunchTap {
  const LaunchTap(this.uid, this.background);

  final String uid;

  /// true nếu app đang ở nền / vừa được thẻ khởi chạy (nên tự quay lại nền
  /// sau khi ghi xong); false nếu app đang mở sẵn.
  final bool background;
}

class NfcLaunchChannel {
  static const _channel = MethodChannel('chamcong/nfc_launch');

  static LaunchTap? _parse(Object? raw) {
    if (raw is Map) {
      final uid = raw['uid'];
      if (uid is String && uid.isNotEmpty) {
        return LaunchTap(uid, raw['background'] == true);
      }
    }
    return null;
  }

  /// Thẻ đã khởi chạy app lúc khởi động (nếu có). Trả null nếu MainActivity
  /// chưa được vá (chưa chạy bootstrap_android.ps1).
  static Future<LaunchTap?> takeInitialTap() async {
    try {
      return _parse(await _channel.invokeMethod<Object?>('getInitialTap'));
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Nhận thẻ chạm khi app đang ở nền và được Android đưa lên.
  static void listen(void Function(LaunchTap tap) onTap) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onTag') {
        final tap = _parse(call.arguments);
        if (tap != null) onTap(tap);
      }
      return null;
    });
  }

  /// Đưa app về nền (quay lại app/màn hình trước đó).
  static Future<void> moveToBack() async {
    try {
      await _channel.invokeMethod<void>('moveToBack');
    } catch (_) {
      // chưa vá MainActivity: bỏ qua
    }
  }
}
