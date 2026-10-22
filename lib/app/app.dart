import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unified_popups/unified_popups.dart';

import '../theme/ts.dart';
import 'local_data_boundary.dart';
import '../theme/app_metrics.dart';
import '../router/router.dart';

class PbApp extends ConsumerWidget {
  const PbApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final pack = ref.watch(themePackProvider);
    return AppViewport(
      builder: (context, metrics) {
        final theme = TS(
          brightness: Brightness.light,
          pack: pack,
          metrics: metrics,
        ).toThemeData();

        return MaterialApp(
          title: 'Yike',
          debugShowCheckedModeBanner: false,
          theme: theme,
          darkTheme: TS(
            brightness: Brightness.dark,
            pack: pack,
            metrics: metrics,
          ).toThemeData(),
          themeMode: mode,
          themeAnimationDuration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : pack.motion.durationSlow,
          themeAnimationCurve: pack.motion.easingStandard,
          navigatorKey: appNavigatorKey,
          navigatorObservers: [Pop.routeObserver],
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: TS
                .of(context)
                .overlayStyleFor(TS.of(context).colors.background),
            child: Pop.hostBuilder(
              context,
              LocalDataBoundary(child: child ?? const SizedBox.shrink()),
            ),
          ),
          initialRoute: AppRoutes.bootstrap,
          routes: appRoutes,
        );
      },
    );
  }
}
