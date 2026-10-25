import 'dart:convert';

class NotificationTarget {
  const NotificationTarget.timer(this.identity, this.session, this.stage)
    : kind = 'timer',
      date = null;
  const NotificationTarget.habit(this.identity, this.date)
    : kind = 'habit',
      session = null,
      stage = null;
  final String kind, identity;
  final String? session, stage, date;
  String get key => kind == 'timer'
      ? '$kind/$identity/$session/$stage'
      : '$kind/$identity/$date';
  String encode() => jsonEncode({
    'kind': kind,
    'identity': identity,
    if (session != null) 'session': session,
    if (stage != null) 'stage': stage,
    if (date != null) 'date': date,
  });
  static NotificationTarget? decode(String? raw) {
    try {
      final j = jsonDecode(raw!) as Map<String, dynamic>;
      final id = j['identity'] as String;
      if (id.isEmpty) return null;
      if (j['kind'] == 'timer' &&
          const ['pomodoro', 'stopwatch', 'countdown'].contains(id) &&
          (j['session'] as String).isNotEmpty &&
          const ['focus', 'shortBreak', 'longBreak'].contains(j['stage'])) {
        return NotificationTarget.timer(
          id,
          j['session'] as String,
          j['stage'] as String,
        );
      }
      if (j['kind'] == 'habit' &&
          DateTime.tryParse(j['date'] as String) != null) {
        return NotificationTarget.habit(id, j['date'] as String);
      }
    } catch (_) {
      /* Invalid external payloads never become business commands. */
    }
    return null;
  }
}

class NotificationRequest {
  const NotificationRequest({
    required this.id,
    required this.target,
    required this.at,
    required this.title,
    required this.body,
    required this.theme,
    required this.sound,
    required this.haptics,
  });
  final int id;
  final NotificationTarget target;
  final DateTime at;
  final String title, body, theme;
  final bool sound, haptics;
  NotificationRequest withId(int id) => NotificationRequest(
    id: id,
    target: target,
    at: at,
    title: title,
    body: body,
    theme: theme,
    sound: sound,
    haptics: haptics,
  );
  bool get timer => target.kind == 'timer';
  String get fingerprint =>
      '$id|${target.encode()}|${at.millisecondsSinceEpoch}|$title|$body|$theme|$sound|$haptics';
}

class NotificationAccess {
  const NotificationAccess({
    this.allowed = false,
    this.exact = false,
    this.sound = false,
    this.alert = false,
    this.disabledChannels = const [],
  });
  final bool allowed, exact, sound, alert;
  final List<String> disabledChannels;
}

abstract class NotificationAdapter {
  Future<void> initialize(void Function(NotificationTarget) onTap);
  Future<NotificationAccess> access({bool request = false});
  Future<void> requestExact();
  Future<void> openSettings();
  Future<void> refreshTimezone();
  Future<void> schedule(NotificationRequest request, {required bool exact});
  Future<Set<int>> pending();
  Future<void> cancelPending(int id);
  Future<void> removeDelivered(int id);
  Future<void> clear();
}
