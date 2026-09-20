import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:test_money/providers/theme_provider.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('kash_theme_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('ThemeProvider and ThemeData symmetry', () {
    test('lightTheme and darkTheme have aligned scaffold backgrounds and transparent appBars', () {
      final light = ThemeProvider.lightTheme;
      final dark = ThemeProvider.darkTheme;

      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);

      expect(light.scaffoldBackgroundColor, const Color(0xFFF8FAFC));
      expect(dark.scaffoldBackgroundColor, const Color(0xFF0F172A));

      expect(light.appBarTheme.backgroundColor, Colors.transparent);
      expect(dark.appBarTheme.backgroundColor, Colors.transparent);
    });

    test('lightTheme and darkTheme have symmetrical cardTheme definitions', () {
      final lightCard = ThemeProvider.lightTheme.cardTheme;
      final darkCard = ThemeProvider.darkTheme.cardTheme;

      expect(lightCard.elevation, 0);
      expect(darkCard.elevation, 0);

      expect(lightCard.shape, isA<RoundedRectangleBorder>());
      expect(darkCard.shape, isA<RoundedRectangleBorder>());

      final lightShape = lightCard.shape as RoundedRectangleBorder;
      final darkShape = darkCard.shape as RoundedRectangleBorder;

      expect(lightShape.borderRadius, BorderRadius.circular(16));
      expect(darkShape.borderRadius, BorderRadius.circular(16));

      expect(lightShape.side.width, 1.0);
      expect(darkShape.side.width, 1.0);
    });

    test('toggleTheme toggles themeMode and isDarkMode synchronously', () async {
      final provider = ThemeProvider();
      await provider.init();

      expect(provider.isDarkMode, false);

      await provider.toggleTheme(true);
      expect(provider.themeMode, ThemeMode.dark);
      expect(provider.isDarkMode, true);

      await provider.toggleTheme(false);
      expect(provider.themeMode, ThemeMode.light);
      expect(provider.isDarkMode, false);
    });
  });
}
