import 'package:material_ui/material_ui.dart';

/// Capa com proporção fixa e fallback; sem salto de layout quando falta imagem.
class GameCover extends StatelessWidget {
  const GameCover({super.key, required this.name, this.url, this.radius = 12});

  final String name;
  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = ColoredBox(
      color: scheme.secondaryContainer,
      child: Center(
        child: Padding(
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
    );
    return Semantics(
      label: 'Capa de $name',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: url == null
              ? fallback
              : Image.network(
                  url!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }
}
