import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/design_system/app_theme.dart';
import 'router.dart';
import 'theme_mode.dart';

class GameTrackerApp extends ConsumerStatefulWidget {
  const GameTrackerApp({super.key});

  @override
  ConsumerState<GameTrackerApp> createState() => _GameTrackerAppState();
}

class _GameTrackerAppState extends ConsumerState<GameTrackerApp> {
  late final GoRouter _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GameTracker',
      routerConfig: _router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}
