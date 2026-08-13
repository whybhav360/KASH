import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/account.dart';
import '../providers/finance_provider.dart';

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

  final ImagePicker _picker = ImagePicker();

  final List<int> _availableColors = [
    0xFF4F46E5, // Indigo
    0xFF10B981, // Emerald
    0xFFF59E0B, // Amber
    0xFFEF4444, // Red
    0xFF8B5CF6, // Violet
    0xFFEC4899, // Pink
  ];

  @override
  void initState() {
    super.initState();
    if (widget.account != null) {
      _name = widget.account!.name;
      _initialBalance = widget.account!.openingBalance;
      _bankProvider = widget.account!.bankProvider ?? '';
      _selectedColor = widget.account!.colorHex;
      _customImagePath = widget.account!.customImagePath;
    } else {
      _name = '';
      _initialBalance = 0;
      _bankProvider = '';
      _selectedColor = 0xFF4F46E5;
      _customImagePath = null;
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = path.basename(image.path);
      final savedImage = await File(image.path).copy('${appDir.path}/$fileName');
      setState(() {
        _customImagePath = savedImage.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add New Account', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Enter your bank account details to start tracking your finances.', 
                style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
              const SizedBox(height: 32),
              
              const Text('Account Name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: _name,
                decoration: InputDecoration(
                  hintText: 'e.g., Daily Expenses',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Please enter a name' : null,
                onSaved: (value) => _name = value!,
              ),
              const SizedBox(height: 24),
              
              const Text('Account Logo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
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
              
              const Text('Initial Balance', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const SizedBox(height: 8),
              TextFormField(
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                keyboardType: TextInputType.number,
                initialValue: _initialBalance.toStringAsFixed(2),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Enter balance';
                  if (double.tryParse(value) == null) return 'Enter valid number';
                  return null;
                },
                onSaved: (value) => _initialBalance = double.parse(value!),
              ),
              const SizedBox(height: 24),
              
              const Text('Bank Provider (Optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: _bankProvider,
                decoration: InputDecoration(
                  hintText: 'Search bank name',
                  prefixIcon: const Icon(Icons.account_balance_outlined, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                onSaved: (value) => _bankProvider = value ?? '',
              ),
              const SizedBox(height: 48),
              
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
    );
  }

  void _saveAccount() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final provider = Provider.of<FinanceProvider>(context, listen: false);
      
      if (widget.account == null) {
        final account = Account(
          id: Uuid().v4(),
          name: _name,
          openingBalance: _initialBalance,
          colorHex: _selectedColor,
          bankProvider: _bankProvider,
          iconCodePoint: Icons.account_balance_rounded.codePoint,
          customImagePath: _customImagePath,
        );
        provider.addAccount(account);
      } else {
        widget.account!.name = _name;
        widget.account!.openingBalance = _initialBalance;
        widget.account!.colorHex = _selectedColor;
        widget.account!.bankProvider = _bankProvider;
        widget.account!.iconCodePoint = Icons.account_balance_rounded.codePoint;
        widget.account!.customImagePath = _customImagePath;
        provider.updateAccount(widget.account!);
      }
      Navigator.pop(context);
    }
  }

  void _deleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text('This will permanently delete this account. Transactions linked to this account will remain but lose their link.'),
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
