import 'package:flutter/material.dart';

class AppColors {
  static const paper = Color(0xFFF7F8EF);
  static const ink = Color(0xFF2B3520);
  static const muted = Color(0xFF656D57);
  static const saffron = Color(0xFFFF7200);
  static const pist = Color(0xFF648C16);
  static const olive = Color(0xFF476600);
  static const line = Color(0xFFE2E5D5);
  static const card = Colors.white;
}

const String kTitleFont = 'Lalezar';

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.saffron,
    primary: AppColors.saffron,
    secondary: AppColors.pist,
    surface: AppColors.paper,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Vazirmatn',
    scaffoldBackgroundColor: AppColors.paper,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.paper,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    textTheme: const TextTheme().apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.saffron : null,
      ),
    ),
  );
}
