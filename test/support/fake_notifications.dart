import 'dart:async';
import 'package:yike/common/notifications/notification_models.dart';

class FakeNotifications implements NotificationAdapter {
  NotificationAccess permission = const NotificationAccess(
    allowed: true,
    exact: true,
    alert: true,
    sound: true,
  );
  final requests = <int, NotificationRequest>{};
  final removedDelivered = <int>[];
  final delivered = <int>{};
  void Function(NotificationTarget)? tap;
  bool fail = false;
  Completer<void>? scheduleGate;
  bool scheduleStarted = false;
  int scheduled = 0;
  @override
  Future<void> initialize(void Function(NotificationTarget) onTap) async {
    tap = onTap;
  }

  @override
  Future<NotificationAccess> access({bool request = false}) async => permission;
  @override
  Future<void> refreshTimezone() async {}
  @override
  Future<void> requestExact() async {}
  @override
  Future<void> openSettings() async {}
  @override
  Future<void> schedule(
    NotificationRequest request, {
    required bool exact,
  }) async {
    scheduleStarted = true;
    await scheduleGate?.future;
    if (fail) throw StateError('schedule failed');
    scheduled++;
    requests[request.id] = request;
  }

  @override
  Future<Set<int>> pending() async => requests.keys.toSet();
  @override
  Future<void> cancelPending(int id) async {
    requests.remove(id);
  }

  @override
  Future<void> removeDelivered(int id) async {
    removedDelivered.add(id);
    delivered.remove(id);
  }

  @override
  Future<void> clear() async {
    requests.clear();
    delivered.clear();
  }
}
