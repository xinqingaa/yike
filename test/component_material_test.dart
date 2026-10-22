import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_popups/unified_popups.dart';

import 'package:yike/common/overlay/app_pop.dart';
import 'package:yike/common/widgets.dart';
import 'package:yike/theme/ts.dart';

Widget shell(WidgetBuilder builder) => ProviderScope(
  child: MaterialApp(
    theme: TS(brightness: Brightness.light).toThemeData(),
    navigatorObservers: [Pop.routeObserver],
    builder: Pop.hostBuilder,
    home: Scaffold(body: Builder(builder: builder)),
  ),
);

void main() {
  testWidgets('toast undo executes once and closes the toast', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      shell(
        (context) => TextButton(
          onPressed: () => AppPop.toast(
            context,
            '已归档',
            actionLabel: '撤销',
            onAction: () => calls++,
          ),
          child: const Text('提示'),
        ),
      ),
    );
    await tester.tap(find.text('提示'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('撤销'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(calls, 1);
    expect(find.text('撤销'), findsNothing);
  });

  testWidgets('failed loading forwards the error and removes the blocker', (
    tester,
  ) async {
    final task = Completer<void>();
    Object? failure;
    await tester.pumpWidget(
      shell(
        (context) => TextButton(
          onPressed: () async {
            try {
              await AppPop.runLoading(
                context,
                message: '处理中',
                task: task.future,
              );
            } catch (error) {
              failure = error;
            }
          },
          child: const Text('提交'),
        ),
      ),
    );
    await tester.tap(find.text('提交'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('处理中'), findsOneWidget);
    final error = StateError('failed');
    task.completeError(error);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(failure, same(error));
    expect(find.text('处理中'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('flow actions stay visible and support back then completion', (
    tester,
  ) async {
    final controller = FlowSheetController<String>();
    String? result;
    await tester.pumpWidget(
      shell(
        (context) => TextButton(
          onPressed: () async {
            result = await AppPop.flowSheet<String>(
              context,
              controller: controller,
              initialPage: _FlowTestPage(controller: controller, step: 0),
              title: '流程',
            );
          },
          child: const Text('打开流程'),
        ),
      ),
    );
    await tester.tap(find.text('打开流程'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('下一步').hitTestable(), findsOneWidget);
    await tester.tap(find.text('下一步'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.canPop, isTrue);
    await tester.tap(find.byTooltip('返回上一步'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.canPop, isFalse);
    await tester.tap(find.text('下一步'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('完成'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(result, 'done');
    expect(find.text('流程'), findsNothing);
  });
  testWidgets('loading retains its label and prevents duplicate actions', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      shell(
        (context) =>
            CommonButton(label: '保存', loading: true, onPressed: () => calls++),
      ),
    );
    expect(find.text('保存'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('保存'));
    expect(calls, 0);
    final opacity = tester.widget<Opacity>(
      find
          .descendant(
            of: find.byType(CommonButton),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(opacity.opacity, 1);
  });

  testWidgets(
    'glass preserves child interaction and supports opaque fallback',
    (tester) async {
      var calls = 0;
      Widget body(bool opaque) => shell(
        (context) => CommonGlassSurface(
          reduceTransparency: opaque,
          child: TextButton(
            onPressed: () => calls++,
            child: const Text('内容操作'),
          ),
        ),
      );
      await tester.pumpWidget(body(false));
      expect(find.byType(LiquidGlass), findsOneWidget);
      await tester.tap(find.text('内容操作'));
      expect(calls, 1);
      await tester.pumpWidget(body(true));
      expect(find.byType(LiquidGlass), findsNothing);
      await tester.tap(find.text('内容操作'));
      expect(calls, 2);
    },
  );

  testWidgets('confirm uses shared buttons and returns the library result', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      shell(
        (context) => TextButton(
          onPressed: () async {
            result = await AppPop.confirm(
              context,
              title: '删除记录',
              content: '确认删除？',
              danger: true,
            );
          },
          child: const Text('打开确认'),
        ),
      ),
    );
    await tester.tap(find.text('打开确认'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('删除记录'), findsOneWidget);
    await tester.tap(find.text('确定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(result, isTrue);
  });

  testWidgets('action sheet completes with the selected typed value', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      shell(
        (context) => TextButton(
          onPressed: () async {
            result = await AppPop.actionSheet<String>(
              context,
              title: '选择操作',
              actions: const [AppSheetAction(value: 'archive', label: '归档')],
            );
          },
          child: const Text('打开动作'),
        ),
      ),
    );
    await tester.tap(find.text('打开动作'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('归档'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(result, 'archive');
  });
}

class _FlowTestPage extends FlowSheetPage<void> {
  const _FlowTestPage({required this.controller, required this.step})
    : super(id: 'step-$step');
  final FlowSheetController<String> controller;
  final int step;
  @override
  State<_FlowTestPage> createState() => _FlowTestPageState();
}

class _FlowTestPageState extends FlowSheetPageState<_FlowTestPage, void> {
  @override
  Widget build(BuildContext context) => CommonFlowSheetContent(
    step: widget.step,
    stepCount: 2,
    body: Column(children: List.generate(40, (i) => Text('正文 $i'))),
    actions: [
      CommonButton(
        label: widget.step == 0 ? '下一步' : '完成',
        onPressed: () {
          if (widget.step == 0) {
            nav.push<void>(
              _FlowTestPage(controller: widget.controller, step: 1),
            );
          } else {
            widget.controller.closeAll('done');
          }
        },
      ),
    ],
  );
}
