import 'package:material_ui/material_ui.dart';

import 'game_status.dart';

abstract final class AppTheme {
  /// Violeta inicial; a identidade final é validada na Etapa 1 (docs/MIGRACAO_FLUTTER.md, decisão 7).
  static const seed = Color(0xFF5D4FE3);

  static ThemeData light() => _build(Brightness.light, DomainColors.light);
  static ThemeData dark() => _build(Brightness.dark, DomainColors.dark);

  static ThemeData _build(Brightness brightness, DomainColors domain) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      extensions: [domain],
      visualDensity: VisualDensity.standard,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      cardTheme: const CardThemeData(margin: EdgeInsets.zero),
    );
  }
}
