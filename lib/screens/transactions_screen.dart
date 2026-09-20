import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import '../providers/finance_provider.dart';
import '../widgets/transaction_tile.dart';
import '../models/transaction.dart';
import 'transfer_screen.dart';
import '../widgets/add_transaction_fab.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final financeProvider = Provider.of<FinanceProvider>(context);
    final transactions = financeProvider.filteredTransactions;
    final accounts = financeProvider.accounts;

    final typeFilters = [
      (label: 'All', type: null),
      (label: 'Income', type: TransactionType.income),
      (label: 'Expenses', type: TransactionType.expense),
      (label: 'Transfers', type: TransactionType.transfer),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        centerTitle: false,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                onPressed: () => _showFilterDialog(context, financeProvider),
                icon: const Icon(Icons.filter_list_rounded),
                tooltip: 'Filter by Category',
              ),
              if (financeProvider.filterCategory != null)
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF6366F1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Transaction Type Filter Chips (All | Income | Expenses | Transfers)
          SizedBox(
            height: 50,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: typeFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = typeFilters[index];
                final isSelected = financeProvider.filterType == item.type;

                return ChoiceChip(
                  label: Text(item.label),
                  selected: isSelected,
                  onSelected: (_) => financeProvider.setFilterType(item.type),
                  selectedColor: Theme.of(context).colorScheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).textTheme.bodyMedium?.color,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide.none,
                  ),
                  showCheckmark: false,
                );
              },
            ),
          ),

          // Active Category Filter Indicator (if any)
          if (financeProvider.filterCategory != null)
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
              child: Row(
                children: [
                  InputChip(
                    label: Text('Category: ${financeProvider.filterCategory}'),
                    selected: true,
                    onDeleted: () => financeProvider.setFilterCategory(null),
                    deleteIcon: const Icon(Icons.close_rounded, size: 16),
                    selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),

          Expanded(
            child: transactions.isEmpty
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Lottie.asset(
                                  'assets/animations/sad_no_result.json',
                                  width: 200,
                                  height: 200,
                                  fit: BoxFit.contain,
                                  repeat: true,
                                  animate: true,
                                ),
                                const SizedBox(height: 16),
                                const Text('No transactions found', style: TextStyle(color: Color(0xFF94A3B8))),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final tx = transactions[index];
                      final account = accounts.where((a) => a.id == tx.accountId).firstOrNull;

                      final toAccount = tx.toAccountId != null
                          ? accounts.where((a) => a.id == tx.toAccountId).firstOrNull
                          : null;

                      return TransactionTile(
                        transaction: tx,
                        account: account,
                        toAccount: toAccount,
                        contextAccountId: financeProvider.filterAccountId,
                        onTap: () => Navigator.push(
                          context,
                          tx.type == TransactionType.transfer
                              ? MaterialPageRoute(
                                  builder: (context) => TransferScreen(transaction: tx),
                                )
                              : AddTransactionFab.route(transaction: tx),
                        ),
                        onDelete: () => financeProvider.deleteTransaction(tx),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: const AddTransactionFab(
        heroTag: 'activity_add_fab',
      ),
    );
  }

  void _showFilterDialog(BuildContext context, FinanceProvider provider) {
    final categories = provider.usedCategories;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Filter by Category', style: Theme.of(context).textTheme.titleLarge),
                      if (provider.filterCategory != null)
                        TextButton(
                          onPressed: () {
                            provider.setFilterCategory(null);
                            setModalState(() {});
                          },
                          child: const Text('Reset'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Showing categories with existing transactions',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 16),
                  if (categories.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Text('No categories with transactions yet.', style: TextStyle(color: Color(0xFF94A3B8))),
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _FilterChip(
                          label: 'All Categories',
                          isSelected: provider.filterCategory == null,
                          onTap: () {
                            provider.setFilterCategory(null);
                            setModalState(() {});
                          },
                        ),
                        ...categories.map(
                          (cat) => _FilterChip(
                            label: cat,
                            isSelected: provider.filterCategory == cat,
                            onTap: () {
                              provider.setFilterCategory(
                                provider.filterCategory == cat ? null : cat,
                              );
                              setModalState(() {});
                            },
                          ),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
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
