import 'package:material_ui/material_ui.dart';

import 'game_cover.dart';
import 'tokens.dart';

/// Item compacto de prateleira: a capa nunca aparece sem nome e contexto.
class GameShelfItem extends StatelessWidget {
  const GameShelfItem({
    super.key,
    required this.title,
    required this.caption,
    this.coverUrl,
    this.onTap,
  });

  final String title;
  final String caption;
  final String? coverUrl;
  final VoidCallback? onTap;

  /// Altura necessária quando a prateleira usa um viewport horizontal de extensão fixa.
  static double extent(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final text = Theme.of(context).textTheme;
    double line(TextStyle? style) {
      final fontSize = style?.fontSize ?? 14;
      return scaler.scale(fontSize) * (style?.height ?? 1);
    }

    final copy = line(text.titleMedium) * 2 + Space.xs + line(text.bodyMedium);
    const cover = 56 * 4 / 3;
    // Padding interno do card e a margem padrão do próprio Card.
    return (copy > cover ? copy : cover) + Space.xl + Space.sm;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: onTap != null,
      label: '$title, $caption',
      onTap: onTap,
      excludeSemantics: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 56,
                  child: GameCover(name: title, url: coverUrl),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: Space.xs),
                      Text(
                        caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
