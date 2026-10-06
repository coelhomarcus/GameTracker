import 'package:material_ui/material_ui.dart';

import 'game_card.dart';
import 'tokens.dart';

/// Bloco cinza que ocupa o lugar de um conteúdo ainda não carregado. Não anima: o esqueleto
/// mantém a proporção do conteúdo final e não pede "menos movimento" ao sistema.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.radius = Radii.cover,
  });

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: SizedBox(width: width, height: height),
    );
  }
}

/// Esqueleto de lista (capa pequena + duas linhas) ou de grade (capas 3:4 com título).
class ContentSkeleton extends StatelessWidget {
  const ContentSkeleton.list({super.key, this.itemCount = 6}) : grid = false;
  const ContentSkeleton.grid({super.key, this.itemCount = 6}) : grid = true;

  final int itemCount;
  final bool grid;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Carregando',
      child: ExcludeSemantics(child: grid ? _grid(context) : _list()),
    );
  }

  Widget _list() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      itemCount: itemCount,
      itemBuilder: (context, _) => const Padding(
        padding: EdgeInsets.symmetric(vertical: Space.sm),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: AspectRatio(aspectRatio: 3 / 4, child: SkeletonBox()),
            ),
            SizedBox(width: Space.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(height: 16),
                  SizedBox(height: Space.sm),
                  FractionallySizedBox(
                    widthFactor: 0.5,
                    child: SkeletonBox(height: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final geometry = GameGridGeometry.resolve(
          context,
          constraints.maxWidth,
        );
        final rows = (itemCount / geometry.columns).ceil();
        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: Space.sm),
          itemCount: rows,
          itemBuilder: (context, row) => Padding(
            padding: const EdgeInsets.only(bottom: Space.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < geometry.columns; c++) ...[
                  if (c > 0) const SizedBox(width: GameGridGeometry.spacing),
                  Expanded(
                    child: row * geometry.columns + c < itemCount
                        ? _GridTileSkeleton(geometry: geometry)
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GridTileSkeleton extends StatelessWidget {
  const _GridTileSkeleton({required this.geometry});

  final GameGridGeometry geometry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AspectRatio(aspectRatio: 3 / 4, child: SkeletonBox()),
        const SizedBox(height: Space.sm),
        SkeletonBox(height: geometry.titleExtent),
        const SizedBox(height: Space.xs),
        SkeletonBox(width: 84, height: geometry.statusExtent),
        const SizedBox(height: Space.xs),
        FractionallySizedBox(
          widthFactor: 0.65,
          child: SkeletonBox(height: geometry.captionExtent),
        ),
      ],
    );
  }
}
