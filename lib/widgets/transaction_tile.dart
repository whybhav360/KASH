import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/account.dart';
import '../services/image_cache_service.dart';
import '../utils/currency_formatter.dart';

class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final Account? account;
  final Account? toAccount;
  final String? contextAccountId;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.account,
    this.toAccount,
    this.contextAccountId,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isExpense = transaction.type == TransactionType.expense;
    final isTransfer = transaction.type == TransactionType.transfer;

    // Category based icon and color palette
    IconData iconData;
    Color iconBgColor;
    Color iconColor;

    if (isTransfer) {
      iconData = Icons.swap_horiz_rounded;
      iconBgColor = theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.12);
      iconColor = theme.colorScheme.primary;
    } else {
      switch (transaction.category.toLowerCase()) {
        case 'adjustment':
          iconData = Icons.tune_rounded;
          iconBgColor = const Color(0xFFEDE7F6);
          iconColor = const Color(0xFF673AB7);
          break;
        case 'paid':
          iconData = Icons.person_rounded;
          iconBgColor = theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.12);
          iconColor = theme.colorScheme.primary;
          break;
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
        case 'entertainment':
          iconData = Icons.movie_rounded;
          iconBgColor = const Color(0xFFFBE9E7);
          iconColor = const Color(0xFFD84315);
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
        case 'bills':
        case 'utilities':
          iconData = Icons.receipt_long_rounded;
          iconBgColor = const Color(0xFFFFF8E1);
          iconColor = const Color(0xFFF57F17);
          break;
        case 'education':
          iconData = Icons.school_rounded;
          iconBgColor = const Color(0xFFEDE7F6);
          iconColor = const Color(0xFF5E35B1);
          break;
        default:
          iconData = Icons.category_rounded;
          iconBgColor = theme.colorScheme.surfaceContainerHighest;
          iconColor = theme.colorScheme.onSurfaceVariant;
      }
    }

    final hasCustomImage = ImageCacheService.fileExists(account?.customImagePath);

    final hasNote = transaction.note.trim().isNotEmpty;

    // Primary title: transaction note if present, else category or 'Transfer'
    final String primaryTitle;
    final String? secondarySubtitle;

    if (isTransfer) {
      primaryTitle = hasNote ? transaction.note.trim() : 'Account Transfer';
      final fromName = account?.name ?? 'Account Removed';
      final toName = toAccount?.name ?? 'Account Removed';
      secondarySubtitle = '$fromName \u2192 $toName';
    } else {
      primaryTitle = hasNote ? transaction.note.trim() : transaction.category;
      secondarySubtitle = null;
    }



    final Color amountColor;
    final String sign;
    if (isTransfer) {
      if (contextAccountId != null && contextAccountId == transaction.accountId) {
        sign = '-';
        amountColor = const Color(0xFFEF4444);
      } else if (contextAccountId != null && contextAccountId == transaction.toAccountId) {
        sign = '+';
        amountColor = const Color(0xFF10B981);
      } else {
        sign = '';
        amountColor = theme.colorScheme.primary;
      }
    } else {
      sign = isExpense ? '-' : '+';
      amountColor = isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    }
    final formattedAmount = '$sign${CurrencyFormatter.format(transaction.amount)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.06),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          onTap: onTap,
          onLongPress: onDelete != null ? () => _showDeleteDialog(context) : null,
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? iconColor.withValues(alpha: 0.15) : iconBgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(iconData, color: iconColor, size: 24),
          ),
          title: Text(
            primaryTitle,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                if (secondarySubtitle != null) ...[
                  Flexible(
                    child: Text(
                      secondarySubtitle,
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Text(' \u2022 ', style: TextStyle(color: Colors.grey, fontSize: 10)),
                ],
                if (!isTransfer && account != null) ...[
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: Color(account!.colorHex).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      image: hasCustomImage
                          ? DecorationImage(
                              image: FileImage(File(account!.customImagePath!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: !hasCustomImage
                        ? Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 7,
                            color: Color(account!.colorHex),
                          )
                        : null,
                  ),
                  Flexible(
                    child: Text(
                      account!.name,
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Text(' \u2022 ', style: TextStyle(color: Colors.grey, fontSize: 10)),
                ],
                Text(
                  DateFormat('MMM dd, yyyy \u2022 h:mm a').format(transaction.date),
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          trailing: Text(
            formattedAmount,
            style: TextStyle(
              color: amountColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Transaction?'),
        content: const Text('This transaction will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () {
              onDelete?.call();
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
