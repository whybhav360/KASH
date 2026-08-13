import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../providers/finance_provider.dart';

class AddTransactionScreen extends StatefulWidget {
  final Transaction? transaction;

  const AddTransactionScreen({super.key, this.transaction});

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
    } else {
      _amount = 0;
      _type = TransactionType.expense;
      _category = _expenseCategories.first;
      _date = DateTime.now();
      _note = '';
      _selectedAccountId = provider.accounts.isNotEmpty ? provider.accounts.first.id : 'default';
    }
  }

  void _onTypeChanged(TransactionType newType) {
    if (_type == newType) return;
    setState(() {
      _type = newType;
      _category = _type == TransactionType.expense 
          ? _expenseCategories.first 
          : _incomeCategories.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final currentCategories = _type == TransactionType.expense ? _expenseCategories : _incomeCategories;
    final accounts = provider.accounts;

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
                  color: Colors.grey.shade100,
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
              const Text('Select Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: accounts.any((a) => a.id == _selectedAccountId) 
                    ? _selectedAccountId 
                    : (accounts.isNotEmpty ? accounts.first.id : null),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
                items: accounts.map((acc) => DropdownMenuItem(
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
                initialValue: _category,
                decoration: InputDecoration(
                  labelText: 'Category',
                  prefixIcon: const Icon(Icons.category_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                items: currentCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
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
