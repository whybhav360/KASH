import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../screens/home_screen.dart';
import '../screens/transactions_screen.dart';
import '../screens/insights_screen.dart';
import '../screens/goals_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late PageController _pageController;
  DateTime? _lastBackPressTime;
  late FToast _fToast;

  late final List<Widget> _screens = [
    const _KeepAlivePage(child: RepaintBoundary(child: HomeScreen())),
    const _KeepAlivePage(child: RepaintBoundary(child: TransactionsScreen())),
    const _KeepAlivePage(child: RepaintBoundary(child: InsightsScreen())),
    const _KeepAlivePage(child: RepaintBoundary(child: GoalsScreen())),
  ];

  @override
  void initState() {
    super.initState();
    _fToast = FToast();
    _fToast.init(context);

    final navProvider = Provider.of<NavigationProvider>(context, listen: false);
    int initialPage = navProvider.selectedIndex;
    if (initialPage < 0 || initialPage >= _screens.length) {
      initialPage = 0;
      navProvider.setIndex(0);
    }
    _pageController = PageController(initialPage: initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showExitToast() {
    if (!mounted) return;
    _fToast.init(context);
    _fToast.removeCustomToast();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final toastWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: Colors.white.withValues(alpha: 0.1),
            ),
            padding: const EdgeInsets.all(2),
            child: Image.asset(
              'assets/images/kash_spark_logo_corrected.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Press back again to exit',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );

    _fToast.showToast(
      child: toastWidget,
      gravity: ToastGravity.BOTTOM,
      toastDuration: const Duration(seconds: 2),
      positionedToastBuilder: (context, child, gravity) {
        return Positioned(
          bottom: 84.0,
          left: 24.0,
          right: 24.0,
          child: Center(child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final navProvider = Provider.of<NavigationProvider>(context);
    int safeIndex = navProvider.selectedIndex;
    if (safeIndex < 0 || safeIndex >= _screens.length) {
      safeIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navProvider.setIndex(0);
      });
    }

    if (_pageController.hasClients && _pageController.positions.isNotEmpty) {
      final currentPage = _pageController.page?.round();
      if (currentPage != null && currentPage != safeIndex && currentPage >= 0 && currentPage < _screens.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients && _pageController.page?.round() != safeIndex) {
            _pageController.animateToPage(
              safeIndex,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            );
          }
        });
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final nav = Provider.of<NavigationProvider>(context, listen: false);
        if (nav.selectedIndex != 0) {
          _lastBackPressTime = null;
          nav.setIndex(0);
          if (_pageController.hasClients) {
            _pageController.animateToPage(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            );
          }
          return;
        }

        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          _showExitToast();
          return;
        }

        _fToast.removeCustomToast();
        SystemNavigator.pop();
      },
      child: Scaffold(
        body: PageView.builder(
          controller: _pageController,
          itemCount: _screens.length,
          onPageChanged: (index) {
            if (index >= 0 && index < _screens.length) {
              navProvider.setIndex(index);
            }
          },
          physics: const ClampingScrollPhysics(),
          itemBuilder: (context, index) {
            if (index < 0 || index >= _screens.length) {
              return _screens[0];
            }
            return _screens[index];
          },
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1))),
          ),
        child: BottomNavigationBar(
          currentIndex: safeIndex,
          onTap: (index) {
            final validIndex = (index >= 0 && index < _screens.length) ? index : 0;
            navProvider.setIndex(validIndex);
            if (_pageController.hasClients) {
              _pageController.animateToPage(
                validIndex,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
              );
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Theme.of(context).colorScheme.surface,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Theme.of(context).textTheme.bodySmall?.color ?? const Color(0xFF94A3B8),
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
    ),
  );
  }
}

class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
