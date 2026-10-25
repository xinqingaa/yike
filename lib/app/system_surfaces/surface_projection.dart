import '../../common/system_surfaces/surface_models.dart';
import '../../common/time.dart';
import '../../features/focus/focus_models.dart';
import '../../features/local_data/local_data.dart';

SurfaceTimer surfaceTimer(FocusSession s, {String? token}) => SurfaceTimer(
  token: token,
  mode: s.mode.name,
  session: s.id,
  stage: s.stage.name,
  status: s.status.name,
  elapsedMs: s.status == TimerStatus.running ? 0 : s.elapsedMs,
  anchorMs: s.status == TimerStatus.running && s.anchor != null
      ? s.anchor!.millisecondsSinceEpoch - s.elapsedMs
      : null,
  limitMs: s.limitMs,
  scaleSeconds: s.scaleSeconds,
  round: s.round,
  laps: s.laps.length,
);

/// Ignore pulse-only anchor movement and elapsed accumulation.
String surfaceSessionIdentity(FocusData data) => data.allSessions.values
    .map(
      (s) =>
          '${s.id}/${s.stage}/${s.status}/${s.limitMs}/${s.scaleSeconds}/${s.round}/${s.laps.length}/${s.status == TimerStatus.running ? 0 : s.elapsedMs}',
    )
    .join('|');

SurfaceSnapshot surfaceProjection(
  LocalDataState state,
  DateTime now, {
  required String epoch,
  required int revision,
  required bool ready,
  required bool liveEnabled,
  required String theme,
  required String appearance,
  Map<String, String> palette = const {},
  Map<String, String> tokens = const {},
}) {
  final readable = ready && state.readError == null;
  final date = dayId(now);
  final active = readable
      ? state.data.habits.where((h) => !h.archived).toList()
      : const <Never>[];
  // Match the existing focus-page summary: recorded daily slices only.
  final seconds = readable
      ? state.data.focus.dailyRecords
            .where((r) => r.date == date)
            .fold<num>(0, (sum, r) => sum + r.seconds)
            .floor()
      : 0;
  return SurfaceSnapshot(
    epoch: epoch,
    revision: revision,
    generatedMs: now.millisecondsSinceEpoch,
    date: date,
    timezone: now.timeZoneName,
    readable: readable,
    unsaved: state.writeError != null,
    liveEnabled: ready && liveEnabled,
    theme: theme,
    appearance: appearance,
    palette: palette,
    timers: readable
        ? [
            for (final mode in TimerMode.values)
              if (state.data.focus.sessionFor(mode) case final s?)
                surfaceTimer(s, token: tokens[s.id]),
          ]
        : const [],
    todaySeconds: seconds,
    habitTotal: active.length,
    habitDone: active.where((h) => h.dates.contains(date)).length,
    habits: [
      for (final h in active.take(3))
        {
          'id': h.id,
          'name': h.name,
          'icon': h.icon.name,
          'done': h.dates.contains(date),
        },
    ],
  );
}
