import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../domain/day_controller.dart';
import '../domain/day_logic.dart';
import '../domain/trigger.dart';
import '../util/time_utils.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.repository, required this.controller});

  final Repository repository;
  final DayController controller;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  DateTime _day = startOfDay(DateTime.now());
  List<TriggerEvent> _events = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final events = await widget.repository.eventsBetween(_day, nextDay(_day));
      if (mounted) setState(() { _events = events; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message('Không đọc được lịch sử: $e', error: true);
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
  }

  Future<void> _pickDay() async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (chosen == null || !mounted) return;
    setState(() => _day = startOfDay(chosen));
    await _load();
  }

  Future<void> _edit(TriggerEvent? event) async {
    var trigger = event?.trigger ?? Trigger.workStart;
    var time = event?.time ?? DateTime(_day.year, _day.month, _day.day, DateTime.now().hour, DateTime.now().minute);
    final result = await showDialog<_EventEdit>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: Text(event == null ? 'Thêm sự kiện' : 'Sửa sự kiện'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<Trigger>(
              value: trigger,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Sự kiện'),
              items: Trigger.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
              onChanged: (v) { if (v != null) setDialogState(() => trigger = v); },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ngày'),
              subtitle: Text(dmy(time)),
              trailing: const Icon(Icons.calendar_month),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: time, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
                if (d != null) {
                  setDialogState(() => time = DateTime(d.year, d.month, d.day, time.hour, time.minute, time.second));
                }
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Giờ'),
              subtitle: Text(hm(time)),
              trailing: const Icon(Icons.schedule),
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(time));
                if (t != null) {
                  setDialogState(() => time = DateTime(time.year, time.month, time.day, t.hour, t.minute, 0));
                }
              },
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
            FilledButton(onPressed: () => Navigator.pop(context, _EventEdit(trigger, time)), child: const Text('Lưu')),
          ],
        );
      }),
    );
    if (result == null || !mounted) return;
    try {
      if (event == null) {
        await widget.repository.insertEvent(result.trigger, result.time);
      } else {
        await widget.repository.updateEvent(event.id, result.trigger, result.time);
      }
      await widget.controller.load();
      if (!mounted) return;
      await _load();
      if (mounted) _message('Đã lưu sự kiện.');
    } catch (e) {
      _message('Không lưu được sự kiện: $e', error: true);
    }
  }

  Future<void> _delete(TriggerEvent event) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa sự kiện?'),
        content: Text('${event.trigger.label} lúc ${hms(event.time)} sẽ bị xóa khỏi lịch sử.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await widget.repository.deleteEvent(event.id);
    await widget.controller.load();
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final today = sameDay(_day, DateTime.now());
    final summary = summarize(_events, DateTime.now(), countOpen: today);
    final issues = findIssues(_events, isToday: today);
    final issueIds = issues.map((i) => i.eventId).whereType<int>().toSet();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: _pickDay,
            icon: const Icon(Icons.calendar_month),
            label: Text(dmy(_day)),
          )),
          const SizedBox(width: 8),
          IconButton(onPressed: _load, tooltip: 'Tải lại', icon: const Icon(Icons.refresh)),
          IconButton.filled(onPressed: () => _edit(null), tooltip: 'Thêm sự kiện', icon: const Icon(Icons.add)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(children: [
          _summaryChip('Làm việc', summary.work, ProcessType.work.color),
          _summaryChip('Thiết kế', summary.design, ProcessType.design.color),
          _summaryChip('CNC', summary.cnc, ProcessType.cnc.color),
        ]),
      ),
      if (issues.isNotEmpty)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Cần kiểm tra ${issues.length} điểm bất thường', style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer, fontWeight: FontWeight.bold)),
            for (final issue in issues) Text('• ${issue.message}', style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
          ]),
        ),
      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
              ? const Center(child: Text('Ngày này chưa có sự kiện.'))
              : ListView.builder(
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    final event = _events[_events.length - 1 - index];
                    return ListTile(
                      leading: CircleAvatar(radius: 6, backgroundColor: event.trigger.process.color),
                      title: Text(event.trigger.label),
                      subtitle: Text('${hms(event.time)} · ${event.tagId ?? 'nhập tay'}${issueIds.contains(event.id) ? ' · CẦN KIỂM TRA' : ''}'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) { if (v == 'edit') _edit(event); if (v == 'delete') _delete(event); },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Sửa')),
                          PopupMenuItem(value: 'delete', child: Text('Xóa')),
                        ],
                      ),
                    );
                  },
                )),
    ]);
  }

  Widget _summaryChip(String label, Duration value, Color color) => Expanded(
    child: Card(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Column(children: [
        Text(label, style: const TextStyle(fontSize: 11)),
        const SizedBox(height: 4),
        Text(hhmm(value), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    )),
  );
}

class _EventEdit {
  const _EventEdit(this.trigger, this.time);
  final Trigger trigger;
  final DateTime time;
}
