import 'package:flutter/material.dart';

import '../app_services.dart';
import '../data/backup_service.dart';
import '../util/time_utils.dart';

String _stamp(DateTime t) => '${dmy(t)} ${hm(t)}';

/// Bảng sao lưu mở từ biểu tượng trên AppBar.
Future<void> showBackupSheet(BuildContext context, AppServices services) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _BackupSheet(parentContext: context, services: services),
  );
}

/// Chạy khi mở app: nhắc chọn thư mục sao lưu, hoặc đề nghị khôi phục nếu
/// điện thoại đang trống mà thư mục đã có bản sao lưu.
Future<void> promptBackupOnStart(
    BuildContext context, AppServices services) async {
  final events = await services.backup.eventCount();
  if (!context.mounted) return;

  if (services.backup.hasFolder) {
    if (events == 0) await _offerRestore(context, services, silentIfNone: true);
    return;
  }

  final choose = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Chọn thư mục sao lưu'),
      content: Text(events == 0
          ? 'Nếu bạn vừa cài lại app, hãy chọn đúng thư mục sao lưu cũ để lấy lại '
              'lịch sử và thẻ NFC. Nếu dùng lần đầu, chọn một thư mục (ví dụ '
              'Documents/ChamCong) để app tự sao lưu về sau.'
          : 'Dữ liệu hiện chỉ nằm trong app và sẽ mất khi gỡ app. Chọn một thư '
              'mục (ví dụ Documents/ChamCong) để app tự sao lưu ra ngoài.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Để sau'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Chọn thư mục'),
        ),
      ],
    ),
  );
  if (choose == true && context.mounted) {
    await _chooseFolderFlow(context, services);
  }
}

/// Chọn thư mục; nếu trong đó đã có bản sao lưu thì đề nghị khôi phục,
/// chưa có thì ghi bản sao lưu đầu tiên.
Future<void> _chooseFolderFlow(BuildContext context, AppServices s) async {
  final picked = await s.backup.pickFolder();
  if (!context.mounted) return;
  if (!picked) {
    final err = s.backup.lastError;
    if (err != null) s.onMessage?.call(err, error: true);
    return;
  }

  final found = await s.findBackup();
  if (!context.mounted) return;
  if (found != null) {
    await _confirmRestore(context, s, found);
    return;
  }
  final result = await s.backup.backupNow();
  s.onMessage?.call(
    result == BackupResult.ok
        ? 'Đã chọn thư mục. Bản sao lưu đầu tiên đã được ghi.'
        : (s.backup.lastError ?? 'Đã chọn thư mục sao lưu.'),
    error: result == BackupResult.error,
  );
}

Future<void> _offerRestore(
  BuildContext context,
  AppServices s, {
  bool silentIfNone = false,
}) async {
  final found = await s.findBackup();
  if (!context.mounted) return;
  if (found == null) {
    if (!silentIfNone) {
      s.onMessage?.call('Chưa có bản sao lưu trong thư mục này.', error: true);
    }
    return;
  }
  await _confirmRestore(context, s, found);
}

Future<void> _confirmRestore(
  BuildContext context,
  AppServices s,
  FoundBackup found,
) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Khôi phục dữ liệu?'),
      content: Text(
        'Tìm thấy bản sao lưu lúc ${_stamp(found.exportedAt)}: '
        '${found.events} sự kiện, ${found.tags} thẻ.\n\n'
        'Sự kiện đã có trên máy được giữ nguyên, chỉ thêm phần còn thiếu. '
        'Thẻ NFC được cập nhật theo bản sao lưu.\n\n'
        'Nếu bấm "Bỏ qua", bản sao lưu cũ sẽ dần bị thay bằng dữ liệu hiện '
        'tại trên máy sau vài lần sao lưu.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Bỏ qua'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Khôi phục'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    final added = await s.restoreBackup(found);
    s.onMessage?.call('Đã khôi phục: thêm $added sự kiện.');
  } catch (e) {
    s.onMessage?.call('Khôi phục lỗi: $e', error: true);
  }
}

Future<void> _backupNowFlow(AppServices s) async {
  final result = await s.backup.backupNow();
  switch (result) {
    case BackupResult.ok:
      s.onMessage?.call('Đã sao lưu.');
    case BackupResult.noFolder:
      s.onMessage?.call('Chưa chọn thư mục sao lưu.', error: true);
    case BackupResult.skippedEmpty:
      s.onMessage?.call(
        'Điện thoại chưa có sự kiện nhưng thư mục đã có bản sao lưu. '
        'Hãy bấm "Khôi phục" thay vì sao lưu.',
        error: true,
      );
    case BackupResult.error:
      s.onMessage?.call(s.backup.lastError ?? 'Không sao lưu được.',
          error: true);
  }
}

class _BackupSheet extends StatelessWidget {
  const _BackupSheet({required this.parentContext, required this.services});

  /// Context của trang bên dưới: dùng cho hộp thoại sau khi đóng bảng này
  /// (Snackbar và hộp thoại sẽ bị bảng che nếu mở khi bảng còn hiện).
  final BuildContext parentContext;
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: services.backup,
      builder: (context, _) {
        final b = services.backup;
        final last = b.lastBackupAt;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sao lưu dữ liệu',
                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  'App tự ghi bản sao lưu vào thư mục bạn chọn (nằm ngoài app). '
                  'Gỡ rồi cài lại app, chọn lại đúng thư mục đó một lần là lấy '
                  'lại được toàn bộ lịch sử và thẻ NFC.',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                _line(
                  context,
                  b.hasFolder ? Icons.folder : Icons.folder_off_outlined,
                  b.hasFolder
                      ? 'Thư mục: ${b.folder!.name.isEmpty ? '(đã chọn)' : b.folder!.name}'
                      : 'Chưa chọn thư mục sao lưu',
                  color: b.hasFolder ? null : cs.error,
                ),
                _line(
                  context,
                  Icons.schedule,
                  last == null
                      ? 'Chưa sao lưu trong lần mở app này'
                      : 'Sao lưu gần nhất: ${_stamp(last)}',
                ),
                if (b.lastError != null)
                  _line(context, Icons.error_outline, b.lastError!,
                      color: cs.error),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _chooseFolderFlow(parentContext, services);
                    },
                    icon: const Icon(Icons.folder_open),
                    label: Text(b.hasFolder
                        ? 'Đổi thư mục'
                        : 'Chọn thư mục sao lưu'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: b.hasFolder
                        ? () {
                            Navigator.pop(context);
                            _backupNowFlow(services);
                          }
                        : null,
                    icon: const Icon(Icons.save_alt),
                    label: const Text('Sao lưu ngay'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: b.hasFolder
                        ? () {
                            Navigator.pop(context);
                            _offerRestore(parentContext, services);
                          }
                        : null,
                    icon: const Icon(Icons.restore),
                    label: const Text('Khôi phục từ bản sao lưu'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _line(BuildContext context, IconData icon, String text,
      {Color? color}) {
    final c = color ?? Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: c))),
        ],
      ),
    );
  }
}
