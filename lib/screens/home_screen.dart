import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transaction_template.dart';
import '../providers/finance_provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/transaction_tile.dart';
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 0,
        titleSpacing: 20,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('KASH', style: Theme.of(context).textTheme.bodySmall?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.bold)),
            Text(_getGreeting(financeProvider.userName), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0, left: 8.0),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                backgroundImage: financeProvider.userProfilePicture != null 
                    ? FileImage(File(financeProvider.userProfilePicture!)) 
                    : null,
                child: financeProvider.userProfilePicture == null 
                    ? const Icon(Icons.person_rounded, size: 20) 
                    : null,
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  'Your Accounts',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              
              const SizedBox(height: 12),

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
              ] else 
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddAccountScreen()),
                    ),
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1), style: BorderStyle.solid),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_card_rounded, size: 48, color: Theme.of(context).dividerColor.withOpacity(0.2)),
                          const SizedBox(height: 12),
                          Text('No accounts added', style: TextStyle(color: Theme.of(context).dividerColor.withOpacity(0.5))),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 32),
              
              // Repetitive Expenses (Templates) Section
              if (financeProvider.templates.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    'Repetitive Expenses',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: financeProvider.templates.length,
                    itemBuilder: (context, index) {
                      final template = financeProvider.templates[index];
                      return _TemplateQuickAction(
                        template: template,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddTransactionScreen(template: template),
                          ),
                        ),
                        onDelete: () => financeProvider.deleteTemplate(template),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),
              ],

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Transactions',
                      style: Theme.of(context).textTheme.titleLarge,
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
          Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const AddTransactionScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = Offset(0.0, 1.0);
                const end = Offset.zero;
                const curve = Curves.easeInOutQuart;
                var slideTween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                var scaleTween = Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));
                
                return SlideTransition(
                  position: animation.drive(slideTween),
                  child: ScaleTransition(
                    scale: animation.drive(scaleTween),
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  ),
                );
              },
              transitionDuration: const Duration(milliseconds: 500),
            ),
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
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
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white),
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
      child: Column(
        children: [
          Icon(Icons.history_rounded, size: 48, color: Theme.of(context).dividerColor.withOpacity(0.1)),
          const SizedBox(height: 12),
          const Text('No transactions yet', style: TextStyle(color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }
}

class _TemplateQuickAction extends StatelessWidget {
  final TransactionTemplate template;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TemplateQuickAction({
    required this.template,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete ?'),
            content: Text('Remove "${template.name}" from repetitive expenses?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  onDelete();
                  Navigator.pop(ctx);
                }, 
                child: const Text('Delete', style: TextStyle(color: Colors.red))
              ),
            ],
          ),
        );
      },
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getCategoryIcon(template.category),
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              template.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Text(
              '₹${template.amount.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'salary': return Icons.account_balance_wallet_rounded;
      case 'food': return Icons.restaurant_rounded;
      case 'groceries': return Icons.shopping_cart_rounded;
      case 'transport': return Icons.directions_bus_rounded;
      case 'rent': return Icons.home_rounded;
      case 'health': return Icons.medical_services_rounded;
      case 'shopping': return Icons.shopping_bag_rounded;
      case 'gift': return Icons.card_giftcard_rounded;
      case 'investment': return Icons.trending_up_rounded;
      case 'business': return Icons.business_center_rounded;
      default: return Icons.category_rounded;
    }
  }
}
