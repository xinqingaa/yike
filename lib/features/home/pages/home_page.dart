import '../../../app/navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/widgets.dart';
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
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(
    length: 3,
    vsync: this,
    initialIndex: ref.read(rootTabProvider),
  );
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(rootTabProvider);
    ref.listen(rootTabProvider, (_, next) => _controller.index = next);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: YikePageWidth(
          child: CommonTabView(
            controller: _controller,
            swipe: false,
            children: const [FocusPage(), CheckinPage(), ReviewPage()],
          ),
        ),
      ),
      bottomNavigationBar: YikePageWidth(
        child: CommonBottomNav(
          currentIndex: tab,
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
    );
  }
}
