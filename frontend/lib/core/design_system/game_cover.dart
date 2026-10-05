import 'package:material_ui/material_ui.dart';

import '../network/image_url.dart';
import 'tokens.dart';

/// Capa com proporção fixa e fallback; sem salto de layout quando falta imagem.
class GameCover extends StatelessWidget {
  const GameCover({
    super.key,
    required this.name,
    this.url,
    this.radius = Radii.cover,
  });

  final String name;
  final String? url;
  final double radius;

  /// Largura máxima de decodificação: capas grandes não ocupam memória à toa.
  static const _decodeWidth = 420;
  static const _minWidthForName = 80.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolved = ImageUrls.resolve(url);
    // Em capas estreitas (miniaturas de lista) o nome ficaria ilegível e repetiria o título.
    final fallback = LayoutBuilder(
      builder: (context, constraints) => ColoredBox(
        color: scheme.secondaryContainer,
        child: Center(
          child: constraints.maxWidth < _minWidthForName
              ? Icon(Icons.sports_esports, color: scheme.onSecondaryContainer)
              : Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: scheme.onSecondaryContainer),
                  ),
                ),
        ),
      ),
    );
    return Semantics(
      label: 'Capa de $name',
      image: true,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: resolved == null
              ? fallback
              : Image.network(
                  resolved,
                  fit: BoxFit.cover,
                  cacheWidth: _decodeWidth,
                  errorBuilder: (_, _, _) => fallback,
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : fallback,
                ),
        ),
      ),
    );
  }
}
