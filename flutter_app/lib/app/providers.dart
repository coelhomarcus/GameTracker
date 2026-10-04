import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/network/session_manager.dart';
import '../core/storage/token_store.dart';
import '../features/auth/data/auth_api.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/session_controller.dart';
import '../features/auth/presentation/session_state.dart';

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
