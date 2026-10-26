/// Flutter-owned motion geometry; durations and curves come from TS.motion.
abstract final class YikeMotion {
  static const settingsGlassTravel = 180.0;
  static const auditionTick = Duration(seconds: 1);
  static const auditionTicks = Duration(seconds: 5);
  static const auditionSingle = Duration(milliseconds: 1400);
  static const statusFold = Duration(milliseconds: 260);
  static const statusResize = Duration(milliseconds: 200);
  static const statusFade = Duration(milliseconds: 160);
  static const statusEnter = Duration(milliseconds: 240);
  static const statusExit = Duration(milliseconds: 220);
  static const statusSweep = Duration(seconds: 3);
  static const statusPausedSweep = Duration(milliseconds: 2700);
  static const statusDragTravel = 96.0;
  static const hourHold = Duration(milliseconds: 700);
  static const digitTravel = .35;
  static double digitTravelFor(String theme) => switch (theme) {
    'yike/water' => .22,
    'yike/sundial' => .18,
    _ => digitTravel,
  };
  static const secondWindow = .18;
  static const minuteWindow = .7;
  static const secondStrength = .12;
  static const minuteStrength = .35;
  static const completionScale = .012;
  static const checkinScale = .06;
  static const contentTravel = .035;
  static const waveTravel = .012;
  static const rippleRadius = .12;
  static const shadowBreath = .035;
}
