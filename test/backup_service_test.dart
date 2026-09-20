import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:test_money/models/account.dart';
import 'package:test_money/models/goal.dart';
import 'package:test_money/models/transaction.dart';
import 'package:test_money/models/transaction_template.dart';
import 'package:test_money/providers/finance_provider.dart';
import 'package:test_money/services/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('kash_backup_test');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TransactionTypeAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TransactionAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(GoalAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(AccountAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(TransactionTemplateAdapter());
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('BackupService Unit Tests (Offline)', () {
    test('JSON export generates valid structure and strictly excludes goals', () async {
      final accounts = [
        Account(
          id: 'acc1',
          name: 'Main Checking',
          openingBalance: 1500.0,
          colorHex: 0xFF123456,
          bankProvider: 'Chase',
          imageBase64: 'fakeBase64ImageDataStringForAccountIcon',
        ),
        Account(id: 'acc2', name: 'Cash Wallet', openingBalance: 200.0, colorHex: 0xFF654321),
      ];

      final transactions = [
        Transaction(
          id: 'tx1',
          amount: 45.50,
          type: TransactionType.expense,
          category: 'Food',
          date: DateTime(2026, 9, 1, 12, 30),
          note: 'Lunch with colleagues',
          accountId: 'acc1',
        ),
        Transaction(
          id: 'tx2',
          amount: 3200.00,
          type: TransactionType.income,
          category: 'Salary',
          date: DateTime(2026, 9, 5, 9, 0),
          note: 'Monthly salary',
          accountId: 'acc1',
        ),
      ];

      final templates = [
        TransactionTemplate(
          id: 'tpl1',
          name: 'Coffee',
          amount: 4.50,
          type: TransactionType.expense,
          category: 'Food',
          accountId: 'acc2',
          note: 'Daily espresso',
        ),
      ];

      final jsonStr = await BackupService.exportToJson(
        accounts: accounts,
        transactions: transactions,
        templates: templates,
        expenseCategories: ['Food', 'Transport'],
        incomeCategories: ['Salary', 'Freelance'],
        userName: 'Alex',
      );

      // Verify goals are nowhere in the exported JSON
      expect(jsonStr.toLowerCase().contains('goal'), isFalse);

      // Verify parsing restored the exact entities
      final parsed = BackupService.parseJsonBackup(jsonStr);
      expect(parsed.format, 'json');
      expect(parsed.userName, 'Alex');
      expect(parsed.accounts.length, 2);
      expect(parsed.accounts[0].name, 'Main Checking');
      expect(parsed.accounts[0].openingBalance, 1500.0);
      expect(parsed.accounts[0].bankProvider, 'Chase');

      expect(parsed.transactions.length, 2);
      expect(parsed.transactions[0].id, 'tx1');
      expect(parsed.transactions[0].amount, 45.50);
      expect(parsed.transactions[0].type, TransactionType.expense);
      expect(parsed.transactions[1].id, 'tx2');
      expect(parsed.transactions[1].amount, 3200.00);
      expect(parsed.transactions[1].type, TransactionType.income);

      expect(parsed.templates.length, 1);
      expect(parsed.templates[0].name, 'Coffee');
      expect(parsed.expenseCategories, ['Food', 'Transport']);
      expect(parsed.incomeCategories, ['Salary', 'Freelance']);
    });

    test('CSV export and import roundtrip handles commas, quotes, and account resolution', () {
      final accounts = [
        Account(id: 'acc1', name: 'Primary Bank', openingBalance: 1000.0, colorHex: 0xFF123456),
      ];

      final transactions = [
        Transaction(
          id: 'tx100',
          amount: 75.25,
          type: TransactionType.expense,
          category: 'Shopping',
          date: DateTime(2026, 8, 20, 14, 15, 0),
          note: 'Groceries, apples, & "fresh" bread',
          accountId: 'acc1',
        ),
        Transaction(
          id: 'tx101',
          amount: 500.00,
          type: TransactionType.income,
          category: 'Gift',
          date: DateTime(2026, 8, 25, 10, 0, 0),
          note: 'Birthday money',
          accountId: 'acc1',
        ),
      ];

      final csvStr = BackupService.exportToCsv(
        transactions: transactions,
        accounts: accounts,
      );

      expect(csvStr, contains('Primary Bank'));
      expect(csvStr, contains('""fresh"" bread'));

      final parsed = BackupService.parseCsvBackup(csvStr, existingAccounts: accounts);
      expect(parsed.format, 'csv');
      expect(parsed.transactions.length, 2);

      final t1 = parsed.transactions.firstWhere((t) => t.id == 'tx100');
      expect(t1.amount, 75.25);
      expect(t1.type, TransactionType.expense);
      expect(t1.category, 'Shopping');
      expect(t1.note, 'Groceries, apples, & "fresh" bread');
      expect(t1.accountId, 'acc1');

      final t2 = parsed.transactions.firstWhere((t) => t.id == 'tx101');
      expect(t2.amount, 500.00);
      expect(t2.type, TransactionType.income);
      expect(t2.category, 'Gift');
    });

    test('CSV import auto-creates new account when account name is not in existing accounts', () {
      const externalCsv = '''Date,Type,Amount,Category,Account,Note,Transaction ID
2026-07-01 10:00:00,expense,12.50,Food,New Coffee Card,Morning coffee,tx-ext-1
''';

      final parsed = BackupService.parseCsvBackup(externalCsv, existingAccounts: []);
      expect(parsed.transactions.length, 1);
      expect(parsed.accounts.length, 1);
      expect(parsed.accounts[0].name, 'New Coffee Card');
      expect(parsed.transactions[0].accountId, parsed.accounts[0].id);
    });
  });

  group('FinanceProvider Import Logic (Merge vs Replace, Goals Excluded)', () {
    late FinanceProvider provider;

    setUp(() async {
      await Hive.deleteBoxFromDisk('transactions');
      await Hive.deleteBoxFromDisk('goals');
      await Hive.deleteBoxFromDisk('accounts');
      await Hive.deleteBoxFromDisk('templates');
      await Hive.deleteBoxFromDisk('settings');

      provider = FinanceProvider();
      await provider.init();
    });

    test('Merge mode adds new data, updates existing, and preserves existing goals', () async {
      // 1. Setup existing state with a Goal
      final existingGoal = Goal(id: 'goal1', title: 'Emergency Fund', targetAmount: 10000, currentAmount: 2500);
      await provider.addGoal(existingGoal);

      final initialAcc = Account(id: 'acc1', name: 'Initial Bank', openingBalance: 500, colorHex: 0xFF111111);
      await provider.addAccount(initialAcc);

      final initialTx = Transaction(
        id: 'tx1',
        amount: 20,
        type: TransactionType.expense,
        category: 'Food',
        date: DateTime(2026, 9, 1),
        note: 'Old note',
        accountId: 'acc1',
      );
      await provider.addTransaction(initialTx);

      expect(provider.goals.length, 1);
      expect(provider.accounts.length, 1);
      expect(provider.transactions.length, 1);

      // 2. Prepare backup data with updated tx1 and a new tx2
      final backupData = BackupData(
        accounts: [
          Account(id: 'acc1', name: 'Updated Bank', openingBalance: 500, colorHex: 0xFF111111),
          Account(id: 'acc2', name: 'Second Bank', openingBalance: 300, colorHex: 0xFF222222),
        ],
        transactions: [
          Transaction(
            id: 'tx1',
            amount: 25,
            type: TransactionType.expense,
            category: 'Food',
            date: DateTime(2026, 9, 1),
            note: 'Updated note',
            accountId: 'acc1',
          ),
          Transaction(
            id: 'tx2',
            amount: 100,
            type: TransactionType.income,
            category: 'Bonus',
            date: DateTime(2026, 9, 2),
            note: 'New bonus',
            accountId: 'acc2',
          ),
        ],
        templates: [],
        expenseCategories: ['Food', 'Utilities'],
        incomeCategories: ['Bonus'],
        userName: 'User',
        format: 'json',
      );

      // 3. Import in Merge mode
      await provider.importBackupData(backupData, replaceExisting: false);

      // 4. Verify Goals remain 100% untouched
      expect(provider.goals.length, 1);
      expect(provider.goals[0].id, 'goal1');
      expect(provider.goals[0].title, 'Emergency Fund');
      expect(provider.goals[0].currentAmount, 2500);

      // 5. Verify accounts merged (1 updated, 1 added)
      expect(provider.accounts.length, 2);
      expect(provider.accounts.firstWhere((a) => a.id == 'acc1').name, 'Updated Bank');

      // 6. Verify transactions merged (1 updated, 1 added)
      expect(provider.transactions.length, 2);
      final updatedTx1 = provider.transactions.firstWhere((t) => t.id == 'tx1');
      expect(updatedTx1.amount, 25);
      expect(updatedTx1.note, 'Updated note');
      expect(provider.transactions.any((t) => t.id == 'tx2'), isTrue);

      // 7. Verify categories merged
      expect(provider.expenseCategories, contains('Utilities'));
      expect(provider.incomeCategories, contains('Bonus'));
    });

    test('Replace mode overwrites accounts and transactions but strictly preserves goals', () async {
      // 1. Setup existing state with a Goal
      final myGoal = Goal(id: 'goal-safeguard', title: 'Vacation Trip', targetAmount: 5000, currentAmount: 1200);
      await provider.addGoal(myGoal);

      final oldAcc = Account(id: 'old-acc', name: 'Old Account', openingBalance: 10, colorHex: 0);
      await provider.addAccount(oldAcc);

      final oldTx = Transaction(
        id: 'old-tx',
        amount: 99,
        type: TransactionType.expense,
        category: 'OldCat',
        date: DateTime.now(),
        note: 'To be wiped',
      );
      await provider.addTransaction(oldTx);

      expect(provider.goals.length, 1);
      expect(provider.accounts.length, 1);
      expect(provider.transactions.length, 1);

      // 2. Prepare new backup data
      final backupData = BackupData(
        accounts: [
          Account(id: 'new-acc-1', name: 'Fresh Bank', openingBalance: 2000, colorHex: 0xFF00AA55),
        ],
        transactions: [
          Transaction(
            id: 'new-tx-1',
            amount: 50,
            type: TransactionType.income,
            category: 'Salary',
            date: DateTime(2026, 9, 10),
            note: 'Fresh transaction',
            accountId: 'new-acc-1',
          ),
        ],
        templates: [],
        expenseCategories: ['Food', 'Transport'],
        incomeCategories: ['Salary'],
        userName: 'New Owner',
        format: 'json',
      );

      // 3. Import in Replace mode
      await provider.importBackupData(backupData, replaceExisting: true);

      // 4. Verify Goals are STILL INTACT!
      expect(provider.goals.length, 1);
      expect(provider.goals[0].id, 'goal-safeguard');
      expect(provider.goals[0].title, 'Vacation Trip');
      expect(provider.goals[0].targetAmount, 5000);
      expect(provider.goals[0].currentAmount, 1200);

      // 5. Verify old account and old tx were replaced
      expect(provider.accounts.length, 1);
      expect(provider.accounts[0].id, 'new-acc-1');
      expect(provider.accounts[0].name, 'Fresh Bank');

      expect(provider.transactions.length, 1);
      expect(provider.transactions[0].id, 'new-tx-1');
      expect(provider.transactions[0].note, 'Fresh transaction');

      expect(provider.userName, 'New Owner');
    });

    test('Full JSON import acceptance: verifies everything lands in exact Hive boxes and computed state', () async {
      // 1. Pre-populate a Goal that must remain completely untouched
      final sacredGoal = Goal(
        id: 'untouchable-goal',
        title: 'Home Downpayment',
        targetAmount: 50000.0,
        currentAmount: 15000.0,
      );
      await provider.addGoal(sacredGoal);

      // 2. Realistic JSON payload as exported or formatted by users
      const rawJsonPayload = '''{
  "metadata": {
    "appName": "KASH",
    "version": "1.0",
    "exportedAt": "2026-09-10T12:00:00.000Z"
  },
  "profile": {
    "userName": "Jane Doe"
  },
  "categories": {
    "expense": ["Food", "Commute", "Subscriptions"],
    "income": ["Salary", "Consulting", "Dividends"]
  },
  "accounts": [
    {
      "id": "acc-hsa",
      "name": "Health Savings",
      "openingBalance": 1500.50,
      "colorHex": 4282548447,
      "bankProvider": "Fidelity",
      "iconCodePoint": 58342
    },
    {
      "id": "acc-vault",
      "name": "Secret Vault",
      "openingBalance": 850.00,
      "colorHex": 4294951168,
      "bankProvider": "Cash"
    }
  ],
  "templates": [
    {
      "id": "tpl-gym",
      "name": "Gym Membership",
      "amount": 55.00,
      "type": "expense",
      "category": "Subscriptions",
      "accountId": "acc-hsa",
      "note": "Monthly gym dues"
    }
  ],
  "transactions": [
    {
      "id": "tx-med-1",
      "amount": 120.00,
      "type": "expense",
      "category": "Food",
      "date": "2026-09-08T15:30:00.000",
      "note": "Vitamin supplements",
      "accountId": "acc-hsa"
    },
    {
      "id": "tx-con-2",
      "amount": 4000.00,
      "type": "income",
      "category": "Consulting",
      "date": "2026-09-09T10:00:00.000",
      "note": "Client retainer payment",
      "accountId": "acc-vault"
    }
  ]
}''';

      // 3. Verify acceptance & parsing
      final backupData = BackupService.parseJsonBackup(rawJsonPayload);
      expect(backupData.format, 'json');
      expect(backupData.userName, 'Jane Doe');
      expect(backupData.accounts.length, 2);
      expect(backupData.templates.length, 1);
      expect(backupData.transactions.length, 2);
      expect(backupData.expenseCategories, contains('Subscriptions'));
      expect(backupData.incomeCategories, contains('Consulting'));

      // 4. Import into provider
      await provider.importBackupData(backupData, replaceExisting: true);

      // 5. DIRECT HIVE BOX INSPECTION (Verifying every item landed exactly where it should)
      final txBox = Hive.box<Transaction>('transactions');
      final accBox = Hive.box<Account>('accounts');
      final tplBox = Hive.box<TransactionTemplate>('templates');
      final setBox = Hive.box('settings');
      final goalBox = Hive.box<Goal>('goals');

      // Transactions in Hive
      expect(txBox.length, 2);
      final tx1 = txBox.values.firstWhere((t) => t.id == 'tx-med-1');
      expect(tx1.amount, 120.00);
      expect(tx1.type, TransactionType.expense);
      expect(tx1.category, 'Food');
      expect(tx1.note, 'Vitamin supplements');
      expect(tx1.accountId, 'acc-hsa');
      expect(tx1.date, DateTime.parse('2026-09-08T15:30:00.000'));

      final tx2 = txBox.values.firstWhere((t) => t.id == 'tx-con-2');
      expect(tx2.amount, 4000.00);
      expect(tx2.type, TransactionType.income);
      expect(tx2.category, 'Consulting');
      expect(tx2.note, 'Client retainer payment');
      expect(tx2.accountId, 'acc-vault');

      // Accounts in Hive
      expect(accBox.length, 2);
      final acc1 = accBox.values.firstWhere((a) => a.id == 'acc-hsa');
      expect(acc1.name, 'Health Savings');
      expect(acc1.openingBalance, 1500.50);
      expect(acc1.bankProvider, 'Fidelity');
      expect(acc1.iconCodePoint, 58342);

      final acc2 = accBox.values.firstWhere((a) => a.id == 'acc-vault');
      expect(acc2.name, 'Secret Vault');
      expect(acc2.openingBalance, 850.00);
      expect(acc2.bankProvider, 'Cash');

      // Templates in Hive
      expect(tplBox.length, 1);
      final tpl = tplBox.values.first;
      expect(tpl.id, 'tpl-gym');
      expect(tpl.name, 'Gym Membership');
      expect(tpl.amount, 55.00);
      expect(tpl.category, 'Subscriptions');
      expect(tpl.accountId, 'acc-hsa');
      expect(tpl.note, 'Monthly gym dues');

      // Settings in Hive
      expect(setBox.get('userName'), 'Jane Doe');
      expect(List<String>.from(setBox.get('expenseCategories')), contains('Subscriptions'));
      expect(List<String>.from(setBox.get('incomeCategories')), contains('Consulting'));

      // Goals in Hive (Untouched!)
      expect(goalBox.length, 1);
      expect(goalBox.values.first.id, 'untouchable-goal');
      expect(goalBox.values.first.title, 'Home Downpayment');
      expect(goalBox.values.first.targetAmount, 50000.0);
      expect(goalBox.values.first.currentAmount, 15000.0);

      // 6. FINANCE PROVIDER COMPUTED STATE INSPECTION
      expect(provider.userName, 'Jane Doe');
      expect(provider.accounts.length, 2);
      expect(provider.transactions.length, 2);
      expect(provider.templates.length, 1);
      expect(provider.goals.length, 1);

      // Account 1 balance = 1500.50 opening - 120.00 expense = 1380.50
      expect(provider.getAccountBalance('acc-hsa'), 1380.50);

      // Account 2 balance = 850.00 opening + 4000.00 income = 4850.00
      expect(provider.getAccountBalance('acc-vault'), 4850.00);

      // Total balances
      expect(provider.totalIncome, 4000.00);
      expect(provider.totalExpenses, 120.00);
      // Total Net Worth = (1500.50 + 850.00) opening + (4000.00 - 120.00) = 6230.50
      expect(provider.totalNetWorth, 6230.50);
    });

    test('Malformed or invalid JSON strings are rejected with FormatException', () {
      // 1. Broken JSON syntax
      expect(
        () => BackupService.parseJsonBackup('{not a valid json'),
        throwsA(isA<FormatException>()),
      );

      // 2. Non-map JSON (e.g. array)
      expect(
        () => BackupService.parseJsonBackup('[{"id": 1}]'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
