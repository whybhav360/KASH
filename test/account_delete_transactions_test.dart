import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:test_money/models/account.dart';
import 'package:test_money/models/goal.dart';
import 'package:test_money/models/transaction.dart';
import 'package:test_money/models/transaction_template.dart';
import 'package:test_money/providers/finance_provider.dart';
import 'package:test_money/screens/add_transaction_screen.dart';
import 'package:test_money/widgets/add_transaction_fab.dart';
import 'package:test_money/widgets/transaction_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FinanceProvider provider;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('kash_delete_account_test');
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
    await Hive.box<Transaction>('transactions').clear();
    await Hive.box<Account>('accounts').clear();
    await Hive.box<TransactionTemplate>('templates').clear();
    await Hive.box('settings').clear();
    await provider.refreshData();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Bank Account Deletion and Cascade Tests', () {
    test('Deleting an account permanently deletes its transactions and does NOT shift them to primary account', () async {
      final acc1 = Account(
        id: 'acc-primary',
        name: 'Primary Bank',
        openingBalance: 1000.0,
        colorHex: 0xFF123456,
        isPrimary: true,
      );
      final acc2 = Account(
        id: 'acc-secondary',
        name: 'Secondary Bank',
        openingBalance: 2000.0,
        colorHex: 0xFF654321,
      );

      await provider.addAccount(acc1);
      await provider.addAccount(acc2);

      // Add transaction for acc1
      final tx1 = Transaction(
        id: 'tx-1',
        amount: 100.0,
        type: TransactionType.expense,
        category: 'Food',
        date: DateTime.now(),
        note: 'Coffee',
        accountId: 'acc-primary',
      );
      await provider.addTransaction(tx1);

      // Add transactions for acc2
      final tx2 = Transaction(
        id: 'tx-2',
        amount: 250.0,
        type: TransactionType.expense,
        category: 'Shopping',
        date: DateTime.now(),
        note: 'Clothes',
        accountId: 'acc-secondary',
      );
      final tx3 = Transaction(
        id: 'tx-3',
        amount: 500.0,
        type: TransactionType.income,
        category: 'Salary',
        date: DateTime.now(),
        note: 'Bonus',
        accountId: 'acc-secondary',
      );
      await provider.addTransaction(tx2);
      await provider.addTransaction(tx3);

      expect(provider.transactions.length, 3);
      expect(provider.getAccountBalance('acc-primary'), 900.0);
      expect(provider.getAccountBalance('acc-secondary'), 2250.0);

      // Delete acc2
      await provider.deleteAccount(acc2);

      // Verify acc2 is removed
      expect(provider.accounts.length, 1);
      expect(provider.accounts.first.id, 'acc-primary');

      // Verify acc2 transactions are deleted and NOT shifted to acc-primary
      expect(provider.transactions.length, 1);
      expect(provider.transactions.first.id, 'tx-1');
      expect(provider.transactions.first.accountId, 'acc-primary');

      // Primary account balance must NOT be affected by deleted account's transactions
      expect(provider.getAccountBalance('acc-primary'), 900.0);
    });

    test('Deleting an account removes repetitive templates linked to it', () async {
      final acc1 = Account(
        id: 'acc-1',
        name: 'Bank 1',
        openingBalance: 500.0,
        colorHex: 0xFF111111,
      );
      await provider.addAccount(acc1);

      final tpl = TransactionTemplate(
        id: 'tpl-1',
        name: 'Netflix',
        amount: 199.0,
        type: TransactionType.expense,
        category: 'Entertainment',
        accountId: 'acc-1',
      );
      await provider.addTemplate(tpl);
      expect(provider.templates.length, 1);

      await provider.deleteAccount(acc1);
      expect(provider.templates.length, 0);
    });

    test('Deleting an account preserves transfer transaction and keeps surviving account balance accurate', () async {
      final accA = Account(id: 'acc-a', name: 'Bank A', openingBalance: 1000.0, colorHex: 0xFF111111);
      final accB = Account(id: 'acc-b', name: 'Bank B', openingBalance: 2000.0, colorHex: 0xFF222222);
      await provider.addAccount(accA);
      await provider.addAccount(accB);

      // Transfer 300 from A to B
      final transferTx = Transaction(
        id: 'tx-transfer-ab',
        amount: 300.0,
        type: TransactionType.transfer,
        category: 'Transfer',
        date: DateTime.now(),
        accountId: 'acc-a',
        toAccountId: 'acc-b',
        note: 'Rent Share',
      );
      // Non-transfer expense on A
      final expenseA = Transaction(
        id: 'tx-expense-a',
        amount: 50.0,
        type: TransactionType.expense,
        category: 'Food',
        date: DateTime.now(),
        note: '',
        accountId: 'acc-a',
      );
      await provider.addTransaction(transferTx);
      await provider.addTransaction(expenseA);

      expect(provider.getAccountBalance('acc-a'), 650.0);
      expect(provider.getAccountBalance('acc-b'), 2300.0);

      // Delete Bank A
      await provider.deleteAccount(accA);

      // Bank A's non-transfer expense is deleted, but transferTx is KEPT
      expect(provider.transactions.any((t) => t.id == 'tx-expense-a'), isFalse);
      expect(provider.transactions.any((t) => t.id == 'tx-transfer-ab'), isTrue);

      // Bank B balance remains accurately at 2300.0 (still received the 300 transfer)
      expect(provider.getAccountBalance('acc-b'), 2300.0);
    });

    testWidgets('TransactionTile displays "Account Removed" for deleted from or to account in transfer', (tester) async {
      final accB = Account(id: 'acc-b', name: 'Bank B', openingBalance: 2000.0, colorHex: 0xFF222222);

      // Transfer where from-account was deleted (account is null)
      final transferTx1 = Transaction(
        id: 'tx-1',
        amount: 300.0,
        type: TransactionType.transfer,
        category: 'Transfer',
        date: DateTime(2024, 5, 10, 14, 30),
        note: '',
        accountId: 'acc-deleted',
        toAccountId: 'acc-b',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionTile(
              transaction: transferTx1,
              account: null, // deleted
              toAccount: accB,
            ),
          ),
        ),
      );

      // Subtitle should display: Account Removed → Bank B
      expect(find.text('Account Removed → Bank B'), findsOneWidget);

      // Transfer where to-account was deleted (toAccount is null)
      final transferTx2 = Transaction(
        id: 'tx-2',
        amount: 150.0,
        type: TransactionType.transfer,
        category: 'Transfer',
        date: DateTime(2024, 5, 12, 11, 0),
        note: '',
        accountId: 'acc-b',
        toAccountId: 'acc-deleted-to',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionTile(
              transaction: transferTx2,
              account: accB,
              toAccount: null, // deleted
            ),
          ),
        ),
      );

      // Subtitle should display: Bank B → Account Removed
      expect(find.text('Bank B → Account Removed'), findsOneWidget);
    });
  });

  group('Balance Reconciliation Tests', () {
    test('reconcileAccountBalance with adjustment transaction syncs balance exactly', () async {
      final acc = Account(
        id: 'acc-rec',
        name: 'Main Bank',
        openingBalance: 5000.0,
        colorHex: 0xFF333333,
      );
      await provider.addAccount(acc);

      // Spend 50
      await provider.addTransaction(Transaction(
        id: 'tx-food',
        amount: 50.0,
        type: TransactionType.expense,
        category: 'Food',
        date: DateTime.now(),
        note: 'Snack',
        accountId: 'acc-rec',
      ));

      expect(provider.getAccountBalance('acc-rec'), 4950.0);

      // Actual bank statement says balance is 5010 (KASH is lower by 60)
      await provider.reconcileAccountBalance('acc-rec', 5010.0, createAdjustmentTransaction: true);

      expect(provider.getAccountBalance('acc-rec'), 5010.0);
      final adjTx = provider.transactions.firstWhere((t) => t.category == 'Adjustment');
      expect(adjTx.amount, 60.0);
      expect(adjTx.type, TransactionType.income);
      expect(adjTx.accountId, 'acc-rec');

      // Now suppose actual bank statement says balance is 4950 (KASH is higher by 60)
      await provider.reconcileAccountBalance('acc-rec', 4950.0, createAdjustmentTransaction: true);
      expect(provider.getAccountBalance('acc-rec'), 4950.0);
      final latestAdjTx = provider.transactions.first;
      expect(latestAdjTx.amount, 60.0);
      expect(latestAdjTx.type, TransactionType.expense);
    });

    test('reconcileAccountBalance with direct openingBalance update', () async {
      final acc = Account(
        id: 'acc-direct',
        name: 'Cash',
        openingBalance: 1000.0,
        colorHex: 0xFF444444,
      );
      await provider.addAccount(acc);

      // Reconcile to 1050 directly without transaction
      await provider.reconcileAccountBalance('acc-direct', 1050.0, createAdjustmentTransaction: false);

      expect(provider.getAccountBalance('acc-direct'), 1050.0);
      expect(provider.transactions.where((t) => t.category == 'Adjustment').isEmpty, isTrue);
      expect(provider.accounts.first.openingBalance, 1050.0);
    });
  });

  group('AddTransactionScreen initialAccountId support', () {
    test('AddTransactionFab.route preserves initialAccountId', () {
      final route = AddTransactionFab.route(initialAccountId: 'acc-2');
      expect(route, isA<PageRouteBuilder>());
    });

    test('AddTransactionScreen holds initialAccountId', () {
      const screen = AddTransactionScreen(initialAccountId: 'acc-test-123');
      expect(screen.initialAccountId, 'acc-test-123');
    });
  });
}
