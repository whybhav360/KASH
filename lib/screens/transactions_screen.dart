import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/finance_provider.dart';
import '../widgets/transaction_tile.dart';
import '../models/transaction.dart';
import '../models/account.dart';
import 'add_transaction_screen.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final financeProvider = Provider.of<FinanceProvider>(context);
    final transactions = financeProvider.filteredTransactions;
    final accounts = financeProvider.accounts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () => _showFilterDialog(context, financeProvider),
            icon: const Icon(Icons.filter_list_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          // Account Filter Chips
          SizedBox(
            height: 50,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: accounts.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final isAll = index == 0;
                final accountId = isAll ? null : accounts[index - 1].id;
                final isSelected = financeProvider.filterAccountId == accountId;

                return ChoiceChip(
                  label: Text(isAll ? 'All Accounts' : accounts[index - 1].name),
                  selected: isSelected,
                  onSelected: (_) => financeProvider.setFilterAccount(accountId),
                  selectedColor: Theme.of(context).colorScheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).textTheme.bodyMedium?.color,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                  showCheckmark: false,
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          Expanded(
            child: transactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          'assets/animations/no_history.svg',
                          width: 200,
                          height: 200,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No transactions found',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).dividerColor.withOpacity(0.5),
                              ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final tx = transactions[index];
                      final account = accounts.firstWhere(
                        (a) => a.id == tx.accountId,
                        orElse: () => accounts.isNotEmpty
                            ? accounts.first
                            : Account(id: 'temp', name: 'Loading...', openingBalance: 0, colorHex: 0xFF94A3B8),
                      );

                      return TransactionTile(
                        transaction: tx,
                        account: account,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddTransactionScreen(transaction: tx),
                          ),
                        ),
                        onDelete: () => financeProvider.deleteTransaction(tx),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'transactions_fab',
        onPressed: () {
          Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const AddTransactionScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = Offset(0.0, 1.0);
                const end = Offset.zero;
                const curve = Curves.easeInOutQuart;
                var slideTween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                var scaleTween = Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));

                return SlideTransition(
                  position: animation.drive(slideTween),
                  child: ScaleTransition(
                    scale: animation.drive(scaleTween),
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  ),
                );
              },
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        },
        backgroundColor: const Color(0xFF4F46E5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }

  void _showFilterDialog(BuildContext context, FinanceProvider provider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filter by Type', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                children: [
                  _FilterChip(
                    label: 'All',
                    isSelected: provider.filterType == null,
                    onTap: () {
                      provider.setFilterType(null);
                      setModalState(() {});
                    },
                  ),
                  _FilterChip(
                    label: 'Income',
                    isSelected: provider.filterType == TransactionType.income,
                    onTap: () {
                      provider.setFilterType(TransactionType.income);
                      setModalState(() {});
                    },
                  ),
                  _FilterChip(
                    label: 'Expense',
                    isSelected: provider.filterType == TransactionType.expense,
                    onTap: () {
                      provider.setFilterType(TransactionType.expense);
                      setModalState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
