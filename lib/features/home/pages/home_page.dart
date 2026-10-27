import '../../../app/external_targets.dart';
import '../../../common/overlay/popup_activity.dart';
import '../../../common/route_activity.dart';
import '../../../router/routes.dart';
import '../../local_data/local_data.dart';
import '../../onboarding/onboarding.dart';
import '../../../app/navigation.dart';
import '../../../app/root_back_boundary.dart';
import '../../../common/motion/motion_activity.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/widgets.dart';
import '../../../theme/ts.dart';
import '../../../common/widgets/yike/layout.dart';
import '../../habits/habits.dart';
import '../../focus/focus.dart';
import '../../review/review.dart';

class YikeHomePage extends ConsumerStatefulWidget {
  const YikeHomePage({super.key});
  @override
  ConsumerState<YikeHomePage> createState() => _YikeHomePageState();
}

class _YikeHomePageState extends ConsumerState<YikeHomePage>
    with TickerProviderStateMixin {
  late TabController _controller;
  Duration? _tabDuration;
  bool _introductionScheduled = false;
  bool _introductionOpen = false;

  void _scheduleIntroduction() {
    if (_introductionScheduled || _introductionOpen) return;
    _introductionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _introductionScheduled = false;
      if (!mounted ||
          _introductionOpen ||
          appRouteActivity.current != AppRoutes.home ||
          ref.read(rootTabProvider) != 0 ||
          ref.read(externalTargetsProvider) != null ||
          ref.read(popupActivityProvider) != 0) {
        return;
      }
      final local = ref.read(localDataProvider);
      if (local.readError != null || local.data.onboardingComplete) return;
      _introductionOpen = true;
      showYikeOnboarding().whenComplete(() {
        if (!mounted) return;
        final data = ref.read(localDataProvider);
        if (data.readError == null && !data.data.onboardingComplete) {
          ref
              .read(localDataProvider.notifier)
              .commit(data.data.copyWith(onboardingComplete: true));
        }
        _introductionOpen = false;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : TS.of(context).motion.durationTabViewport;
    if (_tabDuration == null) {
      _controller = TabController(
        length: 3,
        vsync: this,
        initialIndex: ref.read(rootTabProvider),
        animationDuration: duration,
      );
    } else if (_tabDuration != duration) {
      final previous = _controller;
      _controller = TabController(
        length: 3,
        vsync: this,
        initialIndex: previous.index,
        animationDuration: duration,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
    _tabDuration = duration;
  }

  @override
  void dispose() {
    appRouteActivity.removeListener(_scheduleIntroduction);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(rootTabProvider);
    ref.listen(externalTargetsProvider, (_, _) => _scheduleIntroduction());
    ref.listen(popupActivityProvider, (_, _) => _scheduleIntroduction());
    ref.listen(localDataProvider, (_, _) => _scheduleIntroduction());
    appRouteActivity.removeListener(_scheduleIntroduction);
    appRouteActivity.addListener(_scheduleIntroduction);
    _scheduleIntroduction();
    ref.listen(
      rootTabProvider,
      (_, next) => _controller.animateTo(
        next,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : TS.of(context).motion.durationTabViewport,
        curve: TS.of(context).motion.easingGentle,
      ),
    );
    return RootBackBoundary(
      child: Scaffold(
        body: MotionVisibility(
          child: SafeArea(
            bottom: false,
            child: YikePageWidth(
              child: CommonTabView(
                controller: _controller,
                selectedNow: (index) => ref.read(rootTabProvider) == index,
                swipe: false,
                children: const [FocusPage(), CheckinPage(), ReviewPage()],
              ),
            ),
          ),
        ),
        bottomNavigationBar: YikePageWidth(
          child: CommonBottomNav(
            currentIndex: tab,
            selection: _controller.animation,
            onTap: (value) => ref.read(rootTabProvider.notifier).set(value),
            items: const [
              CommonBottomNavItem(
                value: 'focus',
                label: '专注',
                icon: CommonIconName.yikeModeStopwatch,
              ),
              CommonBottomNavItem(
                value: 'checkin',
                label: '打卡',
                icon: CommonIconName.circleCheck,
              ),
              CommonBottomNavItem(
                value: 'review',
                label: '回顾',
                icon: CommonIconName.chartColumn,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
