import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:test_money/models/account.dart';
import 'package:test_money/models/goal.dart';
import 'package:test_money/models/transaction.dart';
import 'package:test_money/models/transaction_template.dart';
import 'package:test_money/providers/finance_provider.dart';
import 'package:test_money/providers/navigation_provider.dart';
import 'package:test_money/providers/theme_provider.dart';
import 'package:test_money/screens/add_transaction_screen.dart';
import 'package:test_money/screens/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FinanceProvider financeProvider;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('kash_template_tile_test');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TransactionTypeAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TransactionAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(GoalAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(AccountAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(TransactionTemplateAdapter());
  });

  setUp(() async {
    financeProvider = FinanceProvider();
    await financeProvider.init();
    await Hive.box<Transaction>('transactions').clear();
    await Hive.box<Account>('accounts').clear();
    await Hive.box<TransactionTemplate>('templates').clear();
    await Hive.box('settings').clear();

    // Add a template
    await financeProvider.addTemplate(
      TransactionTemplate(
        id: 'tpl_1',
        name: 'Morning Coffee',
        amount: 150,
        category: 'Food',
        type: TransactionType.expense,
      ),
    );

    await financeProvider.refreshData();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('Repetitive expense renders as a compact horizontal tile with logo and name', (tester) async {
    final navProvider = NavigationProvider();
    final themeProvider = ThemeProvider();
    await themeProvider.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<FinanceProvider>.value(value: financeProvider),
          ChangeNotifierProvider<NavigationProvider>.value(value: navProvider),
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify section title exists
    expect(find.text('Repetitive Expenses'), findsOneWidget);

    // Verify tile has the template name
    expect(find.text('Morning Coffee'), findsOneWidget);

    // Verify food icon is rendered
    expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);

    // Tap on the tile to ensure navigation to AddTransactionScreen
    await tester.tap(find.text('Morning Coffee'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(AddTransactionScreen), findsOneWidget);
  });
}
