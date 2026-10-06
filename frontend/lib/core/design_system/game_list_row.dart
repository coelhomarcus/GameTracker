import 'package:material_ui/material_ui.dart';

import 'game_cover.dart';
import 'game_status.dart';
import 'status_chip.dart';
import 'tokens.dart';

/// Linha de coleção com capa, identificação, metadados e uma ação independente.
class GameListRow extends StatelessWidget {
  const GameListRow({
    super.key,
    required this.title,
    required this.status,
    required this.metadata,
    this.coverUrl,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? coverUrl;

  /// `null` representa vários status.
  final GameStatus? status;
  final List<String> metadata;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final meta = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Radii.control),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 56,
                    child: GameCover(
                      name: title,
                      url: coverUrl,
                      radius: Radii.cover,
                    ),
                  ),
                  const SizedBox(width: Space.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: Space.xs),
                        Wrap(
                          spacing: Space.sm,
                          runSpacing: Space.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            status == null
                                ? const StatusChip.mixed()
                                : StatusChip(status!),
                            for (final value in metadata)
                              Text(value, style: meta),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
