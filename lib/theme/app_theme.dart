import 'package:flutter/material.dart';

/// The app's earthy pastel palette — warm terracotta, muted sage, and
/// dusty ochre — seeded into Material 3's color system so every built-in
/// widget (buttons, chips, app bars, dialogs, ...) picks it up
/// automatically. Since screens throughout the app pull their colors from
/// `Theme.of(context).colorScheme` rather than hardcoding any, this one
/// place controls the look of the whole app.
class AppTheme {
  AppTheme._();

  static const _terracottaSeed = Color(0xFFB2764F);

  static ThemeData light() => _theme(Brightness.light);
  static ThemeData dark() => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: _terracottaSeed,
      brightness: brightness,
      // Material's own tonal-spot algorithm rotates the seed hue by a
      // fixed amount to pick secondary/tertiary, which doesn't reliably
      // land on "sage" and "ochre" — so those two are hand-picked instead,
      // with the rest of the scheme (primary, surfaces, outlines, ...)
      // still derived from the terracotta seed for a cohesive feel.
      secondary: isDark ? const Color(0xFFBFCCA6) : const Color(0xFF5B6B44),
      onSecondary: isDark ? const Color(0xFF2E3A1E) : const Color(0xFFFFFFFF),
      secondaryContainer: isDark
          ? const Color(0xFF44502F)
          : const Color(0xFFDCE6C8),
      onSecondaryContainer: isDark
          ? const Color(0xFFDCE6C8)
          : const Color(0xFF29331A),
      tertiary: isDark ? const Color(0xFFE0C878) : const Color(0xFF8C6D1F),
      onTertiary: isDark ? const Color(0xFF3A2E08) : const Color(0xFFFFFFFF),
      tertiaryContainer: isDark
          ? const Color(0xFF6B531A)
          : const Color(0xFFF3E1B0),
      onTertiaryContainer: isDark
          ? const Color(0xFFF3E1B0)
          : const Color(0xFF3A2E08),
      error: isDark ? const Color(0xFFE5A69A) : const Color(0xFFA23B2E),
      onError: isDark ? const Color(0xFF4A160F) : const Color(0xFFFFFFFF),
      errorContainer: isDark
          ? const Color(0xFF6B2A20)
          : const Color(0xFFF0D8D4),
      onErrorContainer: isDark
          ? const Color(0xFFF0D8D4)
          : const Color(0xFF5C231C),
      // Warm cream/charcoal instead of Material's default cool grey-white,
      // so the base background reads as "earthy paper" rather than neutral
      // grey.
      surface: isDark ? const Color(0xFF231F1A) : const Color(0xFFFBF6EF),
      onSurface: isDark ? const Color(0xFFEDE3D6) : const Color(0xFF3D362E),
    );

    return ThemeData(colorScheme: scheme, useMaterial3: true);
  }
}
