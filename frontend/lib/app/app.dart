import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/design_system/app_theme.dart';
import '../features/auth/presentation/session_state.dart';
import '../features/chat/application/chat_providers.dart';
import '../features/chat/application/conversations_controller.dart';
import '../features/feed/application/feed_controller.dart';
import '../features/notifications/application/notifications_controller.dart';
import '../features/library/application/library_controller.dart';
import '../features/push/application/push_controller.dart';
import 'providers.dart';
import 'router.dart';
import 'theme_mode.dart';

/// Faz o router reavaliar os redirects quando a sessão muda.
class _SessionRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

class GameTrackerApp extends ConsumerStatefulWidget {
  const GameTrackerApp({super.key, this.fontFamily});

  /// Injeção usada por capturas determinísticas; em produção a fonte continua sendo a do sistema.
  final String? fontFamily;

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
    // O sistema pode ter matado o socket em segundo plano sem avisar: confere e reconecta.
    unawaited(ref.read(chatConnectionProvider)?.verify());
    if (ref.exists(conversationsControllerProvider)) {
      ref.read(conversationsControllerProvider.notifier).setForeground(true);
    }
    if (ref.exists(notificationsControllerProvider)) {
      ref.read(notificationsControllerProvider.notifier).setForeground(true);
    }
    ref.read(pushControllerProvider.notifier).onResume();
  }

  /// O polling das conversas só roda com o app aberto.
  void _paused() {
    if (ref.exists(conversationsControllerProvider)) {
      ref.read(conversationsControllerProvider.notifier).setForeground(false);
    }
    if (ref.exists(notificationsControllerProvider)) {
      ref.read(notificationsControllerProvider.notifier).setForeground(false);
    }
  }

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _revalidate, onHide: _paused);
    ref.listenManual<SessionState>(
      sessionControllerProvider,
      (_, _) => _refresh.ping(),
    );
    // Push tocado: abre o destino por cima da navegação atual.
    ref.listenManual<String?>(pendingPushRouteProvider, (_, route) {
      if (route == null) return;
      ref.read(pendingPushRouteProvider.notifier).set(null);
      unawaited(_router.push(route));
    });
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
    // Mantém o registro de push e a escuta de mensagens vivos durante a sessão.
    ref.watch(pushControllerProvider);
    return MaterialApp.router(
      title: 'GameTracker',
      routerConfig: _router,
      theme: AppTheme.light(fontFamily: widget.fontFamily),
      darkTheme: AppTheme.dark(fontFamily: widget.fontFamily),
      themeMode: ref.watch(themeModeProvider),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}
