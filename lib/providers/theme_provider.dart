import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeProvider with ChangeNotifier {
  static const String _boxName = 'settings';
  static const String _themeKey = 'themeMode';
  
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      try {
        return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
      } catch (_) {
        return false;
      }
    }
    return _themeMode == ThemeMode.dark;
  }

  Future<void> init() async {
    final box = await Hive.openBox(_boxName);
    final themeIndex = box.get(_themeKey, defaultValue: ThemeMode.system.index);
    if (themeIndex is int && themeIndex >= 0 && themeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[themeIndex];
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> toggleTheme([bool? isDark]) async {
    final nextDark = isDark ?? !isDarkMode;
    _themeMode = nextDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    // Defer disk I/O to avoid dropping frames during theme transition
    Future.delayed(const Duration(milliseconds: 300), () async {
      try {
        final box = Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : await Hive.openBox(_boxName);
        await box.put(_themeKey, _themeMode.index);
      } catch (e) {
        debugPrint('Error persisting themeMode: $e');
      }
    });
  }

  static const PageTransitionsTheme _pageTransitionsTheme = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: ZoomPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: ZoomPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: ZoomPageTransitionsBuilder(),
    },
  );

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

  static final ThemeData lightTheme = _buildLightTheme();
  static final ThemeData darkTheme = _buildDarkTheme();

  static ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
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
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF818CF8),
        brightness: Brightness.light,
        primary: const Color(0xFF4F46E5),
        surface: Colors.white,
        surfaceContainerHighest: const Color(0xFFF1F5F9),
        outline: const Color(0xFFE2E8F0),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0),
        thickness: 1,
        space: 1,
      ),
      pageTransitionsTheme: _pageTransitionsTheme,
    );
  }

  static ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
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
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF818CF8),
        brightness: Brightness.dark,
        primary: const Color(0xFF818CF8),
        onPrimary: const Color(0xFF0F172A),
        surface: const Color(0xFF1E293B),
        onSurface: const Color(0xFFFFFFFF),
        surfaceContainerHighest: const Color(0xFF2D3449),
        outline: const Color(0xFF334155),
        secondary: const Color(0xFF4EDEA3),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF334155),
        thickness: 1,
        space: 1,
      ),
      pageTransitionsTheme: _pageTransitionsTheme,
    );
  }
}
