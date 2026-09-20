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
import 'package:test_money/screens/bank_statement_review_screen.dart';
import 'package:test_money/services/bank_statement_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FinanceProvider provider;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('kash_statement_review_test');
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

  testWidgets('Statement review defaults to create new account when no matching account exists', (tester) async {
    // Existing accounts: Main Bank (on home screen) and Cash
    final acc1 = Account(
      id: 'acc-main',
      name: 'Main Bank',
      openingBalance: 5000.0,
      colorHex: 0xFF123456,
      isPrimary: true,
    );
    final acc2 = Account(
      id: 'acc-cash',
      name: 'Cash',
      openingBalance: 1000.0,
      colorHex: 0xFF654321,
    );
    await provider.addAccount(acc1);
    await provider.addAccount(acc2);

    final statementResult = BankStatementResult(
      rawText: 'PUNJAB NATIONAL BANK Account No: 0123000100987654',
      bankName: 'Punjab National Bank',
      accountNumber: '0123000100987654',
      openingBalance: 7805.05,
      transactions: [
        ParsedBankTransaction(
          id: 'tx-1',
          date: DateTime(2026, 9, 16),
          description: 'UPI/DR/662588224268/Lalit Ku',
          rawDescription: 'UPI/DR/662588224268/Lalit Ku',
          amount: 70.0,
          type: TransactionType.expense,
          category: 'Shopping',
          balance: 7805.05,
        ),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<FinanceProvider>.value(
        value: provider,
        child: MaterialApp(
          home: BankStatementReviewScreen(
            statementResult: statementResult,
            fileName: 'pnb_statement.pdf',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify it suggests '+ Create "Punjab National Bank (7654)"'
    expect(find.textContaining('Create "Punjab National Bank (7654)"'), findsWidgets);
    // Verify it does NOT select "Main Bank"
    expect(find.text('Main Bank'), findsNothing);
  });

  testWidgets('Statement review matches existing account when account number (last 4) matches', (tester) async {
    final accPnb = Account(
      id: 'acc-pnb',
      name: 'Punjab National Bank (7654)',
      openingBalance: 1000.0,
      colorHex: 0xFF800000,
    );
    final accOther = Account(
      id: 'acc-other',
      name: 'SBI Bank',
      openingBalance: 2000.0,
      colorHex: 0xFF0000FF,
      isPrimary: true,
    );
    await provider.addAccount(accPnb);
    await provider.addAccount(accOther);

    final statementResult = BankStatementResult(
      rawText: 'PUNJAB NATIONAL BANK Account No: 0123000100987654',
      bankName: 'Punjab National Bank',
      accountNumber: '0123000100987654',
      openingBalance: 7805.05,
      transactions: [
        ParsedBankTransaction(
          id: 'tx-1',
          date: DateTime(2026, 9, 16),
          description: 'UPI/DR/662588224268/Lalit Ku',
          rawDescription: 'UPI/DR/662588224268/Lalit Ku',
          amount: 70.0,
          type: TransactionType.expense,
          category: 'Shopping',
          balance: 7805.05,
        ),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<FinanceProvider>.value(
        value: provider,
        child: MaterialApp(
          home: BankStatementReviewScreen(
            statementResult: statementResult,
            fileName: 'pnb_statement.pdf',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify it selected the existing PNB account and not SBI Bank
    expect(find.text('Punjab National Bank (7654)'), findsWidgets);
    expect(find.text('SBI Bank'), findsNothing);
  });
}
