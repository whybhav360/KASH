import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/account.dart';

class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final Account? account;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.account,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == TransactionType.expense;
    
    // Category based icon
    IconData iconData;
    Color iconBgColor;
    Color iconColor;

    switch (transaction.category.toLowerCase()) {
      case 'salary':
        iconData = Icons.account_balance_wallet_rounded;
        iconBgColor = const Color(0xFFE8F5E9);
        iconColor = const Color(0xFF2E7D32);
        break;
      case 'food':
        iconData = Icons.restaurant_rounded;
        iconBgColor = const Color(0xFFFFF3E0);
        iconColor = const Color(0xFFEF6C00);
        break;
      case 'groceries':
        iconData = Icons.shopping_cart_rounded;
        iconBgColor = const Color(0xFFE1F5FE);
        iconColor = const Color(0xFF0288D1);
        break;
      case 'transport':
        iconData = Icons.directions_bus_rounded;
        iconBgColor = const Color(0xFFF1F8E9);
        iconColor = const Color(0xFF558B2F);
        break;
      case 'rent':
        iconData = Icons.home_rounded;
        iconBgColor = const Color(0xFFE8EAF6);
        iconColor = const Color(0xFF3F51B5);
        break;
      case 'health':
        iconData = Icons.medical_services_rounded;
        iconBgColor = const Color(0xFFFCE4EC);
        iconColor = const Color(0xFFD81B60);
        break;
      case 'shopping':
        iconData = Icons.shopping_bag_rounded;
        iconBgColor = const Color(0xFFF3E5F5);
        iconColor = const Color(0xFF8E24AA);
        break;
      case 'gift':
        iconData = Icons.card_giftcard_rounded;
        iconBgColor = const Color(0xFFE0F2F1);
        iconColor = const Color(0xFF00897B);
        break;
      case 'investment':
        iconData = Icons.trending_up_rounded;
        iconBgColor = const Color(0xFFE8F5E9);
        iconColor = const Color(0xFF43A047);
        break;
      case 'business':
        iconData = Icons.business_center_rounded;
        iconBgColor = const Color(0xFFEFEBE9);
        iconColor = const Color(0xFF6D4C41);
        break;
      default:
        iconData = Icons.category_rounded;
        iconBgColor = Theme.of(context).colorScheme.surfaceVariant;
        iconColor = Theme.of(context).colorScheme.onSurfaceVariant;
    }

    Widget leadingWidget = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark 
            ? iconColor.withOpacity(0.1) 
            : iconBgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(iconData, color: iconColor, size: 24),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: onTap,
        onLongPress: onDelete != null ? () => _showDeleteDialog(context) : null,
        leading: leadingWidget,
        title: Text(
          transaction.category,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (transaction.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  transaction.note,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ),
            Row(
              children: [
                if (account != null) ...[
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Color(account!.colorHex).withOpacity(0.1),
                      shape: BoxShape.circle,
                      image: account!.customImagePath != null 
                          ? DecorationImage(image: FileImage(File(account!.customImagePath!)), fit: BoxFit.cover) 
                          : null,
                    ),
                    child: account!.customImagePath == null 
                        ? Icon(Icons.account_balance_wallet_rounded, size: 8, color: Color(account!.colorHex))
                        : null,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  DateFormat('MMM dd, yyyy').format(transaction.date),
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        trailing: Text(
          '${isExpense ? "-" : "+"}\u20B9${transaction.amount.toStringAsFixed(0)}',
          style: TextStyle(
            color: isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              onDelete!();
              Navigator.pop(ctx);
            }, 
            child: const Text('Delete', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }
}
