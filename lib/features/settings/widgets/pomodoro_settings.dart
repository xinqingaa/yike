import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/motion/content_transition.dart';
import '../../../common/overlay/app_pop.dart';
import '../../../common/state/local_value.dart';
import '../../../common/time.dart';
import '../../../common/widgets.dart';
import '../../../theme/ts.dart';
import '../../focus/focus.dart';

const _schemes = [
  (name: '经典', focus: 1500, short: 300, long: 900, interval: 4),
  (name: '轻量', focus: 900, short: 180, long: 600, interval: 4),
  (name: '深度', focus: 3000, short: 600, long: 1200, interval: 2),
];

class PomodoroSettings extends ConsumerStatefulWidget {
  const PomodoroSettings({super.key, required this.onNavigate});
  final ValueChanged<String> onNavigate;
  @override
  ConsumerState<PomodoroSettings> createState() => _PomodoroSettingsState();
}

class _PomodoroSettingsState extends ConsumerState<PomodoroSettings> {
  final _expanded = localValueProvider(false);

  int _schemeIndex(TimingPreferences prefs) => _schemes.indexWhere(
    (scheme) =>
        prefs.focusSeconds == scheme.focus &&
        prefs.shortSeconds == scheme.short &&
        prefs.longSeconds == scheme.long &&
        prefs.interval == scheme.interval &&
        prefs.shortInterval == 1 &&
        prefs.totalRounds == 0,
  );

  Future<void> _chooseScheme() async {
    final sheet = AppSheet<void>();
    await sheet.show(
      title: '番茄方案',
      material: CommonSurfaceMaterial.glass,
      child: _SchemeChoices(onSelected: sheet.dismiss),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context), prefs = ref.watch(timingPreferencesProvider);
    final scheme = _schemeIndex(prefs), expanded = ref.watch(_expanded);
    final counts = prefs.breakCounts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CommonGroupedList(
          headingStyle: ts.textStyle.titleSm,
          groups: [
            CommonListGroup(
              id: 'pomodoro',
              title: '番茄钟',
              items: [
                CommonListItem(
                  id: 'scheme',
                  title: '方案',
                  value: scheme < 0 ? '自定义' : _schemes[scheme].name,
                  navigation: true,
                ),
                CommonListItem(
                  id: 'focus',
                  title: '专注时长',
                  value: durationLabel(prefs.focusSeconds),
                  navigation: true,
                ),
                CommonListItem(
                  id: 'short',
                  title: '短休息',
                  value: durationLabel(prefs.shortSeconds),
                  navigation: true,
                ),
                CommonListItem(
                  id: 'long',
                  title: '长休息',
                  value: durationLabel(prefs.longSeconds),
                  navigation: true,
                ),
              ],
            ),
          ],
          onNavigate: (_, item) =>
              item == 'scheme' ? _chooseScheme() : widget.onNavigate(item),
        ),
        CommonCard(
          padding: EdgeInsets.zero,
          margin: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CommonPressableSurface(
                key: const ValueKey('pomodoro-advanced'),
                onPressed: () => ref.read(_expanded.notifier).set(!expanded),
                child: Padding(
                  padding: EdgeInsets.all(ts.spacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('休息与轮次', style: ts.textStyle.content),
                      ),
                      AnimatedRotation(
                        turns: expanded ? .5 : 0,
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : ts.motion.durationNormal,
                        child: CommonIcon(
                          name: CommonIconName.chevronDown,
                          dimension: ts.sizing.iconSm,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              MotionExpand(
                expanded: expanded,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CommonListCell(
                      key: const ValueKey('pomodoro/shortInterval'),
                      title: '短休频率',
                      value: prefs.shortInterval == 0
                          ? '关闭'
                          : '每 ${prefs.shortInterval} 轮',
                      navigation: true,
                      onNavigate: () => widget.onNavigate('shortInterval'),
                    ),
                    CommonListCell(
                      key: const ValueKey('pomodoro/interval'),
                      title: '长休间隔',
                      value: prefs.interval == 0
                          ? '关闭'
                          : '每 ${prefs.interval} 轮',
                      navigation: true,
                      onNavigate: () => widget.onNavigate('interval'),
                    ),
                    CommonListCell(
                      key: const ValueKey('pomodoro/totalRounds'),
                      title: '总专注轮数',
                      value: prefs.totalRounds == 0
                          ? '不限轮数'
                          : '${prefs.totalRounds} 轮',
                      navigation: true,
                      onNavigate: () => widget.onNavigate('totalRounds'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: ts.spacing.sm),
        Text(
          prefs.cycleLength == 0
              ? '不限轮数，不安排休息'
              : '${prefs.totalRounds > 0 ? '本组' : '每循环'} ${prefs.cycleLength} 轮，${counts.short} 次短休、${counts.long} 次长休。',
          key: const ValueKey('pomodoro-summary'),
          style: ts.textStyle.caption,
        ),
      ],
    );
  }
}

class _SchemeChoices extends ConsumerWidget {
  const _SchemeChoices({required this.onSelected});
  final VoidCallback onSelected;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(timingPreferencesProvider);
    final selected = _schemes.indexWhere(
      (s) =>
          prefs.focusSeconds == s.focus &&
          prefs.shortSeconds == s.short &&
          prefs.longSeconds == s.long &&
          prefs.interval == s.interval &&
          prefs.shortInterval == 1 &&
          prefs.totalRounds == 0,
    );
    final ts = TS.of(context);
    return AppSheetContent(
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _schemes.length; i++)
            CommonPressableSurface(
              selected: i == selected,
              onPressed: () {
                final s = _schemes[i];
                ref
                    .read(timingPreferencesProvider.notifier)
                    .update(
                      (p) => p.copyWith(
                        focusSeconds: s.focus,
                        shortSeconds: s.short,
                        longSeconds: s.long,
                        interval: s.interval,
                        shortInterval: 1,
                        totalRounds: 0,
                      ),
                    );
                onSelected();
              },
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: ts.spacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_schemes[i].name, style: ts.textStyle.content),
                          SizedBox(height: ts.spacing.xs),
                          Text(
                            '专注 ${_schemes[i].focus ~/ 60} 分 · 短休 ${_schemes[i].short ~/ 60} 分 · 长休 ${_schemes[i].long ~/ 60} 分',
                            style: ts.textStyle.caption,
                          ),
                        ],
                      ),
                    ),
                    if (i == selected)
                      Icon(
                        Icons.check_rounded,
                        size: ts.sizing.iconMd,
                        color: ts.colors.primary,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
