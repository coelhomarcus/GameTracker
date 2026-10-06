import 'package:material_ui/material_ui.dart';

import 'game_cover.dart';
import 'tokens.dart';

/// Linha de catálogo/seletor: capa, identificação e ação independente.
class GameCatalogRow extends StatelessWidget {
  const GameCatalogRow({
    super.key,
    required this.title,
    required this.caption,
    this.coverUrl,
    this.action,
    this.onTap,
    this.stackActionOnCompact = true,
  });

  final String title;
  final String caption;
  final String? coverUrl;
  final Widget? action;
  final VoidCallback? onTap;
  final bool stackActionOnCompact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final main = Semantics(
      button: onTap != null,
      label: '$title, $caption',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.control),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.md),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: GameCover(name: title, url: coverUrl),
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
                    Text(
                      caption,
                      maxLines: 2,
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
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final stacked =
            action != null &&
            stackActionOnCompact &&
            (constraints.maxWidth < 520 || scale >= 1.5);
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              main,
              Align(alignment: Alignment.centerLeft, child: action!),
              const SizedBox(height: Space.sm),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: main),
            if (action != null) ...[const SizedBox(width: Space.sm), action!],
          ],
        );
      },
    );
  }
}
