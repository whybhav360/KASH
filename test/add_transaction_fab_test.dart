import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:test_money/providers/finance_provider.dart';
import 'package:test_money/providers/theme_provider.dart';
import 'package:test_money/screens/add_transaction_screen.dart';
import 'package:test_money/services/image_cache_service.dart';
import 'package:test_money/widgets/add_transaction_fab.dart';

void main() {
  late Directory tempDir;
  late FinanceProvider financeProvider;
  late ThemeProvider themeProvider;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('kash_fab_test_');
    Hive.init(tempDir.path);
    financeProvider = FinanceProvider();
    await financeProvider.init();
    themeProvider = ThemeProvider();
    await themeProvider.init();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('ImageCacheService Tests', () {
    test('ImageCacheService caches existence check and handles invalidate/clear', () {
      expect(ImageCacheService.fileExists(null), false);
      expect(ImageCacheService.fileExists(''), false);

      final dummyFilePath = '${tempDir.path}/test_cache_file.txt';
      expect(ImageCacheService.fileExists(dummyFilePath), false);

      // Create file
      final file = File(dummyFilePath);
      file.writeAsStringSync('hello');

      // First check was cached as false, so invalidate it
      ImageCacheService.invalidate(dummyFilePath);
      expect(ImageCacheService.fileExists(dummyFilePath), true);

      // Clearing cache
      ImageCacheService.clear();
      expect(ImageCacheService.fileExists(dummyFilePath), true);
    });
  });

  group('AddTransactionFab Widget & Route Tests', () {
    Widget buildTestApp(Widget child) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<FinanceProvider>.value(value: financeProvider),
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: const Center(child: Text('Home Content')),
            floatingActionButton: child,
          ),
        ),
      );
    }

    testWidgets('AddTransactionFab renders with correct heroTag, icon, and styling', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const AddTransactionFab(heroTag: 'test_home_fab')),
      );
      await tester.pumpAndSettle();

      final fabFinder = find.byType(FloatingActionButton);
      expect(fabFinder, findsOneWidget);

      final fab = tester.widget<FloatingActionButton>(fabFinder);
      expect(fab.heroTag, 'test_home_fab');
      expect(fab.backgroundColor, const Color(0xFF4F46E5));
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('AddTransactionFab invokes custom onPressed if provided', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        buildTestApp(
          AddTransactionFab(
            heroTag: 'test_custom_fab',
            onPressed: () {
              pressed = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(pressed, true);
    });

    testWidgets('AddTransactionFab default tap opens AddTransactionScreen via unified route', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const AddTransactionFab(heroTag: 'test_default_fab')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.byType(AddTransactionScreen), findsOneWidget);
      expect(find.text('Add Transaction'), findsOneWidget);
    });

    test('AddTransactionFab.route creates PageRoute with hardware-accelerated slide transition', () {
      final route = AddTransactionFab.route();
      expect(route, isA<PageRouteBuilder>());
      final pageRoute = route as PageRouteBuilder;
      expect(pageRoute.transitionDuration, const Duration(milliseconds: 300));
      expect(pageRoute.reverseTransitionDuration, const Duration(milliseconds: 250));
    });
  });
}
