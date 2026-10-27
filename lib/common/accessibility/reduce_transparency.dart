import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// iOS exposes Reduce Transparency separately from Flutter's high contrast flag.
abstract final class ReduceTransparency {
  static const _channel = MethodChannel('yike/accessibility');
  static final ValueNotifier<bool> enabled = ValueNotifier(false);
  static bool _started = false;

  static void start() {
    if (_started || kIsWeb || !Platform.isIOS) return;
    _started = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'reduceTransparencyChanged' &&
          call.arguments is bool) {
        enabled.value = call.arguments as bool;
      }
    });
    unawaited(refresh());
  }

  static Future<void> refresh() async {
    if (!_started) return;
    try {
      enabled.value =
          await _channel.invokeMethod<bool>('reduceTransparency') ?? false;
    } on PlatformException {
      // The material remains usable if the native preference is unavailable.
    } on MissingPluginException {
      // Widget tests and unsupported hosts have no iOS bridge.
    }
  }
}
