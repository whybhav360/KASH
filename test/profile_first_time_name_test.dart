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
import 'package:test_money/screens/home_screen.dart';
import 'package:test_money/screens/profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FinanceProvider financeProvider;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('kash_profile_name_test');
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
    await Hive.box('settings').clear();
    await financeProvider.refreshData();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('First-Time User Name & Edit Name Tests', () {
    test('Default user name is "User" and hasChangedName is false initially', () {
      expect(financeProvider.userName, 'User');
      expect(financeProvider.hasChangedName, isFalse);
    });

    test('Setting user name marks hasChangedName as true and persists to storage', () async {
      await financeProvider.setUserName('Rahul Sharma');
      expect(financeProvider.userName, 'Rahul Sharma');
      expect(financeProvider.hasChangedName, isTrue);

      // Verify reloaded from box
      final freshProvider = FinanceProvider();
      await freshProvider.init();
      expect(freshProvider.userName, 'Rahul Sharma');
      expect(freshProvider.hasChangedName, isTrue);
    });

    test('hasChangedName returns true if a custom non-default name exists in settings', () async {
      final settingsBox = Hive.box('settings');
      await settingsBox.put('userName', 'Aarav');
      await settingsBox.delete('hasChangedName'); // test legacy fallback

      final provider = FinanceProvider();
      await provider.init();
      expect(provider.hasChangedName, isTrue);
    });

    testWidgets('ProfileScreen with autoEditName=true pops up Edit Name dialog automatically', (tester) async {
      final themeProvider = ThemeProvider();
      await themeProvider.init();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FinanceProvider>.value(value: financeProvider),
            ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ],
          child: const MaterialApp(
            home: ProfileScreen(autoEditName: true),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Edit Name'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Save'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);

      // Enter a new name and save
      await tester.enterText(find.byType(TextFormField), 'Priya');
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(TextButton, 'Save'));
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog should be dismissed and name updated
      expect(find.byType(AlertDialog), findsNothing);
      expect(financeProvider.userName, 'Priya');
      expect(financeProvider.hasChangedName, isTrue);
    });

    testWidgets('ProfileScreen with autoEditName=false does not open Edit Name dialog', (tester) async {
      final themeProvider = ThemeProvider();
      await themeProvider.init();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FinanceProvider>.value(value: financeProvider),
            ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ],
          child: const MaterialApp(
            home: ProfileScreen(autoEditName: false),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Edit Name'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('HomeScreen tapping user avatar opens ProfileScreen and does NOT open Edit Name dialog', (tester) async {
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

      // Tap on the user avatar in AppBar
      final avatarFinder = find.byType(CircleAvatar);
      expect(avatarFinder, findsWidgets);
      await tester.tap(avatarFinder.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Profile screen is visible, but Edit Name dialog should NOT be shown
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('Edit Name'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('HomeScreen tapping user greeting title also opens ProfileScreen with Edit Name dialog when hasChangedName is false', (tester) async {
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

      // Tap on the user greeting title in AppBar
      expect(find.text('KASH'), findsOneWidget);
      await tester.tap(find.text('KASH'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Profile screen and Edit Name dialog should now be visible
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('Edit Name'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('HomeScreen tapping user after name was changed opens ProfileScreen without Edit Name dialog', (tester) async {
      await tester.runAsync(() async {
        await financeProvider.setUserName('Maya');
      });

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

      final avatarFinder = find.byType(CircleAvatar);
      await tester.tap(avatarFinder.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Profile screen is visible, but dialog is NOT opened
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('Edit Name'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('HomeScreen tapping user greeting title after name was changed does not do anything', (tester) async {
      await tester.runAsync(() async {
        await financeProvider.setUserName('Maya');
      });

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

      // Tap on greeting title
      expect(find.text('KASH'), findsOneWidget);
      await tester.tap(find.text('KASH'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Still on HomeScreen, did NOT navigate to ProfileScreen
      expect(find.byType(ProfileScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
