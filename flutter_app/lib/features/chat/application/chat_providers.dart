import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_config.dart';
import '../../../core/network/session_manager.dart';
import '../../../core/realtime/chat_connection.dart';
import '../../../core/realtime/chat_transport.dart';
import '../data/chat_repository.dart';

/// Um único transporte para o app; cada login abre uma conexão nova por cima dele.
final chatTransportProvider = Provider<ChatTransport>((ref) {
  final transport = SocketIoTransport(url: ApiConfig.baseUrl);
  ref.onDispose(transport.dispose);
  return transport;
});

/// A conexão em tempo real da sessão atual, ou `null` sem sessão. Começa ao entrar e é
/// encerrada (socket fechado, salas esquecidas) ao sair ou trocar de conta.
final chatConnectionProvider = Provider<ChatConnection?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  final session = ref.watch(sessionManagerProvider);
  final connection = ChatConnection(
    transport: ref.watch(chatTransportProvider),
    accessToken: () async => session.accessToken,
    refresh: (usedToken) async {
      final outcome = await session.refreshAfterUnauthorized(usedToken);
      return switch (outcome) {
        RefreshOutcome.refreshed => TokenRefresh.refreshed,
        RefreshOutcome.unavailable => TokenRefresh.unavailable,
        RefreshOutcome.invalid ||
        RefreshOutcome.noSession ||
        RefreshOutcome.discarded => TokenRefresh.sessionEnded,
      };
    },
  );
  connection.start();
  ref.onDispose(() => unawaited(connection.stop()));
  return connection;
});

final chatConnectionStateProvider =
    StreamProvider.autoDispose<ChatConnectionState>((ref) async* {
      final connection = ref.watch(chatConnectionProvider);
      if (connection == null) {
        yield const ChatConnectionState(ChatConnectionStatus.stopped);
        return;
      }
      yield connection.state;
      yield* connection.states;
    });

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => RemoteChatRepository(ref.watch(apiDioProvider)),
);

/// Espera entre reenvios de uma mensagem incerta (o envio é idempotente, então reenviar é seguro).
final chatRetryDelayProvider = Provider<Duration Function(int attempt)>(
  (ref) =>
      (attempt) => Duration(seconds: 2 * attempt),
);

/// Tempo máximo esperando o ACK de uma mensagem.
final chatAckTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 8),
);
