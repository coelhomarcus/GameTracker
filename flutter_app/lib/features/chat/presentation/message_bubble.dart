import 'package:material_ui/material_ui.dart';

import '../../../core/design_system/tokens.dart';
import '../../../core/design_system/user_avatar.dart';
import '../data/chat_models.dart';
import 'chat_items.dart';

/// Uma mensagem. As minhas ficam à direita e mostram o estado de entrega; as da outra pessoa à
/// esquerda, com avatar no começo do grupo. Mensagens não entregues oferecem reenviar/descartar.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.item,
    this.onRetry,
    this.onDiscard,
  });

  final MessageItem item;
  final VoidCallback? onRetry;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final message = item.message;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final mine = item.mine;
    final failed = message.status == MessageStatus.failed;

    final bubble = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.75,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.sm,
        ),
        decoration: BoxDecoration(
          color: failed
              ? scheme.errorContainer
              : (mine
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine || !item.lastInGroup ? 16 : 4),
            bottomRight: Radius.circular(!mine || !item.lastInGroup ? 16 : 4),
          ),
        ),
        child: Text(
          message.content,
          style: text.bodyMedium?.copyWith(
            color: failed
                ? scheme.onErrorContainer
                : (mine ? scheme.onPrimaryContainer : scheme.onSurface),
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        left: Space.md,
        right: Space.md,
        top: item.firstInGroup ? Space.sm : 2,
      ),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            SizedBox(
              width: 32,
              child: item.lastInGroup
                  ? UserAvatar(
                      name: message.sender.displayName,
                      url: message.sender.avatarUrl,
                      radius: 16,
                    )
                  : null,
            ),
            const SizedBox(width: Space.sm),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: mine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Semantics(
                  label: _semanticsLabel(message, mine),
                  child: ExcludeSemantics(child: bubble),
                ),
                if (item.lastInGroup || message.status != MessageStatus.sent)
                  _Footer(item: item, onRetry: onRetry, onDiscard: onDiscard),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _semanticsLabel(ChatMessage message, bool mine) {
    final who = mine ? 'Você' : message.sender.displayName;
    final status = switch (message.status) {
      MessageStatus.sending => ', enviando',
      MessageStatus.uncertain => ', confirmando o envio',
      MessageStatus.failed => ', não enviada',
      MessageStatus.sent => '',
    };
    return '$who, ${clockLabel(message.createdAt)}: ${message.content}$status';
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.item, this.onRetry, this.onDiscard});

  final MessageItem item;
  final VoidCallback? onRetry;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final message = item.message;
    final scheme = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.labelSmall;

    if (message.status == MessageStatus.failed) {
      return Padding(
        padding: const EdgeInsets.only(top: Space.xs),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Space.sm,
          children: [
            Icon(Icons.error_outline, size: 16, color: scheme.error),
            Text('Não enviada', style: small?.copyWith(color: scheme.error)),
            TextButton(onPressed: onRetry, child: const Text('Tentar de novo')),
            TextButton(onPressed: onDiscard, child: const Text('Descartar')),
          ],
        ),
      );
    }

    final (icon, label) = switch (message.status) {
      MessageStatus.sending => (Icons.schedule, 'Enviando…'),
      MessageStatus.uncertain => (Icons.sync, 'Confirmando…'),
      _ => (item.mine ? Icons.done : null, clockLabel(message.createdAt)),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: Space.xs,
        children: [
          if (icon != null) Icon(icon, size: 14, color: scheme.outline),
          Text(label, style: small?.copyWith(color: scheme.outline)),
        ],
      ),
    );
  }
}
