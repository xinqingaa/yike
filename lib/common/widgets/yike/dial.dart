import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../theme/ts.dart';
import '../../../theme/yike_motion.dart';
import '../../motion/motion_activity.dart';
import '../../motion/rolling_digits.dart';
import '../../motion/dial_frame.dart';
import '../../motion/content_transition.dart';
import '../../../theme/yike_artwork.dart';
import '../../../theme/yike_geometry.dart';

/// Local presentation only; supplied progress never settles business time.
class YikeDial extends StatefulWidget {
  const YikeDial({
    super.key,
    this.digits,
    this.caption,
    this.hint,
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
    this.frame,
  });
  final String? digits, caption, hint;
  final double progress;
  final bool paused, resting, completed, countdown, brand;
  final double? width;
  final TS? tokens;
  final bool animateDigits, descending;
  final Object? digitIdentity;
  final double beat, wavePhase;
  final ValueListenable<DialFrame>? frame;
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
  DigitMetrics? _metrics;
  TextStyle? _metricsStyle;
  TextScaler? _metricsScaler;
  Locale? _metricsLocale;
  TextDirection? _metricsDirection;
  late final ValueNotifier<DialFrame> _staticFrame = ValueNotifier(
    const DialFrame(progress: 0),
  );
  @override
  void initState() {
    super.initState();
    _roll.value = 1;
  }

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
    _staticFrame.dispose();
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
    final w = widget.width ?? ts.sizing.plot;
    final h = w * ts.artworkAspectRatio;
    _staticFrame.value = DialFrame(
      progress: widget.progress.clamp(0.0, 1.0),
      secondBeat: widget.beat,
      wavePhase: widget.wavePhase,
    );
    final frame = widget.frame ?? _staticFrame;
    final digitTravel = ts.artworkThemes.entries.fold<double>(
      0,
      (travel, entry) =>
          travel + entry.value * YikeMotion.digitTravelFor(entry.key.pack.id),
    );
    final style = DigitMetrics.resolveStyle(
      context,
      ts.textStyle.numericDisplay,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final locale = Localizations.maybeLocaleOf(context);
    final direction = Directionality.of(context);
    final metricStyle = TextStyle(
      fontFamily: style.fontFamily,
      fontFamilyFallback: style.fontFamilyFallback,
      fontSize: style.fontSize,
      fontWeight: style.fontWeight,
      fontStyle: style.fontStyle,
      letterSpacing: style.letterSpacing,
      wordSpacing: style.wordSpacing,
      height: style.height,
      fontFeatures: style.fontFeatures,
      fontVariations: style.fontVariations,
      leadingDistribution: style.leadingDistribution,
      textBaseline: style.textBaseline,
    );
    if (_metricsStyle != metricStyle ||
        _metricsScaler != scaler ||
        _metricsLocale != locale ||
        _metricsDirection != direction) {
      _metricsStyle = metricStyle;
      _metricsScaler = scaler;
      _metricsLocale = locale;
      _metricsDirection = direction;
      _metrics = DigitMetrics(
        style,
        scaler,
        locale: locale,
        direction: direction,
      );
    }
    // Blend geometry using the same weights as the artwork, rather than
    // switching positions when the theme identity crosses its midpoint.
    var readoutY = 0.0, captionY = 0.0;
    final readoutWidth = ts.artworkThemes.entries.fold<double>(
      0,
      (width, entry) =>
          width +
          entry.value *
              (entry.key.pack.id.endsWith('water')
                  ? YikeGeometry.waterReadoutWidth
                  : YikeGeometry.readoutWidth),
    );
    final naturalWidth = (digits ?? '')
        .split('')
        .fold<double>(0, (width, c) => width + _metrics!.width(c));
    final digitHeight =
        _metrics!.height *
        (naturalWidth == 0 ? 1 : math.min(1, w * readoutWidth / naturalWidth));
    final captionStyle = ts.textStyle.caption.copyWith(
      color: paused ? ts.colors.primary : ts.colors.onSurface,
      fontWeight: FontWeight.w500,
    );
    final captionPainter = TextPainter(
      text: TextSpan(
        text: caption ?? '',
        style: DigitMetrics.resolveStyle(context, captionStyle),
      ),
      textDirection: direction,
      textScaler: scaler,
      locale: locale,
    )..layout(maxWidth: w);
    final captionHeight = captionPainter.height;
    captionPainter.dispose();
    for (final entry in ts.artworkThemes.entries) {
      final kind = entry.key.pack.id.split('/').last;
      final water = kind == 'water';
      final inset = kind == 'sundial'
          ? w * YikeGeometry.sundialReadoutTop
          : 0.0;
      final gap = water ? ts.spacing.lg : ts.spacing.xs;
      final groupHeight =
          digitHeight + (caption == null ? 0 : captionHeight + gap);
      final top =
          inset +
          (h - inset - groupHeight) * (water ? YikeGeometry.waterReadoutY : .5);
      readoutY +=
          entry.value *
          (top + (water && caption != null ? captionHeight + gap : 0));
      captionY += entry.value * (water ? top : top + digitHeight + gap);
    }
    Widget readout(bool inverse) => Stack(
      fit: StackFit.expand,
      children: [
        if (digits != null)
          Positioned(
            top: readoutY,
            left: w * (1 - readoutWidth) / 2,
            width: w * readoutWidth,
            height: digitHeight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedBuilder(
                animation: _roll,
                builder: (context, _) => RollingDigits(
                  value: digits,
                  previous: _previous ?? digits,
                  phase: _roll.value,
                  descending: widget.descending,
                  inverse: inverse,
                  travel: digitTravel,
                  metrics: _metrics!,
                  style: style.copyWith(
                    color: inverse
                        ? ts.colors.primary
                        : completed && !resting
                        ? ts.colors.primary
                        : ts.colors.onSurface,
                  ),
                ),
              ),
            ),
          ),
        if (caption != null && !inverse)
          Positioned(
            top: captionY,
            left: 0,
            right: 0,
            child: MotionContent(
              identity: caption,
              resize: false,
              child: Text(
                caption,
                textAlign: TextAlign.center,
                style: captionStyle,
              ),
            ),
          ),
        if (widget.hint != null && !inverse)
          Positioned(
            top: captionY + captionHeight + ts.spacing.xs,
            left: 0,
            right: 0,
            child: Text(
              widget.hint!,
              textAlign: TextAlign.center,
              style: ts.textStyle.caption.copyWith(
                color: ts.colors.onSurfaceMuted.withValues(alpha: .45),
              ),
            ),
          ),
      ],
    );
    final waterWeight = ts.artworkThemes.entries
        .where((e) => e.key.pack.id.endsWith('water'))
        .fold<double>(0, (v, e) => v + e.value);
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
                      child: RepaintBoundary(
                        child: _DialArtwork(
                          tokens: entry.key,
                          frame: frame,
                          paused: paused,
                          resting: resting,
                          countdown: widget.countdown,
                        ),
                      ),
                    ),
                  ),
                ),
              if (!brand) readout(false),
              if (!brand && waterWeight > 0)
                Opacity(
                  opacity: waterWeight.clamp(0, 1),
                  child: ClipPath(
                    key: const ValueKey('water-submerged-readout'),
                    clipper: _Submerged(
                      frame,
                      height:
                          w *
                          ts.artworkThemes.keys
                              .firstWhere(
                                (tokens) => tokens.pack.id.endsWith('water'),
                              )
                              .artworkAspectRatio,
                    ),
                    child: readout(true),
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
    required this.frame,
    required this.paused,
    required this.resting,
    required this.countdown,
  });
  final TS tokens;
  final ValueListenable<DialFrame> frame;
  final bool paused, resting, countdown;
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
        Widget raster(String path, {double? height}) => RepaintBoundary(
          child: Image.asset(
            path,
            width: w,
            height: height ?? h,
            fit: BoxFit.fill,
            gaplessPlayback: true,
            excludeFromSemantics: true,
            filterQuality: FilterQuality.medium,
          ),
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
                  clipper: _DialSector(frame, ring: true),
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
                    frame,
                    ts,
                    resting: resting,
                    paused: paused,
                  ),
                ),
              ] else if (theme == 'water')
                ClipPath(
                  clipper: _WaterBody(),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: ts.colors.surface),
                      ClipPath(
                        key: const ValueKey('water-fill'),
                        clipper: _Submerged(frame),
                        child: raster(resting ? art.layers['rest']! : art.file),
                      ),
                      if (!paused)
                        AnimatedBuilder(
                          animation: frame,
                          child: Image.asset(
                            art.layers['wave']!,
                            fit: BoxFit.fill,
                            excludeFromSemantics: true,
                          ),
                          builder: (context, child) {
                            final f = frame.value;
                            if (f.progress <= 0 || f.progress >= 1) {
                              return const SizedBox.shrink();
                            }
                            return Positioned(
                              left: -w * YikeMotion.waveTravel,
                              right: -w * YikeMotion.waveTravel,
                              top:
                                  h * (1 - f.progress) -
                                  ts.border.widthHairline,
                              height: ts.spacing.xs * (1 + f.secondBeat),
                              child: Transform.translate(
                                offset: Offset(
                                  math.sin(f.wavePhase * 2 * math.pi) *
                                      w *
                                      YikeMotion.waveTravel,
                                  0,
                                ),
                                child: child,
                              ),
                            );
                          },
                        ),
                      CustomPaint(painter: _WaterRipple(frame, ts)),
                      raster(art.layers['glass']!),
                    ],
                  ),
                )
              else ...[
                raster(art.file),
                Positioned(
                  left: w * YikeGeometry.sundialShadowInset,
                  top: w * YikeGeometry.sundialShadowInset,
                  width: w * YikeGeometry.sundialShadowScale,
                  height: w * YikeGeometry.sundialShadowScale,
                  child: AnimatedBuilder(
                    animation: frame,
                    child: raster(
                      art.layers['shadow']!,
                      height: w * YikeGeometry.sundialShadowScale,
                    ),
                    builder: (context, child) {
                      final f = frame.value;
                      return Opacity(
                        opacity: 1 - f.beat * YikeMotion.shadowBreath,
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
                              (f.progress - .045).clamp(0, 1),
                              f.progress.clamp(0, 1),
                              1,
                            ],
                            transform: const GradientRotation(-math.pi / 2),
                          ).createShader(rect),
                          child: child,
                        ),
                      );
                    },
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
  _DialSector(this.frame, {this.ring = false}) : super(reclip: frame);
  final ValueListenable<DialFrame> frame;
  double get progress => frame.value.progress;
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
  bool shouldReclip(_DialSector old) => old.frame != frame || old.ring != ring;
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
  _MechanicalFace(
    this.frame,
    this.ts, {
    required this.resting,
    required this.paused,
  }) : super(repaint: frame);
  final ValueListenable<DialFrame> frame;
  double get progress => frame.value.progress;
  double get beat => frame.value.beat;
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
      old.frame != frame ||
      old.ts != ts ||
      old.resting != resting ||
      old.paused != paused ||
      old.beat != beat;
}

class _Submerged extends CustomClipper<Path> {
  _Submerged(this.frame, {this.height}) : super(reclip: frame);
  final ValueListenable<DialFrame> frame;
  final double? height;
  double get progress => frame.value.progress;
  @override
  Path getClip(Size size) {
    final body = Size(size.width, height ?? size.height);
    return Path.combine(
      PathOperation.intersect,
      _WaterBody().getClip(body),
      Path()..addRect(
        Rect.fromLTRB(0, body.height * (1 - progress), body.width, body.height),
      ),
    );
  }

  @override
  bool shouldReclip(_Submerged old) =>
      old.frame != frame || old.height != height;
}

class _WaterRipple extends CustomPainter {
  _WaterRipple(this.frame, this.ts) : super(repaint: frame);
  final ValueListenable<DialFrame> frame;
  double get progress => frame.value.progress;
  double get beat => frame.value.minuteBeat;
  final TS ts;
  @override
  void paint(Canvas canvas, Size size) {
    if (beat <= 0 || progress <= 0 || progress >= 1) return;
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
  bool shouldRepaint(_WaterRipple old) => old.frame != frame || old.ts != ts;
}
