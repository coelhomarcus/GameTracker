/// Escala de espaçamento em unidades lógicas (plano, seção 4.2).
abstract final class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Larguras de corte (plano, seção 4.5).
abstract final class Breakpoints {
  static const double medium = 600;
  static const double expanded = 840;
}
