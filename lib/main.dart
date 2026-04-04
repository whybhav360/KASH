import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/database_service.dart';
import 'providers/finance_provider.dart';
import 'providers/navigation_provider.dart';
import 'screens/home_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/goals_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await DatabaseService.init();
  
  final financeProvider = FinanceProvider();
  await financeProvider.init();


  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => financeProvider),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ],
      child: const BudgetBuddyApp(),
    ),
  );
}

class BudgetBuddyApp extends StatelessWidget {
  const BudgetBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BudgetBuddy Lite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A6CF7),
          primary: const Color(0xFF4A6CF7),
          secondary: const Color(0xFF6366F1),
          surface: Colors.white,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          titleLarge: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          bodyMedium: TextStyle(color: Color(0xFF475569)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Color(0xFF1E293B)),
        ),
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatelessWidget {
  const MainNavigation({super.key});

  final List<Widget> _screens = const [
    HomeScreen(),
    TransactionsScreen(),
    InsightsScreen(),
    GoalsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final navProvider = Provider.of<NavigationProvider>(context);

    return Scaffold(
      body: IndexedStack(
        index: navProvider.selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade100)),
        ),
        child: BottomNavigationBar(
          currentIndex: navProvider.selectedIndex,
          onTap: (index) => navProvider.setIndex(index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF4A6CF7),
          unselectedItemColor: const Color(0xFF94A3B8),
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
              activeIcon: Icon(Icons.home_filled),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_rounded),
              label: 'Transactions',
              activeIcon: Icon(Icons.receipt),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics),
              label: 'Insights',
              activeIcon: Icon(Icons.analytics_outlined),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.track_changes_rounded),
              label: 'Goals',
              activeIcon: Icon(Icons.money),
            ),
          ],
        ),
      ),
    );
  }
}
