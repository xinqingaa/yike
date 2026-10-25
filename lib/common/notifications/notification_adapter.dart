import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'notification_models.dart';

final notificationAdapterProvider = Provider<NotificationAdapter>(
  (ref) => LocalNotificationAdapter(),
);

/// Native Android scheduling is small and explicit so the receiver can suppress
/// foreground delivery before posting. iOS uses UNUserNotificationCenter.
class LocalNotificationAdapter implements NotificationAdapter {
  final _plugin = FlutterLocalNotificationsPlugin();
  static const _native = MethodChannel('yike/notifications');
  @override
  Future<void> initialize(void Function(NotificationTarget) onTap) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError('仅支持 Android / iOS');
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          defaultPresentAlert: false,
          defaultPresentSound: false,
          defaultPresentBadge: false,
          defaultPresentBanner: false,
          defaultPresentList: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final target = NotificationTarget.decode(response.payload);
        if (target != null) onTap(target);
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      final target = NotificationTarget.decode(
        launch?.notificationResponse?.payload,
      );
      if (target != null) onTap(target);
    }
    if (Platform.isAndroid) {
      _native.setMethodCallHandler((call) async {
        if (call.method == 'tap') {
          final target = NotificationTarget.decode(call.arguments as String?);
          if (target != null) onTap(target);
        }
      });
      final raw = await _native.invokeMethod<String>('launch');
      final target = NotificationTarget.decode(raw);
      if (target != null) onTap(target);
    }
    tzdata.initializeTimeZones();
    await refreshTimezone();
  }

  @override
  Future<void> refreshTimezone() async {
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
  }

  @override
  Future<NotificationAccess> access({bool request = false}) async {
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()!;
      if (request) await android.requestNotificationsPermission();
      final disabled =
          await _native.invokeListMethod<String>('disabledChannels') ?? [];
      final allowed = await android.areNotificationsEnabled() ?? false;
      return NotificationAccess(
        allowed: allowed,
        alert: allowed,
        sound: allowed,
        exact: await android.canScheduleExactNotifications() ?? false,
        disabledChannels: disabled,
      );
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()!;
    if (request) {
      await ios.requestPermissions(alert: true, sound: true, badge: false);
    }
    final options = await ios.checkPermissions();
    return NotificationAccess(
      allowed: options?.isEnabled ?? false,
      alert: options?.isAlertEnabled ?? false,
      sound: options?.isSoundEnabled ?? false,
      exact: true,
    );
  }

  @override
  Future<void> requestExact() async {
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()!
          .requestExactAlarmsPermission();
    }
  }

  @override
  Future<void> openSettings() => _native.invokeMethod<void>('settings');
  @override
  Future<void> schedule(
    NotificationRequest request, {
    required bool exact,
  }) async {
    if (Platform.isAndroid) {
      await _native.invokeMethod<void>('schedule', {
        'id': request.id,
        'at': request.at.millisecondsSinceEpoch,
        'payload': request.target.encode(),
        'title': request.title,
        'body': request.body,
        'sound': request.sound,
        'haptics': request.haptics,
        'theme': request.theme.split('/').last,
        'timer': request.timer,
        'exact': request.timer && exact,
        'date': request.target.date,
        'minutes': request.at.hour * 60 + request.at.minute,
      });
      return;
    }
    await _plugin.zonedSchedule(
      id: request.id,
      scheduledDate: tz.TZDateTime.from(request.at, tz.local),
      title: request.title,
      body: request.body,
      payload: request.target.encode(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: false,
          presentBanner: false,
          presentList: false,
          presentSound: false,
          sound: request.sound
              ? '${request.theme.split('/').last}_finish.caf'
              : null,
        ),
      ),
    );
  }

  @override
  Future<Set<int>> pending() async => Platform.isAndroid
      ? (await _native.invokeListMethod<int>('pending') ?? []).toSet()
      : (await _plugin.pendingNotificationRequests()).map((r) => r.id).toSet();
  @override
  Future<void> cancelPending(int id) async {
    if (Platform.isAndroid) {
      await _native.invokeMethod<void>('cancelPending', id);
    } else {
      await _native.invokeMethod<void>('cancelPending', id);
    }
  }

  @override
  Future<void> removeDelivered(int id) =>
      _native.invokeMethod<void>('removeDelivered', id);
  @override
  Future<void> clear() async {
    if (Platform.isAndroid) {
      await _native.invokeMethod<void>('clear');
    } else {
      await _plugin.cancelAll();
    }
  }
}
