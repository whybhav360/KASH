import 'package:flutter/material.dart';

class NetWorthCard extends StatelessWidget {
  final double totalBalance;
  final double income;
  final double expenses;

  const NetWorthCard({
    super.key,
    required this.totalBalance,
    required this.income,
    required this.expenses,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Net Worth',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${totalBalance.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const Spacer(),
          Row(
            children: [
              _SummarySmall(label: 'Income', amount: income, icon: Icons.arrow_upward_rounded),
              const SizedBox(width: 20),
              _SummarySmall(label: 'Expenses', amount: expenses, icon: Icons.arrow_downward_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummarySmall extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;

  const _SummarySmall({required this.label, required this.amount, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 12),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }
}
