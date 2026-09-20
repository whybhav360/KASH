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
import 'package:test_money/screens/transactions_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FinanceProvider provider;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('kash_primary_test');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TransactionTypeAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TransactionAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(GoalAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(AccountAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(TransactionTemplateAdapter());
  });

  setUp(() async {
    provider = FinanceProvider();
    await provider.init();
    // Clear boxes for clean state
    await Hive.box<Transaction>('transactions').clear();
    await Hive.box<Account>('accounts').clear();
    await Hive.box('settings').clear();
    await provider.refreshData();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Primary Account and Transaction Assignment Tests', () {
    test('Account serialization roundtrip with isPrimary', () {
      final account = Account(
        id: 'acc-primary-1',
        name: 'Salary Account',
        openingBalance: 10000.0,
        colorHex: 0xFF10B981,
        isPrimary: true,
      );

      final json = account.toJson();
      expect(json['isPrimary'], isTrue);

      final deserialized = Account.fromJson(json);
      expect(deserialized.id, 'acc-primary-1');
      expect(deserialized.isPrimary, isTrue);
    });

    test('Adding first account automatically marks it as primary', () async {
      final acc1 = Account(
        id: 'acc1',
        name: 'Account 1',
        openingBalance: 500,
        colorHex: 0xFF123456,
        isPrimary: false,
      );
      await provider.addAccount(acc1);

      expect(provider.accounts.length, 1);
      expect(provider.accounts.first.isPrimary, isTrue);
      expect(provider.primaryAccount?.id, 'acc1');
    });

    test('Adding a second account marked as primary unmarks the first account', () async {
      final acc1 = Account(id: 'acc1', name: 'Account 1', openingBalance: 500, colorHex: 0xFF123456);
      await provider.addAccount(acc1);
      expect(provider.primaryAccount?.id, 'acc1');

      final acc2 = Account(id: 'acc2', name: 'Account 2', openingBalance: 1000, colorHex: 0xFF654321, isPrimary: true);
      await provider.addAccount(acc2);

      expect(provider.accounts.length, 2);
      expect(provider.primaryAccount?.id, 'acc2');
      final updatedAcc1 = provider.accounts.firstWhere((a) => a.id == 'acc1');
      expect(updatedAcc1.isPrimary, isFalse);
    });

    test('Transaction without valid accountId is automatically assigned to primary account', () async {
      final acc1 = Account(id: 'acc1', name: 'Primary Acc', openingBalance: 1000, colorHex: 0xFF123456, isPrimary: true);
      await provider.addAccount(acc1);

      // Add transaction with null accountId
      final tx = Transaction(
        id: 'tx-unassigned',
        amount: 250.0,
        type: TransactionType.expense,
        category: 'Food',
        date: DateTime.now(),
        note: 'Lunch',
        accountId: null,
      );
      await provider.addTransaction(tx);

      final savedTx = provider.transactions.firstWhere((t) => t.id == 'tx-unassigned');
      expect(savedTx.accountId, 'acc1');
      expect(provider.getAccountBalance('acc1'), 750.0);
    });

    test('Horizontal account reordering shifts positions and persists order', () async {
      final acc1 = Account(id: 'acc1', name: 'Alpha', openingBalance: 100, colorHex: 0xFF111111);
      final acc2 = Account(id: 'acc2', name: 'Beta', openingBalance: 200, colorHex: 0xFF222222);
      final acc3 = Account(id: 'acc3', name: 'Gamma', openingBalance: 300, colorHex: 0xFF333333);

      await provider.addAccount(acc1);
      await provider.addAccount(acc2);
      await provider.addAccount(acc3);

      expect(provider.accounts.map((a) => a.id).toList(), ['acc1', 'acc2', 'acc3']);

      // Move acc3 (index 2) to front (index 0)
      await provider.reorderAccounts(2, 0);
      expect(provider.accounts.map((a) => a.id).toList(), ['acc3', 'acc1', 'acc2']);

      // Refresh data should preserve order from settings
      await provider.refreshData();
      expect(provider.accounts.map((a) => a.id).toList(), ['acc3', 'acc1', 'acc2']);
    });
  });

  group('Category Filter and Activity Chips Tests', () {
    test('usedCategories only returns distinct categories with transactions in alphabetical order', () async {
      final acc = Account(id: 'acc1', name: 'Bank', openingBalance: 1000, colorHex: 0xFF111111);
      await provider.addAccount(acc);

      expect(provider.usedCategories, isEmpty);

      await provider.addTransaction(Transaction(
        id: 'tx1',
        amount: 50,
        type: TransactionType.expense,
        category: 'Shopping',
        date: DateTime.now(),
        note: '',
        accountId: 'acc1',
      ));
      await provider.addTransaction(Transaction(
        id: 'tx2',
        amount: 100,
        type: TransactionType.expense,
        category: 'Food',
        date: DateTime.now(),
        note: '',
        accountId: 'acc1',
      ));
      await provider.addTransaction(Transaction(
        id: 'tx3',
        amount: 150,
        type: TransactionType.expense,
        category: 'Food', // duplicate category
        date: DateTime.now(),
        note: '',
        accountId: 'acc1',
      ));

      expect(provider.usedCategories, ['Food', 'Shopping']);
    });

    test('Filtering by category and type filters transactions accurately', () async {
      final acc = Account(id: 'acc1', name: 'Bank', openingBalance: 1000, colorHex: 0xFF111111);
      await provider.addAccount(acc);

      await provider.addTransaction(Transaction(
        id: 'tx-food',
        amount: 50,
        type: TransactionType.expense,
        category: 'Food',
        date: DateTime.now(),
        note: '',
        accountId: 'acc1',
      ));
      await provider.addTransaction(Transaction(
        id: 'tx-salary',
        amount: 5000,
        type: TransactionType.income,
        category: 'Salary',
        date: DateTime.now(),
        note: '',
        accountId: 'acc1',
      ));

      expect(provider.filteredTransactions.length, 2);

      // Filter by category 'Food'
      provider.setFilterCategory('Food');
      expect(provider.filteredTransactions.length, 1);
      expect(provider.filteredTransactions.first.id, 'tx-food');

      // Filter by type 'Income' while category is 'Food' -> empty
      provider.setFilterType(TransactionType.income);
      expect(provider.filteredTransactions.length, 0);

      // Clear category filter -> shows salary
      provider.setFilterCategory(null);
      expect(provider.filteredTransactions.length, 1);
      expect(provider.filteredTransactions.first.id, 'tx-salary');
    });

    testWidgets('Activity screen renders Income and Expenses top chips', (tester) async {
      await tester.runAsync(() async {
        final acc = Account(id: 'acc1', name: 'Checking', openingBalance: 1000, colorHex: 0xFF111111);
        await provider.addAccount(acc);
        await provider.addTransaction(Transaction(
          id: 'tx1',
          amount: 100,
          type: TransactionType.expense,
          category: 'Food',
          date: DateTime.now(),
          note: 'Grocery',
          accountId: 'acc1',
        ));
        await provider.addTransaction(Transaction(
          id: 'tx2',
          amount: 2000,
          type: TransactionType.income,
          category: 'Salary',
          date: DateTime.now(),
          note: 'Paycheck',
          accountId: 'acc1',
        ));
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<FinanceProvider>.value(
            value: provider,
            child: const TransactionsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Transfers'), findsOneWidget);

      // Tap on Expenses chip
      await tester.tap(find.text('Expenses'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(provider.filterType, TransactionType.expense);
      expect(find.text('Grocery'), findsOneWidget);
      expect(find.text('Paycheck'), findsNothing);

      // Tap on Income chip
      await tester.tap(find.text('Income'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(provider.filterType, TransactionType.income);
      expect(find.text('Paycheck'), findsOneWidget);
      expect(find.text('Grocery'), findsNothing);
    });
  });
}
