import 'package:flutter/material.dart';
import '../../theme/yike_motion.dart';

/// Shared by both readouts; recreated only when font or text scaling changes.
class DigitMetrics {
  DigitMetrics(
    this.style,
    this.scaler, {
    this.direction = TextDirection.ltr,
    this.locale,
  }) {
    for (final character in '0123456789:'.split('')) {
      final painter = TextPainter(
        text: TextSpan(text: character, style: style),
        textDirection: direction,
        textScaler: scaler,
        locale: locale,
      )..layout();
      if (character == ':') {
        colonWidth = painter.width.ceilToDouble();
      } else if (painter.width > digitWidth) {
        digitWidth = painter.width.ceilToDouble();
      }
      if (painter.height > height) height = painter.height.ceilToDouble();
      painter.dispose();
    }
  }
  final TextStyle style;
  final TextScaler scaler;
  final TextDirection direction;
  final Locale? locale;

  static TextStyle resolveStyle(BuildContext context, TextStyle style) {
    final resolved = DefaultTextStyle.of(context).style.merge(style);
    return resolved.copyWith(
      inherit: false,
      fontWeight: MediaQuery.boldTextOf(context)
          ? FontWeight.bold
          : resolved.fontWeight,
    );
  }

  double digitWidth = 0, colonWidth = 0, height = 0;
  double width(String character) => character == ':' ? colonWidth : digitWidth;
}

/// Both water readouts consume the same metrics, previous value and phase.
class RollingDigits extends StatelessWidget {
  const RollingDigits({
    super.key,
    required this.value,
    required this.previous,
    required this.phase,
    required this.style,
    required this.descending,
    required this.metrics,
    this.inverse = false,
    this.travel = YikeMotion.digitTravel,
  });
  final String value, previous;
  final double phase;
  final TextStyle style;
  final bool descending, inverse;
  final DigitMetrics metrics;
  final double travel;

  @override
  Widget build(BuildContext context) {
    Widget text(String value) => Center(
      child: RichText(
        text: TextSpan(
          text: value,
          style: metrics.style.copyWith(color: style.color),
        ),
        textScaler: metrics.scaler,
        textDirection: metrics.direction,
        locale: metrics.locale,
        maxLines: 1,
        softWrap: false,
      ),
    );
    final width = value
        .split('')
        .fold<double>(0, (sum, c) => sum + metrics.width(c));
    final rolling = phase < 1 && value.length == previous.length;
    final direction = descending ? -1.0 : 1.0;
    return SizedBox(
      width: width,
      height: metrics.height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < value.length; i++)
            SizedBox(
              width: metrics.width(value[i]),
              height: metrics.height,
              child: !rolling || value[i] == previous[i]
                  ? text(value[i])
                  : ClipRect(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Transform.translate(
                            offset: Offset(
                              0,
                              -direction * phase * metrics.height * travel,
                            ),
                            child: Opacity(
                              opacity: 1 - phase,
                              child: text(previous[i]),
                            ),
                          ),
                          Transform.translate(
                            offset: Offset(
                              0,
                              direction * (1 - phase) * metrics.height * travel,
                            ),
                            child: Opacity(
                              opacity: phase,
                              child: text(value[i]),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
