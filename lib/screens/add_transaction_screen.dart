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

  final List<String> _expenseCategories = [
    'Food',
    'Transport',
    'Rent',
    'Entertainment',
    'Health',
    'Groceries',
    'Shopping',
    'Other'
  ];

  final List<String> _incomeCategories = [
    'Salary',
    'Gift',
    'Investment',
    'Business',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _amount = widget.transaction!.amount;
      _category = widget.transaction!.category;
      _type = widget.transaction!.type;
      _date = widget.transaction!.date;
      _note = widget.transaction!.note;
    } else {
      _amount = 0;
      _type = TransactionType.expense;
      _category = _expenseCategories.first;
      _date = DateTime.now();
      _note = '';
    }
  }

  void _onTypeChanged(TransactionType newType) {
    if (_type == newType) return;
    setState(() {
      _type = newType;
      // Reset category to the first one in the new list to avoid validation errors
      _category = _type == TransactionType.expense 
          ? _expenseCategories.first 
          : _incomeCategories.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentCategories = _type == TransactionType.expense ? _expenseCategories : _incomeCategories;

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
                validator: (value) => (value == null || double.tryParse(value) == null) ? 'Enter valid amount' : null,
                onSaved: (value) => _amount = double.parse(value!),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: InputDecoration(
                  labelText: 'Category',
                  prefixIcon: const Icon(Icons.category_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                items: currentCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (value) => setState(() => _category = value!),
              ),
              const SizedBox(height: 24),
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
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    final provider = Provider.of<FinanceProvider>(context, listen: false);
                    
                    if (widget.transaction == null) {
                      final newTx = Transaction(
                        id: const Uuid().v4(),
                        amount: _amount,
                        type: _type,
                        category: _category,
                        date: _date,
                        note: _note,
                      );
                      provider.addTransaction(newTx);
                    } else {
                      widget.transaction!.amount = _amount;
                      widget.transaction!.type = _type;
                      widget.transaction!.category = _category;
                      widget.transaction!.date = _date;
                      widget.transaction!.note = _note;
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