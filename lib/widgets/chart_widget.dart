import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class CategoryChart extends StatelessWidget {
  final Map<String, double> categoryTotals;

  const CategoryChart({super.key, required this.categoryTotals});

  @override
  Widget build(BuildContext context) {
    if (categoryTotals.isEmpty) {
      return const Center(child: Text('No expense data to show chart'));
    }

    final List<Color> colors = [
      const Color(0xFF6366F1),
      const Color(0xFFEF4444),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF06B6D4),
      const Color(0xFFF97316),
    ];

    int colorIndex = 0;
    final total = categoryTotals.values.fold(0.0, (sum, value) => sum + value);

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 35,
        sections: categoryTotals.entries.map((entry) {
          final color = colors[colorIndex % colors.length];
          colorIndex++;
          final percentage = (entry.value / total) * 100;
          
          return PieChartSectionData(
            color: color,
            value: entry.value,
            title: '${percentage.toStringAsFixed(0)}%',
            radius: 55,
            titleStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            badgeWidget: _Badge(
              _getCategoryIcon(entry.key),
              size: 28,
              color: color,
            ),
            badgePositionPercentageOffset: 0.98,
          );
        }).toList(),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
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
      default:
        return Icons.category_rounded;
    }
  }
}

class _Badge extends StatelessWidget {
  final IconData iconData;
  final double size;
  final Color color;

  const _Badge(
    this.iconData, {
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: color,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.1),
            offset: const Offset(1, 1),
            blurRadius: 3,
          ),
        ],
      ),
      padding: EdgeInsets.all(size * .15),
      child: Center(
        child: Icon(
          iconData,
          color: color,
          size: size * .6,
        ),
      ),
    );
  }
}
