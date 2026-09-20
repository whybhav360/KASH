import 'package:flutter/material.dart';
import '../providers/theme_provider.dart';

/// Helper to execute a clean, instant theme transition without GPU readback stalls.
class ThemeTransitionHelper {
  /// Toggles the application theme cleanly without dropping frames or taps.
  static Future<void> toggleThemeWithTransition({
    required BuildContext context,
    GlobalKey? boundaryKey,
    required ThemeProvider themeProvider,
    required bool newIsDark,
    Duration duration = const Duration(milliseconds: 200),
  }) async {
    await themeProvider.toggleTheme(newIsDark);
  }
}
