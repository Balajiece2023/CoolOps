import 'package:flutter/material.dart';

class AppTheme {
  // Brand Color Palette (Deep Ice & Professional HVAC Navy)
  static const Color primaryBlue = Color(0xFF0284C7);      // Sky 600
  static const Color primaryDark = Color(0xFF0369A1);      // Sky 700
  static const Color primaryLight = Color(0xFF38BDF8);     // Sky 400
  static const Color navyBackground = Color(0xFF0F172A);   // Slate 900
  static const Color surfaceCardDark = Color(0xFF1E293B);  // Slate 800
  static const Color cardBorderDark = Color(0xFF334155);   // Slate 700
  static const Color accentTeal = Color(0xFF0D9488);       // Teal 600
  static const Color accentAmber = Color(0xFFF59E0B);      // Amber 500
  static const Color accentEmerald = Color(0xFF10B981);    // Emerald 500
  static const Color accentRose = Color(0xFFF43F5E);       // Rose 500

  // Neutral Colors
  static const Color neutral50 = Color(0xFFF8FAFC);
  static const Color neutral100 = Color(0xFFF1F5F9);
  static const Color neutral200 = Color(0xFFE2E8F0);
  static const Color neutral300 = Color(0xFFCBD5E1);
  static const Color neutral500 = Color(0xFF64748B);
  static const Color neutral700 = Color(0xFF334155);
  static const Color neutral900 = Color(0xFF0F172A);

  // Modern Light Theme
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.light,
      primary: primaryBlue,
      onPrimary: Colors.white,
      secondary: accentTeal,
      surface: Colors.white,
      onSurface: neutral900,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: neutral50,
      surfaceContainer: neutral100,
      outlineVariant: neutral200,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: neutral900),
        titleTextStyle: TextStyle(
          color: neutral900,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 3,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primaryBlue.withOpacity(0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryBlue);
          }
          return const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: neutral500);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryBlue, size: 24);
          }
          return const IconThemeData(color: neutral500, size: 22);
        }),
      ),
    );
  }

  // Spotify-Inspired Ultra Premium Dark Theme (#121212 background, #181818 surface, #282828 cards, high-contrast crisp white typography)
  static const Color spotifyBlack = Color(0xFF121212);
  static const Color spotifySurface = Color(0xFF181818);
  static const Color spotifyCard = Color(0xFF242424);
  static const Color spotifyCardHover = Color(0xFF2A2A2A);
  static const Color spotifyBorder = Color(0xFF333333);
  static const Color spotifyGreen = Color(0xFF1DB954);
  static const Color textHighEmphasis = Color(0xFFFFFFFF);
  static const Color textMediumEmphasis = Color(0xFFB3B3B3);
  static const Color textSubdued = Color(0xFF727272);

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.dark,
      primary: primaryLight,
      onPrimary: spotifyBlack,
      secondary: spotifyGreen,
      surface: spotifySurface,
      onSurface: textHighEmphasis,
      onSurfaceVariant: textMediumEmphasis,
      surfaceContainerLowest: spotifyBlack,
      surfaceContainerLow: spotifySurface,
      surfaceContainer: spotifyCard,
      surfaceContainerHigh: spotifyCardHover,
      outline: spotifyBorder,
      outlineVariant: Color(0xFF2E2E2E),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: spotifyBlack,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: textHighEmphasis, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: textHighEmphasis, fontWeight: FontWeight.bold),
        headlineSmall: TextStyle(color: textHighEmphasis, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: textHighEmphasis, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: textHighEmphasis, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: textHighEmphasis, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: textHighEmphasis),
        bodyMedium: TextStyle(color: textMediumEmphasis),
        bodySmall: TextStyle(color: textSubdued),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: spotifyBlack,
        elevation: 0,
        scrolledUnderElevation: 2,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: textHighEmphasis),
        titleTextStyle: TextStyle(
          color: textHighEmphasis,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: spotifyCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: spotifyBorder, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: spotifySurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: spotifyBorder, width: 1),
        ),
        titleTextStyle: const TextStyle(
          color: textHighEmphasis,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(
          color: textMediumEmphasis,
          fontSize: 14,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: spotifyCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: textSubdued),
        labelStyle: const TextStyle(color: textMediumEmphasis),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: spotifyBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: spotifyBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryLight, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: spotifyBlack,
        elevation: 4,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primaryLight.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryLight);
          }
          return const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: textSubdued);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryLight, size: 24);
          }
          return const IconThemeData(color: textSubdued, size: 22);
        }),
      ),
    );
  }
}
