import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../providers/theme_provider.dart';
import '../models/account.dart';
import '../widgets/net_worth_card.dart';
import 'add_account_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<FinanceProvider>(context, listen: false);
      _nameController.text = provider.userName;
    });
  }

  Future<void> _pickProfilePicture(FinanceProvider provider) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      final primaryColor = Theme.of(context).colorScheme.primary;
      
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Picture',
            toolbarColor: primaryColor,
            toolbarWidgetColor: Colors.white,
            aspectRatioPresets: [CropAspectRatioPreset.square],
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Profile Picture',
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
        ],
      );

      if (croppedFile != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedImage = await File(croppedFile.path).copy('${appDir.path}/$fileName');
        await provider.setUserProfilePicture(savedImage.path);
      }
    }
  }

  void _showImagePreview(String? path) {
    if (path == null) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.file(File(path), fit: BoxFit.cover),
            ),
            const SizedBox(height: 16),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditNameDialog(FinanceProvider provider) {
    _nameController.text = provider.userName;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(hintText: 'Enter your name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.setUserName(_nameController.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showCategoryCustomization(bool isExpense) {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final categories = isExpense ? provider.expenseCategories : provider.incomeCategories;
    final newCategoryController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isExpense ? 'Customise Expense Categories' : 'Customise Income Categories', 
                style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: newCategoryController,
                      decoration: const InputDecoration(hintText: 'New category name'),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (newCategoryController.text.isNotEmpty) {
                        if (isExpense) {
                          provider.addExpenseCategory(newCategoryController.text);
                        } else {
                          provider.addIncomeCategory(newCategoryController.text);
                        }
                        newCategoryController.clear();
                        setModalState(() {});
                      }
                    },
                    icon: const Icon(Icons.add_circle_rounded),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return ListTile(
                      title: Text(cat),
                      contentPadding: EdgeInsets.zero,
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.red),
                        onPressed: () {
                          if (isExpense) {
                            provider.removeExpenseCategory(cat);
                          } else {
                            provider.removeIncomeCategory(cat);
                          }
                          setModalState(() {});
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final financeProvider = Provider.of<FinanceProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final accounts = financeProvider.accounts;
    final isDark = themeProvider.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => themeProvider.toggleTheme(!isDark),
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => _pickProfilePicture(financeProvider),
              onLongPress: () => _showImagePreview(financeProvider.userProfilePicture),
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                    backgroundImage: financeProvider.userProfilePicture != null
                        ? FileImage(File(financeProvider.userProfilePicture!))
                        : null,
                    child: financeProvider.userProfilePicture == null
                        ? const Icon(Icons.person_rounded, size: 50)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _showEditNameDialog(financeProvider),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Text(
                  financeProvider.userName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Net Worth Card shifted here
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: NetWorthCard(
                totalBalance: financeProvider.totalNetWorth,
                income: financeProvider.totalIncome,
                expenses: financeProvider.totalExpenses,
              ),
            ),
            const SizedBox(height: 32),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'BANK ACCOUNTS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                          letterSpacing: 1.2,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddAccountScreen(),
                          ),
                        ),
                        child: const Text('Add New'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < accounts.length; i++) ...[
                          _AccountListTile(
                            account: accounts[i],
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AddAccountScreen(account: accounts[i]),
                              ),
                            ),
                          ),
                          if (i < accounts.length - 1)
                            const Divider(height: 1, indent: 70, endIndent: 20),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'CATEGORIES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          title: const Text('Customise Expense'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _showCategoryCustomization(true),
                        ),
                        const Divider(height: 1, indent: 20, endIndent: 20),
                        ListTile(
                          title: const Text('Customise Income'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _showCategoryCustomization(false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _AccountListTile extends StatelessWidget {
  final Account account;
  final VoidCallback onTap;

  const _AccountListTile({required this.account, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Color(account.colorHex).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          image: account.customImagePath != null
              ? DecorationImage(
                  image: FileImage(File(account.customImagePath!)),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: account.customImagePath == null
            ? Icon(
                Icons.account_balance_rounded,
                color: Color(account.colorHex),
              )
            : null,
      ),
      title: Text(
        account.name,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        account.bankProvider ?? "Bank",
        style: const TextStyle(fontSize: 12),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Color(0xFFCBD5E1),
      ),
    );
  }
}
