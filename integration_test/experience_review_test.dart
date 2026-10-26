// Temporary acceptance capture. Keep until this round is accepted by the user.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yike/app/startup.dart';
import 'package:yike/common/widgets.dart';
import 'package:yike/features/focus/focus.dart';
import 'package:yike/features/focus/focus_models.dart' show FocusData;
import 'package:yike/features/home/pages/home_page.dart';
import 'package:yike/features/local_data/models/local_data.dart';
import 'package:yike/features/local_data/models/local_data_prefs.dart';
import 'package:yike/storage/mmkv_app_prefs.dart';
import 'package:yike/theme/ts.dart';
import 'package:yike/features/settings/pages/settings_page.dart';
import 'package:yike/theme/yike_motion.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'capture agreed focus, settings and review experience on a mobile device',
    (tester) async {
      final prefs = await MmkvAppPrefs.open(id: 'yike_experience_review');
      prefs.write(
        localDataPrefs,
        YikeData.initial(DateTime.now()).copyWith(
          focus: const FocusData(
            preferences: TimingPreferences(sound: true, haptics: false),
          ),
        ),
      );
      final screen = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: screen,
          child: AppStartup(openPreferences: () async => prefs),
        ),
      );
      Future<void> settle() async {
        await tester.pump();
        for (var frame = 0; frame < 16; frame++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(tester.takeException(), isNull);
      }

      Future<void> capture(String name) async {
        await settle();
        final boundary =
            screen.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final result = await boundary.toImage(pixelRatio: 2);
        final bytes = await result.toByteData(format: ui.ImageByteFormat.png);
        result.dispose();
        final directory = Directory(
          '${Directory.systemTemp.path}/yike-experience-review',
        )..createSync(recursive: true);
        final file = File('${directory.path}/$name.png');
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        debugPrint('YIKE_REVIEW_CAPTURE=${file.path}');
      }

      Finder nav(String label) => find.descendant(
        of: find.byKey(const ValueKey('settings-navigation')),
        matching: find.text(label),
      );
      Future<void> select(String label) async {
        if (nav(label).hitTestable().evaluate().isEmpty) {
          await tester.drag(
            find.byKey(const ValueKey('settings-navigation')),
            const Offset(-200, 0),
          );
          await settle();
        }
        await tester.tap(nav(label));
        await settle();
      }

      await capture('focus');
      final app = ProviderScope.containerOf(
        tester.element(find.byType(YikeHomePage)),
      );
      await tester.tap(find.byTooltip('设置'));
      await capture('settings-top');
      final scroll = tester
          .widget<CustomScrollView>(
            find.descendant(
              of: find.byType(YikeSettingsPage),
              matching: find.byType(CustomScrollView),
            ),
          )
          .controller!;
      scroll.jumpTo(YikeMotion.settingsGlassTravel / 2);
      await capture('settings-glass-mid');
      scroll.jumpTo(YikeMotion.settingsGlassTravel);
      await capture('settings-glass-clear');
      scroll.jumpTo(0);
      await settle();
      await select('番茄钟');
      await capture('settings-pomodoro');
      await tester.tap(find.byKey(const ValueKey('pomodoro-advanced')));
      await capture('settings-advanced');
      await select('声音');
      await capture('settings-sounds');
      await select('通用');
      await capture('settings-bottom');
      await select('倒计时');
      await tester.tap(find.byTooltip('打开常用倒计时'));
      await settle();
      await tester.tap(find.byKey(const ValueKey('preset-row-0')));
      await capture('preset-editor');
      await tester.tap(find.byKey(const ValueKey('preset-row-1')));
      await capture('preset-editor-next');
      await tester.tap(find.byTooltip('关闭'));
      await settle();
      await tester.tap(find.byTooltip('返回'));
      await settle();
      await tester.tap(
        find.descendant(of: find.byType(FocusPage), matching: find.text('倒计时')),
      );
      await capture('countdown');
      for (final theme in ['water', 'sundial']) {
        app.read(themePackProvider.notifier).select('yike/$theme');
        await capture('countdown-$theme');
      }
      app.read(themePackProvider.notifier).select('yike/mechanical');
      await settle();
      await tester.tap(
        find.descendant(
          of: find.byType(CommonBottomNav),
          matching: find.text('回顾'),
        ),
      );
      await capture('review');
      await tester.tap(find.byKey(const ValueKey('review-period-picker')));
      await capture('review-week-picker');
      await tester.tap(find.byTooltip('上一年'));
      await capture('review-previous-year');
      await tester.tap(find.byTooltip('关闭'));
      await settle();
      await tester.tap(find.text('月'));
      await settle();
      await tester.tap(find.byKey(const ValueKey('review-period-picker')));
      await capture('review-month-picker');
    },
  );
}
