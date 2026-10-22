import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yike/theme/ts.dart';
import 'package:yike/theme/proto_bridge_tokens.dart';

Color cssColor(String raw) {
  final hex = raw.substring(1);
  final rgb = hex.length == 8 ? hex.substring(0, 6) : hex;
  final alpha = hex.length == 8 ? int.parse(hex.substring(6), radix: 16) : 255;
  return Color((alpha << 24) | int.parse(rgb, radix: 16));
}

void main() {
  test(
    'every exported theme/mode is registered and consumes resolved token values',
    () {
      final manifest =
          jsonDecode(File('proto-bridge.themes.json').readAsStringSync())
              as Map<String, dynamic>;
      final tables = manifest['tables'] as List;
      final exported = <String>{};
      for (final raw in tables) {
        final id = raw['identity'] as Map;
        final identity = '${id['packId']}/${id['theme']}';
        exported.add(identity);
        final pack = generatedThemePacks.singleWhere(
          (pack) => pack.id == identity,
        );
        final ts = TS(
          brightness: id['mode'] == 'dark' ? Brightness.dark : Brightness.light,
          pack: pack,
        );
        final values = raw['values'] as Map;
        final actual = protoBridgeTokenSnapshot(ts);
        expect(values.keys, containsAll(actual.keys));
        for (final entry in actual.entries) {
          final expected = values[entry.key];
          if (entry.value is Color &&
              expected is String &&
              expected.startsWith('#')) {
            expect(
              (entry.value as Color).toARGB32(),
              cssColor(expected).toARGB32(),
              reason: '$identity/${id['mode']}/${entry.key}',
            );
          } else if (entry.value is num && expected is num) {
            expect(
              entry.value,
              closeTo(expected.toDouble(), 0.000001),
              reason: '$identity/${entry.key}',
            );
          } else if (entry.value is TextStyle && expected is Map) {
            final rawSize = expected['size'];
            final size = rawSize is num
                ? rawSize.toDouble()
                : double.parse((rawSize as String).replaceAll('rem', '')) * 16;
            expect(
              (entry.value as TextStyle).fontSize,
              size,
              reason: '$identity/${entry.key}',
            );
          }
        }
        final captionTracking = values['tracking.caption'];
        final caption = ts.textStyle.caption;
        final expectedTracking = captionTracking is num
            ? captionTracking.toDouble()
            : double.parse((captionTracking as String).replaceAll('em', '')) *
                  caption.fontSize!;
        expect(
          caption.letterSpacing,
          closeTo(expectedTracking, 0.000001),
          reason: '$identity/caption tracking',
        );
        for (final asset in [
          ts.assets.brandMark,
          ts.assets.brandWordmark,
          ts.assets.launchImage,
          ts.assets.emptyIllustration,
        ]) {
          if (asset != null) expect(File(asset).existsSync(), isTrue);
        }
      }
      expect(generatedThemePacks.map((pack) => pack.id).toSet(), exported);
    },
  );
}
