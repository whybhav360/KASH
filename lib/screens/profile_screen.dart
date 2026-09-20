import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../providers/theme_provider.dart';
import '../models/account.dart';
import '../services/backup_service.dart';
import '../services/bank_statement_parser.dart';
import '../widgets/bank_password_dialog.dart';
import '../widgets/net_worth_card.dart';
import '../services/image_cache_service.dart';
import 'add_account_screen.dart';
import 'bank_statement_review_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool autoEditName;

  const ProfileScreen({super.key, this.autoEditName = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = Provider.of<FinanceProvider>(context, listen: false);
      _nameController.text = provider.userName;
      if (widget.autoEditName) {
        _showEditNameDialog(provider);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(File(path), fit: BoxFit.contain),
              ),
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
    if (!provider.hasChangedName && provider.userName == 'User') {
      _nameController.clear();
    } else {
      _nameController.text = provider.userName;
      _nameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _nameController.text.length,
      );
    }
    showDialog(
      context: context,
      builder: (context) => GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: AlertDialog(
          title: const Text('Edit Name'),
          content: SingleChildScrollView(
            child: TextFormField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Enter your name'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final text = _nameController.text.trim();
                if (text.isNotEmpty) {
                  provider.setUserName(text);
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
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

  void _showCategoryCustomization(bool isExpense) {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final newCategoryController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          final categories = isExpense ? provider.expenseCategories : provider.incomeCategories;
          final mediaQuery = MediaQuery.of(modalContext);
          final keyboardHeight = mediaQuery.viewInsets.bottom;
          final screenHeight = mediaQuery.size.height;
          // Available visible height above keyboard and top system status bar
          final availableHeight = (screenHeight - keyboardHeight - mediaQuery.padding.top).clamp(200.0, screenHeight);
          final sheetHeight = keyboardHeight > 0
              ? (availableHeight * 0.95).clamp(260.0, availableHeight)
              : (screenHeight * 0.70).clamp(320.0, screenHeight * 0.85);

          Future<void> addCategory() async {
            final trimmed = newCategoryController.text.trim();
            if (trimmed.isNotEmpty) {
              if (isExpense) {
                await provider.addExpenseCategory(trimmed);
              } else {
                await provider.addIncomeCategory(trimmed);
              }
              newCategoryController.clear();
              if (modalContext.mounted) {
                setModalState(() {});
              }
            }
          }

          return AnimatedPadding(
            padding: EdgeInsets.only(bottom: keyboardHeight),
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: GestureDetector(
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              behavior: HitTestBehavior.translucent,
              child: SizedBox(
                height: sheetHeight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isExpense ? 'Customise Expense Categories' : 'Customise Income Categories', 
                                  style: Theme.of(modalContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Hold & drag to rearrange categories (reflects in Add Transaction)',
                                  style: TextStyle(fontSize: 11, color: Theme.of(modalContext).hintColor),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(modalContext),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: newCategoryController,
                              autofocus: false,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                hintText: isExpense ? 'New expense category name' : 'New income category name',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onSubmitted: (_) => addCategory(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: addCategory,
                            icon: const Icon(Icons.add_rounded),
                            tooltip: 'Add Category',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ReorderableListView.builder(
                          buildDefaultDragHandles: false,
                          itemCount: categories.length,
                          onReorder: (oldIndex, newIndex) {
                            if (isExpense) {
                              provider.reorderExpenseCategories(oldIndex, newIndex);
                            } else {
                              provider.reorderIncomeCategories(oldIndex, newIndex);
                            }
                            setModalState(() {});
                          },
                          itemBuilder: (context, index) {
                            final cat = categories[index];
                            final catIcon = _getCategoryIcon(cat);
                            return ReorderableDelayedDragStartListener(
                              key: ValueKey(cat),
                              index: index,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Material(
                                  color: Theme.of(modalContext).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  clipBehavior: Clip.antiAlias,
                                  child: ListTile(
                                    dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                  leading: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Theme.of(modalContext).colorScheme.primary.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(catIcon, size: 18, color: Theme.of(modalContext).colorScheme.primary),
                                  ),
                                  title: Text(
                                    cat,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.red, size: 20),
                                        onPressed: () async {
                                          if (isExpense) {
                                            await provider.removeExpenseCategory(cat);
                                          } else {
                                            await provider.removeIncomeCategory(cat);
                                          }
                                          if (modalContext.mounted) {
                                            setModalState(() {});
                                          }
                                        },
                                      ),
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 4, right: 4),
                                        child: Icon(Icons.drag_handle_rounded, color: Theme.of(context).hintColor, size: 22),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        },
      ),
    );
  }

  void _showExportOptions(BuildContext context, FinanceProvider provider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Export Data',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Save data backup to your device (Goals are excluded):',
                  style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor),
                ),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  tileColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.save_rounded, color: Theme.of(context).colorScheme.primary),
                  ),
                  title: const Text('Save Full Backup (JSON)', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Save JSON file of accounts, transactions, templates & categories to device', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _exportJson(context, provider);
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  tileColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.table_chart_rounded, color: Colors.teal),
                  ),
                  title: const Text('Save Spreadsheet (CSV)', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Save CSV file of transactions to device for Excel or Sheets', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _exportCsv(context, provider);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportJson(BuildContext context, FinanceProvider provider) async {
    try {
      final jsonStr = await BackupService.exportToJson(
        accounts: provider.accounts,
        transactions: provider.transactions,
        templates: provider.templates,
        expenseCategories: provider.expenseCategories,
        incomeCategories: provider.incomeCategories,
        userName: provider.userName,
        userProfilePicture: provider.userProfilePicture,
      );
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'kash_backup_$timestamp.json';
      final savedPath = await BackupService.saveBackupFile(
        content: jsonStr,
        fileName: fileName,
      );
      if (savedPath != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup saved successfully: $fileName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportCsv(BuildContext context, FinanceProvider provider) async {
    try {
      final csvStr = BackupService.exportToCsv(
        transactions: provider.transactions,
        accounts: provider.accounts,
      );
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'kash_transactions_$timestamp.csv';
      final savedPath = await BackupService.saveBackupFile(
        content: csvStr,
        fileName: fileName,
      );
      if (savedPath != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV saved successfully: $fileName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handlePdfStatementImport(BuildContext context, FinanceProvider provider) async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (picked == null) return;

      Uint8List bytes;
      if (picked.path != null) {
        bytes = await File(picked.path!).readAsBytes();
      } else {
        bytes = await picked.readAsBytes();
      }

      if (!context.mounted) return;

      BankStatementResult? statementResult;
      String? currentPassword;
      bool isUnlocked = false;

      while (!isUnlocked) {
        try {
          statementResult = BankStatementParser.parsePdfBytes(bytes, password: currentPassword);
          isUnlocked = true;
        } on PdfPasswordProtectedException {
          if (!context.mounted) return;
          final entered = await showDialog<String>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => const BankPasswordDialog(),
          );
          if (entered == null) return;
          currentPassword = entered;
        } on PdfInvalidPasswordException {
          if (!context.mounted) return;
          final entered = await showDialog<String>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => const BankPasswordDialog(
              initialError: 'Incorrect password. Please verify and try again.',
            ),
          );
          if (entered == null) return;
          currentPassword = entered;
        }
      }

      if (statementResult != null && context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BankStatementReviewScreen(
              statementResult: statementResult!,
              fileName: picked.name,
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Statement Error'),
          content: Text(e.toString().replaceAll('Exception: ', '')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _handleImport(BuildContext context, FinanceProvider provider) async {
    try {
      final picked = await BackupService.pickBackupFile();
      if (picked == null || !context.mounted) return;

      final BackupData backupData;
      if (picked.extension == 'csv') {
        backupData = BackupService.parseCsvBackup(
          picked.content,
          existingAccounts: provider.accounts,
        );
      } else {
        backupData = BackupService.parseJsonBackup(picked.content);
      }

      if (!context.mounted) return;
      _showImportStrategyDialog(context, provider, backupData, picked.fileName);
    } catch (e) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Import Failed'),
            content: Text('Could not read or parse the selected file:\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showImportStrategyDialog(
    BuildContext context,
    FinanceProvider provider,
    BackupData data,
    String fileName,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Import ${data.format.toUpperCase()} Data',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('File: $fileName', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (data.accounts.isNotEmpty)
                      Text('• ${data.accounts.length} Accounts', style: const TextStyle(fontSize: 13)),
                    Text('• ${data.transactions.length} Transactions', style: const TextStyle(fontSize: 13)),
                    if (data.templates.isNotEmpty)
                      Text('• ${data.templates.length} Templates', style: const TextStyle(fontSize: 13)),
                    if (data.expenseCategories.isNotEmpty || data.incomeCategories.isNotEmpty)
                      Text('• ${data.expenseCategories.length + data.incomeCategories.length} Categories', style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your existing Goals will NOT be affected.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select how you want to import this data:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _executeImport(context, provider, data, replace: false);
            },
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Merge'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _executeImport(context, provider, data, replace: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeImport(
    BuildContext context,
    FinanceProvider provider,
    BackupData data, {
    required bool replace,
  }) async {
    try {
      await provider.importBackupData(data, replaceExisting: replace);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${replace ? "Replaced with" : "Merged"} ${data.transactions.length} transactions successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final financeProvider = Provider.of<FinanceProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final accounts = financeProvider.accounts;
    final isDark = themeProvider.isDarkMode;

    return RepaintBoundary(
      key: _repaintBoundaryKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profile & Settings'),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: () => themeProvider.toggleTheme(!isDark),
              tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return RotationTransition(
                    turns: Tween<double>(begin: 0.75, end: 1.0).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                    child: ScaleTransition(
                      scale: CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutBack,
                      ),
                      child: child,
                    ),
                  );
                },
                child: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  key: ValueKey<bool>(isDark),
                  color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF6366F1),
                ),
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
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    backgroundImage: financeProvider.userProfilePicture != null
                        ? FileImage(File(financeProvider.userProfilePicture!))
                        : const AssetImage('assets/images/d_prof.jpg') as ImageProvider,
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
                  if (accounts.isNotEmpty) ...[
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
                    Material(
                      color: Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
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
                  ],
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
                  Material(
                    color: Theme.of(context).colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
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
                  const SizedBox(height: 32),
                  const Text(
                    'DATA & BACKUP',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: Theme.of(context).colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.upload_file_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          title: const Text(
                            'Export Data',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text(
                            'JSON full backup or CSV spreadsheet (goals excluded)',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFFCBD5E1),
                          ),
                          onTap: () => _showExportOptions(context, financeProvider),
                        ),
                        const Divider(height: 1, indent: 64, endIndent: 20),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.download_for_offline_rounded,
                              color: Colors.teal,
                            ),
                          ),
                          title: const Text(
                            'Import Data',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text(
                            'Restore JSON backup or import CSV spreadsheet',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFFCBD5E1),
                          ),
                          onTap: () => _handleImport(context, financeProvider),
                        ),
                        const Divider(height: 1, indent: 64, endIndent: 20),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.picture_as_pdf_rounded,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                          title: const Text(
                            'Import Bank Statement',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text(
                            'Import PDF statement with smart auto-categorization',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFFCBD5E1),
                          ),
                          onTap: () => _handlePdfStatementImport(context, financeProvider),
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
          color: Color(account.colorHex).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          image: ImageCacheService.fileExists(account.customImagePath)
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
