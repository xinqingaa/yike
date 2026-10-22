import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/launch/pages/launch_page.dart';
import '../storage/app_prefs.dart';
import '../storage/providers.dart';
import '../theme/ts.dart';
import '../theme/app_metrics.dart';
import 'app.dart';

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
  late final _preferencesProvider = FutureProvider.autoDispose<AppPrefs>(
    (ref) => Future.sync(widget.openPreferences),
  );

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(_preferencesProvider);
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
                          const Text('应用准备失败，请重试'),
                          TextButton(
                            onPressed: () =>
                                ref.invalidate(_preferencesProvider),
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    )
                  : const YikeLaunchPage(),
            ),
          ),
        );
      },
    );
  }
}
