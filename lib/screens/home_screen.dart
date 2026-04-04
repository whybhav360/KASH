import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/transaction_tile.dart';
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
            Text('KASH', style: TextStyle(fontSize: 12, color: Colors.grey.shade500, letterSpacing: 1.2)),
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
                // Total Balance Card
                _buildBalanceCard(financeProvider),
                const SizedBox(height: 24),
                
                // Savings Goal Card
                if (primaryGoal != null)
                  _buildGoalCard(primaryGoal, totalBalance, goalProgress),
                
                const SizedBox(height: 32),
                
                // Recent Transactions Header
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
                
                // Transaction List
                if (recentTransactions.isEmpty)
                  _buildEmptyState()
                else
                  ...recentTransactions
                      .map((tx) => TransactionTile(
                            transaction: tx,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddTransactionScreen(transaction: tx),
                              ),
                            ),
                            onDelete: () => financeProvider.deleteTransaction(tx),
                          ))
                      .toList(),
                
                const SizedBox(height: 100), // Space for FAB
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

  Widget _buildBalanceCard(FinanceProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          Text('Total Balance', style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(
            '₹${provider.totalBalance.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.arrow_upward_rounded, color: Color(0xFF10B981), size: 16),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Income', style: TextStyle(color: Color(0xFF065F46), fontSize: 11)),
                          Text('₹${provider.totalIncome.toStringAsFixed(0)}', 
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.arrow_downward_rounded, color: Color(0xFFEF4444), size: 16),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Expenses', style: TextStyle(color: Color(0xFF991B1B), fontSize: 11)),
                          Text('₹${provider.totalExpenses.toStringAsFixed(0)}', 
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF991B1B))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(dynamic goal, double currentBalance, double progress) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 20, offset: const Offset(0, 10)),
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
                  backgroundColor: Colors.grey.shade100,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                children: [
                  Text('${(progress * 100).toInt()}%', 
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  const Text('PROGRESS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Savings Goal', style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            '₹${currentBalance.toStringAsFixed(0)} saved',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
          ),
          const SizedBox(height: 4),
          Text('Goal: ₹${goal.targetAmount.toStringAsFixed(0)}', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.history_rounded, size: 48, color: Colors.grey.shade200),
          const SizedBox(height: 12),
          Text('No transactions yet', style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
