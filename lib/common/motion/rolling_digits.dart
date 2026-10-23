import 'package:flutter/material.dart';
import '../../theme/yike_motion.dart';

/// Both water readouts consume the same previous value and animation phase.
class RollingDigits extends StatelessWidget {
  const RollingDigits({
    super.key,
    required this.value,
    required this.previous,
    required this.phase,
    required this.style,
    required this.descending,
    this.inverse = false,
  });
  final String value, previous;
  final double phase;
  final TextStyle style;
  final bool descending, inverse;

  @override
  Widget build(BuildContext context) {
    Widget text(String value) => inverse
        ? RichText(
            text: TextSpan(text: value, style: style),
            textScaler: MediaQuery.textScalerOf(context),
          )
        : Text(value, maxLines: 1, style: style);
    final base = text(value);
    if (phase >= 1 || value.length != previous.length) return base;
    final scaler = MediaQuery.textScalerOf(context);
    Size measure(String character) {
      final painter = TextPainter(
        text: TextSpan(text: character, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      final size = painter.size;
      painter.dispose();
      return size;
    }

    final height = measure('0').height;
    final direction = descending ? -1.0 : 1.0;
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(opacity: 0, child: base),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < value.length; i++)
              SizedBox(
                width: measure(value[i]).width,
                height: height,
                child: value[i] == previous[i]
                    ? text(value[i])
                    : ClipRect(
                        child: Stack(
                          children: [
                            Transform.translate(
                              offset: Offset(
                                0,
                                -direction *
                                    phase *
                                    height *
                                    YikeMotion.digitTravel,
                              ),
                              child: Opacity(
                                opacity: 1 - phase,
                                child: text(previous[i]),
                              ),
                            ),
                            Transform.translate(
                              offset: Offset(
                                0,
                                direction *
                                    (1 - phase) *
                                    height *
                                    YikeMotion.digitTravel,
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
      ],
    );
  }
}
