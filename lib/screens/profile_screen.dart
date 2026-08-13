import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<FinanceProvider>(context, listen: false);
      _nameController.text = provider.userName;
    });
  }

  void _showEditNameDialog(FinanceProvider provider) {
    _nameController.text = provider.userName;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            hintText: 'Enter your name',
          ),
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

  @override
  Widget build(BuildContext context) {
    final financeProvider = Provider.of<FinanceProvider>(context);
    final accounts = financeProvider.accounts;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Profile & Settings'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            const CircleAvatar(
              radius: 50,
              backgroundColor: Color(0xFFF1F5F9),
              child: Icon(Icons.person_rounded, size: 50, color: Color(0xFF6366F1)),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  financeProvider.userName,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                IconButton(
                  onPressed: () => _showEditNameDialog(financeProvider),
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF6366F1)),
                ),
              ],
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
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 1.2),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddAccountScreen()),
                        ),
                        child: const Text('Add New'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < accounts.length; i++) ...[
                          _AccountListTile(
                            account: accounts[i],
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => AddAccountScreen(account: accounts[i])),
                            ),
                          ),
                          if (i < accounts.length - 1)
                            const Divider(height: 1, indent: 70, endIndent: 20),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
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
              ? DecorationImage(image: FileImage(File(account.customImagePath!)), fit: BoxFit.cover) 
              : null,
        ),
        child: account.customImagePath == null 
            ? Icon(Icons.account_balance_rounded, color: Color(account.colorHex))
            : null,
      ),
      title: Text(
        account.name,
        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
      ),
      subtitle: Text(
        '${account.bankProvider ?? "Bank"} •••• ${account.id.length > 4 ? account.id.substring(account.id.length - 4) : "0000"}',
        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
    );
  }
}
