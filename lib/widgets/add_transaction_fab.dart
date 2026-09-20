import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/transaction_template.dart';
import '../screens/add_transaction_screen.dart';

/// Reusable Floating Action Button for adding transactions,
/// ensuring consistent UI styling, accessibility, and smooth,
/// locked-frame slide-up page transitions across HomeScreen and ActivityScreen.
class AddTransactionFab extends StatelessWidget {
  final String heroTag;
  final VoidCallback? onPressed;

  const AddTransactionFab({
    super.key,
    required this.heroTag,
    this.onPressed,
  });

  /// Unified route transition for opening AddTransactionScreen across the entire app.
  /// Uses a hardware-accelerated bottom-up slide transition without expensive
  /// GPU saveLayer full-screen opacity passes, preventing initial animation stutter.
  static Route<T> route<T>({
    Transaction? transaction,
    TransactionTemplate? template,
    TransactionType? initialType,
    String? initialAccountId,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => AddTransactionScreen(
        transaction: transaction,
        template: template,
        initialType: initialType,
        initialAccountId: initialAccountId,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 1.0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: heroTag,
      onPressed: onPressed ??
          () {
            Navigator.of(context).push(
              AddTransactionFab.route(),
            );
          },
      backgroundColor: const Color(0xFF4F46E5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      tooltip: 'Add Transaction',
      child: const Icon(Icons.add, color: Colors.white, size: 30),
    );
  }
}
