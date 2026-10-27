import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/accessibility/reduce_transparency.dart';
import '../storage/app_prefs.dart';
import '../storage/providers.dart';
import '../theme/ts.dart';
import '../theme/app_metrics.dart';
import 'app.dart';
import '../common/system_surfaces/surface_adapter.dart';

/// Initializes the app once. Route changes and foreground resumes keep it ready.
class AppStartup extends StatelessWidget {
  const AppStartup({super.key, required this.openPreferences});
  final Future<AppPrefs> Function() openPreferences;
  @override
  Widget build(BuildContext context) =>
      ProviderScope(child: _StartupBody(openPreferences: openPreferences));
}

class _StartupBody extends ConsumerStatefulWidget {
  const _StartupBody({required this.openPreferences});
  final Future<AppPrefs> Function() openPreferences;
  @override
  ConsumerState<_StartupBody> createState() => _StartupBodyState();
}

class _StartupBodyState extends ConsumerState<_StartupBody> {
  bool _holdingFirstFrame = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.deferFirstFrame();
    ReduceTransparency.start();
  }

  void _releaseFirstFrame() {
    if (!_holdingFirstFrame) return;
    _holdingFirstFrame = false;
    WidgetsBinding.instance.allowFirstFrame();
  }

  @override
  void dispose() {
    _releaseFirstFrame();
    super.dispose();
  }

  late final _preferencesProvider = FutureProvider.autoDispose<AppPrefs>((
    ref,
  ) async {
    try {
      return await widget.openPreferences();
    } catch (_) {
      // Surface cleanup must not delay the original storage error UI.
      unawaited(NativeSystemSurfaceAdapter().clear().catchError((Object _) {}));
      rethrow;
    }
  }, retry: (retryCount, error) => null);

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(_preferencesProvider);
    if (snapshot.hasValue || snapshot.hasError) {
      // Build the themed home or the retry UI before taking down native splash.
      WidgetsBinding.instance.addPostFrameCallback((_) => _releaseFirstFrame());
    }
    if (snapshot.hasValue) {
      return ProviderScope(
        overrides: [appPrefsProvider.overrideWithValue(snapshot.requireValue)],
        child: const PbApp(),
      );
    }
    return AppViewport(
      builder: (context, metrics) {
        final ts = TS(
          brightness: MediaQuery.platformBrightnessOf(context),
          metrics: metrics,
          pack: generatedThemePacks.firstWhere(
            (pack) => pack.id == 'yike/mechanical',
          ),
        );
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ts.toThemeData(),
          home: AnnotatedRegion<SystemUiOverlayStyle>(
            value: ts.systemOverlayStyle,
            child: Scaffold(
              body: snapshot.hasError && !snapshot.isLoading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            snapshot.error is PrefsOpenException &&
                                    (snapshot.error as PrefsOpenException)
                                            .failure ==
                                        PrefsOpenFailure.damaged
                                ? '本机存储文件损坏，原文件已保留，请检查后重试'
                                : '本机存储暂不可用，请重试',
                          ),
                          TextButton(
                            onPressed: () =>
                                ref.invalidate(_preferencesProvider),
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }
}
