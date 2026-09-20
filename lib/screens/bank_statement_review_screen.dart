import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/account.dart';
import '../models/transaction.dart';
import '../providers/finance_provider.dart';
import '../services/bank_statement_parser.dart';
import '../utils/currency_formatter.dart';

const Color _emeraldGreen = Color(0xFF10B981);
const String _newAccountSentinel = '__NEW_ACCOUNT__';

int _getBankColorHex(String bankName) {
  final upper = bankName.toUpperCase();
  if (upper.contains('AXIS')) return 0xFF97144D; // Axis Burgundy
  if (upper.contains('PNB') || upper.contains('PUNJAB')) return 0xFFA21C2B; // PNB Maroon
  if (upper.contains('SBI') || upper.contains('STATE BANK')) return 0xFF1E88E5; // SBI Blue
  if (upper.contains('HDFC')) return 0xFF004C8F; // HDFC Navy
  if (upper.contains('ICICI')) return 0xFFB71C1C; // ICICI Maroon
  if (upper.contains('KOTAK')) return 0xFFED1C24; // Kotak Red
  return 0xFF4F46E5; // Default Indigo
}

String _getSuggestedAccountName(String bankName, String? accountNumber) {
  final cleanBank = bankName != 'Bank Statement' ? bankName : 'Bank Account';
  if (accountNumber != null && accountNumber.isNotEmpty) {
    final lastDigits = accountNumber.length > 4
        ? accountNumber.substring(accountNumber.length - 4)
        : accountNumber;
    return '$cleanBank ($lastDigits)';
  }
  return cleanBank;
}

class BankStatementReviewScreen extends StatefulWidget {
  final BankStatementResult statementResult;
  final String fileName;

  const BankStatementReviewScreen({
    super.key,
    required this.statementResult,
    required this.fileName,
  });

  @override
  State<BankStatementReviewScreen> createState() => _BankStatementReviewScreenState();
}

class _BankStatementReviewScreenState extends State<BankStatementReviewScreen> {
  late List<ParsedBankTransaction> _transactions;
  String? _selectedAccountId;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isImporting = false;

  late String _newAccountName;
  late double _newAccountOpeningBalance;
  late int _newAccountColorHex;

  @override
  void initState() {
    super.initState();
    _transactions = List.from(widget.statementResult.transactions);

    _newAccountName = _getSuggestedAccountName(
      widget.statementResult.bankName,
      widget.statementResult.accountNumber,
    );
    _newAccountOpeningBalance = widget.statementResult.openingBalance ?? 0.0;
    _newAccountColorHex = _getBankColorHex(widget.statementResult.bankName);

    final provider = Provider.of<FinanceProvider>(context, listen: false);
    _resolveDefaultAccount(provider);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resolveDefaultAccount(FinanceProvider provider) {
    // By default, always default to creating a new account
    _selectedAccountId = _newAccountSentinel;

    final bankName = widget.statementResult.bankName.toLowerCase().trim();
    final accountNum = widget.statementResult.accountNumber?.trim();
    final last4 = (accountNum != null && accountNum.length >= 4)
        ? accountNum.substring(accountNum.length - 4)
        : null;

    // 1. Strict match by account number if available (e.g. Account Name ends with '(7654)' or contains digits)
    if (last4 != null) {
      final matchedByNumber = provider.accounts.where((a) {
        final name = a.name.trim();
        return name.contains('($last4)') || name.endsWith(last4);
      }).firstOrNull;

      if (matchedByNumber != null) {
        _selectedAccountId = matchedByNumber.id;
        return;
      }
    }

    // 2. Strict, unambiguous bank match (disallow generic names like "Bank", "Account", "Savings", "Main")
    if (bankName.isNotEmpty && bankName != 'bank statement' && bankName != 'bank account') {
      const genericNames = {
        'bank', 'account', 'bank account', 'savings', 'current', 'cash', 'main', 'primary',
        'my bank', 'wallet', 'card', 'credit card', 'debit card', 'personal', 'office', 'default'
      };

      final matchedByBank = provider.accounts.where((a) {
        final accName = a.name.toLowerCase().trim();
        final prov = (a.bankProvider ?? '').toLowerCase().trim();

        // Disallow generic account names from falsely adopting statement
        if (genericNames.contains(accName)) return false;

        // Exact bank provider match
        if (prov.isNotEmpty &&
            (prov == bankName || (prov == 'punjab national bank' && bankName.contains('punjab')))) {
          return true;
        }

        // Strict bank name match (only if accName specifically names the bank)
        if (bankName.contains('punjab national') &&
            (accName == 'pnb' ||
                accName == 'punjab national bank' ||
                accName.startsWith('pnb ') ||
                accName.startsWith('punjab national bank '))) {
          return true;
        }
        if (bankName.contains('state bank') &&
            (accName == 'sbi' ||
                accName == 'state bank of india' ||
                accName.startsWith('sbi ') ||
                accName.startsWith('state bank of india '))) {
          return true;
        }
        if (bankName.contains('hdfc') &&
            (accName == 'hdfc' || accName == 'hdfc bank' || accName.startsWith('hdfc '))) {
          return true;
        }
        if (bankName.contains('icici') &&
            (accName == 'icici' || accName == 'icici bank' || accName.startsWith('icici '))) {
          return true;
        }
        if (bankName.contains('axis') &&
            (accName == 'axis' || accName == 'axis bank' || accName.startsWith('axis '))) {
          return true;
        }
        if (bankName.contains('kotak') &&
            (accName == 'kotak' || accName == 'kotak bank' || accName.startsWith('kotak '))) {
          return true;
        }

        return false;
      }).firstOrNull;

      if (matchedByBank != null) {
        _selectedAccountId = matchedByBank.id;
        return;
      }
    }

    // If no existing account pre-exists for this statement, default to creating a new account!
    _selectedAccountId = _newAccountSentinel;
  }

  List<ParsedBankTransaction> get _filteredTransactions {
    if (_searchQuery.trim().isEmpty) return _transactions;
    final q = _searchQuery.toLowerCase();
    return _transactions.where((t) {
      return t.description.toLowerCase().contains(q) ||
          t.category.toLowerCase().contains(q) ||
          t.amount.toString().contains(q);
    }).toList();
  }

  int get _selectedCount => _transactions.where((t) => t.isSelected).length;

  double get _selectedIncome => _transactions
      .where((t) => t.isSelected && t.type == TransactionType.income)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get _selectedExpense => _transactions
      .where((t) => t.isSelected && t.type == TransactionType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);

  void _toggleSelectAll() {
    final allSelected = _transactions.every((t) => t.isSelected);
    setState(() {
      for (final t in _transactions) {
        t.isSelected = !allSelected;
      }
    });
  }

  void _showCategoryPicker(ParsedBankTransaction item) {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final isExpense = item.type == TransactionType.expense;
    final categories = isExpense ? provider.expenseCategories : provider.incomeCategories;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Choose Category (${item.type.name.toUpperCase()})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isCurrent = item.category.toLowerCase() == cat.toLowerCase();
                    return ListTile(
                      title: Text(cat),
                      trailing: isCurrent
                          ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () {
                        setState(() {
                          item.category = cat;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  }

  void _editTransactionNote(ParsedBankTransaction item) {
    final controller = TextEditingController(text: item.description);
    showDialog(
      context: context,
      builder: (context) => GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Note'),
          content: SingleChildScrollView(
            child: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Transaction Note',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  item.description = controller.text.trim();
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditNewAccountDialog() {
    final nameController = TextEditingController(text: _newAccountName);
    final balanceController = TextEditingController(
      text: _newAccountOpeningBalance <= 0
          ? ''
          : CurrencyFormatter.formatInput(_newAccountOpeningBalance),
    );

    showDialog(
      context: context,
      builder: (ctx) => GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('New Account Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Account Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: balanceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Opening Balance (₹)',
                    hintText: '0',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final trimmedName = nameController.text.trim();
                final parsedBal = double.tryParse(balanceController.text.trim()) ?? 0.0;
                if (trimmedName.isNotEmpty) {
                  setState(() {
                    _newAccountName = trimmedName;
                    _newAccountOpeningBalance = parsedBal;
                  });
                }
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _commitImport() async {
    final selectedItems = _transactions.where((t) => t.isSelected).toList();
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one transaction to import.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final provider = Provider.of<FinanceProvider>(context, listen: false);
    setState(() => _isImporting = true);

    try {
      final String targetAccountId;
      final String targetAccountDisplayName;

      final bool isCreatingNew = _selectedAccountId == _newAccountSentinel ||
          (_selectedAccountId == null && provider.accounts.isEmpty) ||
          (_selectedAccountId != null &&
              _selectedAccountId != _newAccountSentinel &&
              !provider.accounts.any((a) => a.id == _selectedAccountId));

      if (isCreatingNew) {
        // Automatically create the new bank account in Hive!
        final newAccount = Account(
          id: const Uuid().v4(),
          name: _newAccountName,
          openingBalance: _newAccountOpeningBalance,
          colorHex: _newAccountColorHex,
          bankProvider: widget.statementResult.bankName != 'Bank Statement'
              ? widget.statementResult.bankName
              : null,
        );
        await provider.addAccount(newAccount);
        targetAccountId = newAccount.id;
        targetAccountDisplayName = newAccount.name;
      } else {
        targetAccountId = _selectedAccountId ??
            (provider.accounts.isNotEmpty ? provider.accounts.first.id : 'default');
        final acc = provider.accounts.where((a) => a.id == targetAccountId).firstOrNull;
        targetAccountDisplayName = acc?.name ?? widget.statementResult.bankName;
      }

      final transactionsToImport = selectedItems.map((item) {
        return item.toTransaction(accountId: targetAccountId);
      }).toList();

      final count = await provider.addTransactions(transactionsToImport);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selectedAccountId == _newAccountSentinel
                ? 'Created "$targetAccountDisplayName" and imported $count transactions!'
                : 'Successfully imported $count transactions into $targetAccountDisplayName!',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isImporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to import: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    String formatAmount(double val) => CurrencyFormatter.format(val, symbol: '₹ ');
    final provider = Provider.of<FinanceProvider>(context);

    final filtered = _filteredTransactions;
    final allSelected = _transactions.isNotEmpty && _transactions.every((t) => t.isSelected);

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Review Statement'),
          actions: [
            TextButton.icon(
              onPressed: _transactions.isEmpty ? null : _toggleSelectAll,
              icon: Icon(
                allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                size: 18,
              ),
              label: Text(allSelected ? 'Deselect All' : 'Select All'),
            ),
          ],
        ),
        body: Column(
          children: [
            // Top Statement Meta Card
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.picture_as_pdf_rounded,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.statementResult.bankName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.fileName,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_transactions.length} txns',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  // Destination Account Selector
                  Row(
                    children: [
                      const Text(
                        'Target Account:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: (_selectedAccountId == _newAccountSentinel ||
                                    provider.accounts.any((a) => a.id == _selectedAccountId))
                                ? _selectedAccountId
                                : _newAccountSentinel,
                            isDense: true,
                            isExpanded: true,
                            borderRadius: BorderRadius.circular(14),
                            items: [
                              DropdownMenuItem<String>(
                                value: _newAccountSentinel,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: Color(_newAccountColorHex),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        '+ Create "$_newAccountName"',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: theme.colorScheme.primary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ...provider.accounts.map((acc) {
                                return DropdownMenuItem<String>(
                                  value: acc.id,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: Color(acc.colorHex),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          acc.name,
                                          style: const TextStyle(fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedAccountId = val);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  if ((_selectedAccountId == _newAccountSentinel ||
                          (_selectedAccountId == null && !provider.accounts.any((a) => a.id == _selectedAccountId)))) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Color(_newAccountColorHex).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Color(_newAccountColorHex).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Color(_newAccountColorHex).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.account_balance_rounded,
                              size: 16,
                              color: Color(_newAccountColorHex),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'New Account: $_newAccountName',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Opening Balance: ${formatAmount(_newAccountOpeningBalance)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _showEditNewAccountDialog,
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 14),
                            label: const Text('Edit', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Financial Totals Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSummaryMetric(
                      title: 'Expenses',
                      amount: formatAmount(_selectedExpense),
                      color: Colors.redAccent,
                      icon: Icons.arrow_downward_rounded,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSummaryMetric(
                      title: 'Income',
                      amount: formatAmount(_selectedIncome),
                      color: _emeraldGreen,
                      icon: Icons.arrow_upward_rounded,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Search Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Search narration, category, or amount...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),

            const SizedBox(height: 8),

            // Transaction List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 48,
                            color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No matching transactions'
                                : 'No transactions found in this statement',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final isExpense = item.type == TransactionType.expense;
                        final dateStr = DateFormat('dd MMM yyyy').format(item.date);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: item.isSelected
                                  ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
                                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                            ),
                          ),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                item.isSelected = !item.isSelected;
                              });
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Selection Checkbox
                                  Checkbox(
                                    value: item.isSelected,
                                    onChanged: (val) {
                                      setState(() {
                                        item.isSelected = val ?? false;
                                      });
                                    },
                                    activeColor: theme.colorScheme.primary,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  ),

                                  // Date & Narration
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              dateStr,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Category chip (tap to change)
                                            Flexible(
                                              child: InkWell(
                                                onTap: () => _showCategoryPicker(item),
                                                borderRadius: BorderRadius.circular(6),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          item.category,
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.w600,
                                                            color: theme.colorScheme.primary,
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                          maxLines: 1,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 2),
                                                      Icon(
                                                        Icons.arrow_drop_down_rounded,
                                                        size: 14,
                                                        color: theme.colorScheme.primary,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        InkWell(
                                          onTap: () => _editTransactionNote(item),
                                          child: Text(
                                            item.description,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  // Amount and Type toggle
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${isExpense ? '-' : '+'}${formatAmount(item.amount)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: isExpense ? Colors.redAccent : _emeraldGreen,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            item.type = isExpense
                                                ? TransactionType.income
                                                : TransactionType.expense;
                                            item.category = BankStatementParser.categorize(
                                              item.description,
                                              item.type,
                                            );
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(4),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          child: Text(
                                            isExpense ? 'Expense ⇄' : 'Income ⇄',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        bottomSheet: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_selectedCount of ${_transactions.length} selected',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        formatAmount(_selectedExpense + _selectedIncome),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (_selectedCount == 0 || _isImporting) ? null : _commitImport,
                    icon: _isImporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.download_done_rounded, size: 18),
                    label: Text(
                      _isImporting
                          ? 'Importing...'
                          : 'Import ($_selectedCount) Txns',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryMetric({
    required String title,
    required String amount,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
