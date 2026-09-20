import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:test_money/models/account.dart';
import 'package:test_money/models/goal.dart';
import 'package:test_money/models/transaction.dart';
import 'package:test_money/models/transaction_template.dart';
import 'package:test_money/providers/finance_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FinanceProvider sharedProvider;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('kash_transfer_test');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TransactionTypeAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TransactionAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(GoalAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(AccountAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(TransactionTemplateAdapter());

    sharedProvider = FinanceProvider();
    await sharedProvider.init();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Account Transfer & Paid Category Tests', () {
    test('Transaction serialization roundtrip with transfer type and toAccountId', () {
      final transferTx = Transaction(
        id: 'tx-transfer-1',
        amount: 5000.0,
        type: TransactionType.transfer,
        category: 'Transfer',
        date: DateTime(2026, 9, 10, 10, 0),
        note: 'Savings transfer',
        accountId: 'acc-source',
        toAccountId: 'acc-dest',
      );

      final json = transferTx.toJson();
      expect(json['type'], 'transfer');
      expect(json['accountId'], 'acc-source');
      expect(json['toAccountId'], 'acc-dest');
      expect(json['amount'], 5000.0);

      final deserialized = Transaction.fromJson(json);
      expect(deserialized.id, 'tx-transfer-1');
      expect(deserialized.type, TransactionType.transfer);
      expect(deserialized.accountId, 'acc-source');
      expect(deserialized.toAccountId, 'acc-dest');
      expect(deserialized.amount, 5000.0);
    });

    test('Transfer updates source and destination balances correctly and preserves net worth', () async {
      final provider = sharedProvider;

      // Clear any preexisting items
      for (final acc in List.from(provider.accounts)) {
        await provider.deleteAccount(acc);
      }
      for (final tx in List.from(provider.transactions)) {
        await provider.deleteTransaction(tx);
      }

      final hdfc = Account(
        id: 'hdfc-1',
        name: 'HDFC Bank',
        openingBalance: 20000.0,
        colorHex: 0xFF004C8F,
      );
      final sbi = Account(
        id: 'sbi-1',
        name: 'SBI Bank',
        openingBalance: 5000.0,
        colorHex: 0xFF1E88E5,
      );

      await provider.addAccount(hdfc);
      await provider.addAccount(sbi);

      expect(provider.getAccountBalance('hdfc-1'), 20000.0);
      expect(provider.getAccountBalance('sbi-1'), 5000.0);
      expect(provider.totalNetWorth, 25000.0);

      // Perform transfer of 4,000 from HDFC to SBI
      await provider.transfer(
        fromAccountId: 'hdfc-1',
        toAccountId: 'sbi-1',
        amount: 4000.0,
        date: DateTime.now(),
        note: 'Emergency savings',
      );

      // HDFC should be debited (20000 - 4000 = 16000)
      expect(provider.getAccountBalance('hdfc-1'), 16000.0);
      // SBI should be credited (5000 + 4000 = 9000)
      expect(provider.getAccountBalance('sbi-1'), 9000.0);
      // Net worth strictly preserved
      expect(provider.totalNetWorth, 25000.0);

      // Transfers must NOT be counted as monthly expenses or income
      expect(provider.totalExpenses, 0.0);
      expect(provider.totalIncome, 0.0);

      // Filter by HDFC should show the transfer
      provider.setFilterAccount('hdfc-1');
      expect(provider.filteredTransactions.length, 1);

      // Filter by SBI should also show the transfer
      provider.setFilterAccount('sbi-1');
      expect(provider.filteredTransactions.length, 1);

      // Clear filter
      provider.setFilterAccount(null);
    });

    test('Paid category exists in expenseCategories by default', () async {
      expect(sharedProvider.expenseCategories.contains('Paid'), isTrue);
    });

    test('Reordering categories updates list and persists order', () async {
      final originalPaidIndex = sharedProvider.expenseCategories.indexOf('Paid');
      expect(originalPaidIndex, isNonNegative);

      // Move 'Paid' to index 0
      await sharedProvider.reorderExpenseCategories(originalPaidIndex, 0);
      expect(sharedProvider.expenseCategories.first, 'Paid');

      // Move it to index 2
      await sharedProvider.reorderExpenseCategories(0, 3);
      expect(sharedProvider.expenseCategories[2], 'Paid');
    });
  });
}

