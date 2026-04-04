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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Insights'),
        backgroundColor: const Color(0xFFF8FAFC),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 20, offset: const Offset(0, 10)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Category Breakdown',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<DateTime>(
                              value: _selectedMonth,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                              onChanged: (DateTime? newValue) {
                                setState(() {
                                  _selectedMonth = newValue;
                                });
                              },
                              items: availableMonths.map<DropdownMenuItem<DateTime>>((DateTime date) {
                                return DropdownMenuItem<DateTime>(
                                  value: date,
                                  child: Text(DateFormat('MMM yyyy').format(date)),
                                );
                              }).toList(),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
