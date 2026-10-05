import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/providers.dart';
import '../../../core/dates/relative_time.dart';
import '../../../core/design_system/async_content.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/design_system/user_avatar.dart';
import '../../../core/design_system/primary_action.dart';
import '../application/chat_drafts.dart';
import '../application/conversations_controller.dart';
import '../data/chat_models.dart';
import 'chat_room_page.dart';
import 'start_conversation.dart';

/// Mensagens: lista de conversas. A partir de 840 px vira lista + conversa lado a lado.
class MessagesPage extends ConsumerWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.expanded;
    if (!wide) return const _ConversationsScaffold();

    final selected = ref.watch(selectedConversationProvider);
    return Row(
      children: [
        const SizedBox(width: 360, child: _ConversationsScaffold()),
        const VerticalDivider(width: 1),
        Expanded(
          child: selected == null
              ? const Scaffold(
                  body: EmptyView(
                    icon: Icons.forum_outlined,
                    title: 'Selecione uma conversa',
                    message: 'Ou comece uma nova.',
                  ),
                )
              : ChatRoomView(
                  key: ValueKey(selected),
                  conversationId: selected,
                  embedded: true,
                ),
        ),
      ],
    );
  }
}

class _ConversationsScaffold extends ConsumerWidget {
  const _ConversationsScaffold();

  Future<void> _newConversation(BuildContext context, WidgetRef ref) async {
    final person = await pickPerson(context);
    if (person != null && context.mounted) {
      await startConversation(context, ref, person.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsControllerProvider);
    final newConversation = PrimaryAction(
      heroTag: 'fab-messages',
      icon: Icons.edit_outlined,
      label: 'Nova conversa',
      onPressed: () => _newConversation(context, ref),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mensagens'),
        // A lista tem 360 dp no layout largo: só o ícone cabe com texto ampliado.
        actions: [?newConversation.headerButton(context, compact: true)],
      ),
      floatingActionButton: newConversation.fab(context),
      body: AsyncContent<List<ConversationSummary>>(
        value: conversations,
        staleBanner: true,
        onRetry: () => ref.invalidate(conversationsControllerProvider),
        data: (list) {
          if (list.isEmpty) {
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
          return RefreshIndicator(
            onRefresh: () => _refresh(ref),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(
                bottom: PrimaryAction.fabClearance,
              ),
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) =>
                  _ConversationTile(conversation: list[i]),
            ),
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

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.conversation});

  final ConversationSummary conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final other = conversation.otherUser;
    final last = conversation.lastMessage;
    final me = ref.watch(currentUserIdProvider);
    final unread = conversation.unread;
    final text = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.expanded;
    final selected = ref.watch(selectedConversationProvider) == conversation.id;

    final name = other?.displayName ?? 'Conversa';
    final preview = last == null
        ? 'Nenhuma mensagem'
        : '${last.senderId == me ? 'Você: ' : ''}${last.content}';

    return Semantics(
      label: '$name, ${unread ? 'mensagem não lida, ' : ''}$preview',
      excludeSemantics: true,
      button: true,
      child: ListTile(
        selected: wide && selected,
        leading: UserAvatar(name: name, url: other?.avatarUrl),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: unread ? text.titleSmall : null,
        ),
        subtitle: Text(
          preview,
          maxLines: 1,
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
        onTap: () {
          if (wide) {
            ref
                .read(selectedConversationProvider.notifier)
                .select(conversation.id);
          } else {
            context.push('/messages/${conversation.id}');
          }
        },
      ),
    );
  }
}
