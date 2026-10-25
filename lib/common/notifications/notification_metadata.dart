import '../../storage/app_prefs.dart';

/// Scheduling deadline reservations and opportunity tokens, never a second business snapshot.
class NotificationMetadata {
  NotificationMetadata({
    this.nextId = 100,
    Map<String, int>? ids,
    Set<String>? consumed,
    Map<String, int>? scheduledAt,
  }) : ids = ids ?? {},
       consumed = consumed ?? {},
       scheduledAt = scheduledAt ?? {};
  int nextId;
  final Map<String, int> ids, scheduledAt;
  final Set<String> consumed;
  int idFor(String key) => ids.putIfAbsent(key, () => nextId++);
  Map<String, dynamic> toJson() => {
    'nextId': nextId,
    'ids': ids,
    'consumed': consumed.toList(),
    'scheduledAt': scheduledAt,
  };
  factory NotificationMetadata.fromJson(Map<String, dynamic> j) {
    final ids = (j['ids'] as Map<String, dynamic>).cast<String, int>();
    final next = j['nextId'] as int;
    if (next < 100 ||
        next >= 0x7fffffff ||
        ids.values.any((id) => id < 100 || id >= next) ||
        ids.values.toSet().length != ids.length) {
      throw const FormatException('Invalid notification IDs');
    }
    return NotificationMetadata(
      nextId: next,
      ids: Map.of(ids),
      consumed: (j['consumed'] as List).cast<String>().toSet(),
      scheduledAt: Map.of(
        (j['scheduledAt'] as Map<String, dynamic>).cast<String, int>(),
      ),
    );
  }
}

final notificationMetadataPrefs = PrefsEntry<NotificationMetadata>(
  PrefsKey.notifications,
  VersionedJsonPrefsCodec(
    schemaVersion: 1,
    fromJson: NotificationMetadata.fromJson,
    toJson: (value) => value.toJson(),
  ),
);
