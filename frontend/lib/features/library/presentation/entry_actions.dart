import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/dates/date_only.dart';
import '../../../core/design_system/game_status.dart';
import '../../../core/network/error_messages.dart';
import '../../feed/presentation/celebration.dart';
import '../../games/data/game_models.dart';
import '../application/library_controller.dart';
import '../data/game_entry.dart';

enum _EntryAction { status, edit, remove }

enum _GameAction { records, newRecord }

/// Menu de um jogo na Biblioteca: ver os registros ou começar um novo. Editar e excluir acontecem
/// no registro específico (página do jogo, "Meu progresso"), nunca no mais recente por tabela.
class GameMenuButton extends StatelessWidget {
  const GameMenuButton({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_GameAction>(
      tooltip: 'Ações de ${game.name}',
      icon: const Icon(Icons.more_vert),
      onSelected: (action) => switch (action) {
        _GameAction.records => context.push(
          '/games/${game.igdbId}?tab=progress',
        ),
        _GameAction.newRecord => context.push(
          '/games/${game.igdbId}/playthroughs/new',
        ),
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: _GameAction.records, child: Text('Ver registros')),
        PopupMenuItem(
          value: _GameAction.newRecord,
          child: Text('Novo registro'),
        ),
      ],
    );
  }
}

/// Menu do registro: alterar status, editar e remover. Cada ação mostra o resultado
/// em um SnackBar; falhas não mudam a coleção.
class EntryMenuButton extends ConsumerWidget {
  const EntryMenuButton({super.key, required this.entry});

  final GameEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_EntryAction>(
      tooltip: 'Ações do registro de ${entry.game.name}',
      icon: const Icon(Icons.more_vert),
      onSelected: (action) => switch (action) {
        _EntryAction.status => _changeStatus(context, ref),
        _EntryAction.edit => context.push(
          '/games/${entry.game.igdbId}/playthroughs/${entry.id}/edit',
        ),
        _EntryAction.remove => _remove(context, ref),
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _EntryAction.status,
          child: Text('Alterar status'),
        ),
        PopupMenuItem(value: _EntryAction.edit, child: Text('Editar')),
        PopupMenuItem(value: _EntryAction.remove, child: Text('Remover')),
      ],
    );
  }

  Future<void> _changeStatus(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final chosen = await showModalBottomSheet<GameStatus>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Status de ${entry.game.name}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            for (final status in GameStatus.values)
              ListTile(
                leading: Icon(
                  status.icon,
                  color: context.domainColors.forStatus(status),
                ),
                title: Text(status.label),
                trailing: status == entry.status
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(context).pop(status),
              ),
          ],
        ),
      ),
    );
    if (chosen == null || chosen == entry.status) return;

    try {
      final draft = EntryDraft.fromEntry(entry);
      final saved = await ref
          .read(libraryProvider.notifier)
          .edit(
            entry,
            EntryDraft(
              platform: draft.platform,
              status: chosen,
              startedAt: draft.startedAt,
              finishedAt: draft.finishedAt,
              hoursPlayed: draft.hoursPlayed,
              rating: draft.rating,
              notes: draft.notes,
            ),
          );
      if (chosen == GameStatus.completed) {
        offerCelebration(messenger: messenger, router: router, entry: saved);
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text('${entry.game.name}: ${chosen.label}')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover registro?'),
        content: Text(
          'Isso apaga o registro de ${entry.game.name}: ${entry.platform} · '
          '${entry.status.label} · criado em '
          '${DateOnly.fromLocal(entry.createdAt.toLocal()).format()}. '
          'Seus outros registros do jogo continuam.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(libraryProvider.notifier).remove(entry);
      messenger.showSnackBar(
        const SnackBar(content: Text('Registro removido')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }
}
