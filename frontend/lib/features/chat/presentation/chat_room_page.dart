import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/providers.dart';
import '../../../core/design_system/async_content.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/design_system/user_avatar.dart';
import '../../../core/network/error_messages.dart';
import '../../../core/realtime/chat_connection.dart';
import '../application/chat_controller.dart';
import '../application/chat_drafts.dart';
import '../application/chat_providers.dart';
import 'chat_items.dart';
import 'message_bubble.dart';

/// A conversa como rota própria (telas estreitas e links diretos).
class ChatRoomPage extends StatelessWidget {
  const ChatRoomPage({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context) =>
      ChatRoomView(conversationId: conversationId);
}

/// A conversa em si. Também é usada como painel de detalhe nas telas largas.
class ChatRoomView extends ConsumerStatefulWidget {
  const ChatRoomView({
    super.key,
    required this.conversationId,
    this.embedded = false,
  });

  final String conversationId;

  /// No painel de detalhe não há botão de voltar.
  final bool embedded;

  @override
  ConsumerState<ChatRoomView> createState() => _ChatRoomViewState();
}

class _ChatRoomViewState extends ConsumerState<ChatRoomView>
    with WidgetsBindingObserver {
  late final TextEditingController _text;
  final _focus = FocusNode();
  final _scroll = ScrollController();

  /// Distância do topo (mensagens mais antigas), em px, para pedir mais histórico.
  static const _prefetchExtent = 300.0;

  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _text = TextEditingController(
      text: ref.read(chatDraftsProvider)[widget.conversationId] ?? '',
    );
    _focus.addListener(() {
      if (!_focus.hasFocus) _controller.composerBlurred();
    });
    _scroll.addListener(_maybeLoadOlder);
    // A conversa só conta como lida enquanto está na tela e o app em primeiro plano.
    SchedulerBinding.instance.addPostFrameCallback((_) => _syncVisibility());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _text.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  ChatController get _controller =>
      ref.read(chatControllerProvider(widget.conversationId).notifier);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    _syncVisibility();
  }

  void _syncVisibility() {
    if (!mounted) return;
    final visible = _lifecycle == AppLifecycleState.resumed;
    if (ref.read(chatControllerProvider(widget.conversationId)).hasValue) {
      _controller.setVisible(visible);
    }
  }

  void _maybeLoadOlder() {
    if (!_scroll.hasClients) return;
    final state = ref.read(chatControllerProvider(widget.conversationId)).value;
    if (state == null || state.olderError != null) return;
    // Em uma lista invertida, `extentAfter` é a distância até as mensagens mais antigas.
    if (_scroll.position.extentAfter < _prefetchExtent) {
      _controller.loadOlder();
    }
  }

  void _send() {
    final text = _text.text;
    if (text.trim().isEmpty || text.trim().length > maxMessageLength) return;
    _controller.send(text);
    _text.clear();
    ref.read(chatDraftsProvider.notifier).set(widget.conversationId, '');
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider(widget.conversationId));

    return chat.when(
      skipLoadingOnRefresh: true,
      loading: () => Scaffold(appBar: _plainBar(), body: const LoadingView()),
      error: (e, _) => Scaffold(
        appBar: _plainBar(),
        body: ErrorView(
          message: describeError(e),
          onRetry: () =>
              ref.invalidate(chatControllerProvider(widget.conversationId)),
        ),
      ),
      data: (state) {
        // Atualiza a visibilidade assim que o conteúdo existe (marca como lida o que já está lá).
        SchedulerBinding.instance.addPostFrameCallback(
          (_) => _syncVisibility(),
        );
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: widget.embedded
                ? null
                : BackButton(
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go('/messages'),
                  ),
            titleSpacing: widget.embedded ? Space.lg : 0,
            title: _Title(state: state),
          ),
          body: Column(
            children: [
              const _ConnectionBanner(),
              Expanded(
                child: _Messages(
                  state: state,
                  scroll: _scroll,
                  conversationId: widget.conversationId,
                  onChanged: _maybeLoadOlder,
                ),
              ),
              _Composer(
                controller: _text,
                focus: _focus,
                onChanged: (value) {
                  ref
                      .read(chatDraftsProvider.notifier)
                      .set(widget.conversationId, value);
                  _controller.composerChanged(value);
                },
                onSend: _send,
              ),
            ],
          ),
        );
      },
    );
  }

  AppBar _plainBar() => AppBar(
    automaticallyImplyLeading: false,
    leading: widget.embedded
        ? null
        : BackButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/messages'),
          ),
  );
}

class _Title extends StatelessWidget {
  const _Title({required this.state});

  final ChatState state;

  @override
  Widget build(BuildContext context) {
    final other = state.other;
    final text = Theme.of(context).textTheme;
    // `otherOnline == null` é "desconhecido": não mostra nada em vez de afirmar "offline".
    final status = state.otherTyping
        ? 'digitando…'
        : (state.otherOnline == true ? 'online' : null);

    return Semantics(
      button: true,
      label:
          'Perfil de ${other.displayName}${status == null ? '' : ', $status'}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push('/users/${other.id}'),
        child: Row(
          children: [
            UserAvatar(
              name: other.displayName,
              url: other.avatarUrl,
              radius: 18,
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    other.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium,
                  ),
                  if (status != null)
                    Text(
                      status,
                      style: text.bodySmall?.copyWith(
                        color: state.otherTyping
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avisa quando não há conexão em tempo real. As mensagens escritas ficam na fila e saem sozinhas.
class _ConnectionBanner extends ConsumerWidget {
  const _ConnectionBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(chatConnectionStateProvider).value;
    if (status == null ||
        status.status == ChatConnectionStatus.connected ||
        status.status == ChatConnectionStatus.stopped) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final waiting = status.status == ChatConnectionStatus.waiting;
    return Semantics(
      liveRegion: true,
      child: Material(
        color: scheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.lg,
            vertical: Space.xs,
          ),
          child: Row(
            spacing: Space.md,
            children: [
              waiting
                  ? Icon(
                      Icons.cloud_off,
                      size: 18,
                      color: scheme.onSecondaryContainer,
                    )
                  : const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
              Expanded(
                child: Text(
                  waiting
                      ? 'Sem conexão. As mensagens saem quando voltar.'
                      : 'Conectando…',
                  style: TextStyle(color: scheme.onSecondaryContainer),
                ),
              ),
              if (waiting)
                TextButton(
                  onPressed: () =>
                      ref.read(chatConnectionProvider)?.reconnectNow(),
                  child: const Text('Tentar agora'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Messages extends ConsumerWidget {
  const _Messages({
    required this.state,
    required this.scroll,
    required this.conversationId,
    required this.onChanged,
  });

  final ChatState state;
  final ScrollController scroll;
  final String conversationId;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentUserIdProvider) ?? '';
    final controller = ref.read(
      chatControllerProvider(conversationId).notifier,
    );
    final now = ref.watch(clockProvider)();
    final items = buildChatItems(state.messages, meId: session);

    if (items.isEmpty && !state.hasOlder) {
      return EmptyView(
        icon: Icons.chat_bubble_outline,
        title: 'Diga oi para ${state.other.displayName}',
        message: 'As mensagens aparecem aqui.',
      );
    }

    // Depois do primeiro quadro, uma lista curta pode não rolar: pede mais histórico se faltar.
    SchedulerBinding.instance.addPostFrameCallback((_) => onChanged());

    // Lista invertida: o índice 0 é a mensagem mais nova (colada no teclado) e o último é o cabeçalho de "mais antigas".
    return ListView.builder(
      controller: scroll,
      reverse: true,
      padding: const EdgeInsets.only(bottom: Space.sm, top: Space.sm),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == items.length) {
          return _OlderHeader(state: state, onRetry: controller.loadOlder);
        }
        final item = items[items.length - 1 - index];
        switch (item) {
          case DaySeparator(:final day):
            return _DayChip(label: dayLabel(day, now: now));
          case MessageItem():
            final cid = item.message.clientMessageId;
            return MessageBubble(
              key: ValueKey(item.message.key),
              item: item,
              onRetry: cid == null ? null : () => controller.retry(cid),
              onDiscard: cid == null ? null : () => controller.discard(cid),
            );
        }
      },
    );
  }
}

class _OlderHeader extends StatelessWidget {
  const _OlderHeader({required this.state, required this.onRetry});

  final ChatState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.olderError != null) {
      return Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          children: [
            const Text('Não foi possível carregar mensagens mais antigas.'),
            TextButton(onPressed: onRetry, child: const Text('Tentar de novo')),
          ],
        ),
      );
    }
    if (state.loadingOlder) {
      return const Padding(
        padding: EdgeInsets.all(Space.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!state.hasOlder) {
      return Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Center(
          child: Text(
            'Início da conversa',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }
    return const SizedBox(height: Space.lg);
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.md),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.md,
            vertical: Space.xs,
          ),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label, style: Theme.of(context).textTheme.labelSmall),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focus,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 3,
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.lg,
            Space.sm,
            Space.sm,
            Space.sm,
          ),
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final length = controller.text.trim().length;
              final canSend = length > 0 && length <= maxMessageLength;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focus,
                      onChanged: onChanged,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: maxMessageLength,
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: 'Mensagem',
                        // O contador só aparece perto do limite, para não poluir a tela.
                        counterText:
                            controller.text.length > maxMessageLength - 200
                            ? '${controller.text.length}/$maxMessageLength'
                            : '',
                      ),
                    ),
                  ),
                  IconButton.filled(
                    tooltip: 'Enviar mensagem',
                    icon: const Icon(Icons.send),
                    onPressed: canSend ? onSend : null,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
