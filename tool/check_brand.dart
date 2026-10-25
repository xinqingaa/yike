import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

void main() {
  void require(bool condition, String message) {
    if (!condition) throw StateError(message);
  }

  var checked = 0;
  for (final catalog in [
    'AppIcon.appiconset',
    'LaunchImage.imageset',
    'LaunchBackground.imageset',
  ]) {
    final directory = 'ios/Runner/Assets.xcassets/$catalog';
    final manifest =
        jsonDecode(File('$directory/Contents.json').readAsStringSync())
            as Map<String, dynamic>;
    for (final item in manifest['images'] as List<dynamic>) {
      final entry = item as Map<String, dynamic>;
      final filename = entry['filename'] as String;
      final image = img.decodePng(
        File('$directory/$filename').readAsBytesSync(),
      );
      require(image != null, 'Invalid PNG: $filename');
      checked++;
      if (catalog != 'AppIcon.appiconset') continue;
      final size = (entry['size'] as String)
          .split('x')
          .map(double.parse)
          .toList();
      final scale = double.parse(
        (entry['scale'] as String).replaceAll('x', ''),
      );
      require(
        image!.width == (size[0] * scale).round() &&
            image.height == (size[1] * scale).round(),
        'Wrong icon size: $filename',
      );
      if (entry['appearances'] == null) {
        require(
          image.every((p) => p.a == 255),
          'iOS icon has alpha: $filename',
        );
      }
    }
  }

  for (final entry in <String, double>{
    'adaptive-foreground': 1024 * 33 / 108,
    'adaptive-monochrome': 1024 * 33 / 108,
    'splash-android12': 384,
    'splash-android12-dark': 384,
  }.entries) {
    final image = img.decodePng(
      File('asset/yike/brand/${entry.key}.png').readAsBytesSync(),
    )!;
    var radius = 0.0;
    for (final pixel in image) {
      if (pixel.a < 8) continue;
      final dx = pixel.x + .5 - image.width / 2;
      final dy = pixel.y + .5 - image.height / 2;
      radius = math.max(radius, math.sqrt(dx * dx + dy * dy));
    }
    require(radius <= entry.value, '${entry.key} exceeds circular safe zone');
    stdout.writeln(
      '${entry.key}: radius ${radius.toStringAsFixed(1)} / ${entry.value.toStringAsFixed(1)}',
    );
  }
  for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
    require(
      File(
        'android/app/src/main/res/mipmap-$density/ic_launcher.png',
      ).existsSync(),
      'Missing Android icon: $density',
    );
  }
  stdout.writeln(
    'Brand assets passed: $checked catalog images, iOS opacity, Android safe zones and densities.',
  );
}
