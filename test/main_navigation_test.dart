import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:test_money/models/account.dart';
import 'package:test_money/models/goal.dart';
import 'package:test_money/models/transaction.dart';
import 'package:test_money/models/transaction_template.dart';
import 'package:test_money/providers/finance_provider.dart';
import 'package:test_money/providers/navigation_provider.dart';
import 'package:test_money/providers/theme_provider.dart';
import 'package:test_money/widgets/main_navigation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FinanceProvider financeProvider;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('kash_main_nav_test');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TransactionTypeAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TransactionAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(GoalAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(AccountAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(TransactionTemplateAdapter());

    financeProvider = FinanceProvider();
    await financeProvider.init();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Widget buildTestApp(NavigationProvider navProvider, ThemeProvider themeProvider) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<FinanceProvider>.value(value: financeProvider),
        ChangeNotifierProvider<NavigationProvider>.value(value: navProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
      ],
      child: MaterialApp(
        builder: FToastBuilder(),
        home: const MainNavigation(),
      ),
    );
  }

  testWidgets('Back navigation from other tabs returns to HomeScreen (tab 0)', (tester) async {
    final navProvider = NavigationProvider();
    final themeProvider = ThemeProvider();

    await tester.pumpWidget(buildTestApp(navProvider, themeProvider));
    await tester.pump();

    // Start on Activity tab (index 1)
    navProvider.setIndex(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(navProvider.selectedIndex, 1);

    // Simulate system back press / back swipe
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // Must navigate back to HomeScreen (index 0)
    expect(navProvider.selectedIndex, 0);

    // Switch to Insights tab (index 2)
    navProvider.setIndex(2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(navProvider.selectedIndex, 2);

    // Simulate system back press
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // Must return to HomeScreen (index 0)
    expect(navProvider.selectedIndex, 0);

    // Switch to Goals tab (index 3)
    navProvider.setIndex(3);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(navProvider.selectedIndex, 3);

    // Simulate system back press
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // Must return to HomeScreen (index 0)
    expect(navProvider.selectedIndex, 0);
  });

  testWidgets('On HomeScreen, first back press shows exit toast with logo and message', (tester) async {
    final navProvider = NavigationProvider();
    final themeProvider = ThemeProvider();

    await tester.pumpWidget(buildTestApp(navProvider, themeProvider));
    await tester.pump();

    // Ensure we are on HomeScreen
    expect(navProvider.selectedIndex, 0);

    // Press back once
    await tester.binding.handlePopRoute();
    await tester.pump();

    // Verify exit toast is displayed
    expect(find.text('Press back again to exit'), findsOneWidget);

    // Verify app logo image is leading the text
    final imageFinder = find.byWidgetPredicate((widget) {
      if (widget is Image && widget.image is AssetImage) {
        return (widget.image as AssetImage).assetName == 'assets/images/kash_spark_logo_corrected.png';
      }
      return false;
    });
    expect(imageFinder, findsOneWidget);

    // Advance clock past FToast timer
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('On HomeScreen, second back press within 2s triggers SystemNavigator.pop', (tester) async {
    final navProvider = NavigationProvider();
    final themeProvider = ThemeProvider();

    bool systemPopCalled = false;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'SystemNavigator.pop') {
          systemPopCalled = true;
        }
        return null;
      },
    );

    await tester.pumpWidget(buildTestApp(navProvider, themeProvider));
    await tester.pump();

    // First back press
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(systemPopCalled, isFalse);

    // Second back press within 500ms
    await tester.pump(const Duration(milliseconds: 500));
    await tester.binding.handlePopRoute();
    await tester.pump();

    // SystemNavigator.pop must have been called
    expect(systemPopCalled, isTrue);

    // Clean up channel mock handler and flush timers
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
    await tester.pump(const Duration(seconds: 3));
  });
}
