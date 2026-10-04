import 'package:material_ui/material_ui.dart';

import '../network/image_url.dart';

/// Avatar com fallback de inicial; nunca quebra se a imagem falha ou não existe.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.name, this.url, this.radius = 20});

  final String name;
  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolved = ImageUrls.resolve(url);
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().characters.first.toUpperCase();
    final fallback = Text(
      initial,
      style: TextStyle(
        color: scheme.onPrimaryContainer,
        fontSize: radius * 0.9,
        fontWeight: FontWeight.w600,
      ),
    );
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: radius,
        backgroundColor: scheme.primaryContainer,
        foregroundImage: resolved == null ? null : NetworkImage(resolved),
        onForegroundImageError: resolved == null ? null : (_, _) {},
        child: fallback,
      ),
    );
  }
}
