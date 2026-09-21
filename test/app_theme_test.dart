import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bookie_bookie/theme/app_theme.dart';

double _relativeLuminance(Color color) {
  double toLinear(double channel) {
    return channel <= 0.03928
        ? channel / 12.92
        : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * toLinear(color.r) +
      0.7152 * toLinear(color.g) +
      0.0722 * toLinear(color.b);
}

/// WCAG contrast ratio between two colors — 1.0 (identical) to 21.0
/// (black on white).
double _contrastRatio(Color a, Color b) {
  final lumA = _relativeLuminance(a) + 0.05;
  final lumB = _relativeLuminance(b) + 0.05;
  return lumA > lumB ? lumA / lumB : lumB / lumA;
}

void main() {
  for (final MapEntry(key: name, value: theme) in {
    'light': AppTheme.light(),
    'dark': AppTheme.dark(),
  }.entries) {
    final scheme = theme.colorScheme;

    // Each hand-picked (role, onRole) pair needs to stay readable — these
    // are hardcoded hex values, not algorithmically derived, so nothing
    // else catches a bad pick.
    final pairs = {
      'secondary/onSecondary': (scheme.secondary, scheme.onSecondary),
      'secondaryContainer/onSecondaryContainer': (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      'tertiary/onTertiary': (scheme.tertiary, scheme.onTertiary),
      'tertiaryContainer/onTertiaryContainer': (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      'error/onError': (scheme.error, scheme.onError),
      'errorContainer/onErrorContainer': (
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      'surface/onSurface': (scheme.surface, scheme.onSurface),
    };

    for (final MapEntry(key: label, value: (fg, bg)) in pairs.entries) {
      test('$name theme: $label meets WCAG AA (>= 4.5:1)', () {
        final ratio = _contrastRatio(fg, bg);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: 'contrast ratio was ${ratio.toStringAsFixed(2)}:1',
        );
      });
    }
  }
}
