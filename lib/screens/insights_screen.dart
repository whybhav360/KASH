import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../widgets/chart_widget.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  DateTime? _selectedMonth;

  @override
  Widget build(BuildContext context) {
    final financeProvider = Provider.of<FinanceProvider>(context);
    
    final availableMonths = financeProvider.availableMonths;
    
    if (_selectedMonth == null || !availableMonths.contains(_selectedMonth)) {
      _selectedMonth = availableMonths.first;
    }

    final categoryTotals = financeProvider.getCategoryTotalsForMonth(
      _selectedMonth!.month, 
      _selectedMonth!.year
    );
    
    String highestCategory = 'N/A';
    double highestAmount = 0;
    
    categoryTotals.forEach((key, value) {
      if (value > highestAmount) {
        highestAmount = value;
        highestCategory = key;
      }
    });

    final currentMonthExp = financeProvider.currentMonthExpenses;
    final lastMonthExp = financeProvider.lastMonthExpenses;
    
    String trendStatus = 'On Track';
    String trendSubtitle = 'No data from last month';
    Color trendColor = const Color(0xFF10B981);
    IconData trendIcon = Icons.trending_up_rounded;

    if (lastMonthExp > 0) {
      final diff = ((currentMonthExp - lastMonthExp) / lastMonthExp) * 100;
      if (diff > 0) {
        trendStatus = 'Spending Up';
        trendSubtitle = 'You spent ${diff.toStringAsFixed(1)}% more than last month';
        trendColor = const Color(0xFFEF4444);
        trendIcon = Icons.trending_up_rounded;
      } else {
        trendStatus = 'On Track';
        trendSubtitle = 'You spent ${diff.abs().toStringAsFixed(1)}% less than last month';
        trendColor = const Color(0xFF10B981);
        trendIcon = Icons.trending_down_rounded;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: () => financeProvider.refreshData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Category Breakdown',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<DateTime>(
                              menuMaxHeight: 300,
                              value: _selectedMonth,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                              onChanged: (DateTime? newValue) {
                                setState(() {
                                  _selectedMonth = newValue;
                                });
                              },
                              items: (() {
                                final List<DateTime> orderedMonths = List.from(availableMonths);
                                final selectedIndex = orderedMonths.indexOf(_selectedMonth!);
                                if (selectedIndex > 0) {
                                  final selected = orderedMonths.removeAt(selectedIndex);
                                  orderedMonths.insert(0, selected);
                                }
                                return orderedMonths.map<DropdownMenuItem<DateTime>>((DateTime date) {
                                  return DropdownMenuItem<DateTime>(
                                    value: date,
                                    child: Text(DateFormat('MMM yyyy').format(date)),
                                  );
                                }).toList();
                              })(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 200,
                      child: CategoryChart(categoryTotals: categoryTotals),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildInsightCard(
                title: 'Highest Spending',
                value: highestCategory,
                subtitle: '₹${highestAmount.toStringAsFixed(0)}',
                icon: Icons.pie_chart_rounded,
                color: const Color(0xFFF59E0B),
              ),
              const SizedBox(height: 16),
              _buildInsightCard(
                title: 'Monthly Trend',
                value: trendStatus,
                subtitle: trendSubtitle,
                icon: trendIcon,
                color: trendColor,
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsightCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(value, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
