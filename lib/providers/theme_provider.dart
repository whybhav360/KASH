import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeProvider with ChangeNotifier {
  static const String _boxName = 'settings';
  static const String _themeKey = 'themeMode';
  
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  Future<void> init() async {
    final box = await Hive.openBox(_boxName);
    final themeIndex = box.get(_themeKey, defaultValue: ThemeMode.system.index);
    _themeMode = ThemeMode.values[themeIndex];
    notifyListeners();
  }

  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    final box = await Hive.openBox(_boxName);
    await box.put(_themeKey, _themeMode.index);
    notifyListeners();
  }

  static TextTheme get _textTheme {
    return const TextTheme(
      headlineMedium: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
      titleLarge: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      titleMedium: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      bodyLarge: TextStyle(fontSize: 16),
      bodyMedium: TextStyle(fontSize: 14),
      bodySmall: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
      labelLarge: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF818CF8),
        primary: const Color(0xFF4F46E5),
        surface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Color(0xFF1E293B),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textTheme: _textTheme.apply(
        bodyColor: const Color(0xFF1E293B),
        displayColor: const Color(0xFF1E293B),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textTheme: _textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF818CF8),
        onPrimary: Color(0xFF0F172A),
        surface: Color(0xFF1E293B),
        onSurface: Color(0xFFFFFFFF),
        background: Color(0xFF0F172A),
        onBackground: Color(0xFFDAE2FD),
        secondary: Color(0xFF4EDEA3),
        outline: Color(0xFF334155),
        surfaceVariant: Color(0xFF2D3449),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
        elevation: 0,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
