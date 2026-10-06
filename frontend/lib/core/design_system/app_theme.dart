import 'package:material_ui/material_ui.dart';

import 'game_status.dart';
import 'tokens.dart';

abstract final class AppTheme {
  /// Violeta da identidade; todas as cores da interface saem do esquema gerado a partir dele.
  static const seed = Color(0xFF5D4FE3);

  static ThemeData light({String? fontFamily}) =>
      _build(Brightness.light, DomainColors.light, fontFamily);
  static ThemeData dark({String? fontFamily}) =>
      _build(Brightness.dark, DomainColors.dark, fontFamily);

  /// Papéis tipográficos (tamanho/altura de linha). Não há escala fixa: o texto segue o sistema.
  ///
  /// - título de página 28/34: `headlineMedium`
  /// - título de seção 20/28: `titleLarge`
  /// - título de item 16/24: `titleMedium`
  /// - corpo 16/24: `bodyLarge`
  /// - metadado 14/20: `bodyMedium`
  /// - rótulo auxiliar 12/16: `labelSmall`
  static const _textTheme = TextTheme(
    headlineMedium: TextStyle(
      fontSize: 28,
      height: 34 / 28,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      height: 28 / 20,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 24 / 16),
    bodyMedium: TextStyle(fontSize: 14, height: 20 / 14),
    labelSmall: TextStyle(fontSize: 12, height: 16 / 12),
  );

  static ThemeData _build(
    Brightness brightness,
    DomainColors domain,
    String? fontFamily,
  ) {
    final generated = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final scheme = generated.copyWith(
      // A identidade fica nas ações e seleções. As superfícies são neutras para que capas e
      // conteúdo tenham prioridade, sem transformar toda a página em um grande bloco violeta.
      surface: brightness == Brightness.light
          ? const Color(0xFFF9F8FC)
          : const Color(0xFF121216),
      surfaceDim: brightness == Brightness.light
          ? const Color(0xFFDDDCE2)
          : const Color(0xFF121216),
      surfaceBright: brightness == Brightness.light
          ? const Color(0xFFFDFBFF)
          : const Color(0xFF39383E),
      surfaceContainerLowest: brightness == Brightness.light
          ? const Color(0xFFFFFFFF)
          : const Color(0xFF0D0D10),
      surfaceContainerLow: brightness == Brightness.light
          ? const Color(0xFFF5F3F8)
          : const Color(0xFF1A191E),
      surfaceContainer: brightness == Brightness.light
          ? const Color(0xFFEFEDF2)
          : const Color(0xFF1E1D22),
      surfaceContainerHigh: brightness == Brightness.light
          ? const Color(0xFFE9E7EC)
          : const Color(0xFF29272E),
      surfaceContainerHighest: brightness == Brightness.light
          ? const Color(0xFFE3E1E6)
          : const Color(0xFF34313A),
      outlineVariant: brightness == Brightness.light
          ? const Color(0xFFC9C5CF)
          : const Color(0xFF49464F),
    );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.control),
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      useMaterial3: true,
      extensions: [domain],
      textTheme: fontFamily == null
          ? _textTheme
          : _textTheme.apply(fontFamily: fontFamily),
      visualDensity: VisualDensity.standard,
      // Alvo de toque de 48 dp também no web/desktop, onde o padrão do Material é menor.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      focusColor: scheme.primary.withValues(alpha: 0.18),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.control),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.control),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHighest),
        elevation: const WidgetStatePropertyAll(0),
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.focused)
                ? scheme.primary
                : scheme.outlineVariant,
            width: states.contains(WidgetState.focused) ? 2 : 1,
          ),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.control),
          ),
        ),
      ),
      // Sem sombra: a separação vem da cor da superfície e de um contorno discreto.
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        // O mesmo alinhamento à esquerda em qualquer plataforma.
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.secondaryContainer,
        labelPadding: EdgeInsets.zero,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            height: 1.2,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.secondaryContainer,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(shape: controlShape),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: controlShape),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: controlShape),
      ),
      chipTheme: ChipThemeData(shape: controlShape),
      // Cinco destinos em 360 dp: com o corpo padrão (12 sp) "Comunidade" quebrava no meio da
      // palavra. 11 sp cabe sem cortar e continua acompanhando a escala de texto do sistema.
      // Três abas de largura igual: "Meu progresso" não cabe com o recuo padrão (16 dp) em 360 dp.
      tabBarTheme: const TabBarThemeData(
        labelPadding: EdgeInsets.symmetric(horizontal: Space.xs),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: controlShape,
      ),
    );
  }
}
