import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../library/data/game_entry.dart';
import 'create_post_page.dart';

/// Depois de concluir um jogo, convida (sem obrigar) a contar para a comunidade. Só deve ser
/// chamado depois de o servidor confirmar a alteração: a publicação é um ato voluntário e é
/// distinta da atividade automática que o backend já cria.
void offerCelebration({
  required ScaffoldMessengerState messenger,
  required GoRouter router,
  required GameEntry entry,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          '${entry.game.name}: concluído! Quer contar para a comunidade?',
        ),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Publicar',
          onPressed: () => router.push(
            '/posts/new?entryId=${Uri.encodeQueryComponent(entry.id)}&text=${Uri.encodeQueryComponent(celebrationText(entry.game.name))}',
          ),
        ),
      ),
    );
}
