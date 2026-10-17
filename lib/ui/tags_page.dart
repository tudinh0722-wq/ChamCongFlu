import 'package:flutter/material.dart';

import '../app_services.dart';
import '../domain/tag_info.dart';

class TagsPage extends StatefulWidget {
  const TagsPage({super.key, required this.services});

  final AppServices services;

  @override
  State<TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends State<TagsPage> {
  List<TagInfo> _tags = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.services.addListener(_refresh);
    _load();
  }

  @override
  void didUpdateWidget(covariant TagsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.services != widget.services) {
      oldWidget.services.removeListener(_refresh);
      widget.services.addListener(_refresh);
      _load();
    }
  }

  @override
  void dispose() {
    widget.services.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    try {
      final tags = await widget.services.repository.tags();
      if (mounted) setState(() { _tags = tags; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      widget.services.onMessage?.call('Không đọc được danh sách thẻ: $e', error: true);
    }
  }

  Future<void> _rename(TagInfo tag) async {
    final controller = TextEditingController(text: tag.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi tên thẻ'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Tên thẻ')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Lưu')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    await widget.services.repository.renameTag(tag.id, name);
    await _load();
  }

  Future<void> _selectAction(TagInfo tag, String value) async {
    final services = widget.services;
    try {
      if (value == 'assign') {
        services.beginAssignTag(tag.id);
      } else if (value == 'clear') {
        await services.repository.clearTagUid(tag.id);
        await _load();
      } else if (value == 'toggle') {
        await services.repository.setTagActive(tag.id, !tag.active);
        await _load();
      } else if (value == 'rename') {
        await _rename(tag);
      }
    } catch (e) {
      services.onMessage?.call('Không cập nhật được thẻ: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Gán thẻ bằng NFC', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              const Text('Chọn “Quét để gán”, sau đó chạm thẻ vào mặt lưng điện thoại. UID chỉ lưu trong database trên máy.'),
              if (services.waitingForTag) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(),
                const SizedBox(height: 6),
                Text('Đang chờ thẻ cho ${services.assigningTagId}…'),
                Align(alignment: Alignment.centerRight, child: TextButton(
                  onPressed: services.cancelAssignTag,
                  child: const Text('Hủy quét'),
                )),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 8),
        for (final tag in _tags)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: tag.trigger.process.color.withValues(alpha: 0.15),
                child: Icon(Icons.nfc, color: tag.trigger.process.color),
              ),
              title: Text(tag.name),
              subtitle: Text('${tag.id} · ${tag.trigger.label}\nUID: ${tag.uid ?? 'chưa gán'}',
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              isThreeLine: true,
              onTap: () => services.beginAssignTag(tag.id),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(tag.active ? Icons.check_circle : Icons.pause_circle,
                    color: tag.active ? Colors.green : Theme.of(context).colorScheme.outline),
                PopupMenuButton<String>(
                  onSelected: (value) => _selectAction(tag, value),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'assign', child: Text('Quét để gán UID')),
                    if (tag.uid != null) const PopupMenuItem(value: 'clear', child: Text('Gỡ UID')),
                    PopupMenuItem(value: 'toggle', child: Text(tag.active ? 'Tắt thẻ' : 'Bật thẻ')),
                    const PopupMenuItem(value: 'rename', child: Text('Đổi tên')),
                  ],
                ),
              ]),
            ),
          ),
      ],
    );
  }
}
