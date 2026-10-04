import 'package:material_ui/material_ui.dart';

import 'game_status.dart';
import 'tokens.dart';

/// Status com cor, ícone e texto: cor sozinha nunca carrega o significado.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final GameStatus status;

  @override
  Widget build(BuildContext context) {
    final color = context.domainColors.forStatus(status);
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
          Icon(status.icon, size: 14, color: color),
          const SizedBox(width: Space.xs),
          Flexible(
            child: Text(
              status.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
