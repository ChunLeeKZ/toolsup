import 'package:flutter/material.dart';

class ToolsupPalette {
  static const ink = Color(0xFF021326);
  static const navy = Color(0xFF061D31);
  static const navyCard = Color(0xFF0B2A43);
  static const border = Color(0xFF2C5570);
  static const gold = Color(0xFFFFD21F);
  static const goldSoft = Color(0xFFFFE88A);
  static const sky = Color(0xFF5EC7F3);
  static const text = Color(0xFFF7FBFF);
  static const mutedText = Color(0xFFC7D6E6);
}

ThemeData buildToolsupTheme() {
  const colors = ColorScheme.dark(
    primary: ToolsupPalette.gold,
    onPrimary: ToolsupPalette.ink,
    primaryContainer: Color(0xFF5B4700),
    onPrimaryContainer: ToolsupPalette.goldSoft,
    secondary: ToolsupPalette.sky,
    onSecondary: ToolsupPalette.ink,
    secondaryContainer: Color(0xFF0F4666),
    onSecondaryContainer: Color(0xFFD9F3FF),
    tertiary: ToolsupPalette.goldSoft,
    onTertiary: ToolsupPalette.ink,
    surface: ToolsupPalette.ink,
    onSurface: ToolsupPalette.text,
    surfaceContainerHighest: ToolsupPalette.navyCard,
    onSurfaceVariant: ToolsupPalette.mutedText,
    outline: ToolsupPalette.border,
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
  );

  return ThemeData(
    colorScheme: colors,
    scaffoldBackgroundColor: ToolsupPalette.ink,
    appBarTheme: const AppBarTheme(
      backgroundColor: ToolsupPalette.ink,
      foregroundColor: ToolsupPalette.text,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: ToolsupPalette.navyCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: ToolsupPalette.border),
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: ToolsupPalette.border,
      thickness: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ToolsupPalette.navy,
      labelStyle: const TextStyle(color: ToolsupPalette.mutedText),
      prefixIconColor: ToolsupPalette.sky,
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: ToolsupPalette.border),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: ToolsupPalette.gold, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFFFB4AB)),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFFFB4AB), width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ToolsupPalette.gold,
        foregroundColor: ToolsupPalette.ink,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ToolsupPalette.sky,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    useMaterial3: true,
  );
}
