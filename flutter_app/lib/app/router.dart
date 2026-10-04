import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/design_system/placeholder_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/chat/presentation/messages_page.dart';
import '../features/explore/presentation/explore_page.dart';
import '../features/feed/presentation/community_page.dart';
import '../features/games/presentation/game_page.dart';
import '../features/library/presentation/library_page.dart';
import '../features/profiles/presentation/profile_page.dart';
import 'shell.dart';

/// Rotas do plano (seção 4.3). O guard de sessão entra na Etapa 3.
GoRouter buildRouter() => GoRouter(
  initialLocation: '/login',
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
    GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
    GoRoute(
      path: '/register',
      builder: (_, _) => const PlaceholderPage(
        title: 'Criar conta',
        icon: Icons.person_add_alt,
        message: 'Cadastro chega na Etapa 3.',
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
    GoRoute(
      path: '/games/:igdbId',
      builder: (_, state) => GamePage(
        igdbId: int.tryParse(state.pathParameters['igdbId'] ?? '') ?? -1,
      ),
    ),
  ],
);
