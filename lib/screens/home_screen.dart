import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/net_worth_card.dart';
import '../models/account.dart';
import 'add_transaction_screen.dart';
import 'add_account_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  String _getGreeting(String name) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }
    return '$greeting, $name';
  }

  @override
  Widget build(BuildContext context) {
    final financeProvider = Provider.of<FinanceProvider>(context);
    final navProvider = Provider.of<NavigationProvider>(context, listen: false);
    final accounts = financeProvider.accounts;
    final recentTransactions = financeProvider.transactions.take(5).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFF8FAFC),
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('KASH', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), letterSpacing: 1.2)),
            Text(_getGreeting(financeProvider.userName), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Color(0xFF1E293B))),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            child: const Padding(
              padding: EdgeInsets.only(right: 16.0, left: 8.0),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFF1F5F9),
                child: Icon(Icons.person_rounded, color: Color(0xFF6366F1), size: 20),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => financeProvider.refreshData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              
              // Your Accounts Section
              if (accounts.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    'Your Accounts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ),
              
              if (accounts.isNotEmpty) const SizedBox(height: 12),

              // Accounts Carousel (Only bank accounts)
              if (accounts.isNotEmpty) ...[
                SizedBox(
                  height: 200,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) => setState(() => _currentPage = index),
                    itemCount: accounts.length,
                    itemBuilder: (context, index) {
                      final account = accounts[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (_) => AddAccountScreen(account: account))
                          ),
                          child: AccountCard(
                            account: account,
                            balance: financeProvider.getAccountBalance(account.id),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                // Page Indicators for accounts
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    accounts.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: _currentPage == index ? const Color(0xFF6366F1) : const Color(0xFFCBD5E1),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Transactions',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    TextButton(
                      onPressed: () => navProvider.setIndex(1),
                      child: const Text('See all', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    if (recentTransactions.isEmpty)
                      const EmptyTransactionsState()
                    else
                      for (final tx in recentTransactions)
                        TransactionTile(
                          transaction: tx,
                          account: accounts.firstWhere(
                            (a) => a.id == tx.accountId, 
                            orElse: () => Account(id: '', name: 'Loading...', openingBalance: 0, colorHex: 0xFF94A3B8)
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddTransactionScreen(transaction: tx),
                            ),
                          ),
                          onDelete: () => financeProvider.deleteTransaction(tx),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'home_fab',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddTransactionScreen()),
          );
        },
        backgroundColor: const Color(0xFF4F46E5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }
}

class AccountCard extends StatelessWidget {
  final Account account;
  final double balance;

  const AccountCard({
    super.key,
    required this.account,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Color(account.colorHex),
        borderRadius: BorderRadius.circular(24),
        image: account.customImagePath != null 
            ? DecorationImage(
                image: FileImage(File(account.customImagePath!)), 
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
              ) 
            : null,
        boxShadow: [
          BoxShadow(
            color: Color(account.colorHex).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                account.name,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              if (account.customImagePath == null)
                const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white70,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹${balance.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const Spacer(),
          if (account.bankProvider != null && account.bankProvider!.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.account_balance_rounded, color: Colors.white70, size: 14),
                const SizedBox(width: 8),
                Text(
                  account.bankProvider!,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class EmptyTransactionsState extends StatelessWidget {
  const EmptyTransactionsState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: const Column(
        children: [
          Icon(Icons.history_rounded, size: 48, color: Color(0xFFF1F5F9)),
          SizedBox(height: 12),
          Text('No transactions yet', style: TextStyle(color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }
}
