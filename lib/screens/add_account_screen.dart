import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/account.dart';
import '../providers/finance_provider.dart';
import '../utils/currency_formatter.dart';

class AddAccountScreen extends StatefulWidget {
  final Account? account;
  const AddAccountScreen({super.key, this.account});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late double _initialBalance;
  late String _bankProvider;
  int _selectedColor = 0xFF4F46E5;
  String? _customImagePath;
  late bool _isPrimary;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    if (widget.account != null) {
      _name = widget.account!.name;
      _initialBalance = widget.account!.openingBalance;
      _bankProvider = widget.account!.bankProvider ?? '';
      _selectedColor = widget.account!.colorHex;
      _customImagePath = widget.account!.customImagePath;
      _isPrimary = widget.account!.isPrimary;
    } else {
      _name = '';
      _initialBalance = 0;
      _bankProvider = '';
      _selectedColor = 0xFF4F46E5;
      _customImagePath = null;
      _isPrimary = provider.accounts.isEmpty;
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = image.name;
      final savedImage = await File(image.path).copy('${appDir.path}/$fileName');
      setState(() {
        _customImagePath = savedImage.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account == null ? 'Add Bank Account' : 'Edit Bank Account', style: const TextStyle(fontSize: 18)),
        centerTitle: true,
        actions: [
          if (widget.account != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              onPressed: _deleteAccount,
            ),
          TextButton(
            onPressed: _saveAccount,
            child: Text(widget.account == null ? 'Create' : 'Save', style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.account == null ? 'Add New Account' : 'Edit Account', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(widget.account == null 
                  ? 'Enter your bank account details to start tracking your finances.'
                  : 'Manage and reconcile your account details.', 
                style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 32),
              
              Text('Account Name', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: _name,
                autofocus: widget.account == null,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'e.g., Daily Expenses',
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Please enter a name' : null,
                onSaved: (value) => _name = value!,
              ),
              const SizedBox(height: 24),
              
              Text('Account Logo', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      image: _customImagePath != null 
                          ? DecorationImage(image: FileImage(File(_customImagePath!)), fit: BoxFit.cover) 
                          : null,
                    ),
                    child: _customImagePath == null 
                        ? Icon(Icons.account_balance_rounded, color: Color(_selectedColor)) 
                        : null,
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton(
                    onPressed: _pickImage,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF6366F1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Choose Image', style: TextStyle(color: Color(0xFF6366F1))),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              if (widget.account != null) ...[
                Builder(
                  builder: (context) {
                    final provider = Provider.of<FinanceProvider>(context);
                    final currentBal = provider.getAccountBalance(widget.account!.id);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Calculated Balance',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                CurrencyFormatter.format(currentBal),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _showReconcileDialog(currentBal),
                            icon: const Icon(Icons.tune_rounded, size: 16),
                            label: const Text('Reconcile'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
              
              Text(widget.account == null ? 'Initial Balance' : 'Opening Balance (Starting Balance)', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextFormField(
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  hintText: '0',
                  filled: true,
                  helperText: widget.account == null ? null : 'Starting balance before transactions. Use "Reconcile" above to adjust current balance.',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                keyboardType: TextInputType.number,
                initialValue: (widget.account == null || _initialBalance <= 0) ? '' : CurrencyFormatter.formatInput(_initialBalance),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return null; // Defaults to 0
                  }
                  if (double.tryParse(value.trim()) == null) return 'Enter valid number';
                  return null;
                },
                onSaved: (value) => _initialBalance = (value == null || value.trim().isEmpty) ? 0 : double.parse(value.trim()),
              ),
              const SizedBox(height: 24),
              
              Text('Bank Provider (Optional)', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: _bankProvider,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Search bank name',
                  prefixIcon: const Icon(Icons.account_balance_outlined, size: 20),
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                onSaved: (value) => _bankProvider = value ?? '',
              ),
              const SizedBox(height: 24),

              // Primary Account Switch
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isPrimary 
                        ? const Color(0xFF6366F1).withValues(alpha: 0.5) 
                        : Colors.transparent,
                  ),
                ),
                child: SwitchListTile(
                  value: _isPrimary,
                  onChanged: (val) => setState(() => _isPrimary = val),
                  activeThumbColor: const Color(0xFF6366F1),
                  title: Row(
                    children: [
                      const Text('Set as Primary Account', style: TextStyle(fontWeight: FontWeight.w600)),
                      if (_isPrimary) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                      ],
                    ],
                  ),
                  subtitle: const Text(
                    'Default account automatically assigned when adding transactions',
                    style: TextStyle(fontSize: 12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 36),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveAccount,
                  icon: Icon(widget.account == null ? Icons.add_circle_outline_rounded : Icons.save_rounded),
                  label: Text(widget.account == null ? 'Create Account' : 'Save Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
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

  void _saveAccount() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final provider = Provider.of<FinanceProvider>(context, listen: false);
      
      if (widget.account == null) {
        final account = Account(
          id: const Uuid().v4(),
          name: _name,
          openingBalance: _initialBalance,
          colorHex: _selectedColor,
          bankProvider: _bankProvider,
          iconCodePoint: Icons.account_balance_rounded.codePoint,
          customImagePath: _customImagePath,
          isPrimary: _isPrimary,
        );
        provider.addAccount(account);
      } else {
        widget.account!.name = _name;
        widget.account!.openingBalance = _initialBalance;
        widget.account!.colorHex = _selectedColor;
        widget.account!.bankProvider = _bankProvider;
        widget.account!.iconCodePoint = Icons.account_balance_rounded.codePoint;
        widget.account!.customImagePath = _customImagePath;
        widget.account!.isPrimary = _isPrimary;
        provider.updateAccount(widget.account!);
      }
      Navigator.pop(context);
    }
  }

  void _showReconcileDialog(double currentBalance) {
    final actualBalController = TextEditingController(
      text: CurrencyFormatter.formatInput(currentBalance),
    );
    bool createTx = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final parsed = double.tryParse(actualBalController.text.trim()) ?? currentBalance;
          final diff = parsed - currentBalance;

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.tune_rounded, size: 22, color: Color(0xFF6366F1)),
                SizedBox(width: 8),
                Text('Reconcile Balance'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current KASH balance: ${CurrencyFormatter.format(currentBalance)}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: actualBalController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Actual Bank Balance',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 12),
                  if (diff.abs() >= 0.01) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: diff > 0 ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        diff > 0
                            ? 'Difference: +${CurrencyFormatter.format(diff)} (KASH is lower)'
                            : 'Difference: ${CurrencyFormatter.format(diff)} (KASH is higher)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: diff > 0 ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  CheckboxListTile(
                    value: createTx,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Record adjustment transaction', style: TextStyle(fontSize: 13)),
                    subtitle: const Text('Creates a clear Adjustment entry in history', style: TextStyle(fontSize: 11)),
                    onChanged: (val) => setModalState(() => createTx = val ?? true),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final entered = double.tryParse(actualBalController.text.trim());
                  if (entered != null) {
                    final provider = Provider.of<FinanceProvider>(context, listen: false);
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(ctx);
                    await provider.reconcileAccountBalance(
                      widget.account!.id,
                      entered,
                      createAdjustmentTransaction: createTx,
                    );
                    if (mounted) {
                      setState(() {});
                      navigator.pop();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Account balance updated to ${CurrencyFormatter.format(entered)}'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Sync Balance'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text('This will permanently delete this account and all transactions associated with it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Provider.of<FinanceProvider>(context, listen: false).deleteAccount(widget.account!);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back from screen
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
