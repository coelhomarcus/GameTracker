import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/chat_models.dart';
import 'chat_providers.dart';

/// Lista de conversas. Não há evento por usuário no backend, então ela é revalidada ao voltar
/// para o app, ao entrar na aba e por polling leve enquanto o app está aberto: o contador de
/// não lidas nunca depende só das mensagens da conversa aberta.
class ConversationsController extends AsyncNotifier<List<ConversationSummary>> {
  static const pollInterval = Duration(seconds: 30);
  static const maxAge = Duration(seconds: 30);

  Timer? _poll;
  bool _foreground = true;
  DateTime? _loadedAt;

  @override
  Future<List<ConversationSummary>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    ref.onDispose(() => _poll?.cancel());
    if (userId == null) return const [];

    final list = await ref.watch(chatRepositoryProvider).conversations();
    _loadedAt = ref.read(clockProvider)();
    _schedulePoll();
    return _sorted(list);
  }

  static List<ConversationSummary> _sorted(List<ConversationSummary> list) =>
      [...list]..sort(
        (a, b) =>
            (b.lastMessage?.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(
                  a.lastMessage?.createdAt ??
                      DateTime.fromMillisecondsSinceEpoch(0),
                ),
      );

  void _schedulePoll() {
    _poll?.cancel();
    if (!_foreground) return;
    _poll = Timer.periodic(pollInterval, (_) => revalidate());
  }

  /// O app foi para o segundo plano (ou voltou): o polling só roda com o app aberto.
  void setForeground(bool foreground) {
    _foreground = foreground;
    if (foreground) {
      revalidateIfStale();
      _schedulePoll();
    } else {
      _poll?.cancel();
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Refaz a consulta em segundo plano, mantendo a lista na tela (falha não apaga nada).
  void revalidate() {
    if (state.isLoading) return;
    ref.invalidateSelf();
  }

  void revalidateIfStale() {
    final loadedAt = _loadedAt;
    if (loadedAt == null) return;
    if (ref.read(clockProvider)().difference(loadedAt) > maxAge) revalidate();
  }

  void _update(
    String id,
    ConversationSummary Function(ConversationSummary) change,
  ) {
    final current = state.value;
    if (current == null) return;
    final next = [for (final c in current) c.id == id ? change(c) : c];
    state = AsyncData(_sorted(next));
  }

  /// Li a conversa (localmente, sem esperar o servidor).
  void markReadLocal(String conversationId) =>
      _update(conversationId, (c) => c.copyWith(unread: false));

  /// Uma mensagem minha: vira a última e a conversa não fica "não lida" por minha causa.
  void applyOutgoing(String conversationId, ChatMessage message) => _update(
    conversationId,
    (c) => c.copyWith(
      lastMessage: LastMessage.fromMessage(message),
      unread: false,
    ),
  );

  /// Uma mensagem da outra pessoa: vira a última e, se a conversa não está sendo lida, não lida.
  void applyIncoming(
    String conversationId,
    ChatMessage message, {
    required bool beingRead,
  }) => _update(
    conversationId,
    (c) => c.copyWith(
      lastMessage: LastMessage.fromMessage(message),
      unread: !beingRead,
    ),
  );
}

final conversationsControllerProvider =
    AsyncNotifierProvider<ConversationsController, List<ConversationSummary>>(
      ConversationsController.new,
    );

/// Quantas conversas têm mensagem não lida (para o selo da aba Mensagens).
final unreadConversationsProvider = Provider<int>((ref) {
  final list =
      ref.watch(conversationsControllerProvider).value ??
      const <ConversationSummary>[];
  return list.where((c) => c.unread).length;
});
