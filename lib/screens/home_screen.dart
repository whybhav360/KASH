import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/transaction_tile.dart';
import '../models/goal.dart';
import 'add_transaction_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final financeProvider = Provider.of<FinanceProvider>(context);
    final navProvider = Provider.of<NavigationProvider>(context, listen: false);
    final recentTransactions = financeProvider.transactions.take(3).toList();
    
    final primaryGoal = financeProvider.goals.isNotEmpty ? financeProvider.goals.first : null;
    final totalBalance = financeProvider.totalBalance;
    final goalProgress = primaryGoal != null ? (totalBalance / primaryGoal.targetAmount).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFF8FAFC),
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('KASH', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), letterSpacing: 1.2)),
            Text(_getGreeting(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Color(0xFF1E293B))),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0, left: 8.0),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFF1F5F9),
              child: Icon(Icons.person_rounded, color: Color(0xFF6366F1), size: 20),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => financeProvider.refreshData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              children: [
                const SizedBox(height: 12),
                BalanceCard(
                  balance: totalBalance,
                  income: financeProvider.totalIncome,
                  expenses: financeProvider.totalExpenses,
                ),
                const SizedBox(height: 24),
                
                if (primaryGoal != null)
                  GoalProgressCard(
                    goal: primaryGoal,
                    currentBalance: totalBalance,
                    progress: goalProgress,
                  )
                else
                  const NoGoalCard(),
                
                const SizedBox(height: 32),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Transactions',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    TextButton(
                      onPressed: () => navProvider.setIndex(1),
                      child: const Text('See all', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                if (recentTransactions.isEmpty)
                  const EmptyTransactionsState()
                else
                  for (final tx in recentTransactions)
                    TransactionTile(
                      transaction: tx,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddTransactionScreen(transaction: tx),
                        ),
                      ),
                      onDelete: () => financeProvider.deleteTransaction(tx),
                    ),
                
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddTransactionScreen()),
          );
        },
        backgroundColor: const Color(0xFF4F46E5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }
}

class BalanceCard extends StatelessWidget {
  final double balance;
  final double income;
  final double expenses;

  const BalanceCard({
    super.key,
    required this.balance,
    required this.income,
    required this.expenses,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Total Balance',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${balance.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _BalanceSummaryItem(
                label: 'Income',
                amount: income,
                color: const Color(0xFF10B981),
                bgColor: const Color(0xFFECFDF5),
                textColor: const Color(0xFF065F46),
                icon: Icons.arrow_upward_rounded,
              ),
              const SizedBox(width: 12),
              _BalanceSummaryItem(
                label: 'Expenses',
                amount: expenses,
                color: const Color(0xFFEF4444),
                bgColor: const Color(0xFFFEF2F2),
                textColor: const Color(0xFF991B1B),
                icon: Icons.arrow_downward_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceSummaryItem extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final Color bgColor;
  final Color textColor;
  final IconData icon;

  const _BalanceSummaryItem({
    required this.label,
    required this.amount,
    required this.color,
    required this.bgColor,
    required this.textColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: textColor, fontSize: 11)),
                  Text(
                    '₹${amount.toStringAsFixed(0)}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GoalProgressCard extends StatelessWidget {
  final Goal goal;
  final double currentBalance;
  final double progress;

  const GoalProgressCard({
    super.key,
    required this.goal,
    required this.currentBalance,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 12,
                  backgroundColor: const Color(0xFFF1F5F9),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                children: [
                  Text('${(progress * 100).toInt()}%', 
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  const Text('PROGRESS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Savings Goal', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            '₹${currentBalance.toStringAsFixed(0)} saved',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
          ),
          const SizedBox(height: 4),
          Text('Goal: ₹${goal.targetAmount.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
        ],
      ),
    );
  }
}

class NoGoalCard extends StatelessWidget {
  const NoGoalCard({super.key});

  @override
  Widget build(BuildContext context) {
    final navProvider = Provider.of<NavigationProvider>(context, listen: false);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 2),
      ),
      child: Column(
        children: [
          const Icon(Icons.stars_rounded, size: 40, color: Color(0xFFF59E0B)),
          const SizedBox(height: 12),
          const Text(
            'Track your savings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Set a goal to stay motivated and see your progress.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => navProvider.setIndex(3),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEEF2FF),
              foregroundColor: const Color(0xFF4F46E5),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Set a Goal', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class EmptyTransactionsState extends StatelessWidget {
  const EmptyTransactionsState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: const Column(
        children: [
          Icon(Icons.history_rounded, size: 48, color: Color(0xFFF1F5F9)),
          SizedBox(height: 12),
          Text('No transactions yet', style: TextStyle(color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }
}
