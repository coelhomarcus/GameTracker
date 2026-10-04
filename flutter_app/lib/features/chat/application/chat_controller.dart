import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/client_id.dart';
import '../../../core/models/user_summary.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/realtime/chat_connection.dart';
import '../../../core/realtime/chat_transport.dart';
import '../../auth/presentation/session_state.dart';
import '../data/chat_models.dart';
import 'chat_providers.dart';
import 'conversations_controller.dart';
import 'message_merge.dart';

const maxMessageLength = 2000;

class ChatState {
  const ChatState({
    required this.messages,
    required this.other,
    required this.olderCursor,
    this.loadingOlder = false,
    this.olderError,
    this.otherTyping = false,
    this.otherOnline,
  });

  /// Em ordem de leitura: mais antigas primeiro, pendentes no fim.
  final List<ChatMessage> messages;
  final UserSummary other;

  /// Cursor das mensagens mais antigas; `null` quando todo o histórico foi carregado.
  final String? olderCursor;
  final bool loadingOlder;
  final Object? olderError;
  final bool otherTyping;

  /// `null` até o servidor informar (não confundir "desconhecido" com "offline").
  final bool? otherOnline;

  bool get hasOlder => olderCursor != null;

  ChatState copyWith({
    List<ChatMessage>? messages,
    Object? olderCursor = _keep,
    bool? loadingOlder,
    Object? olderError = _keep,
    bool? otherTyping,
    Object? otherOnline = _keep,
  }) => ChatState(
    messages: messages ?? this.messages,
    other: other,
    olderCursor: identical(olderCursor, _keep)
        ? this.olderCursor
        : olderCursor as String?,
    loadingOlder: loadingOlder ?? this.loadingOlder,
    olderError: identical(olderError, _keep) ? this.olderError : olderError,
    otherTyping: otherTyping ?? this.otherTyping,
    otherOnline: identical(otherOnline, _keep)
        ? this.otherOnline
        : otherOnline as bool?,
  );

  static const _keep = Object();
}

/// Uma conversa 1:1: histórico paginado, mensagens ao vivo, envio confiável, digitação,
/// presença e leitura. Descartada (e a sala deixada) quando a tela fecha.
class ChatController extends AsyncNotifier<ChatState> {
  ChatController(this.conversationId);
  final String conversationId;

  /// Tentativas com ACK perdido antes de desistir e marcar como falha.
  static const maxAttempts = 3;

  /// Páginas buscadas ao reencontrar o último id conhecido depois de uma queda.
  static const maxResyncPages = 10;

  static const typingThrottle = Duration(seconds: 2);
  static const typingIdle = Duration(seconds: 3);
  static const typingExpiry = Duration(seconds: 4);
  static const markReadDelay = Duration(milliseconds: 300);

  late final String _meId;
  late final UserSummary _me;

  // Capturados no build: o Riverpod proíbe `ref.read` dentro de `onDispose`.
  late ChatTransport _transport;
  ChatConnection? _roomConnection;
  final _subs = <StreamSubscription<Object?>>[];
  final _early = <ChatEvent>[];
  final _delivering = <String>{};
  Timer? _typingExpiryTimer;
  Timer? _typingIdleTimer;
  Timer? _typingThrottleTimer;
  Timer? _markReadTimer;
  bool _typingActive = false;
  bool _visible = false;
  bool _disposed = false;
  String? _lastMarkedReadId;

  ChatConnection? get _connection => ref.read(chatConnectionProvider);
  ConversationsController get _conversations =>
      ref.read(conversationsControllerProvider.notifier);

  @override
  Future<ChatState> build() async {
    final userId = ref.watch(currentUserIdProvider);
    final session = ref.read(sessionControllerProvider);
    if (userId == null || session is! SessionAuthenticated) {
      throw const ApiException(401, 'unauthorized', 'Sessão encerrada');
    }
    _meId = userId;
    _me = UserSummary(
      id: userId,
      username: session.user.username,
      name: session.user.name,
      avatarUrl: session.user.avatarUrl,
    );
    _disposed = false;
    _transport = ref.read(chatTransportProvider);
    _roomConnection = ref.read(chatConnectionProvider);
    ref.onDispose(_teardown);

    final conversation = await _resolveConversation();
    final other = conversation.otherUser;
    if (other == null) {
      throw const ApiException(404, 'not_found', 'Conversa não encontrada');
    }

    // Escuta antes de carregar o histórico: o que chegar durante a carga é guardado e mesclado depois.
    final connection = _connection;
    _subs.add(ref.read(chatTransportProvider).events.listen(_onEvent));
    if (connection != null) {
      _subs.add(connection.resynced.listen((_) => unawaited(_onResynced())));
    }

    final page = await ref
        .read(chatRepositoryProvider)
        .messages(conversationId);
    var messages = mergeMessages(const [], page.items);
    for (final event in _early) {
      if (event is MessageReceived) {
        messages = mergeMessages(messages, [ChatMessage.fromJson(event.json)]);
      }
    }
    _early.clear();

    unawaited(_afterLoad(other));
    return ChatState(
      messages: messages,
      other: other,
      olderCursor: page.nextCursor,
    );
  }

  Future<ConversationSummary> _resolveConversation() async {
    ConversationSummary? find(List<ConversationSummary> list) {
      for (final c in list) {
        if (c.id == conversationId) return c;
      }
      return null;
    }

    final list = await ref.read(conversationsControllerProvider.future);
    var conversation = find(list);
    if (conversation == null) {
      // Conversa recém-criada (ou link direto): a lista em cache pode não conhecê-la ainda.
      await _conversations.refresh();
      conversation = find(
        ref.read(conversationsControllerProvider).value ?? const [],
      );
    }
    if (conversation == null) {
      throw const ApiException(404, 'not_found', 'Conversa não encontrada');
    }
    return conversation;
  }

  Future<void> _afterLoad(UserSummary other) async {
    final connection = _connection;
    if (connection == null) return;
    await connection.joinRoom(conversationId);
    await _fetchPresence(other.id);
    _scheduleMarkRead();
  }

  void _teardown() {
    _disposed = true;
    _typingExpiryTimer?.cancel();
    _typingIdleTimer?.cancel();
    _typingThrottleTimer?.cancel();
    _markReadTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    if (_typingActive) {
      _transport.send('typing:stop', {'conversationId': conversationId});
    }
    _roomConnection?.leaveRoom(conversationId);
  }

  // ---------- eventos ----------

  void _onEvent(ChatEvent event) {
    final current = state.value;
    if (current == null) {
      // Ainda carregando o histórico.
      if (event is MessageReceived) _early.add(event);
      return;
    }
    switch (event) {
      case MessageReceived(:final json):
        if (json['conversationId'] != conversationId) return;
        final message = ChatMessage.fromJson(json);
        _merge([message]);
        if (message.sender.id == _meId) {
          _conversations.applyOutgoing(conversationId, message);
        } else {
          _setTyping(false);
          _conversations.applyIncoming(
            conversationId,
            message,
            beingRead: _visible,
          );
          _scheduleMarkRead();
        }
      case TypingChanged(:final conversationId, :final userId, :final typing):
        if (conversationId == this.conversationId &&
            userId == current.other.id) {
          _setTyping(typing);
        }
      case PresenceChanged(:final userId, :final online):
        if (userId == current.other.id) {
          _set((s) => s.copyWith(otherOnline: online));
        }
    }
  }

  void _set(ChatState Function(ChatState) change) {
    final current = state.value;
    if (current != null && !_disposed) state = AsyncData(change(current));
  }

  void _merge(Iterable<ChatMessage> incoming) =>
      _set((s) => s.copyWith(messages: mergeMessages(s.messages, incoming)));

  ChatMessage? _find(String clientMessageId) {
    for (final m in state.value?.messages ?? const <ChatMessage>[]) {
      if (m.clientMessageId == clientMessageId) return m;
    }
    return null;
  }

  static const _unset = Object();

  void _updateMessage(
    String clientMessageId, {
    MessageStatus? status,
    int? attempts,
    Object? error = _unset,
  }) {
    _set(
      (s) => s.copyWith(
        messages: [
          for (final m in s.messages)
            m.clientMessageId == clientMessageId && !m.isConfirmed
                ? m.copyWith(
                    status: status,
                    attempts: attempts,
                    error: identical(error, _unset)
                        ? m.error
                        : error as String?,
                  )
                : m,
        ],
      ),
    );
  }

  // ---------- reconexão ----------

  /// A conexão voltou e a sala foi reentrada: busca o que chegou durante a queda e atualiza a presença.
  Future<void> _onResynced() async {
    await _resync();
    final other = state.value?.other;
    if (other != null) await _fetchPresence(other.id);
    _scheduleMarkRead();
  }

  /// Busca páginas recentes até reencontrar a última mensagem conhecida (ou chegar ao fim) e
  /// mescla. Uma única primeira página não bastaria depois de uma queda longa.
  Future<void> _resync() async {
    final current = state.value;
    if (current == null) return;
    final knownId = latestConfirmedId(current.messages);
    final repository = ref.read(chatRepositoryProvider);
    try {
      final fetched = <ChatMessage>[];
      String? cursor;
      String? next;
      var reachedKnown = false;
      var pages = 0;
      do {
        final page = await repository.messages(conversationId, cursor: cursor);
        fetched.addAll(page.items);
        next = page.nextCursor;
        reachedKnown =
            knownId == null || page.items.any((m) => m.id == knownId);
        cursor = next;
        pages++;
      } while (!reachedKnown && next != null && pages < maxResyncPages);

      if (_disposed) return;
      if (!reachedKnown && next != null) {
        // Houve mais mensagens do que o limite de páginas: não dá para garantir que o histórico
        // antigo já carregado seja contíguo com as novas. Mantém só as pendentes + o que veio.
        _set(
          (s) => s.copyWith(
            messages: mergeMessages(
              s.messages.where((m) => !m.isConfirmed).toList(),
              fetched,
            ),
            olderCursor: next,
          ),
        );
      } else {
        _merge(fetched);
      }
    } catch (_) {
      // Sem rede ou erro do servidor: a próxima reconexão tenta de novo.
    }
  }

  Future<void> _fetchPresence(String otherId) async {
    try {
      final response = await ref.read(chatTransportProvider).request(
        'presence:get',
        {'conversationId': conversationId},
      );
      final online = response['online'];
      if (online is List) {
        _set((s) => s.copyWith(otherOnline: online.contains(otherId)));
      }
    } on TransportException {
      // Desconhecido continua desconhecido: não vira "offline" só porque a consulta falhou.
    }
  }

  // ---------- histórico ----------

  Future<void> loadOlder() async {
    final current = state.value;
    if (current == null || !current.hasOlder || current.loadingOlder) return;
    _set((s) => s.copyWith(loadingOlder: true, olderError: null));
    try {
      final page = await ref
          .read(chatRepositoryProvider)
          .messages(conversationId, cursor: current.olderCursor);
      if (_disposed) return;
      _set(
        (s) => s.copyWith(
          messages: mergeMessages(s.messages, page.items),
          olderCursor: page.nextCursor,
          loadingOlder: false,
        ),
      );
    } catch (e) {
      if (!_disposed) {
        _set((s) => s.copyWith(loadingOlder: false, olderError: e));
      }
    }
  }

  // ---------- envio ----------

  /// Põe a mensagem na conversa na hora (pendente) e a entrega em segundo plano. O texto nunca
  /// se perde: se não for entregue, continua na lista com "Tentar de novo" e "Descartar".
  void send(String text) {
    final content = text.trim();
    if (content.isEmpty ||
        content.length > maxMessageLength ||
        state.value == null) {
      return;
    }
    _stopTyping();

    final cid = newClientId();
    final pending = ChatMessage(
      clientMessageId: cid,
      conversationId: conversationId,
      sender: _me,
      content: content,
      createdAt: ref.read(clockProvider)(),
      status: MessageStatus.sending,
    );
    _merge([pending]);
    _conversations.applyOutgoing(conversationId, pending);
    unawaited(_deliver(cid));
  }

  /// Reenvio manual de uma mensagem que falhou. Seguro: o servidor ignora o `clientMessageId` repetido.
  void retry(String clientMessageId) {
    final message = _find(clientMessageId);
    if (message == null || message.isConfirmed) return;
    _updateMessage(
      clientMessageId,
      status: MessageStatus.sending,
      attempts: 0,
      error: null,
    );
    unawaited(_deliver(clientMessageId));
  }

  /// Remove uma mensagem não entregue só da tela. Se o servidor chegou a gravá-la, ela volta
  /// na próxima sincronização, o que reflete a realidade.
  void discard(String clientMessageId) {
    _set(
      (s) => s.copyWith(
        messages: [
          for (final m in s.messages)
            if (!(m.clientMessageId == clientMessageId && !m.isConfirmed)) m,
        ],
      ),
    );
  }

  Future<void> _deliver(String cid) async {
    if (!_delivering.add(cid)) return;
    try {
      while (!_disposed) {
        final message = _find(cid);
        // Confirmada no meio (evento, ACK de outra tentativa ou histórico) ou descartada.
        if (message == null || message.isConfirmed) return;

        final connection = _connection;
        if (connection == null) return;
        if (!connection.transport.isConnected) {
          await _waitForConnection(connection);
          continue;
        }

        _updateMessage(cid, status: MessageStatus.sending);
        try {
          final response = await connection.transport.request('message:send', {
            'conversationId': conversationId,
            'content': message.content,
            'clientMessageId': cid,
          }, timeout: ref.read(chatAckTimeoutProvider));
          if (_disposed) return;

          final raw = response['message'];
          if (raw is Map) {
            final confirmed = ChatMessage.fromJson(
              Map<String, dynamic>.from(raw),
            );
            _merge([confirmed]);
            _conversations.applyOutgoing(conversationId, confirmed);
            return;
          }
          final error = response['error'];
          if (error == 'Erro interno') {
            if (!await _backOff(cid)) return;
            continue;
          }
          // Recusa definitiva do servidor (payload inválido, conversa inexistente): não adianta repetir.
          _updateMessage(cid, status: MessageStatus.failed, error: '$error');
          return;
        } on RequestTimeoutException {
          // Pode ter sido gravada: não dá para saber. Reenviar é seguro (idempotente).
          if (!await _backOff(cid)) return;
        } on TransportException {
          // Caiu no meio: espera a conexão voltar sem gastar tentativas.
          await _waitForConnection(connection);
        }
      }
    } finally {
      _delivering.remove(cid);
    }
  }

  /// Conta uma tentativa sem confirmação. Devolve `false` se desistiu (marcou como falha).
  Future<bool> _backOff(String cid) async {
    final attempts = (_find(cid)?.attempts ?? 0) + 1;
    if (attempts >= maxAttempts) {
      _updateMessage(
        cid,
        status: MessageStatus.failed,
        attempts: attempts,
        error: 'Não foi possível confirmar o envio.',
      );
      return false;
    }
    _updateMessage(cid, status: MessageStatus.uncertain, attempts: attempts);
    await Future<void>.delayed(ref.read(chatRetryDelayProvider)(attempts));
    return !_disposed;
  }

  Future<void> _waitForConnection(ChatConnection connection) async {
    if (connection.transport.isConnected) return;
    try {
      await connection.resynced.first;
    } on StateError {
      // Stream fechado: a conexão foi encerrada.
    }
  }

  // ---------- digitação ----------

  /// A pessoa está escrevendo: avisa a outra (no máximo a cada 2 s) e para sozinho depois de 3 s parado.
  void composerChanged(String text) {
    if (text.trim().isEmpty) {
      _stopTyping();
      return;
    }
    if (_typingThrottleTimer == null) {
      ref.read(chatTransportProvider).send('typing:start', {
        'conversationId': conversationId,
      });
      _typingActive = true;
      _typingThrottleTimer = Timer(
        typingThrottle,
        () => _typingThrottleTimer = null,
      );
    }
    _typingIdleTimer?.cancel();
    _typingIdleTimer = Timer(typingIdle, _stopTyping);
  }

  /// A tela perdeu o foco (o campo de texto): avisa que parou de digitar.
  void composerBlurred() => _stopTyping();

  void _stopTyping() {
    _typingIdleTimer?.cancel();
    _typingIdleTimer = null;
    _typingThrottleTimer?.cancel();
    _typingThrottleTimer = null;
    if (_typingActive) {
      _typingActive = false;
      ref.read(chatTransportProvider).send('typing:stop', {
        'conversationId': conversationId,
      });
    }
  }

  void _setTyping(bool typing) {
    _typingExpiryTimer?.cancel();
    _set((s) => s.copyWith(otherTyping: typing));
    // Sem um `typing:stop` (a conexão caiu), o indicador some sozinho.
    if (typing) {
      _typingExpiryTimer = Timer(
        typingExpiry,
        () => _set((s) => s.copyWith(otherTyping: false)),
      );
    }
  }

  // ---------- leitura ----------

  /// A conversa só conta como lida enquanto está visível (tela aberta e app em primeiro plano).
  void setVisible(bool visible) {
    _visible = visible;
    if (visible) _scheduleMarkRead(immediate: true);
  }

  void _scheduleMarkRead({bool immediate = false}) {
    if (!_visible || _disposed) return;
    final latest = _latestIncomingId();
    if (latest == null || latest == _lastMarkedReadId) return;
    _markReadTimer?.cancel();
    _markReadTimer = Timer(
      immediate ? Duration.zero : markReadDelay,
      () => unawaited(_markRead(latest)),
    );
  }

  String? _latestIncomingId() {
    final messages = state.value?.messages ?? const <ChatMessage>[];
    for (var i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (m.id != null && m.sender.id != _meId) return m.id;
    }
    return null;
  }

  Future<void> _markRead(String latestId) async {
    if (!_visible || _disposed) return;
    try {
      await ref.read(chatRepositoryProvider).markRead(conversationId);
      _lastMarkedReadId = latestId;
      _conversations.markReadLocal(conversationId);
    } catch (_) {
      // Tenta de novo no próximo evento ou ao reabrir.
    }
  }
}

final chatControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ChatController, ChatState, String>(ChatController.new);
