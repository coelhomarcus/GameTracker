import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_client.dart';
import '../core/network/session_manager.dart';
import '../core/storage/token_store.dart';
import '../features/auth/data/auth_api.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/session_controller.dart';
import '../features/auth/presentation/session_state.dart';
import '../features/feed/data/feed_repository.dart';
import '../features/games/data/games_repository.dart';
import '../features/library/data/library_repository.dart';

/// Web: sem persistência do refresh token (ADR-3). Nativo: armazenamento seguro.
final tokenStoreProvider = Provider<TokenStore>(
  (ref) => kIsWeb ? MemoryTokenStore() : SecureTokenStore(),
);

final authApiProvider = Provider<AuthApi>((ref) => AuthApi(createAuthDio()));

final sessionManagerProvider = Provider<SessionManager>((ref) {
  final api = ref.watch(authApiProvider);
  return SessionManager(
    store: ref.watch(tokenStoreProvider),
    refreshCall: api.refresh,
  );
});

/// Cliente das rotas de negócio. Repositories das funcionalidades usam este.
final apiDioProvider = Provider<Dio>(
  (ref) => createApiDio(ref.watch(sessionManagerProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => RemoteAuthRepository(
    api: ref.watch(authApiProvider),
    session: ref.watch(sessionManagerProvider),
    apiDio: ref.watch(apiDioProvider),
  ),
);

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

/// Identidade da sessão atual. Providers de dados devem observar este valor:
/// ao sair ou trocar de conta ele muda e todo o estado derivado é descartado.
final currentUserIdProvider = Provider<String?>((ref) {
  final state = ref.watch(sessionControllerProvider);
  return state is SessionAuthenticated ? state.user.id : null;
});

/// Preferências locais (tema, grade/lista, ordenação). Sobrescrito em `main` e nos testes.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider precisa ser sobrescrito',
  ),
);

final gamesRepositoryProvider = Provider<GamesRepository>(
  (ref) => RemoteGamesRepository(ref.watch(apiDioProvider)),
);

final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) => RemoteFeedRepository(ref.watch(apiDioProvider)),
);

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => RemoteLibraryRepository(ref.watch(apiDioProvider)),
);

/// Sem retry automático: uma falha chega à tela, que oferece "Tentar de novo".
/// Repetir sozinho esconderia o erro e, em mutações, poderia duplicar efeitos (plano, seção 5.3).
Duration? noAutomaticRetry(int retryCount, Object error) => null;

/// Relógio injetável (testes de expiração de cache).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
