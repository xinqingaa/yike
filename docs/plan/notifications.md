# 阶段 5:后台提醒

## 范围

实现计时完成与习惯提醒的本地通知。前台反馈（音频震动动效）在阶段 1-4 已完成;这里只做**后台通知**:应用不可见时由系统推送,点击通知唤起应用到对应页面。

**明确不做**:前台通知横幅（应用可见时已有交互反馈），推送通知（无服务端），以及音频和震动的系统授权与 iOS 音频会话管理（在阶段 1 已完成）。

## 产品设计

### 通知场景

| 场景 | 触发 | 标题 | 正文 | 点击目标 |
| --- | --- | --- | --- | --- |
| 番茄钟完成 | 倒计时到 0 且应用不可见 | "番茄钟完成" | "本轮 25 分钟已完成" | 专注页待开始下一轮 |
| 倒计时完成 | 倒计时到 0 且应用不可见 | "倒计时完成" | "{mm}:{ss} 时间到" | 专注页待开始倒计时 |
| 习惯提醒 | 到达设定时间且未完成 | "{习惯名称}" | "今日尚未完成" | 打卡页对应习惯 |

**前台判断**:
- iOS: `WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed`
- Android: `ActivityLifecycleState.resumed`

只在后台时调度通知。前台有反馈,不发通知。

### 习惯提醒规则

- **每日一次**:每个习惯每天最多提醒一次,到时间后检查今日是否已打卡。
- **已完成不提醒**:打卡后取消该习惯当日的待发通知。
- **归档取消**:归档习惯立即取消其所有待发通知。
- **删除清理**:删除习惯清理其所有历史通知（pending + delivered）。
- **编辑更新**:修改提醒时间或关闭提醒时,取消旧的,按新设置调度。

### 通知设置

在设置页"提示与反馈"区块增加一项:

```
通知提醒  [开关]   -- 控制所有后台通知（计时 + 习惯）
```

默认**关闭**。开启时请求权限,关闭时保留权限但不调度新通知（已调度的不主动取消）。

## 技术设计

### 依赖

```yaml
flutter_local_notifications: ^22.3.2
```

已在 `technical-design.md` 明确;版本稳定,支持 iOS 10+、Android 5+,有 3.4M 下载/周,pub points 150/160。

### 初始化

```dart
// lib/common/services/notification_service.dart

class NotificationService {
  static final instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,  // 手动请求
      requestBadgePermission: false,
      requestSoundPermission: false,  // 音频已在 audio_session 管理
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _handleTap,
    );

    _initialized = true;
  }

  void _handleTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;

    // 路由格式: "focus/pomodoro" | "focus/countdown" | "checkin/{habitId}"
    // 调用 app_router.dart 的 deeplink 方法
  }
}
```

### 权限请求

```dart
// 用户在设置页开启"通知提醒"时调用
Future<bool> requestPermission() async {
  if (Platform.isAndroid) {
    if (Build.VERSION.SDK_INT >= 33) {
      final result = await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return result ?? false;
    }
    return true;  // Android 13 以下默认允许
  } else if (Platform.isIOS) {
    final result = await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return result ?? false;
  }
  return false;
}
```

### 计时完成通知

```dart
Future<void> showTimerComplete({
  required String mode,  // 'pomodoro' | 'countdown'
  required String body,
}) async {
  if (!await _shouldNotify()) return;

  const androidDetails = AndroidNotificationDetails(
    'timer_complete',
    '计时完成',
    channelDescription: '番茄钟或倒计时完成提醒',
    importance: Importance.high,
    priority: Priority.high,
    sound: RawResourceAndroidNotificationSound('complete'),  // res/raw/complete.wav
  );

  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentSound: true,
    sound: 'complete.caf',  // Runner/Sounds/complete.caf
  );

  await _plugin.show(
    mode == 'pomodoro' ? 1001 : 1002,  // 固定 id,新的覆盖旧的
    mode == 'pomodoro' ? '番茄钟完成' : '倒计时完成',
    body,
    const NotificationDetails(android: androidDetails, iOS: iosDetails),
    payload: 'focus/$mode',
  );
}

Future<bool> _shouldNotify() async {
  final prefs = await SharedPreferences.getInstance();
  if (!prefs.getBool('notification_enabled') ?? false) return false;

  // 检查前台
  final state = WidgetsBinding.instance.lifecycleState;
  return state != AppLifecycleState.resumed;
}
```

### 习惯提醒

```dart
Future<void> scheduleHabitReminder({
  required String habitId,
  required String habitName,
  required DateTime reminderTime,
}) async {
  await _plugin.zonedSchedule(
    habitId.hashCode,  // 用 habitId 的 hash 作为通知 id
    habitName,
    '今日尚未完成',
    tz.TZDateTime.from(reminderTime, tz.local),
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'habit_reminder',
        '习惯提醒',
        channelDescription: '习惯打卡提醒',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(presentAlert: true),
    ),
    payload: 'checkin/$habitId',
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.time,  // 每日重复
  );
}

Future<void> cancelHabitReminder(String habitId) async {
  await _plugin.cancel(habitId.hashCode);
}

Future<void> cancelAllHabitReminders(String habitId) async {
  await _plugin.cancel(habitId.hashCode);
  // 清理已送达的
  if (Platform.isAndroid) {
    final delivered = await _plugin.getActiveNotifications();
    for (final n in delivered) {
      if (n.id == habitId.hashCode) {
        await _plugin.cancel(n.id!);
      }
    }
  }
}
```

### 自定义音效

**Android**:
- 文件: `android/app/src/main/res/raw/complete.wav` (< 5 秒，采样率 44.1kHz)
- 通知用 `RawResourceAndroidNotificationSound('complete')`

**iOS**:
- 文件: `ios/Runner/Sounds/complete.caf` (LPCM 或 IMA4，< 30 秒)
- Xcode 添加到 Bundle Resources
- 通知用 `sound: 'complete.caf'`

首版复用阶段 1 的合成音效转格式。

### 路由跳转

```dart
// lib/app_router.dart 增加

void handleNotificationPayload(String payload) {
  final parts = payload.split('/');
  if (parts.length != 2) return;

  switch (parts[0]) {
    case 'focus':
      // 切换到专注页，模式已在 payload 中
      _rootNavigatorKey.currentState?.pushNamedAndRemoveUntil('/focus', (_) => false);
      break;
    case 'checkin':
      // 切换到打卡页，滚动到对应习惯（需要传递 habitId）
      _rootNavigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/checkin',
        (_) => false,
        arguments: {'scrollToHabit': parts[1]},
      );
      break;
  }
}
```

## 集成点

### 1. 设置页

- `lib/features/settings/settings_page.dart`:增加"通知提醒"开关
- 开关打开时调用 `NotificationService.instance.requestPermission()`
- 偏好存 `notification_enabled` (bool)

### 2. 计时完成

- `lib/features/focus/focus_vm.dart`:`_onTimerComplete()`:
  ```dart
  if (mode == TimerMode.pomodoro) {
    await NotificationService.instance.showTimerComplete(
      mode: 'pomodoro',
      body: '本轮 $_duration 分钟已完成',
    );
  } else if (mode == TimerMode.countdown) {
    await NotificationService.instance.showTimerComplete(
      mode: 'countdown',
      body: '${_duration ~/ 60}:${(_duration % 60).toString().padLeft(2, '0')} 时间到',
    );
  }
  ```

### 3. 习惯提醒

- `lib/features/checkin/habit_vm.dart`:
  - 新建/编辑习惯保存时:如果开启提醒,调用 `scheduleHabitReminder()`
  - 打卡时:完成后调用 `cancelHabitReminder(habitId)` 取消当日提醒
  - 归档时:调用 `cancelHabitReminder()`
  - 删除时:调用 `cancelAllHabitReminders()`

### 4. 应用启动

- `lib/main.dart`:`main()`:
  ```dart
  await NotificationService.instance.initialize();
  final launchDetails = await NotificationService.instance.getNotificationAppLaunchDetails();
  if (launchDetails?.didNotificationLaunchApp ?? false) {
    final payload = launchDetails!.notificationResponse?.payload;
    if (payload != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppRouter.instance.handleNotificationPayload(payload);
      });
    }
  }
  ```

## Android 权限

`android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Android 13+ 需要显式权限 -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

<!-- 精确定时（习惯提醒） -->
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>

<!-- 应用内无需 foreground service -->
```

## iOS 配置

**Info.plist** 无需额外配置（不用后台模式）。

**音效文件**:Xcode 中 Add Files to "Runner",勾选 Copy items if needed 和 Runner target,放入 `ios/Runner/Sounds/`。

## 测试清单

| 场景 | 验证点 |
| --- | --- |
| 权限请求 | 首次开启"通知提醒"弹出系统权限对话框 |
| 番茄钟后台完成 | 应用在后台,番茄钟到 0 时收到通知,点击回到专注页 |
| 倒计时后台完成 | 应用在后台,倒计时到 0 时收到通知 |
| 习惯提醒 | 到提醒时间且未打卡,收到通知 |
| 打卡取消提醒 | 打卡后当日不再收到该习惯提醒 |
| 归档取消 | 归档习惯后不再收到提醒 |
| 编辑提醒时间 | 修改时间后按新时间提醒 |
| 前台不通知 | 应用在前台时完成计时,只有交互反馈,无通知 |
| 关闭开关 | 关闭"通知提醒"后不再调度新通知 |
| Android 13+ 权限 | targetSdk 33+,首次请求弹出权限对话框 |

## 完成后同步文档

- `docs/known-gaps.md`:移除"通知、音频与触觉"中的通知部分
- `docs/product/logic-and-interactions.md`:增加通知规则段落
- `docs/plan/README.md`:标记阶段 5 完成
