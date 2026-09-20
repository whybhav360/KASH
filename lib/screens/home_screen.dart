import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import '../models/transaction_template.dart';
import '../providers/finance_provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/transaction_tile.dart';
import '../models/transaction.dart';
import '../models/account.dart';
import 'add_account_screen.dart';
import 'transfer_screen.dart';
import 'profile_screen.dart';
import '../widgets/add_transaction_fab.dart';
import '../utils/currency_formatter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ScrollController _accountScrollController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _accountScrollController = ScrollController();
    _accountScrollController.addListener(_onAccountScroll);
  }

  @override
  void dispose() {
    _accountScrollController.removeListener(_onAccountScroll);
    _accountScrollController.dispose();
    super.dispose();
  }

  void _onAccountScroll() {
    if (!_accountScrollController.hasClients) return;
    final itemWidth = MediaQuery.of(context).size.width - 40;
    if (itemWidth <= 0) return;
    final page = (_accountScrollController.offset / itemWidth).round();
    if (page != _currentPage && page >= 0) {
      setState(() => _currentPage = page);
    }
  }

  String _getGreetingPrefix() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  void _openProfile(BuildContext context, {bool autoEditName = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          autoEditName: autoEditName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final financeProvider = Provider.of<FinanceProvider>(context);
    final navProvider = Provider.of<NavigationProvider>(context, listen: false);
    final accounts = financeProvider.accounts;
    final recentTransactions = financeProvider.transactions.take(5).toList();
    final headlineStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold);
    final textColor = headlineStyle?.color ?? Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 0,
        titleSpacing: 20,
        centerTitle: false,
        title: GestureDetector(
          onTap: !financeProvider.hasChangedName
              ? () => _openProfile(context, autoEditName: true)
              : null,
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('KASH', style: Theme.of(context).textTheme.bodySmall?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.bold)),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${_getGreetingPrefix()}, '),
                    if (!financeProvider.hasChangedName)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: CustomPaint(
                          painter: _DashedUnderlinePainter(
                            color: textColor,
                            style: headlineStyle!,
                            text: financeProvider.userName,
                            strokeWidth: 2.4,
                            dashLength: 4.5,
                            dashGap: 6.0,
                            spacing: 5.0,
                          ),
                          child: Text(
                            financeProvider.userName,
                            style: headlineStyle,
                          ),
                        ),
                      )
                    else
                      TextSpan(text: financeProvider.userName),
                  ],
                ),
                style: headlineStyle,
              ),
            ],
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () => _openProfile(context, autoEditName: false),
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0, left: 8.0),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                backgroundImage: financeProvider.userProfilePicture != null 
                    ? FileImage(File(financeProvider.userProfilePicture!)) 
                    : const AssetImage('assets/images/d_prof.jpg') as ImageProvider,
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
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your Accounts',
                        style: Theme.of(context).textTheme.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (accounts.length >= 2) ...[
                      TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TransferScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                        label: const Text('Transfer'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddAccountScreen()),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add account'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),

              // Accounts Carousel (Hold and drag to reorder)
              if (accounts.isNotEmpty) ...[
                SizedBox(
                  height: 205,
                  child: ReorderableListView.builder(
                    scrollController: _accountScrollController,
                    scrollDirection: Axis.horizontal,
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: accounts.length,
                    onReorder: (oldIndex, newIndex) {
                      financeProvider.reorderAccounts(oldIndex, newIndex);
                    },
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, animChild) {
                          final animVal = Curves.easeInOut.transform(animation.value);
                          final scale = 1.0 + (0.04 * animVal);
                          return Transform.scale(
                            scale: scale,
                            child: Material(
                              color: Colors.transparent,
                              elevation: 12,
                              shadowColor: Colors.black54,
                              borderRadius: BorderRadius.circular(24),
                              child: animChild,
                            ),
                          );
                        },
                        child: child,
                      );
                    },
                    itemBuilder: (context, index) {
                      if (index < 0 || index >= accounts.length) return const SizedBox();
                      final account = accounts[index];
                      return Container(
                        key: ValueKey(account.id),
                        width: MediaQuery.of(context).size.width - 40,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: ReorderableDelayedDragStartListener(
                          index: index,
                          child: GestureDetector(
                            onTap: () => Navigator.push(
                              context, 
                              MaterialPageRoute(builder: (_) => AddAccountScreen(account: account)),
                            ),
                            child: AccountCard(
                              account: account,
                              balance: financeProvider.getAccountBalance(account.id),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                // Page Indicators for accounts
                if (accounts.length > 1) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < accounts.length; i++)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: (_currentPage < accounts.length && _currentPage == i) ? 20 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: (_currentPage < accounts.length && _currentPage == i) ? const Color(0xFF6366F1) : const Color(0xFFCBD5E1),
                          ),
                        ),
                    ],
                  ),
                ],
              ] else 
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddAccountScreen()),
                    ),
                    child: Container(
                      height: 230,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1), style: BorderStyle.solid),
                      ),
                      child: Center(
                        child: Theme.of(context).brightness == Brightness.dark
                            ? ColorFiltered(
                                colorFilter: ColorFilter.mode(
                                  Theme.of(context).colorScheme.primary,
                                  BlendMode.srcIn,
                                ),
                                child: Lottie.asset(
                                  'assets/animations/not_found.json',
                                  width: 220,
                                  height: 220,
                                  fit: BoxFit.contain,
                                  repeat: true,
                                  animate: true,
                                ),
                              )
                            : Lottie.asset(
                                'assets/animations/not_found.json',
                                width: 220,
                                height: 220,
                                fit: BoxFit.contain,
                                repeat: true,
                                animate: true,
                              ),
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
                  height: 44,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: financeProvider.templates.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final template = financeProvider.templates[index];
                      return _TemplateQuickAction(
                        template: template,
                        onTap: () => Navigator.push(
                          context,
                          AddTransactionFab.route(template: template),
                        ),
                        onDelete: () => financeProvider.deleteTemplate(template),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
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
                          account: accounts.where((a) => a.id == tx.accountId).firstOrNull,
                          toAccount: tx.toAccountId != null
                              ? accounts.where((a) => a.id == tx.toAccountId).firstOrNull
                              : null,
                          onTap: () => Navigator.push(
                            context,
                            tx.type == TransactionType.transfer
                                ? MaterialPageRoute(
                                    builder: (_) => TransferScreen(transaction: tx),
                                  )
                                : AddTransactionFab.route(transaction: tx),
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
      floatingActionButton: AddTransactionFab(
        heroTag: 'home_add_fab',
        onPressed: () {
          final currentAccId = (accounts.isNotEmpty && _currentPage >= 0 && _currentPage < accounts.length)
              ? accounts[_currentPage].id
              : null;
          Navigator.of(context).push(
            AddTransactionFab.route(initialAccountId: currentAccId),
          );
        },
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
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        account.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (account.isPrimary) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                        ),
                        child: const Icon(Icons.star_rounded, color: Colors.amberAccent, size: 14),
                      ),
                    ],
                  ],
                ),
              ),
              if (account.customImagePath == null) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white70,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(balance),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          if (account.bankProvider != null && account.bankProvider!.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.account_balance_rounded, color: Colors.white70, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    account.bankProvider!,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
          Lottie.asset(
            'assets/animations/no_results.json',
            width: 140,
            height: 140,
            fit: BoxFit.contain,
            repeat: true,
            animate: true,
          ),
          const SizedBox(height: 16),
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
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete Template?'),
              content: Text('Remove "${template.name}" from repetitive expenses?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                TextButton(
                  onPressed: () {
                    onDelete();
                    Navigator.pop(ctx);
                  }, 
                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getCategoryIcon(template.category),
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                template.name,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'adjustment': return Icons.tune_rounded;
      case 'paid': return Icons.person_rounded;
      case 'salary': return Icons.account_balance_wallet_rounded;
      case 'food': return Icons.restaurant_rounded;
      case 'groceries': return Icons.shopping_cart_rounded;
      case 'transport': return Icons.directions_bus_rounded;
      case 'rent': return Icons.home_rounded;
      case 'health': return Icons.medical_services_rounded;
      case 'shopping': return Icons.shopping_bag_rounded;
      case 'entertainment': return Icons.play_circle_fill_rounded;
      case 'gift': return Icons.card_giftcard_rounded;
      case 'investment': return Icons.trending_up_rounded;
      case 'business': return Icons.business_center_rounded;
      case 'bills':
      case 'utilities': return Icons.receipt_long_rounded;
      case 'education': return Icons.school_rounded;
      default: return Icons.category_rounded;
    }
  }
}

class _DashedUnderlinePainter extends CustomPainter {
  final Color color;
  final TextStyle style;
  final String text;
  final double strokeWidth;
  final double dashLength;
  final double dashGap;
  final double spacing;

  _DashedUnderlinePainter({
    required this.color,
    required this.style,
    required this.text,
    this.strokeWidth = 2.4,
    this.dashLength = 4.5,
    this.dashGap = 6.0,
    this.spacing = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    final baseline = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final y = baseline + spacing;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    double startX = 0;
    while (startX < size.width) {
      final endX = (startX + dashLength).clamp(0.0, size.width);
      canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
      startX += dashLength + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedUnderlinePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.style != style ||
        oldDelegate.text != text ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.dashGap != dashGap ||
        oldDelegate.spacing != spacing;
  }
}
