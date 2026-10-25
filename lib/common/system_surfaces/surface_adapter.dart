import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'surface_models.dart';

class NativeSystemSurfaceAdapter implements SystemSurfaceAdapter {
  static const channel = MethodChannel('yike/system_surfaces');
  @override
  Future<void> initialize(void Function(String) receive) async {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'open' && call.arguments is String) {
        receive(call.arguments as String);
      }
    });
    try {
      final initial = await channel.invokeListMethod<String>('launch');
      for (final raw in initial ?? const <String>[]) {
        receive(raw);
      }
    } on MissingPluginException {
      // Desktop and Widget tests have no platform surface extension.
    }
  }

  @override
  Future<SurfaceAccess> access() async {
    try {
      final result = await channel.invokeMapMethod<String, dynamic>('access');
      return SurfaceAccess(
        widgets: result?['widgets'] == true,
        activities: result?['activities'] == true,
        allowed: result?['allowed'] == true,
        shared: result?['shared'] == true,
      );
    } on MissingPluginException {
      return const SurfaceAccess();
    }
  }

  @override
  Future<void> publish(SurfaceSnapshot snapshot) async {
    try {
      await channel.invokeMethod<void>('publish', snapshot.encode());
    } on MissingPluginException {
      // Unsupported hosts do not pretend that a surface was published.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await channel.invokeMethod<void>('clear');
    } on MissingPluginException {
      /* unsupported host */
    }
  }

  @override
  Future<void> openSettings() => channel.invokeMethod<void>('settings');
  @override
  void dispose() => channel.setMethodCallHandler(null);
}

final systemSurfaceAdapterProvider = Provider<SystemSurfaceAdapter>(
  (ref) => NativeSystemSurfaceAdapter(),
);
