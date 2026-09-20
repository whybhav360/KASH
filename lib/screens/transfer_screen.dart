import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../providers/finance_provider.dart';
import 'add_account_screen.dart';
import '../services/image_cache_service.dart';
import '../utils/currency_formatter.dart';

class TransferScreen extends StatefulWidget {
  final Transaction? transaction;

  const TransferScreen({
    super.key,
    this.transaction,
  });

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  late double _amount;
  late DateTime _date;
  late String _note;
  late String _fromAccountId;
  String? _toAccountId;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final accounts = provider.accounts;

    if (widget.transaction != null) {
      _amount = widget.transaction!.amount;
      _date = widget.transaction!.date;
      _note = widget.transaction!.note;
      final fromExists = accounts.any((a) => a.id == widget.transaction!.accountId);
      final toExists = widget.transaction!.toAccountId != null && accounts.any((a) => a.id == widget.transaction!.toAccountId);
      _fromAccountId = fromExists
          ? widget.transaction!.accountId!
          : (accounts.isNotEmpty ? accounts.first.id : 'default');
      _toAccountId = toExists
          ? widget.transaction!.toAccountId
          : (accounts.where((a) => a.id != _fromAccountId).firstOrNull?.id);
    } else {
      _amount = 0;
      _date = DateTime.now();
      _note = '';
      _fromAccountId = accounts.isNotEmpty ? accounts.first.id : 'default';
      _toAccountId = accounts.length >= 2
          ? accounts.firstWhere((a) => a.id != _fromAccountId, orElse: () => accounts.last).id
          : null;
    }
  }

  void _swapAccounts() {
    if (_toAccountId == null) return;
    setState(() {
      final temp = _fromAccountId;
      _fromAccountId = _toAccountId!;
      _toAccountId = temp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<FinanceProvider>(context);
    final accounts = provider.accounts;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transaction == null ? 'Transfer Funds' : 'Edit Transfer'),
        elevation: 0,
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
                if (accounts.length < 2) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 28),
                        const SizedBox(height: 8),
                        const Text(
                          'At least 2 accounts are required to transfer funds between accounts.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AddAccountScreen()),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add Second Account'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  // Source Account (From)
                  Text('From Account', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: ValueKey('from_$_fromAccountId'),
                    isExpanded: true,
                    menuMaxHeight: 300,
                    initialValue: accounts.any((a) => a.id == _fromAccountId) ? _fromAccountId : accounts.first.id,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.outbox_rounded, color: Color(0xFFEF4444)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                    ),
                    items: accounts.map((acc) {
                      final balance = provider.getAccountBalance(acc.id);
                      return DropdownMenuItem(
                        value: acc.id,
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: Color(acc.colorHex).withValues(alpha: 0.15),
                                image: ImageCacheService.fileExists(acc.customImagePath)
                                    ? DecorationImage(image: FileImage(File(acc.customImagePath!)), fit: BoxFit.cover)
                                    : null,
                              ),
                              child: !ImageCacheService.fileExists(acc.customImagePath)
                                  ? Icon(Icons.account_balance_rounded, size: 12, color: Color(acc.colorHex))
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Flexible(child: Text(acc.name, overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            Text(
                              CurrencyFormatter.format(balance),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _fromAccountId = value;
                          if (_toAccountId == value) {
                            final other = accounts.where((a) => a.id != value).firstOrNull;
                            _toAccountId = other?.id;
                          }
                        });
                      }
                    },
                  ),

                  // Swap Button
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: IconButton.filledTonal(
                        onPressed: _swapAccounts,
                        icon: const Icon(Icons.swap_vert_rounded),
                        tooltip: 'Swap Accounts',
                      ),
                    ),
                  ),

                  // Destination Account (To)
                  Text('To Account', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: ValueKey('to_$_toAccountId'),
                    isExpanded: true,
                    menuMaxHeight: 300,
                    initialValue: (_toAccountId != null && accounts.any((a) => a.id == _toAccountId))
                        ? _toAccountId
                        : (accounts.where((a) => a.id != _fromAccountId).firstOrNull?.id),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.move_to_inbox_rounded, color: Color(0xFF10B981)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                    ),
                    items: accounts.map((acc) {
                      final balance = provider.getAccountBalance(acc.id);
                      final isSelectedSource = acc.id == _fromAccountId;
                      return DropdownMenuItem(
                        value: acc.id,
                        enabled: !isSelectedSource,
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: Color(acc.colorHex).withValues(alpha: 0.15),
                                image: ImageCacheService.fileExists(acc.customImagePath)
                                    ? DecorationImage(image: FileImage(File(acc.customImagePath!)), fit: BoxFit.cover)
                                    : null,
                              ),
                              child: !ImageCacheService.fileExists(acc.customImagePath)
                                  ? Icon(Icons.account_balance_rounded, size: 12, color: Color(acc.colorHex))
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                acc.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isSelectedSource ? Colors.grey : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              CurrencyFormatter.format(balance),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelectedSource ? Colors.grey : theme.textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _toAccountId = value);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                ],

                // Amount Field
                TextFormField(
                  initialValue: CurrencyFormatter.formatInput(_amount),
                  autofocus: widget.transaction == null && accounts.length >= 2,
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
                    if (value == null || value.trim().isEmpty) return 'Enter amount';
                    final amount = double.tryParse(value.trim());
                    if (amount == null) return 'Enter valid number';
                    if (amount <= 0) return 'Amount must be positive';
                    return null;
                  },
                  onSaved: (value) => _amount = double.parse(value!.trim()),
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
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat.yMMMd().format(_date),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Note Field
                TextFormField(
                  initialValue: _note,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Transfer Note (Optional)',
                    hintText: 'e.g., Savings, Emergency fund',
                    prefixIcon: const Icon(Icons.note_alt_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onSaved: (value) => _note = value?.trim() ?? '',
                ),
                const SizedBox(height: 36),

                // Submit Button
                ElevatedButton(
                  onPressed: accounts.length < 2
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            _formKey.currentState!.save();
                            final navigator = Navigator.of(context);

                            if (_toAccountId == null || _toAccountId == _fromAccountId) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Source and destination accounts must be different.'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            if (widget.transaction == null) {
                              await provider.transfer(
                                fromAccountId: _fromAccountId,
                                toAccountId: _toAccountId!,
                                amount: _amount,
                                date: _date,
                                note: _note,
                              );
                            } else {
                              widget.transaction!.amount = _amount;
                              widget.transaction!.type = TransactionType.transfer;
                              widget.transaction!.category = 'Transfer';
                              widget.transaction!.date = _date;
                              widget.transaction!.note = _note;
                              widget.transaction!.accountId = _fromAccountId;
                              widget.transaction!.toAccountId = _toAccountId;
                              await provider.updateTransaction(widget.transaction!);
                            }

                            navigator.pop(true);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    widget.transaction == null ? 'Transfer Funds' : 'Update Transfer',
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
