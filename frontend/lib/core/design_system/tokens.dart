import 'package:material_ui/material_ui.dart';

/// Escala de espaçamento em unidades lógicas (docs/MIGRACAO_FLUTTER.md).
abstract final class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Raios de borda: capas, controles (botões, campos, chips) e cards.
abstract final class Radii {
  static const double cover = 8;
  static const double control = 12;
  static const double card = 16;
}

/// Larguras de corte (docs/MIGRACAO_FLUTTER.md).
abstract final class Breakpoints {
  static const double medium = 600;
  static const double expanded = 840;

  /// A partir daqui o rail de navegação mostra os textos.
  static const double railExtended = 1240;
}

/// Largura máxima do conteúdo de uma página; o texto não cresce com a janela, o espaço lateral sim.
abstract final class ContentWidth {
  /// Texto, formulários e conversas.
  static const double reading = 680;

  /// Biblioteca e perfil.
  static const double wide = 1200;
}

/// Durações das animações locais. Quando o sistema pede menos movimento, tudo vira instantâneo.
abstract final class Motion {
  static const Duration short = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 200);

  static Duration resolve(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}
