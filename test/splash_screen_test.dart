import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:test_money/providers/theme_provider.dart';
import 'package:test_money/screens/splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SplashScreen renders title, tagline and spark logo', (WidgetTester tester) async {
    final themeProvider = ThemeProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: themeProvider,
        child: const MaterialApp(
          home: SplashScreen(),
        ),
      ),
    );

    // Initial frame
    await tester.pump();

    expect(find.text('KASH'), findsOneWidget);
    expect(find.text('PERSONAL FINANCE SIMPLIFIED'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    // Advance animation
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('KASH'), findsOneWidget);
  });
}
