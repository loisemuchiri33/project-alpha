import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ZENI Ops design system — light + premium OLED-friendly dark.
class ZeniOpsTheme {
  static const Color brand = Color(0xFF0B6E4F);
  static const Color brandBright = Color(0xFF14B87A);
  static const Color brandDeep = Color(0xFF064E3B);

  // Dark surfaces (deep charcoal, not pure black — reduces smear on LCD/OLED)
  static const Color darkBg = Color(0xFF0B0F14);
  static const Color darkSurface = Color(0xFF141A22);
  static const Color darkCard = Color(0xFF1A222D);
  static const Color darkElevated = Color(0xFF222B38);
  static const Color darkBorder = Color(0xFF2A3444);
  static const Color darkMuted = Color(0xFF8B9BB0);
  static const Color darkText = Color(0xFFE8EEF6);

  static const Color lightBg = Color(0xFFF4F7F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);

  static ThemeData get light {
    final base = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: Brightness.light,
      primary: brand,
      surface: lightSurface,
    );
    final text = GoogleFonts.interTextTheme().apply(
      bodyColor: const Color(0xFF0F172A),
      displayColor: const Color(0xFF0F172A),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: base,
      scaffoldBackgroundColor: lightBg,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: lightSurface,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: lightBorder),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: lightSurface,
        selectedIconTheme: const IconThemeData(color: brand),
        selectedLabelTextStyle: const TextStyle(color: brand, fontWeight: FontWeight.w600, fontSize: 12),
        unselectedIconTheme: IconThemeData(color: Colors.grey.shade600),
        indicatorColor: brand.withOpacity(0.12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brand, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: brand.withOpacity(0.1),
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerColor: lightBorder,
      dataTableTheme: DataTableThemeData(
        headingTextStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        dataTextStyle: text.bodyMedium,
      ),
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: brandBright,
      onPrimary: const Color(0xFF003824),
      primaryContainer: brandDeep,
      onPrimaryContainer: const Color(0xFFA7F3D0),
      secondary: const Color(0xFF5EEAD4),
      onSecondary: const Color(0xFF00382F),
      secondaryContainer: const Color(0xFF0F766E),
      onSecondaryContainer: const Color(0xFFCCFBF1),
      tertiary: const Color(0xFFFBBF24),
      onTertiary: const Color(0xFF422006),
      error: const Color(0xFFF87171),
      onError: const Color(0xFF450A0A),
      surface: darkSurface,
      onSurface: darkText,
      surfaceContainerHighest: darkElevated,
      onSurfaceVariant: darkMuted,
      outline: darkBorder,
      outlineVariant: const Color(0xFF1F2937),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: darkText,
      onInverseSurface: darkBg,
      inversePrimary: brand,
    );

    final baseText = GoogleFonts.interTextTheme(ThemeData(brightness: Brightness.dark).textTheme);
    final text = baseText.apply(bodyColor: darkText, displayColor: darkText);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: darkBg,
      canvasColor: darkBg,
      cardColor: darkCard,
      dialogBackgroundColor: darkCard,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: darkText),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: darkSurface,
        selectedIconTheme: const IconThemeData(color: brandBright),
        unselectedIconTheme: const IconThemeData(color: darkMuted),
        selectedLabelTextStyle: const TextStyle(color: brandBright, fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelTextStyle: const TextStyle(color: darkMuted, fontSize: 12),
        indicatorColor: brandBright.withOpacity(0.14),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkElevated,
        hintStyle: const TextStyle(color: darkMuted),
        labelStyle: const TextStyle(color: darkMuted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brandBright, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brandBright,
          foregroundColor: const Color(0xFF003824),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: brandBright),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: brandBright.withOpacity(0.12),
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: brandBright),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerColor: darkBorder,
      dividerTheme: const DividerThemeData(color: darkBorder, thickness: 1),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(darkElevated),
        dataRowColor: WidgetStateProperty.all(darkCard),
        headingTextStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: darkMuted),
        dataTextStyle: text.bodyMedium?.copyWith(color: darkText),
        dividerThickness: 0.5,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkElevated,
        contentTextStyle: const TextStyle(color: darkText),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      iconTheme: const IconThemeData(color: darkMuted),
      listTileTheme: const ListTileThemeData(
        iconColor: darkMuted,
        textColor: darkText,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder),
        ),
      ),
    );
  }
}
