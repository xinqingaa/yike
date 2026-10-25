import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Derives platform inputs from the user-selected root logo.png.
/// The original is retained; the pale presentation tile is not an icon layer.
void main() {
  final source = img.decodePng(File('logo.png').readAsBytesSync());
  if (source == null) throw StateError('logo.png must be a valid PNG');
  final mark = img.Image(
    width: source.width,
    height: source.height,
    numChannels: 4,
  );
  var left = source.width, top = source.height, right = 0, bottom = 0;
  bool isMark(img.Pixel p) => math.min(p.r, math.min(p.g, p.b)) < 180;
  for (final pixel in source) {
    final x = pixel.x, y = pixel.y;
    double alpha = 0;
    var r = pixel.r.toDouble();
    var g = pixel.g.toDouble();
    var b = pixel.b.toDouble();
    if (isMark(pixel)) {
      alpha = 1;
    } else {
      // Recover only the antialiased edge adjacent to the mark. The original
      // paper tile and its surrounding white margin remain transparent.
      img.Pixel? nearest;
      var distance = 99;
      for (var dy = -2; dy <= 2; dy++) {
        for (var dx = -2; dx <= 2; dx++) {
          final nx = x + dx, ny = y + dy;
          final d = dx * dx + dy * dy;
          if (nx < 0 || ny < 0 || nx >= source.width || ny >= source.height) {
            continue;
          }
          final candidate = source.getPixel(nx, ny);
          if (d < distance && isMark(candidate)) {
            nearest = candidate;
            distance = d;
          }
        }
      }
      if (nearest != null) {
        const background = [232.0, 236.0, 232.0];
        final observed = [r, g, b];
        final foreground = [
          nearest.r.toDouble(),
          nearest.g.toDouble(),
          nearest.b.toDouble(),
        ];
        double numerator = 0, denominator = 0;
        for (var channel = 0; channel < 3; channel++) {
          final delta = foreground[channel] - background[channel];
          numerator += (observed[channel] - background[channel]) * delta;
          denominator += delta * delta;
        }
        alpha = (numerator / denominator).clamp(0.0, 1.0);
        if (alpha < .03) alpha = 0;
        if (alpha > 0) {
          r = ((r - (1 - alpha) * background[0]) / alpha).clamp(0, 255);
          g = ((g - (1 - alpha) * background[1]) / alpha).clamp(0, 255);
          b = ((b - (1 - alpha) * background[2]) / alpha).clamp(0, 255);
        }
      }
    }
    if (alpha == 0) continue;
    mark.setPixelRgba(
      x,
      y,
      r.round(),
      g.round(),
      b.round(),
      (alpha * 255).round(),
    );
    left = math.min(left, x);
    top = math.min(top, y);
    right = math.max(right, x);
    bottom = math.max(bottom, y);
  }
  if (right <= left || bottom <= top) {
    throw StateError('No logo silhouette found in logo.png');
  }
  final cropped = img.copyCrop(
    mark,
    x: left,
    y: top,
    width: right - left + 1,
    height: bottom - top + 1,
  );
  final dark = img.Image.from(cropped);
  final mono = img.Image.from(cropped);
  for (final pixel in dark) {
    if (pixel.a == 0 || pixel.r - pixel.g > 12) continue;
    pixel
      ..r = 218 + pixel.r * .12
      ..g = 224 + pixel.g * .10
      ..b = 220 + pixel.b * .10;
  }
  for (final pixel in mono) {
    pixel
      ..r = 255
      ..g = 255
      ..b = 255;
  }
  final directory = Directory('asset/yike/brand')..createSync(recursive: true);
  void save(String name, img.Image image) => File(
    '${directory.path}/$name.png',
  ).writeAsBytesSync(img.encodePng(image));
  img.Image compose(
    img.Image glyph,
    int size,
    double fraction, {
    img.Color? background,
  }) {
    final canvas = img.Image(width: size, height: size, numChannels: 4);
    if (background != null) img.fill(canvas, color: background);
    final width = (size * fraction).round();
    final resized = img.copyResize(
      glyph,
      width: width,
      interpolation: img.Interpolation.cubic,
    );
    return img.compositeImage(
      canvas,
      resized,
      dstX: (size - resized.width) ~/ 2,
      dstY: (size - resized.height) ~/ 2,
    );
  }

  save('mark', compose(cropped, 768, .80));
  save('mark-dark', compose(dark, 768, .80));
  save(
    'icon',
    compose(cropped, 1024, .77, background: img.ColorRgb8(232, 236, 232)),
  );
  save('icon-dark', compose(dark, 1024, .77));
  save(
    'icon-tinted',
    compose(mono, 1024, .77, background: img.ColorRgb8(0, 0, 0)),
  );
  save('adaptive-foreground', compose(cropped, 1024, .46));
  save('adaptive-monochrome', compose(mono, 1024, .46));
  save('splash', compose(cropped, 768, .75));
  save('splash-dark', compose(dark, 768, .75));
  save('splash-android12', compose(cropped, 1152, .50));
  save('splash-android12-dark', compose(dark, 1152, .50));
  stdout.writeln('Prepared 11 brand inputs from logo.png; original preserved.');
}
