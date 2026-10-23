# 阶段 6:桌面小部件与实时活动

## 范围

为 iOS 和 Android 提供桌面小部件,iOS 增加锁屏与动态岛实时活动,让用户在主屏幕与锁屏查看专注与打卡进度。

**明确不做**:推送通知更新（无服务端）,iPadOS 桌面小部件交互,macOS AppKit widget,Android Material You 主题动态取色（使用固定品牌色）。

## 产品设计

### iOS 小部件

**位置与尺寸**:
- **主屏幕**: Small (正方形)、Medium (横长)、Large (大)
- **锁屏**: Circular (圆形)、Rectangular (矩形条)、Inline (单行文字)

**内容**:

| 类型 | 内容 | 刷新 |
| --- | --- | --- |
| 专注进度 (Medium/Large) | 当前模式、轮次/圈数、倒计时/正计时、今日总时长 | 计时中每分钟,暂停/完成时立即 |
| 今日打卡 (Small/Medium) | 今日完成 N/M、进行中习惯列表（最多 3 个） | 打卡时立即 |
| 锁屏圆形 (Circular) | 今日打卡进度环形图,中心显示完成数 | 打卡时立即 |
| 锁屏矩形 (Rectangular) | 当前专注倒计时或"已暂停" | 计时中每分钟 |

点击小部件跳转到应用对应页面（专注或打卡）。

### iOS 实时活动（Live Activity）

**触发**: 开始番茄钟或倒计时时启动,暂停/完成时结束。正计时不启动（无终点）。

**锁屏样式**:

```
[图标] 番茄钟 第 2 轮
━━━━━━━━━━━━━━━━━━━━ 18:32
暂停  |  结束
```

**动态岛样式**:

- **Compact Leading**: 图标 + 轮次数字
- **Compact Trailing**: 倒计时 mm:ss
- **Expanded**: 模式名称、进度条、时间、两个按钮（暂停/结束）

**更新频率**: 每秒更新倒计时（ActivityKit 支持高频实时）。

### Android 小部件

**尺寸**: 2x2 (小)、4x2 (中)、4x4 (大)

**内容**:

| 类型 | 内容 | 刷新 |
| --- | --- | --- |
| 专注进度 (4x2) | 模式、时间、开始/暂停按钮 | 计时中每分钟 |
| 今日打卡 (2x2) | 完成数 + 第一个习惯的图标和名称 | 打卡时立即 |
| 今日打卡 (4x2) | 完成进度条 + 前 3 个习惯列表 | 打卡时立即 |

点击小部件跳转到应用,点击按钮直接操作（开始/暂停）。

## 技术设计

### 方案选择

经调研,选择 **live_activities 2.6.0** + 手写原生代码:

**live_activities 能力**:
- ✅ iOS Live Activity + Dynamic Island
- ✅ Android RemoteViews (兼容 Android 5+)
- ✅ App Groups 数据共享
- ✅ 图片和 URL Scheme
- ❌ **不支持 iOS WidgetKit 主屏小部件**（只支持 Live Activity）
- ❌ **不支持 iOS 锁屏小部件**（Circular/Rectangular）

**因此分两层**:
1. **iOS WidgetKit 小部件**（主屏 + 锁屏）:手写 Swift + WidgetKit
2. **iOS Live Activity**（锁屏动态岛）:用 live_activities 包
3. **Android 小部件**: 用 live_activities 包

### 依赖

```yaml
live_activities: ^2.6.0
```

Pub points 150/160,659 likes,72k 下载/月。

### iOS WidgetKit（手写）

#### 项目结构

```
ios/
  Runner/
  YikeWidgets/         # Widget Extension target
    YikeWidgets.swift  # 入口
    FocusWidget.swift  # 专注小部件
    CheckinWidget.swift # 打卡小部件
    Info.plist
```

#### Xcode 配置

1. 创建 Widget Extension target: File → New → Target → Widget Extension
2. 命名 `YikeWidgets`,语言 Swift,勾选 Include Live Activity
3. 设置 App Groups: `group.com.yourcompany.yike`（Runner 和 Widget 共用）
4. Info.plist 增加 `NSExtension` → `NSExtensionPointIdentifier`: `com.apple.widgetkit-extension`

#### 数据共享

**Flutter 端**:

```dart
// lib/common/services/widget_service.dart

class WidgetService {
  static const _channel = MethodChannel('com.yourcompany.yike/widget');
  static const _groupId = 'group.com.yourcompany.yike';

  Future<void> updateFocusWidget({
    required String mode,
    required int round,
    required int remainingSeconds,
    required bool isRunning,
    required int todayTotalSeconds,
  }) async {
    final data = {
      'mode': mode,
      'round': round,
      'remainingSeconds': remainingSeconds,
      'isRunning': isRunning,
      'todayTotalSeconds': todayTotalSeconds,
    };

    // 写入 App Group UserDefaults
    await _writeToAppGroup('focus', data);

    // 通知 WidgetKit 刷新
    await _channel.invokeMethod('reloadTimelines');
  }

  Future<void> _writeToAppGroup(String key, Map<String, dynamic> data) async {
    // 通过 MethodChannel 调用 iOS UserDefaults(suiteName: _groupId)
    await _channel.invokeMethod('writeAppGroup', {'key': key, 'data': data});
  }
}
```

**iOS 端** (`ios/Runner/AppDelegate.swift`):

```swift
import Flutter
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "com.yourcompany.yike/widget",
                                       binaryMessenger: controller.binaryMessenger)

    channel.setMethodCallHandler { (call, result) in
      if call.method == "writeAppGroup",
         let args = call.arguments as? [String: Any],
         let key = args["key"] as? String,
         let data = args["data"] {
        let userDefaults = UserDefaults(suiteName: "group.com.yourcompany.yike")
        let jsonData = try? JSONSerialization.data(withJSONObject: data)
        userDefaults?.set(jsonData, forKey: key)
        result(nil)
      } else if call.method == "reloadTimelines" {
        WidgetCenter.shared.reloadAllTimelines()
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

**Widget 端** (`ios/YikeWidgets/FocusWidget.swift`):

```swift
import WidgetKit
import SwiftUI

struct FocusEntry: TimelineEntry {
    let date: Date
    let mode: String
    let round: Int
    let remainingSeconds: Int
    let isRunning: Bool
    let todayTotal: Int
}

struct FocusProvider: TimelineProvider {
    func getSnapshot(in context: Context, completion: @escaping (FocusEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = entry.isRunning ? Date().addingTimeInterval(60) : Date().addingTimeInterval(900)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    func placeholder(in context: Context) -> FocusEntry {
        FocusEntry(date: Date(), mode: "番茄钟", round: 1, remainingSeconds: 1500, isRunning: false, todayTotal: 0)
    }

    private func loadEntry() -> FocusEntry {
        let userDefaults = UserDefaults(suiteName: "group.com.yourcompany.yike")
        guard let data = userDefaults?.data(forKey: "focus"),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return placeholder(in: .init())
        }

        return FocusEntry(
            date: Date(),
            mode: json["mode"] as? String ?? "",
            round: json["round"] as? Int ?? 1,
            remainingSeconds: json["remainingSeconds"] as? Int ?? 0,
            isRunning: json["isRunning"] as? Bool ?? false,
            todayTotal: json["todayTotalSeconds"] as? Int ?? 0
        )
    }
}

struct FocusWidgetView: View {
    let entry: FocusEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.mode)
                .font(.headline)
            Text("第 \(entry.round) 轮")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack {
                Text(formatTime(entry.remainingSeconds))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Spacer()
                Image(systemName: entry.isRunning ? "pause.fill" : "play.fill")
                    .foregroundColor(.blue)
            }

            Text("今日 \(formatTime(entry.todayTotal))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

@main
struct YikeWidgets: Widget {
    let kind = "FocusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FocusProvider()) { entry in
            FocusWidgetView(entry: entry)
        }
        .configurationDisplayName("专注进度")
        .description("查看当前专注轮次和倒计时")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
```

同理实现 `CheckinWidget.swift`（打卡小部件）。锁屏小部件用 `AccessoryCircular` / `AccessoryRectangular` family。

### iOS Live Activity（live_activities 包）

#### 初始化

```dart
// lib/main.dart

await LiveActivities().init(appGroupId: 'group.com.yourcompany.yike');
```

#### 创建 Activity

```dart
// lib/common/services/live_activity_service.dart

class LiveActivityService {
  String? _activityId;

  Future<void> startActivity({
    required String mode,
    required int round,
    required int totalSeconds,
  }) async {
    _activityId = await LiveActivities().createActivity({
      'mode': mode,
      'round': round,
      'remainingSeconds': totalSeconds,
      'startTime': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> updateActivity(int remainingSeconds) async {
    if (_activityId == null) return;
    await LiveActivities().updateActivity(_activityId!, {
      'remainingSeconds': remainingSeconds,
    });
  }

  Future<void> endActivity() async {
    if (_activityId == null) return;
    await LiveActivities().endActivity(_activityId!);
    _activityId = null;
  }
}
```

#### Swift 端（动态岛布局）

在 Widget Extension 中创建 `LiveActivityWidget.swift`:

```swift
import ActivityKit
import WidgetKit
import SwiftUI

struct YikeActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var mode: String
        var round: Int
        var remainingSeconds: Int
        var startTime: Int64
    }
}

struct YikeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: YikeActivityAttributes.self) { context in
            // 锁屏样式
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: "timer")
                    Text("\(context.state.mode) 第 \(context.state.round) 轮")
                        .font(.headline)
                }
                ProgressView(value: progress(context.state), total: 1.0)
                Text(formatTime(context.state.remainingSeconds))
                    .font(.title)
                    .fontWeight(.bold)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "timer")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(formatTime(context.state.remainingSeconds))
                        .font(.title3.bold())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Button("暂停") { /* Deep link */ }
                        Button("结束") { /* Deep link */ }
                    }
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                Text(formatTime(context.state.remainingSeconds))
                    .font(.caption2)
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func progress(_ state: YikeActivityAttributes.ContentState) -> Double {
        // 根据 startTime 和 remainingSeconds 计算进度
        return 0.5  // 示例
    }
}
```

### Android 小部件（live_activities 包）

#### 布局 XML

`android/app/src/main/res/layout/focus_widget.xml`:

```xml
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:padding="16dp"
    android:background="@drawable/widget_background">

    <TextView
        android:id="@+id/mode_text"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="番茄钟"
        android:textSize="16sp"
        android:textStyle="bold" />

    <TextView
        android:id="@+id/time_text"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="25:00"
        android:textSize="32sp"
        android:textStyle="bold"
        android:layout_marginTop="8dp" />

    <Button
        android:id="@+id/start_button"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="开始"
        android:layout_marginTop="8dp" />
</LinearLayout>
```

#### Flutter 端

```dart
// lib/common/services/android_widget_service.dart

class AndroidWidgetService {
  static const _channel = MethodChannel('com.yourcompany.yike/android_widget');

  Future<void> updateFocusWidget({
    required String mode,
    required int remainingSeconds,
    required bool isRunning,
  }) async {
    await _channel.invokeMethod('updateWidget', {
      'widgetType': 'focus',
      'mode': mode,
      'time': formatTime(remainingSeconds),
      'buttonText': isRunning ? '暂停' : '开始',
    });
  }

  String formatTime(int seconds) {
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}
```

#### Kotlin 端（WidgetProvider）

`android/app/src/main/kotlin/.../YikeWidgetProvider.kt`:

```kotlin
class YikeWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val prefs = context.getSharedPreferences("widget_prefs", Context.MODE_PRIVATE)
            val mode = prefs.getString("mode", "番茄钟")
            val time = prefs.getString("time", "25:00")
            val buttonText = prefs.getString("buttonText", "开始")

            val views = RemoteViews(context.packageName, R.layout.focus_widget)
            views.setTextViewText(R.id.mode_text, mode)
            views.setTextViewText(R.id.time_text, time)
            views.setTextViewText(R.id.start_button, buttonText)

            // 按钮点击 -> 调用 Flutter 方法
            val intent = Intent(context, MainActivity::class.java).apply {
                action = "START_TIMER"
            }
            val pendingIntent = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.start_button, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
```

在 `MainActivity.kt` 处理 `onNewIntent` 解析 action 并通过 MethodChannel 传回 Flutter。

## 集成点

### 1. 专注页

- `lib/features/focus/focus_vm.dart`:
  ```dart
  // 开始计时
  await WidgetService.instance.updateFocusWidget(...);
  if (_mode == TimerMode.pomodoro || _mode == TimerMode.countdown) {
    await LiveActivityService.instance.startActivity(...);
  }

  // 每秒更新
  await LiveActivityService.instance.updateActivity(_remainingSeconds);

  // 完成/暂停
  await LiveActivityService.instance.endActivity();
  await WidgetService.instance.updateFocusWidget(...);
  ```

### 2. 打卡页

- `lib/features/checkin/habit_vm.dart`:
  ```dart
  // 打卡后
  await WidgetService.instance.updateCheckinWidget(
    completed: _habits.where((h) => h.todayCompleted).length,
    total: _habits.length,
    habits: _habits.take(3).toList(),
  );
  ```

## 平台配置

### iOS

**Info.plist** (Widget Extension):

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.widgetkit-extension</string>
</dict>
```

**Entitlements** (Runner + Widget):

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.yourcompany.yike</string>
</array>
```

### Android

**AndroidManifest.xml**:

```xml
<receiver android:name=".YikeWidgetProvider"
    android:exported="false">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
    </intent-filter>
    <meta-data android:name="android.appwidget.provider"
        android:resource="@xml/focus_widget_info" />
</receiver>
```

**res/xml/focus_widget_info.xml**:

```xml
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:initialLayout="@layout/focus_widget"
    android:minWidth="250dp"
    android:minHeight="110dp"
    android:resizeMode="horizontal|vertical"
    android:updatePeriodMillis="0"
    android:widgetCategory="home_screen" />
```

## 主题适配

三主题在小部件中的视觉差异:

- **机械**: 齿轮图标,冷灰色背景,等宽数字
- **水**: 水滴图标,青蓝渐变,圆润字体
- **日晷**: 太阳图标,暖黄色,衬线数字

小部件读取 `SharedPreferences` 中的 `theme` 键,切换对应资源。iOS 用不同 Asset,Android 用 `@drawable/widget_bg_mechanical` 等。

## 测试清单

| 场景 | 验证点 |
| --- | --- |
| iOS 主屏小部件 | 添加 Medium/Large 小部件,显示专注进度和打卡数 |
| iOS 锁屏小部件 | 添加 Circular/Rectangular,显示打卡环形图和倒计时 |
| iOS Live Activity | 开始番茄钟,锁屏和动态岛显示倒计时,每秒更新 |
| Android 小部件 | 添加 4x2 专注小部件,点击开始按钮启动计时 |
| 数据同步 | 打卡后小部件立即更新完成数 |
| 主题切换 | 切换主题后小部件样式同步 |
| 后台刷新 | 计时中小部件每分钟更新,Activity 每秒更新 |
| 深链接 | 点击小部件跳转到专注/打卡页 |
| 权限 | iOS App Groups 配置正确,Android 无需额外权限 |

## 完成后同步文档

- `docs/known-gaps.md`: 移除"通知、音频与触觉"中的桌面小部件
- `docs/product/product.md`: 增加小部件说明段落
- `docs/plan/README.md`: 标记阶段 6 完成
- `README.md`: 增加小部件和实时活动的截图演示
