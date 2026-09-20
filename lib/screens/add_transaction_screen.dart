import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../models/transaction_template.dart';
import '../providers/finance_provider.dart';
import 'add_account_screen.dart';
import 'transfer_screen.dart';
import '../services/image_cache_service.dart';
import '../utils/currency_formatter.dart';

class AddTransactionScreen extends StatefulWidget {
  final Transaction? transaction;
  final TransactionTemplate? template;
  final TransactionType? initialType;
  final String? initialAccountId;

  const AddTransactionScreen({
    super.key,
    this.transaction,
    this.template,
    this.initialType,
    this.initialAccountId,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late double _amount;
  late String _category;
  late TransactionType _type;
  late DateTime _date;
  late String _note;
  late String _selectedAccountId;
  bool _saveAsTemplate = false;
  final _templateNameController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();

  final List<String> _expenseCategories = [
    'Food', 'Transport', 'Rent', 'Entertainment', 'Health', 'Groceries', 'Shopping', 'Paid', 'Other'
  ];

  final List<String> _incomeCategories = [
    'Salary', 'Gift', 'Investment', 'Business', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final defaultId = (widget.initialAccountId != null && provider.accounts.any((a) => a.id == widget.initialAccountId))
        ? widget.initialAccountId!
        : (provider.primaryAccount?.id ??
            (provider.accounts.isNotEmpty ? provider.accounts.first.id : 'default'));
    
    if (widget.transaction != null) {
      _amount = widget.transaction!.amount;
      _category = widget.transaction!.category;
      _type = widget.transaction!.type == TransactionType.transfer
          ? TransactionType.expense
          : widget.transaction!.type;
      _date = widget.transaction!.date;
      _note = widget.transaction!.note;
      _selectedAccountId = widget.transaction!.accountId ?? defaultId;
    } else if (widget.template != null) {
      _amount = widget.template!.amount;
      _category = widget.template!.category;
      _type = widget.template!.type == TransactionType.transfer
          ? TransactionType.expense
          : widget.template!.type;
      _date = DateTime.now();
      _note = widget.template!.note;
      _selectedAccountId = widget.template!.accountId ?? defaultId;
    } else {
      _amount = 0;
      _type = (widget.initialType != null && widget.initialType != TransactionType.transfer)
          ? widget.initialType!
          : TransactionType.expense;
      _category = provider.expenseCategories.isNotEmpty ? provider.expenseCategories.first : 'Other';
      _date = DateTime.now();
      _note = '';
      _selectedAccountId = defaultId;

      // Auto-open keyboard directly for Amount section on new transaction
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted && !_amountFocusNode.hasFocus) {
            _amountFocusNode.requestFocus();
          }
        });
      });
    }

    final currentCats = _type == TransactionType.expense ? provider.expenseCategories : provider.incomeCategories;
    if (!currentCats.contains(_category)) {
      if (currentCats.isNotEmpty) {
        _category = currentCats.first;
      } else {
        _category = 'Other'; 
        if (_type == TransactionType.expense) {
          provider.addExpenseCategory('Other');
        } else {
          provider.addIncomeCategory('Other');
        }
      }
    }
  }

  @override
  void dispose() {
    _amountFocusNode.dispose();
    _templateNameController.dispose();
    super.dispose();
  }

  void _onTypeChanged(TransactionType newType) {
    if (_type == newType) return;
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    setState(() {
      _type = newType;
      _category = _type == TransactionType.expense 
          ? (provider.expenseCategories.isNotEmpty ? provider.expenseCategories.first : 'Other')
          : (provider.incomeCategories.isNotEmpty ? provider.incomeCategories.first : 'Other');
    });
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'adjustment':
        return Icons.tune_rounded;
      case 'paid':
        return Icons.person_rounded;
      case 'salary':
        return Icons.account_balance_wallet_rounded;
      case 'food':
        return Icons.restaurant_rounded;
      case 'groceries':
        return Icons.shopping_cart_rounded;
      case 'entertainment':
        return Icons.play_circle_fill_rounded;
      case 'transport':
        return Icons.directions_bus_rounded;
      case 'rent':
        return Icons.home_rounded;
      case 'health':
        return Icons.medical_services_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'gift':
        return Icons.card_giftcard_rounded;
      case 'investment':
        return Icons.trending_up_rounded;
      case 'business':
        return Icons.business_center_rounded;
      case 'bills':
      case 'utilities':
        return Icons.receipt_long_rounded;
      case 'education':
        return Icons.school_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<FinanceProvider>(context);
    final currentCategories = _type == TransactionType.expense
        ? (provider.expenseCategories.isNotEmpty ? provider.expenseCategories : _expenseCategories)
        : (provider.incomeCategories.isNotEmpty ? provider.incomeCategories : _incomeCategories);
    final accounts = provider.accounts;
    final primaryAccount = provider.primaryAccount;

    // Ensure _selectedAccountId is set to a valid account if accounts are available
    if (accounts.isNotEmpty && !accounts.any((a) => a.id == _selectedAccountId)) {
      _selectedAccountId = primaryAccount?.id ?? accounts.first.id;
    }

    // Dropdown fix: Move selected account to index 0
    final List<Account> orderedAccounts = List.from(accounts);
    if (_selectedAccountId != 'default') {
      final selectedIndex = orderedAccounts.indexWhere((a) => a.id == _selectedAccountId);
      if (selectedIndex > 0) {
        final selected = orderedAccounts.removeAt(selectedIndex);
        orderedAccounts.insert(0, selected);
      }
    }

    final String screenTitle = widget.transaction != null ? 'Edit Transaction' : 'Add Transaction';

    return Scaffold(
      appBar: AppBar(
        title: Text(screenTitle),
        elevation: 0,
        actions: [
          if (widget.transaction == null)
            IconButton(
              icon: const Icon(Icons.swap_horiz_rounded),
              tooltip: 'Transfer Funds',
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const TransferScreen()),
                );
                if (result == true && context.mounted) {
                  Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Type Toggle (Expense | Income)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TypeButton(
                          label: 'Expense',
                          isSelected: _type == TransactionType.expense,
                          color: const Color(0xFFEF4444),
                          onTap: () => _onTypeChanged(TransactionType.expense),
                        ),
                      ),
                      Expanded(
                        child: _TypeButton(
                          label: 'Income',
                          isSelected: _type == TransactionType.income,
                          color: const Color(0xFF10B981),
                          onTap: () => _onTypeChanged(TransactionType.income),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Regular Account Selector (for Expense / Income)
                Text('Select Account', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  if (accounts.isEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('No accounts available', style: TextStyle(color: Colors.red.shade400, fontSize: 13, fontWeight: FontWeight.w500)),
                        TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AddAccountScreen()),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add new account'),
                        ),
                      ],
                    )
                  else
                    DropdownButtonFormField<String>(
                      menuMaxHeight: 300,
                      initialValue: orderedAccounts.any((a) => a.id == _selectedAccountId) 
                          ? _selectedAccountId 
                          : (orderedAccounts.isNotEmpty ? orderedAccounts.first.id : null),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        filled: true,
                      ),
                      items: orderedAccounts.map((acc) => DropdownMenuItem(
                        value: acc.id,
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: Color(acc.colorHex).withValues(alpha: 0.15),
                                image: ImageCacheService.fileExists(acc.customImagePath)
                                    ? DecorationImage(image: FileImage(File(acc.customImagePath!)), fit: BoxFit.cover) 
                                    : null,
                              ),
                              child: !ImageCacheService.fileExists(acc.customImagePath)
                                  ? Icon(Icons.account_balance_rounded, size: 14, color: Color(acc.colorHex)) 
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Text(acc.name),
                            if (acc.isPrimary) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                                    SizedBox(width: 2),
                                    Text(
                                      'Primary',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF6366F1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      )).toList(),
                      onChanged: (value) => setState(() => _selectedAccountId = value!),
                    ),
                  const SizedBox(height: 24),

                  // Category selector with Category Icons (including Paid person icon)
                  DropdownButtonFormField<String>(
                    menuMaxHeight: 300,
                    initialValue: currentCategories.contains(_category) ? _category : (currentCategories.isNotEmpty ? currentCategories.first : null),
                    decoration: InputDecoration(
                      labelText: 'Category',
                      prefixIcon: const Icon(Icons.category_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    items: () {
                      final List<String> cats = List<String>.from(currentCategories.isEmpty ? ['Other'] : currentCategories);
                      if (!cats.contains(_category)) {
                        cats.add(_category);
                      }
                      return cats.map((c) {
                        final catIcon = _getCategoryIcon(c);
                        return DropdownMenuItem(
                          value: c,
                          child: Row(
                            children: [
                              Icon(
                                catIcon,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Text(c),
                            ],
                          ),
                        );
                      }).toList();
                    }(),
                    onChanged: (value) => setState(() => _category = value!),
                  ),
                  const SizedBox(height: 24),

                // Amount field
                TextFormField(
                  focusNode: _amountFocusNode,
                  autofocus: widget.transaction == null,
                  initialValue: CurrencyFormatter.formatInput(_amount),
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    hintText: '0',
                    labelStyle: const TextStyle(fontSize: 16),
                    prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 32),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter amount';
                    final amount = double.tryParse(value);
                    if (amount == null) return 'Enter valid number';
                    if (amount <= 0) return 'Amount must be positive';
                    return null;
                  },
                  onSaved: (value) => _amount = double.parse(value!),
                ),
                const SizedBox(height: 24),

                // Date picker
                InkWell(
                  onTap: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2101),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date',
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      '${_date.day}/${_date.month}/${_date.year}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Note field
                TextFormField(
                  initialValue: _note,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Note (Optional)',
                    prefixIcon: const Icon(Icons.notes_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onSaved: (value) => _note = value ?? '',
                ),
                const SizedBox(height: 24),

                // Save as Template Option (only for Expense)
                if (widget.transaction == null && _type == TransactionType.expense) ...[
                  CheckboxListTile(
                    title: const Text('Save as repetitive expense (Template)', style: TextStyle(fontSize: 14)),
                    value: _saveAsTemplate,
                    onChanged: (val) => setState(() => _saveAsTemplate = val ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_saveAsTemplate)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextFormField(
                        controller: _templateNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Template Name',
                          hintText: 'e.g. Monthly Netflix, House Rent',
                          prefixIcon: const Icon(Icons.bookmark_added_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        validator: (value) => _saveAsTemplate && (value == null || value.isEmpty) ? 'Enter template name' : null,
                      ),
                    ),
                ],
                const SizedBox(height: 40),

                // Submit Button
                ElevatedButton(
                  onPressed: accounts.isEmpty
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            _formKey.currentState!.save();
                            final navigator = Navigator.of(context);
                            final effectiveAccountId = accounts.any((a) => a.id == _selectedAccountId)
                                ? _selectedAccountId
                                : (provider.primaryAccount?.id ??
                                    (accounts.isNotEmpty ? accounts.first.id : 'default'));
                            
                            if (widget.transaction == null) {
                              final newTx = Transaction(
                                id: const Uuid().v4(),
                                amount: _amount,
                                type: _type,
                                category: _category,
                                date: _date,
                                note: _note,
                                accountId: effectiveAccountId,
                              );
                              await provider.addTransaction(newTx);

                              if (_saveAsTemplate && _type == TransactionType.expense) {
                                final template = TransactionTemplate(
                                  id: const Uuid().v4(),
                                  name: _templateNameController.text,
                                  amount: _amount,
                                  type: _type,
                                  category: _category,
                                  accountId: effectiveAccountId,
                                  note: _note,
                                );
                                await provider.addTemplate(template);
                              }
                            } else {
                              widget.transaction!.amount = _amount;
                              widget.transaction!.type = _type;
                              widget.transaction!.category = _category;
                              widget.transaction!.date = _date;
                              widget.transaction!.note = _note;
                              widget.transaction!.accountId = effectiveAccountId;
                              await provider.updateTransaction(widget.transaction!);
                            }
                            navigator.pop();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    widget.transaction == null ? 'Save Transaction' : 'Update Transaction',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
