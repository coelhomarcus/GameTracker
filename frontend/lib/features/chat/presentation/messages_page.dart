import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/providers.dart';
import '../../../core/dates/relative_time.dart';
import '../../../core/design_system/async_content.dart';
import '../../../core/design_system/primary_action.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/design_system/user_avatar.dart';
import '../application/conversation_filter.dart';
import '../application/conversations_controller.dart';
import '../data/chat_models.dart';
import 'chat_room_page.dart';
import 'start_conversation.dart';

/// Espaço mínimo (já descontado o rail de navegação) para lista e conversa lado a lado.
const _splitMinWidth = 760.0;
const _listPaneWidth = 320.0;

/// Mensagens. A conversa aberta é a rota (`/messages/:conversationId`): com espaço, lista de 320 dp
/// e conversa lado a lado; sem espaço, só a lista ou só a conversa, conforme a rota.
class MessagesPage extends ConsumerWidget {
  const MessagesPage({super.key, this.conversationId});

  final String? conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // O espaço que importa é o da própria área, depois do rail de navegação.
    return LayoutBuilder(
      builder: (context, box) {
        final split = box.maxWidth >= _splitMinWidth;
        final id = conversationId;
        if (!split) {
          return id == null
              ? const ConversationsPane()
              : ChatRoomView(key: ValueKey(id), conversationId: id);
        }
        return Row(
          children: [
            SizedBox(
              width: _listPaneWidth,
              child: ConversationsPane(selectedId: id, splitLayout: true),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: id == null
                  ? const Scaffold(
                      body: EmptyView(
                        icon: Icons.forum_outlined,
                        title: 'Escolha uma conversa',
                        message: 'Ou comece uma nova.',
                      ),
                    )
                  : ChatRoomView(
                      key: ValueKey(id),
                      conversationId: id,
                      embedded: true,
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Lista de conversas com busca e o filtro "Não lidas".
class ConversationsPane extends ConsumerWidget {
  const ConversationsPane({
    super.key,
    this.selectedId,
    this.splitLayout = false,
  });

  final String? selectedId;

  /// Lista ao lado da conversa: tocar troca a conversa em vez de empilhar uma tela.
  final bool splitLayout;

  Future<void> _newConversation(BuildContext context, WidgetRef ref) async {
    final person = await pickPerson(context);
    if (person != null && context.mounted) {
      await startConversation(context, ref, person.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsControllerProvider);
    final filter = ref.watch(conversationFilterProvider);
    final newConversation = PrimaryAction(
      heroTag: 'fab-messages',
      icon: Icons.edit_outlined,
      label: 'Nova conversa',
      onPressed: () => _newConversation(context, ref),
    );
    return Scaffold(
      appBar: AppBar(
        // Raiz do destino: com a conversa aberta por rota (a lista fica embaixo na pilha), o
        // Material mostraria um voltar que não pertence a este cabeçalho.
        automaticallyImplyLeading: false,
        title: const Text('Mensagens'),
        // A lista pode ter só 320 dp: só o ícone cabe com texto ampliado.
        actions: [?newConversation.headerButton(context, compact: true)],
      ),
      // Com a conversa ao lado, o botão fica no cabeçalho; o FAB cobriria a lista.
      floatingActionButton: splitLayout ? null : newConversation.fab(context),
      body: AsyncContent<List<ConversationSummary>>(
        value: conversations,
        staleBanner: true,
        onRetry: () => ref.invalidate(conversationsControllerProvider),
        data: (all) {
          if (all.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 80),
                  EmptyView(
                    icon: Icons.chat_bubble_outline,
                    title: 'Nenhuma conversa ainda',
                    message: 'Converse com quem você encontrar na comunidade.',
                    action: FilledButton.icon(
                      onPressed: () => _newConversation(context, ref),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Nova conversa'),
                    ),
                  ),
                ],
              ),
            );
          }
          final shown = filterConversations(all, filter);
          final unread = all.where((c) => c.unread).length;
          return Column(
            children: [
              _Toolbar(filter: filter, total: all.length, unread: unread),
              Expanded(
                child: shown.isEmpty
                    ? _NoMatches(
                        onClear: ref
                            .read(conversationFilterProvider.notifier)
                            .clear,
                      )
                    : RefreshIndicator(
                        onRefresh: () => _refresh(ref),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(
                            bottom: PrimaryAction.fabClearance,
                          ),
                          itemCount: shown.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) => _ConversationTile(
                            conversation: shown[i],
                            selected: shown[i].id == selectedId,
                            splitLayout: splitLayout,
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    try {
      await ref.read(conversationsControllerProvider.notifier).refresh();
    } catch (_) {
      // O erro aparece no banner de dados desatualizados.
    }
  }
}

/// Busca por nome ou username e os chips "Todas" e "Não lidas". Os números contam conversas
/// (a API só diz se há mensagem não lida, não quantas).
class _Toolbar extends ConsumerStatefulWidget {
  const _Toolbar({
    required this.filter,
    required this.total,
    required this.unread,
  });

  final ConversationFilter filter;
  final int total;
  final int unread;

  @override
  ConsumerState<_Toolbar> createState() => _ToolbarState();
}

class _ToolbarState extends ConsumerState<_Toolbar> {
  late final _controller = TextEditingController(text: widget.filter.query);

  @override
  void didUpdateWidget(_Toolbar old) {
    super.didUpdateWidget(old);
    // "Limpar" fora do campo (estado vazio de busca) também esvazia o texto.
    if (widget.filter.query != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.filter.query,
        selection: TextSelection.collapsed(offset: widget.filter.query.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(conversationFilterProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.lg,
        Space.sm,
        Space.lg,
        Space.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            onChanged: controller.setQuery,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Buscar conversas',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) => _controller.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        tooltip: 'Limpar busca',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _controller.clear();
                          controller.setQuery('');
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.xs,
            children: [
              FilterChip(
                label: Text('Todas (${widget.total})'),
                selected: !widget.filter.unreadOnly,
                onSelected: (_) => controller.setUnreadOnly(false),
              ),
              FilterChip(
                label: Text('Não lidas (${widget.unread})'),
                selected: widget.filter.unreadOnly,
                onSelected: (_) => controller.setUnreadOnly(true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => EmptyView(
    icon: Icons.search_off,
    title: 'Nenhuma conversa encontrada',
    message: 'Tente outro nome ou limpe a busca.',
    action: OutlinedButton(
      onPressed: onClear,
      child: const Text('Limpar busca'),
    ),
  );
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({
    required this.conversation,
    required this.selected,
    required this.splitLayout,
  });

  final ConversationSummary conversation;
  final bool selected;
  final bool splitLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final other = conversation.otherUser;
    final last = conversation.lastMessage;
    final me = ref.watch(currentUserIdProvider);
    final unread = conversation.unread;
    final text = Theme.of(context).textTheme;

    final name = other?.displayName ?? 'Conversa';
    final preview = last == null
        ? 'Nenhuma mensagem'
        : '${last.senderId == me ? 'Você: ' : ''}${last.content}';

    return Semantics(
      label: '$name, ${unread ? 'mensagem não lida, ' : ''}$preview',
      excludeSemantics: true,
      button: true,
      selected: selected,
      child: ListTile(
        selected: selected,
        leading: UserAvatar(name: name, url: other?.avatarUrl),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: unread ? text.titleSmall : null,
        ),
        subtitle: Text(
          preview,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: unread
              ? text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)
              : null,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (last != null)
              Text(formatRelativeTime(last.createdAt), style: text.labelSmall),
            if (unread) ...[
              const SizedBox(height: Space.xs),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
        // Lado a lado, trocar de conversa não acumula histórico; sozinha, a conversa é uma tela
        // empilhada sobre a lista.
        onTap: () => splitLayout
            ? context.go('/messages/${conversation.id}')
            : context.push('/messages/${conversation.id}'),
      ),
    );
  }
}
