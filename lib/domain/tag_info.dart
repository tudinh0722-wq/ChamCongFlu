import 'trigger.dart';

/// Thẻ NFC. UID có thể chưa gán (null) và có thể đổi khi thay thẻ.
class TagInfo {
  const TagInfo({
    required this.id,
    required this.name,
    required this.trigger,
    required this.active,
    this.uid,
  });

  final String id;
  final String name;
  final Trigger trigger;
  final bool active;
  final String? uid;
}
