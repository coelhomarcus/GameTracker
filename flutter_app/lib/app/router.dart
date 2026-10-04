import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/register_page.dart';
import '../features/auth/presentation/session_pages.dart';
import '../features/auth/presentation/session_state.dart';
import '../features/chat/presentation/messages_page.dart';
import '../features/explore/presentation/explore_page.dart';
import '../features/feed/presentation/community_page.dart';
import '../features/feed/presentation/create_post_page.dart';
import '../features/feed/presentation/post_detail_page.dart';
import '../features/games/presentation/game_page.dart';
import '../features/library/presentation/library_page.dart';
import '../features/library/presentation/tracking_form_page.dart';
import '../features/profiles/presentation/profile_page.dart';
import 'shell.dart';

const _publicRoutes = {'/login', '/register'};
const _sessionRoutes = {'/splash', '/restore'};

/// Aceita só caminhos internos; evita redirect aberto e rotas de sessão como destino.
String? safeDestination(String? from) {
  if (from == null || from.isEmpty) {
    return null;
  }
  if (!from.startsWith('/') || from.startsWith('//')) {
    return null;
  }
  final path = Uri.tryParse(from)?.path;
  if (path == null ||
      _publicRoutes.contains(path) ||
      _sessionRoutes.contains(path)) {
    return null;
  }
  return from;
}

/// Decide o redirect a partir do estado da sessão (função pura, testável).
String? sessionRedirect(SessionState session, Uri uri) {
  final path = uri.path;
  final from = safeDestination(uri.queryParameters['from']);
  // Destino a lembrar: o `from` já carregado ou, fora das rotas de sessão, a própria URL.
  final remembered =
      from ??
      (_publicRoutes.contains(path) || _sessionRoutes.contains(path)
          ? null
          : uri.toString());

  String withFrom(String route) => remembered == null
      ? route
      : '$route?from=${Uri.encodeQueryComponent(remembered)}';

  switch (session) {
    case SessionInitializing():
      return path == '/splash' ? null : withFrom('/splash');
    case SessionRestoreUnavailable():
      return path == '/restore' ? null : withFrom('/restore');
    case SessionUnauthenticated():
      if (path == '/login' || path == '/register') {
        return null;
      }
      return withFrom('/login');
    case SessionAuthenticated():
      if (_publicRoutes.contains(path) || _sessionRoutes.contains(path)) {
        return from ?? '/library';
      }
      return null;
  }
}

int _igdbId(GoRouterState state) =>
    int.tryParse(state.pathParameters['igdbId'] ?? '') ?? -1;

/// Rotas do plano (seção 4.3). [session] e [refresh] ligam o guard ao estado de sessão.
GoRouter buildRouter({
  required ValueGetter<SessionState> session,
  required Listenable refresh,
}) => GoRouter(
  initialLocation: '/library',
  refreshListenable: refresh,
  redirect: (context, state) => sessionRedirect(session(), state.uri),
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Página não encontrada.'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.go('/library'),
            child: const Text('Ir para a Biblioteca'),
          ),
        ],
      ),
    ),
  ),
  routes: [
    GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
    GoRoute(
      path: '/restore',
      builder: (_, _) => const RestoreUnavailablePage(),
    ),
    GoRoute(
      path: '/login',
      builder: (_, state) =>
          LoginPage(from: safeDestination(state.uri.queryParameters['from'])),
    ),
    GoRoute(
      path: '/register',
      builder: (_, state) => RegisterPage(
        from: safeDestination(state.uri.queryParameters['from']),
      ),
    ),
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => AppShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/library', builder: (_, _) => const LibraryPage()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/explore', builder: (_, _) => const ExplorePage()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/community',
              builder: (_, _) => const CommunityPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/messages', builder: (_, _) => const MessagesPage()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/me', builder: (_, _) => const ProfilePage()),
          ],
        ),
      ],
    ),
    // `/posts/new` precisa vir antes de `/posts/:postId`.
    GoRoute(
      path: '/posts/new',
      builder: (_, state) => CreatePostPage(
        entryId: state.uri.queryParameters['entryId'],
        initialText: state.uri.queryParameters['text'],
      ),
    ),
    GoRoute(
      path: '/posts/:postId',
      builder: (_, state) =>
          PostDetailPage(postId: state.pathParameters['postId'] ?? ''),
    ),
    GoRoute(
      path: '/users/:userId',
      // O próprio usuário é resolvido para a experiência canônica do perfil.
      redirect: (context, state) {
        final current = session();
        final isMe =
            current is SessionAuthenticated &&
            current.user.id == state.pathParameters['userId'];
        return isMe ? '/me' : null;
      },
      builder: (_, _) => const UserProfilePlaceholderPage(),
    ),
    GoRoute(
      path: '/games/:igdbId',
      builder: (_, state) => GamePage(igdbId: _igdbId(state)),
      routes: [
        GoRoute(
          path: 'playthroughs/new',
          builder: (_, state) => TrackingFormPage(igdbId: _igdbId(state)),
        ),
        GoRoute(
          path: 'playthroughs/:entryId/edit',
          builder: (_, state) => TrackingFormPage(
            igdbId: _igdbId(state),
            entryId: state.pathParameters['entryId'],
          ),
        ),
      ],
    ),
  ],
);
