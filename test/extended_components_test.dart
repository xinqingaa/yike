import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yike/common/widgets.dart';
import 'package:yike/common/widgets/charts/calendar_dates.dart';
import 'package:yike/theme/ts.dart';
import 'package:yike/common/state/local_value.dart';

Widget shell(WidgetBuilder builder) => ProviderScope(
  child: MaterialApp(
    theme: TS(brightness: Brightness.light).toThemeData(),
    home: Scaffold(body: Builder(builder: builder)),
  ),
);

void main() {
  test(
    'date-only arithmetic rejects rollover dates and caps the heatmap range',
    () {
      expect(parseCalendarDay('2026-02-30'), isNull);
      expect(parseCalendarDay('2028-02-29')?.isUtc, isTrue);
      expect(shiftCalendarMonth('2026-12', 1), '2027-01');
      final weeks = heatmapWeeks(const [
        CommonHeatmapDay(date: '2026-01-01', value: 0),
        CommonHeatmapDay(date: '2026-01-03', value: -2),
        CommonHeatmapDay(date: '2029-01-01', value: 9),
      ]);
      final cells = weeks.expand((week) => week).toList();
      expect(cells.singleWhere((cell) => cell.date == '2026-01-01').value, 0);
      expect(
        cells.singleWhere((cell) => cell.date == '2026-01-02').value,
        isNull,
      );
      expect(cells.singleWhere((cell) => cell.date == '2026-01-03').value, 0);
      expect(cells.any((cell) => cell.date == '2029-01-01'), isFalse);
      expect(cells.length, lessThanOrEqualTo(371));
    },
  );

  testWidgets('stepper keyboard and buttons share step and bounds', (
    tester,
  ) async {
    double value = 1;
    final valueProvider = localValueProvider<double>(1);
    await tester.pumpWidget(
      shell(
        (context) => Consumer(
          builder: (context, ref, _) {
            value = ref.watch(valueProvider);
            return CommonStepper(
              value: value,
              min: 1,
              max: 8,
              step: 2,
              onChanged: (next) => ref.read(valueProvider.notifier).set(next),
            );
          },
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '5.1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(value, 5);
    await tester.tap(find.byTooltip('增加'));
    await tester.pump();
    expect(value, 7);
    await tester.tap(find.byTooltip('增加'));
    await tester.pump();
    expect(value, 8);
    await tester.enterText(find.byType(TextField), 'NaN');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(value, 8);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, '8');
  });

  testWidgets(
    'wheel follows external updates and emits independent column values',
    (tester) async {
      var values = <Object>[1, 2];
      final valuesProvider = localValueProvider<List<Object>>(const [1, 2]);
      late LocalValue<List<Object>> update;
      const columns = [
        CommonWheelColumn(
          id: 'one',
          label: 'One',
          options: [
            CommonWheelOption(value: 0, label: 'zero'),
            CommonWheelOption(value: 1, label: 'one'),
            CommonWheelOption(value: 2, label: 'two'),
          ],
        ),
        CommonWheelColumn(
          id: 'two',
          label: 'Two',
          options: [
            CommonWheelOption(value: 1, label: 'first'),
            CommonWheelOption(value: 2, label: 'second'),
          ],
        ),
      ];
      await tester.pumpWidget(
        shell(
          (context) => Consumer(
            builder: (context, ref, _) {
              values = ref.watch(valuesProvider);
              update = ref.read(valuesProvider.notifier);
              return CommonWheelPicker(
                columns: columns,
                values: values,
                onChanged: (next) => update.set(List.unmodifiable(next)),
              );
            },
          ),
        ),
      );
      update.set(const [0, 2]);
      await tester.pump();
      final first = tester.widget<ListWheelScrollView>(
        find.byType(ListWheelScrollView).first,
      );
      expect((first.controller as FixedExtentScrollController).selectedItem, 0);
      await tester.drag(
        find.byType(ListWheelScrollView).first,
        const Offset(0, -40),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(values.first, 1);
      expect(values.last, 2);
    },
  );

  testWidgets(
    'calendar handles leap days, disabled dates and controlled month changes',
    (tester) async {
      String? selected;
      String? month;
      await tester.pumpWidget(
        shell(
          (context) => CommonMonthCalendar(
            month: '2028-02',
            today: '2028-02-29',
            disabledDates: const {'2028-02-28'},
            onChanged: (value) => selected = value,
            onMonthChanged: (value) => month = value,
          ),
        ),
      );
      await tester.tap(find.text('28'));
      expect(selected, isNull);
      await tester.tap(find.text('29'));
      expect(selected, '2028-02-29');
      await tester.tap(find.byTooltip('下个月'));
      expect(month, '2028-03');
      await tester.pumpWidget(
        shell((context) => const CommonMonthCalendar(month: '2028-99')),
      );
      expect(find.byType(InkWell), findsNothing);
    },
  );

  testWidgets(
    'calendar day builder keeps component-owned disabled interaction',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        shell(
          (context) => CommonMonthCalendar(
            month: '2026-07',
            value: '2026-07-15',
            showHeader: false,
            customDayAppearance: true,
            disabledDates: const {'2026-07-15'},
            onChanged: (_) => calls++,
            dayBuilder: (context, day) => Text('day:${day.date}'),
          ),
        ),
      );
      expect(find.byTooltip('下个月'), findsNothing);
      await tester.tap(find.text('day:2026-07-15'));
      expect(calls, 0);
      await tester.tap(find.text('day:2026-07-16'));
      expect(calls, 1);
    },
  );

  testWidgets('heatmap shell renders the supplied year grid', (tester) async {
    const days = [
      CommonHeatmapDay(date: '2026-07-01', value: 0),
      CommonHeatmapDay(date: '2026-07-03', value: 3),
    ];
    await tester.pumpWidget(
      shell(
        (context) => CommonHeatmap(
          days: days,
          label: '最近记录',
          plotBuilder: (context, weeks, maximum) => CommonYearGrid(
            weeks: weeks,
            cellBuilder: (context, cell, size) => CommonHeatmapBlock(
              size: size,
              cellKey: ValueKey(cell.date),
              color: cell.value == null
                  ? const Color(0xFF111111)
                  : const Color(0xFFEEEEEE),
            ),
          ),
        ),
      ),
    );
    expect(find.text('最近记录'), findsOneWidget);
    expect(find.text('少'), findsNothing);
    Color colorOf(String date) =>
        (tester.widget<DecoratedBox>(find.byKey(ValueKey(date))).decoration
                as BoxDecoration)
            .color!;
    expect(colorOf('2026-07-01'), const Color(0xFFEEEEEE));
    expect(colorOf('2026-07-02'), const Color(0xFF111111));
  });

  testWidgets('group events carry both stable group and item identities', (
    tester,
  ) async {
    Object? event;
    await tester.pumpWidget(
      shell(
        (context) => CommonGroupedList(
          groups: const [
            CommonListGroup(
              id: 'settings',
              title: '设置',
              items: [
                CommonListItem(id: 'details', title: '明细', navigation: true),
                CommonListItem(id: 'reminder', title: '提醒', switchValue: false),
              ],
            ),
          ],
          onNavigate: (group, item) => event = (group, item),
          onChanged: (group, item, value) => event = (group, item, value),
        ),
      ),
    );
    await tester.tap(find.text('明细'));
    expect(event, ('settings', 'details'));
    event = null;
    final row = tester.getRect(find.byKey(const ValueKey('settings/details')));
    await tester.tapAt(Offset(row.right - 70, row.center.dy));
    expect(event, ('settings', 'details'));
    await tester.tap(find.byType(Switch));
    expect(event, ('settings', 'reminder', true));
    expect(find.byType(Scrollable), findsNothing);
  });

  testWidgets('launch mode has no welcome actions or timer-driven navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      shell(
        (context) => const CommonLaunchScreen(
          mode: CommonLaunchMode.launch,
          brandName: '品牌标识',
        ),
      ),
    );
    expect(find.text('品牌标识'), findsOneWidget);
    expect(find.byType(CommonButton), findsNothing);
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('品牌标识'), findsOneWidget);
  });
}
