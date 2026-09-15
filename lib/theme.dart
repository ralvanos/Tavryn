import 'package:flutter/material.dart';

/// Dusk ink + ember copper. Eating-window accents use dawn teal.
class TavrynColors {
  TavrynColors._();

  static const Color ink = Color(0xFF07080C);
  static const Color inkElevated = Color(0xFF101218);
  static const Color surface = Color(0xFF161822);
  static const Color card = Color(0xFF1C1F2B);
  static const Color ember = Color(0xFFE8A05A);
  static const Color emberDeep = Color(0xFFC47A32);
  static const Color dawn = Color(0xFF6EC8C0);
  static const Color dusk = Color(0xFF8B7CFF);
  static const Color danger = Color(0xFFE85D5D);
  static const Color onInk = Color(0xFFF4F1EA);
}

class TavrynTheme {
  TavrynTheme._();

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: TavrynColors.ember,
      secondary: TavrynColors.dawn,
      tertiary: TavrynColors.dusk,
      surface: TavrynColors.ink,
      error: TavrynColors.danger,
      onPrimary: Color(0xFF1A1208),
      onSecondary: Color(0xFF041614),
      onSurface: TavrynColors.onInk,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: TavrynColors.ink,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: TavrynColors.onInk,
        centerTitle: false,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: TavrynColors.card,
        contentTextStyle: const TextStyle(color: TavrynColors.onInk),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: TavrynColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: TavrynColors.card,
        headerForegroundColor: TavrynColors.onInk,
        dayForegroundColor: const WidgetStatePropertyAll(TavrynColors.onInk),
        todayForegroundColor: const WidgetStatePropertyAll(TavrynColors.ember),
        todayBackgroundColor: WidgetStatePropertyAll(
          TavrynColors.ember.withValues(alpha: 0.18),
        ),
      ),
      timePickerTheme: const TimePickerThemeData(
        backgroundColor: TavrynColors.card,
        hourMinuteColor: TavrynColors.surface,
        hourMinuteTextColor: TavrynColors.onInk,
        dialBackgroundColor: TavrynColors.surface,
        dialHandColor: TavrynColors.ember,
        dialTextColor: TavrynColors.onInk,
        entryModeIconColor: TavrynColors.ember,
        helpTextStyle: TextStyle(color: TavrynColors.ember),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: TavrynColors.inkElevated,
        selectedItemColor: TavrynColors.ember,
        unselectedItemColor: Color(0x99F4F1EA),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      scrollbarTheme: const ScrollbarThemeData(
        thickness: WidgetStatePropertyAll(0),
        thumbVisibility: WidgetStatePropertyAll(false),
        trackVisibility: WidgetStatePropertyAll(false),
        interactive: false,
      ),
    );
  }
}
