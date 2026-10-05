import 'package:material_ui/material_ui.dart';

import 'game_status.dart';
import 'tokens.dart';

/// Status com cor, ícone e texto: cor sozinha nunca carrega o significado.
class StatusChip extends StatelessWidget {
  const StatusChip(GameStatus this.status, {super.key});

  /// Vários registros do mesmo jogo com status diferentes: ícone e cor neutros.
  const StatusChip.mixed({super.key}) : status = null;

  final GameStatus? status;

  @override
  Widget build(BuildContext context) {
    final color = status == null
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : context.domainColors.forStatus(status!);
    // O fundo é a própria cor a 14%: o texto puxa um pouco para a cor do conteúdo para manter
    // 4,5:1 em 12 px. O ícone fica na cor pura do status.
    final textColor = Color.lerp(
      color,
      Theme.of(context).colorScheme.onSurface,
      0.35,
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.sm,
        vertical: Space.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Space.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status?.icon ?? Icons.layers_outlined, size: 14, color: color),
          const SizedBox(width: Space.xs),
          Flexible(
            child: Text(
              status?.label ?? 'Vários status',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: textColor, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
