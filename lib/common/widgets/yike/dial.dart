import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../theme/ts.dart';
import '../../../theme/yike_motion.dart';
import '../../motion/motion_activity.dart';
import '../../motion/rolling_digits.dart';
import '../../../theme/yike_artwork.dart';
import '../../../theme/yike_geometry.dart';

/// Local presentation only; supplied progress never settles business time.
class YikeDial extends StatefulWidget {
  const YikeDial({
    super.key,
    this.digits,
    this.caption,
    this.progress = 25 / 60,
    this.paused = false,
    this.resting = false,
    this.completed = false,
    this.countdown = false,
    this.width,
    this.brand = false,
    this.tokens,
    this.animateDigits = false,
    this.digitIdentity,
    this.descending = false,
    this.beat = 0,
    this.wavePhase = 0,
  });
  final String? digits, caption;
  final double progress;
  final bool paused, resting, completed, countdown, brand;
  final double? width;
  final TS? tokens;
  final bool animateDigits, descending;
  final Object? digitIdentity;
  final double beat, wavePhase;
  @override
  State<YikeDial> createState() => _YikeDialState();
}

class _YikeDialState extends State<YikeDial>
    with SingleTickerProviderStateMixin {
  late final AnimationController _roll = AnimationController(
    vsync: this,
    value: 1,
  );
  String? _previous;
  bool _enabled = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enabled =
        !MediaQuery.disableAnimationsOf(context) &&
        MotionGate.activeOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (!_enabled) _roll.value = 1;
  }

  int? _seconds(String? digits) {
    if (digits == null) return null;
    var seconds = 0;
    for (final part in digits.split(':')) {
      final number = int.tryParse(part);
      if (number == null) return null;
      seconds = seconds * 60 + number;
    }
    return seconds;
  }

  @override
  void didUpdateWidget(covariant YikeDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.animateDigits ||
        !_enabled ||
        oldWidget.digitIdentity != widget.digitIdentity) {
      _roll.value = 1;
    } else if (widget.digits != oldWidget.digits) {
      final before = _seconds(oldWidget.digits),
          after = _seconds(widget.digits);
      if (before != null &&
          after != null &&
          (after - before).abs() == 1 &&
          oldWidget.digits?.length == widget.digits?.length) {
        _previous = oldWidget.digits;
        _roll.duration = (widget.tokens ?? TS.of(context)).motion.durationFast;
        _roll.forward(from: 0);
      } else {
        _roll.value = 1;
      }
    }
  }

  @override
  void dispose() {
    _roll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ts = widget.tokens ?? TS.of(context);
    final digits = widget.digits, caption = widget.caption;
    final paused = widget.paused,
        resting = widget.resting,
        completed = widget.completed;
    final brand = widget.brand;
    final theme = ts.pack.id.split('/').last;
    final w = widget.width ?? ts.sizing.plot;
    final h = w * ts.artworkAspectRatio;
    final p = widget.progress.clamp(0.0, 1.0);
    Widget readout(bool inverse) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (theme == 'water' && caption != null) ...[
          Text(
            caption,
            style: ts.textStyle.micro.copyWith(
              color: inverse ? ts.colors.onPrimary : null,
            ),
          ),
          SizedBox(height: ts.spacing.lg),
        ],
        if (digits != null)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedBuilder(
              animation: _roll,
              builder: (context, _) => RollingDigits(
                value: digits,
                previous: _previous ?? digits,
                phase: _roll.value,
                descending: widget.descending,
                inverse: inverse,
                style: ts.textStyle.numericDisplay.copyWith(
                  color: inverse
                      ? ts.colors.onPrimary
                      : completed && !resting
                      ? ts.colors.primary
                      : ts.colors.onSurface,
                ),
              ),
            ),
          ),
        if (theme != 'water' && caption != null) ...[
          SizedBox(height: ts.spacing.xs),
          Text(
            caption,
            style: ts.textStyle.micro.copyWith(
              color: paused ? ts.colors.primary : ts.colors.onSurfaceMuted,
            ),
          ),
        ],
      ],
    );
    return Semantics(
      image: true,
      label: brand ? '一刻表盘' : [digits, caption].nonNulls.join('，'),
      child: ExcludeSemantics(
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              for (final entry in ts.artworkThemes.entries)
                Opacity(
                  opacity: entry.value.clamp(0, 1),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: w,
                      height: w * entry.key.artworkAspectRatio,
                      child: _DialArtwork(
                        tokens: entry.key,
                        progress: p,
                        paused: paused,
                        resting: resting,
                        countdown: widget.countdown,
                        beat: widget.beat,
                        wavePhase: widget.wavePhase,
                      ),
                    ),
                  ),
                ),
              if (!brand)
                Positioned.fill(
                  top: theme == 'sundial'
                      ? w * YikeGeometry.sundialReadoutTop
                      : 0,
                  child: Align(
                    alignment: Alignment(
                      0,
                      theme == 'water'
                          ? YikeGeometry.waterReadoutY * 2 - 1
                          : theme == 'sundial'
                          ? 0
                          : 0,
                    ),
                    child: FractionallySizedBox(
                      widthFactor: theme == 'water'
                          ? YikeGeometry.waterReadoutWidth
                          : YikeGeometry.readoutWidth,
                      child: readout(false),
                    ),
                  ),
                ),
              if (!brand && theme == 'water')
                ClipPath(
                  key: const ValueKey('water-submerged-readout'),
                  clipper: _Submerged(p),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(
                        top: theme == 'sundial'
                            ? w * YikeGeometry.sundialReadoutTop
                            : 0,
                        child: Align(
                          alignment: Alignment(
                            0,
                            theme == 'water'
                                ? YikeGeometry.waterReadoutY * 2 - 1
                                : theme == 'sundial'
                                ? 0
                                : 0,
                          ),
                          child: FractionallySizedBox(
                            widthFactor: theme == 'water'
                                ? YikeGeometry.waterReadoutWidth
                                : YikeGeometry.readoutWidth,
                            child: readout(true),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialArtwork extends StatelessWidget {
  const _DialArtwork({
    required this.tokens,
    required this.progress,
    required this.paused,
    required this.resting,
    required this.countdown,
    required this.beat,
    required this.wavePhase,
  });
  final TS tokens;
  final double progress;
  final bool paused, resting, countdown;
  final double beat, wavePhase;
  @override
  Widget build(BuildContext context) {
    final ts = tokens;
    final theme = ts.pack.id.split('/').last;
    final original =
        yikeArtwork['yike/$theme-${ts.isDark ? 'dark' : 'light'}']!;
    final art = countdown && original.session != null
        ? yikeArtwork[original.session]!
        : original;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth, h = constraints.maxHeight;
        Widget raster(String path, {double? height}) => Image.asset(
          path,
          width: w,
          height: height ?? h,
          fit: BoxFit.fill,
          gaplessPlayback: true,
          excludeFromSemantics: true,
          filterQuality: FilterQuality.medium,
        );
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: theme == 'mechanical' ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: theme == 'mechanical'
                ? null
                : BorderRadius.circular(
                    theme == 'water' ? ts.radius.full : ts.radius.xs,
                  ),
            boxShadow: ts.effect.artworkShadow,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (theme == 'mechanical') ...[
                raster(art.file),
                ClipPath(
                  clipper: _DialSector(progress, ring: true),
                  child: raster(
                    art.layers[resting
                        ? 'rest'
                        : paused
                        ? 'paused'
                        : 'progress']!,
                  ),
                ),
                CustomPaint(
                  painter: _MechanicalFace(
                    progress,
                    ts,
                    resting: resting,
                    paused: paused,
                    beat: beat,
                  ),
                ),
              ] else if (theme == 'water')
                ClipPath(
                  clipper: _WaterBody(),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: ts.colors.surface),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: progress,
                          widthFactor: 1,
                          child: raster(
                            resting ? art.layers['rest']! : art.file,
                          ),
                        ),
                      ),
                      if (!paused && progress > 0 && progress < 1)
                        Positioned(
                          left: -w * YikeMotion.waveTravel,
                          right: -w * YikeMotion.waveTravel,
                          top: h * (1 - progress) - ts.border.widthHairline,

                          child: Transform.translate(
                            offset: Offset(
                              math.sin(wavePhase * 2 * math.pi) *
                                  w *
                                  YikeMotion.waveTravel,
                              0,
                            ),
                            child: Image.asset(
                              art.layers['wave']!,
                              height: ts.spacing.xs * (1 + beat),
                              fit: BoxFit.fill,
                              excludeFromSemantics: true,
                            ),
                          ),
                        ),
                      if (beat > 0 && progress > 0 && progress < 1)
                        CustomPaint(painter: _WaterRipple(progress, beat, ts)),
                      raster(art.layers['glass']!),
                    ],
                  ),
                )
              else ...[
                raster(art.file),
                // The shadow viewBox is square (316 x 316), independent of the
                // 316 x 404 face. Keep its circular gradient in that coordinate space.
                Positioned(
                  left: w * YikeGeometry.sundialShadowInset,
                  top: w * YikeGeometry.sundialShadowInset,
                  width: w * YikeGeometry.sundialShadowScale,
                  height: w * YikeGeometry.sundialShadowScale,
                  child: Opacity(
                    opacity: 1 - beat * YikeMotion.shadowBreath,
                    child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (rect) => SweepGradient(
                        startAngle: 0,
                        endAngle: 2 * math.pi,
                        colors: const [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                          Colors.transparent,
                        ],
                        stops: [
                          0,
                          (progress - .045).clamp(0, 1),
                          progress.clamp(0, 1),
                          1,
                        ],
                        transform: const GradientRotation(-math.pi / 2),
                      ).createShader(rect),
                      child: raster(
                        art.layers['shadow']!,
                        height: w * YikeGeometry.sundialShadowScale,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DialSector extends CustomClipper<Path> {
  const _DialSector(this.progress, {this.ring = false});
  final double progress;
  final bool ring;
  @override
  Path getClip(Size size) {
    final center = Offset(size.width / 2, size.height * .5);
    final radius = size.width * YikeGeometry.mechanicalOuter;
    final outer = Rect.fromCircle(center: center, radius: radius);
    // arcTo normalizes a complete turn to an empty arc. Keep both endpoints
    // explicit so full countdowns and exact stopwatch hours remain visible.
    if (progress <= 0) return Path();
    if (progress >= 1) {
      final full = Path()..addOval(outer);
      if (!ring) return full;
      return Path.combine(
        PathOperation.difference,
        full,
        Path()..addOval(
          Rect.fromCircle(
            center: center,
            radius: size.width * YikeGeometry.mechanicalInner,
          ),
        ),
      );
    }
    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(outer, -math.pi / 2, math.pi * 2 * progress, false)
      ..close();
    return ring
        ? Path.combine(
            PathOperation.difference,
            path,
            Path()..addOval(
              Rect.fromCircle(
                center: center,
                radius: size.width * YikeGeometry.mechanicalInner,
              ),
            ),
          )
        : path;
  }

  @override
  bool shouldReclip(_DialSector old) =>
      old.progress != progress || old.ring != ring;
}

class _WaterBody extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..addRRect(
      RRect.fromRectAndCorners(
        Offset.zero & size,
        topLeft: Radius.circular(size.width * YikeGeometry.waterTopRadius),
        topRight: Radius.circular(size.width * YikeGeometry.waterTopRadius),
        bottomLeft: Radius.circular(
          size.width * YikeGeometry.waterBottomRadius,
        ),
        bottomRight: Radius.circular(
          size.width * YikeGeometry.waterBottomRadius,
        ),
      ),
    );
  @override
  bool shouldReclip(_WaterBody old) => false;
}

class _MechanicalFace extends CustomPainter {
  const _MechanicalFace(
    this.progress,
    this.ts, {
    required this.resting,
    required this.paused,
    required this.beat,
  });
  final double progress, beat;
  final TS ts;
  final bool resting, paused;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final ink = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = ts.border.widthHairline
      ..color = ts.colors.onSurfaceMuted;
    canvas.drawCircle(c, size.width * YikeGeometry.mechanicalInner, ink);
    final angle = progress * math.pi * 2 - math.pi / 2;
    final r = size.width * YikeGeometry.mechanicalPointer;
    final point = c + Offset(math.cos(angle), math.sin(angle)) * r;
    ink
      ..color = resting ? ts.colors.onSurfaceMuted : ts.colors.primary
      ..strokeWidth = ts.border.widthStrong;
    final inner =
        c + Offset(math.cos(angle), math.sin(angle)) * (r - ts.spacing.sm);
    canvas.drawLine(inner, point, ink);
    canvas.drawCircle(
      point,
      ts.spacing.xsPlus * (1 + beat),
      Paint()..color = ts.colors.primary,
    );
    canvas.drawCircle(
      point,
      ts.spacing.xxs,
      Paint()..color = ts.colors.surface,
    );
  }

  @override
  bool shouldRepaint(_MechanicalFace old) =>
      old.progress != progress ||
      old.ts != ts ||
      old.resting != resting ||
      old.paused != paused ||
      old.beat != beat;
}

class _Submerged extends CustomClipper<Path> {
  const _Submerged(this.progress);
  final double progress;
  @override
  Path getClip(Size size) => Path.combine(
    PathOperation.intersect,
    _WaterBody().getClip(size),
    Path()..addRect(
      Rect.fromLTRB(0, size.height * (1 - progress), size.width, size.height),
    ),
  );
  @override
  bool shouldReclip(_Submerged old) => old.progress != progress;
}

class _WaterRipple extends CustomPainter {
  const _WaterRipple(this.progress, this.beat, this.ts);
  final double progress, beat;
  final TS ts;
  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width * YikeMotion.rippleRadius * (1 - beat);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * (1 - progress)),
        width: radius * 2,
        height: radius / 3,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ts.border.widthHairline
        ..color = ts.colors.onPrimary.withValues(alpha: beat),
    );
  }

  @override
  bool shouldRepaint(_WaterRipple old) =>
      old.progress != progress || old.beat != beat || old.ts != ts;
}
