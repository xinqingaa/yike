import 'package:flutter/material.dart';
import '../../../common/widgets.dart';
import '../models/habit_view.dart';

CommonIconName habitIconName(HabitIcon icon) => switch (icon) {
  HabitIcon.leaf => CommonIconName.leaf,
  HabitIcon.book => CommonIconName.bookOpen,
  HabitIcon.water => CommonIconName.glassWater,
  HabitIcon.running => CommonIconName.footprints,
  HabitIcon.moon => CommonIconName.moon,
  HabitIcon.stretch => CommonIconName.stretchHorizontal,
};
String habitIconLabel(HabitIcon icon) =>
    const ['叶子', '书', '水', '跑步', '月亮', '拉伸'][icon.index];

class HabitGlyph extends StatelessWidget {
  const HabitGlyph({super.key, required this.icon});
  final HabitIcon icon;
  @override
  Widget build(BuildContext context) => CommonIcon(name: habitIconName(icon));
}
