/// Transient rendering input, independent of sessions and persistence.
class DialFrame {
  const DialFrame({
    required this.progress,
    this.secondBeat = 0,
    this.minuteBeat = 0,
    this.wavePhase = 0,
  });
  final double progress, secondBeat, minuteBeat, wavePhase;
  double get beat => secondBeat + minuteBeat;
}
