import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../screens/home_screen.dart';
import '../screens/transactions_screen.dart';
import '../screens/insights_screen.dart';
import '../screens/goals_screen.dart';

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
              icon: Icon(Icons.home_outlined),
              label: 'Home',
              activeIcon: Icon(Icons.home_filled),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              label: 'Activity',
              activeIcon: Icon(Icons.receipt_long_rounded),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined),
              label: 'Insights',
              activeIcon: Icon(Icons.analytics_rounded),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.track_changes_outlined),
              label: 'Goals',
              activeIcon: Icon(Icons.track_changes_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
