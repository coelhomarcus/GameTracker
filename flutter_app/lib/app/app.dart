import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/design_system/app_theme.dart';
import '../features/auth/presentation/session_state.dart';
import '../features/feed/application/feed_controller.dart';
import '../features/library/application/library_controller.dart';
import 'providers.dart';
import 'router.dart';
import 'theme_mode.dart';

/// Faz o router reavaliar os redirects quando a sessão muda.
class _SessionRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

class GameTrackerApp extends ConsumerStatefulWidget {
  const GameTrackerApp({super.key});

  @override
  ConsumerState<GameTrackerApp> createState() => _GameTrackerAppState();
}

class _GameTrackerAppState extends ConsumerState<GameTrackerApp> {
  final _refresh = _SessionRefresh();
  late final GoRouter _router = buildRouter(
    session: () => ref.read(sessionControllerProvider),
    refresh: _refresh,
  );

  late final AppLifecycleListener _lifecycle;

  /// Ao voltar para o app, dados já carregados e velhos são revalidados.
  void _revalidate() {
    if (ref.exists(libraryProvider)) {
      ref.read(libraryProvider.notifier).revalidateIfStale();
    }
    ref.read(feedRevalidatorProvider).revalidateIfStale();
  }

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _revalidate);
    ref.listenManual<SessionState>(
      sessionControllerProvider,
      (_, _) => _refresh.ping(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _router.dispose();
    _refresh.dispose();
    super.dispose();
  }

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
