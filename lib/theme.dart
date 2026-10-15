import 'package:flutter/material.dart';

/// Cores do PocketStage Mídia. Tema escuro único.
class Cores {
  static const fundo = Color(0xFF090A0F);
  static const painel = Color(0xFF12141C);
  static const painel2 = Color(0xFF1E212D);
  static const painel3 = Color(0xFF272B38);
  static const linha = Color(0xFF2E3242);
  static const texto = Color(0xFFE2E4E9);
  static const textoFraco = Color(0xFF8B8F9E);
  static const textoApagado = Color(0xFF4A4E5E);

  /// Deixa ativa.
  static const ciano = Color(0xFF6FD3DF);
  static const cianoFundo = Color(0x2E6FD3DF);
  static const cianoEscuro = Color(0xFF0D1B1F);

  /// Telão.
  static const lilas = Color(0xFFE0A6F0);

  /// Aviso de fim.
  static const laranja = Color(0xFFFFB648);

  /// Destrutivo.
  static const vermelho = Color(0xFFFF6B6B);

  /// Tocando.
  static const verde = Color(0xFF3DDC84);

  /// Tinta sobre o ciano.
  static const tinta = Color(0xFF071417);
}

const String fonteMono = 'ChivoMono';

TextStyle mono({double size = 14, Color color = Cores.texto, FontWeight weight = FontWeight.w700}) => TextStyle(
      fontFamily: fonteMono,
      fontSize: size,
      color: color,
      fontWeight: weight,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

ThemeData temaPocketStage() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: 'Archivo',
    scaffoldBackgroundColor: Cores.fundo,
    colorScheme: const ColorScheme.dark(
      surface: Cores.painel,
      primary: Cores.ciano,
      onPrimary: Cores.tinta,
      secondary: Cores.lilas,
      error: Cores.vermelho,
      outline: Cores.linha,
    ),
  );
  return base.copyWith(
    splashFactory: NoSplash.splashFactory,
    hoverColor: Colors.transparent,
    dividerColor: Cores.linha,
    appBarTheme: const AppBarTheme(
      backgroundColor: Cores.fundo,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(fontFamily: 'Archivo', fontSize: 18, fontWeight: FontWeight.w800, color: Cores.texto),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Cores.painel, surfaceTintColor: Colors.transparent),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Cores.painel, surfaceTintColor: Colors.transparent),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Cores.painel3,
      contentTextStyle: TextStyle(fontFamily: 'Archivo', color: Cores.texto, fontSize: 14),
      behavior: SnackBarBehavior.floating,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Cores.painel2,
      isDense: true,
      border: OutlineInputBorder(borderSide: BorderSide(color: Cores.linha)),
      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Cores.linha)),
      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Cores.ciano)),
      labelStyle: TextStyle(color: Cores.textoFraco),
      hintStyle: TextStyle(color: Cores.textoApagado),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Cores.tinta : Cores.textoFraco),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Cores.ciano : Cores.painel3),
    ),
    sliderTheme: const SliderThemeData(activeTrackColor: Cores.ciano, thumbColor: Cores.ciano, inactiveTrackColor: Cores.painel3),
  );
}
