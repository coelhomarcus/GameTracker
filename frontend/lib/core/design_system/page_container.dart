import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

/// Largura máxima do conteúdo da página.
enum PageWidth {
  reading(ContentWidth.reading),
  wide(ContentWidth.wide);

  const PageWidth(this.maxWidth);

  final double maxWidth;
}

/// Centraliza o conteúdo com largura máxima e margem lateral de 16 (estreito) ou 24 (largo).
/// O texto não aumenta com a janela: sobra espaço dos lados.
class PageContainer extends StatelessWidget {
  const PageContainer({
    super.key,
    required this.child,
    this.width = PageWidth.reading,
  });

  final Widget child;
  final PageWidth width;

  /// Margem lateral mínima para a largura disponível (já descontado o rail de navegação).
  static double gutterFor(double availableWidth) =>
      availableWidth < Breakpoints.medium ? Space.lg : Space.xl;

  /// Recuo horizontal que centraliza um conteúdo de [width]. Serve para listas que precisam
  /// rolar na largura inteira (a barra de rolagem fica na borda) e manter o conteúdo centralizado.
  static EdgeInsets insetsFor(double availableWidth, PageWidth width) {
    final gutter = gutterFor(availableWidth);
    final side = (availableWidth - width.maxWidth) / 2;
    return EdgeInsets.symmetric(horizontal: side > gutter ? side : gutter);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: insetsFor(constraints.maxWidth, width),
        child: child,
      ),
    );
  }
}
