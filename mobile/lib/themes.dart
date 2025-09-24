import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Border radius
  static const double borderRadius = 8.0; // --radius: 0.65rem ≈ 8px

  // Light theme colors
  static const Color lightBackground = Color(0xFFFFFFFF); // --background
  static const Color lightForeground = Color(0xFF1C2526); // --foreground
  static const Color lightCard = Color(0xFFFFFFFF); // --card
  static const Color lightCardForeground = Color(
    0xFF1C2526,
  ); // --card-foreground
  static const Color lightPrimary = Color(0xFF2ECC71); // --primary
  static const Color lightPrimaryForeground = Color(
    0xFFF5F7F5,
  ); // --primary-foreground
  static const Color lightSecondary = Color(0xFFF5F6F5); // --secondary
  static const Color lightSecondaryForeground = Color(
    0xFF2E3638,
  ); // --secondary-foreground
  static const Color lightMuted = Color(0xFFF5F6F5); // --muted
  static const Color lightMutedForeground = Color(
    0xFF7F888A,
  ); // --muted-foreground
  static const Color lightAccent = Color(0xFFF5F6F5); // --accent
  static const Color lightAccentForeground = Color(
    0xFF2E3638,
  ); // --accent-foreground
  static const Color lightDestructive = Color(0xFFB91C1C); // --destructive
  static const Color lightBorder = Color(0xFFE8EAEB); // --border
  static const Color lightInput = Color(0xFFE8EAEB); // --input
  static const Color lightRing = Color(0xFF2ECC71); // --ring

  // Dark theme colors
  static const Color darkBackground = Color(0xFF1C2526); // --background
  static const Color darkForeground = Color(0xFFF5F7F5); // --foreground
  static const Color darkCard = Color(0xFF2E3638); // --card
  static const Color darkCardForeground = Color(
    0xFFF5F7F5,
  ); // --card-foreground
  static const Color darkPrimary = Color(0xFF34C759); // --primary
  static const Color darkPrimaryForeground = Color(
    0xFF1A3C34,
  ); // --primary-foreground
  static const Color darkSecondary = Color(0xFF3E4648); // --secondary
  static const Color darkSecondaryForeground = Color(
    0xFFF5F7F5,
  ); // --secondary-foreground
  static const Color darkMuted = Color(0xFF3E4648); // --muted
  static const Color darkMutedForeground = Color(
    0xFFA8B0B2,
  ); // --muted-foreground
  static const Color darkAccent = Color(0xFF3E4648); // --accent
  static const Color darkAccentForeground = Color(
    0xFFF5F7F5,
  ); // --accent-foreground
  static const Color darkDestructive = Color(0xFFD33F49); // --destructive
  static const Color darkBorder = Color(0x26FFFFFF); // --border
  static const Color darkInput = Color(0x3DFFFFFF); // --input
  static const Color darkRing = Color(0xFF1A8B4A); // --ring

  // Light theme
  static ThemeData lightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        background: lightBackground,
        onBackground: lightForeground,
        surface: lightCard,
        onSurface: lightCardForeground,
        primary: lightPrimary,
        onPrimary: lightPrimaryForeground,
        secondary: lightSecondary,
        onSecondary: lightSecondaryForeground,
        surfaceVariant: lightMuted,
        onSurfaceVariant: lightMutedForeground,
        error: lightDestructive,
        outline: lightBorder,
        outlineVariant: lightInput,
        scrim: lightRing,
      ),
      textTheme: GoogleFonts.ibmPlexMonoTextTheme().copyWith(
        displayLarge: GoogleFonts.ibmPlexMono(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: lightCardForeground,
        ),
        bodyMedium: GoogleFonts.ibmPlexMono(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: lightCardForeground,
        ),
        labelMedium: GoogleFonts.ibmPlexMono(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: lightMutedForeground,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: lightPrimaryForeground,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: lightAccent,
          textStyle: GoogleFonts.ibmPlexMono(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: lightInput),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: lightRing),
        ),
        labelStyle: GoogleFonts.ibmPlexMono(color: lightMutedForeground),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: lightMuted,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: const BorderSide(color: lightBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: const BorderSide(color: lightInput),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: const BorderSide(color: lightRing),
          ),
          labelStyle: GoogleFonts.ibmPlexMono(color: lightMutedForeground),
        ),
        textStyle: GoogleFonts.ibmPlexMono(color: lightCardForeground),
      ),
      scaffoldBackgroundColor: lightBackground,
      cardColor: lightCard,
      dividerColor: lightBorder,
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: lightRing,
      ),
    );
  }

  // Dark theme
  static ThemeData darkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        background: darkBackground,
        onBackground: darkForeground,
        surface: darkCard,
        onSurface: darkCardForeground,
        primary: darkPrimary,
        onPrimary: darkPrimaryForeground,
        secondary: darkSecondary,
        onSecondary: darkSecondaryForeground,
        surfaceVariant: darkMuted,
        onSurfaceVariant: darkMutedForeground,
        error: darkDestructive,
        outline: darkBorder,
        outlineVariant: darkInput,
        scrim: darkRing,
      ),
      textTheme: GoogleFonts.ibmPlexMonoTextTheme().copyWith(
        displayLarge: GoogleFonts.ibmPlexMono(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: darkCardForeground,
        ),
        bodyMedium: GoogleFonts.ibmPlexMono(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: darkCardForeground,
        ),
        labelMedium: GoogleFonts.ibmPlexMono(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: darkMutedForeground,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: darkPrimaryForeground,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkAccent,
          textStyle: GoogleFonts.ibmPlexMono(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: darkInput),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: darkRing),
        ),
        labelStyle: GoogleFonts.ibmPlexMono(color: darkMutedForeground),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: darkMuted,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: const BorderSide(color: darkBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: const BorderSide(color: darkInput),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: const BorderSide(color: darkRing),
          ),
          labelStyle: GoogleFonts.ibmPlexMono(color: darkMutedForeground),
        ),
        textStyle: GoogleFonts.ibmPlexMono(color: darkCardForeground),
      ),
      scaffoldBackgroundColor: darkBackground,
      cardColor: darkCard,
      dividerColor: darkBorder,
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: darkRing),
    );
  }
}
