import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../models/transaction_template.dart';
import '../providers/finance_provider.dart';

class AddTransactionScreen extends StatefulWidget {
  final Transaction? transaction;
  final TransactionTemplate? template;

  const AddTransactionScreen({super.key, this.transaction, this.template});

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

  final List<String> _expenseCategories = [
    'Food', 'Transport', 'Rent', 'Entertainment', 'Health', 'Groceries', 'Shopping', 'Other'
  ];

  final List<String> _incomeCategories = [
    'Salary', 'Gift', 'Investment', 'Business', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    
    if (widget.transaction != null) {
      _amount = widget.transaction!.amount;
      _category = widget.transaction!.category;
      _type = widget.transaction!.type;
      _date = widget.transaction!.date;
      _note = widget.transaction!.note;
      _selectedAccountId = widget.transaction!.accountId ?? 'default';
    } else if (widget.template != null) {
      _amount = widget.template!.amount;
      _category = widget.template!.category;
      _type = widget.template!.type;
      _date = DateTime.now();
      _note = widget.template!.note;
      _selectedAccountId = widget.template!.accountId ?? (provider.accounts.isNotEmpty ? provider.accounts.first.id : 'default');
    } else {
      _amount = 0;
      _type = TransactionType.expense;
      _category = provider.expenseCategories.isNotEmpty ? provider.expenseCategories.first : 'Other';
      _date = DateTime.now();
      _note = '';
      _selectedAccountId = provider.accounts.isNotEmpty ? provider.accounts.first.id : 'default';
    }
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final currentCategories = _type == TransactionType.expense ? _expenseCategories : _incomeCategories;
    final accounts = provider.accounts;
    
    // Dropdown fix: Move selected account to index 0
    final List<Account> orderedAccounts = List.from(accounts);
    if (_selectedAccountId != 'default') {
      final selectedIndex = orderedAccounts.indexWhere((a) => a.id == _selectedAccountId);
      if (selectedIndex > 0) {
        final selected = orderedAccounts.removeAt(selectedIndex);
        orderedAccounts.insert(0, selected);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transaction == null ? 'Add Transaction' : 'Edit Transaction'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Type Toggle
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
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
              const SizedBox(height: 32),

              // Account Selector
              Text('Select Account', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                menuMaxHeight: 300,
                value: _selectedAccountId,
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
                          color: Color(acc.colorHex).withOpacity(0.1),
                          image: acc.customImagePath != null 
                              ? DecorationImage(image: FileImage(File(acc.customImagePath!)), fit: BoxFit.cover) 
                              : null,
                        ),
                        child: acc.customImagePath == null 
                            ? Icon(Icons.account_balance_rounded, size: 14, color: Color(acc.colorHex)) 
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Text(acc.name),
                    ],
                  ),
                )).toList(),
                onChanged: (value) => setState(() => _selectedAccountId = value!),
              ),
              const SizedBox(height: 24),

              // Amount field
              TextFormField(
                initialValue: _amount == 0 ? '' : _amount.toString(),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Amount',
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

              // Category selector
              DropdownButtonFormField<String>(
                menuMaxHeight: 300,
                value: _category,
                decoration: InputDecoration(
                  labelText: 'Category',
                  prefixIcon: const Icon(Icons.category_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                items: (() {
                  final List<String> orderedCats = List.from(currentCategories);
                  final selectedIndex = orderedCats.indexOf(_category);
                  if (selectedIndex > 0) {
                    final selected = orderedCats.removeAt(selectedIndex);
                    orderedCats.insert(0, selected);
                  }
                  return orderedCats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList();
                })(),
                onChanged: (value) => setState(() => _category = value!),
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
                decoration: InputDecoration(
                  labelText: 'Note (Optional)',
                  prefixIcon: const Icon(Icons.notes_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onSaved: (value) => _note = value ?? '',
              ),
              const SizedBox(height: 24),

              // Save as Template Option
              if (widget.transaction == null && _type == TransactionType.expense) ...[
                CheckboxListTile(
                  title: const Text('Save as repetitive expense (Template)', style: TextStyle(fontSize: 14)),
                  value: _saveAsTemplate,
                  onChanged: (val) => setState(() => _saveAsTemplate = val ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: const Color(0xFF6366F1),
                ),
                if (_saveAsTemplate)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: TextFormField(
                      controller: _templateNameController,
                      decoration: InputDecoration(
                        labelText: 'Template Name',
                        hintText: 'e.g., Morning Coffee',
                        prefixIcon: const Icon(Icons.label_outline_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      validator: (value) => _saveAsTemplate && (value == null || value.isEmpty) ? 'Enter template name' : null,
                    ),
                  ),
              ],
              const SizedBox(height: 40),

              // Submit Button
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    
                    if (widget.transaction == null) {
                      final newTx = Transaction(
                        id: const Uuid().v4(),
                        amount: _amount,
                        type: _type,
                        category: _category,
                        date: _date,
                        note: _note,
                        accountId: _selectedAccountId,
                      );
                      provider.addTransaction(newTx);

                      if (_saveAsTemplate) {
                        final template = TransactionTemplate(
                          id: const Uuid().v4(),
                          name: _templateNameController.text,
                          amount: _amount,
                          type: _type,
                          category: _category,
                          accountId: _selectedAccountId,
                          note: _note,
                        );
                        provider.addTemplate(template);
                      }
                    } else {
                      widget.transaction!.amount = _amount;
                      widget.transaction!.type = _type;
                      widget.transaction!.category = _category;
                      widget.transaction!.date = _date;
                      widget.transaction!.note = _note;
                      widget.transaction!.accountId = _selectedAccountId;
                      provider.updateTransaction(widget.transaction!);
                    }
                    Navigator.pop(context);
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
