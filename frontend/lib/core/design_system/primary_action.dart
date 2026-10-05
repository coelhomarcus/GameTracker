import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

/// Ação principal de uma tela: FAB estendido em janela estreita, botão no cabeçalho em larga.
/// Nunca os dois ao mesmo tempo; o corte é o mesmo da navegação (rail a partir de 600 dp).
///
/// Como os FABs de todos os destinos coexistem no `IndexedStack`, cada um precisa de [heroTag]
/// próprio. A lista abaixo do FAB deve reservar [fabClearance] no fim.
class PrimaryAction {
  const PrimaryAction({
    required this.heroTag,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final String heroTag;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  /// Espaço no fim da lista para o FAB não cobrir o último item.
  static const double fabClearance = 96;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= Breakpoints.medium;

  /// Para `Scaffold.floatingActionButton`; nulo em janela larga.
  Widget? fab(BuildContext context) => isWide(context)
      ? null
      : FloatingActionButton.extended(
          heroTag: heroTag,
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
        );

  /// Para `AppBar.actions`; nulo em janela estreita. Com [compact] vira só ícone, para cabeçalhos
  /// que não comportam o texto (o rótulo continua na dica e na semântica).
  Widget? headerButton(BuildContext context, {bool compact = false}) {
    if (!isWide(context)) return null;
    return Padding(
      padding: const EdgeInsets.only(right: Space.sm),
      child: compact
          ? IconButton.filled(
              tooltip: label,
              icon: Icon(icon),
              onPressed: onPressed,
            )
          : FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
            ),
    );
  }
}
