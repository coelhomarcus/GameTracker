import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

/// Destino ainda sem implementação: diz qual etapa o entrega, sem fingir dados.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    required this.icon,
    required this.message,
  });

  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: Space.lg),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

/// Só o corpo (para uso dentro de abas), sem Scaffold próprio.
class PlaceholderBody extends StatelessWidget {
  const PlaceholderBody({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: Space.lg),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
