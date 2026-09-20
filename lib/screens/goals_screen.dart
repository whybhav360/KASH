import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:lottie/lottie.dart';
import '../providers/finance_provider.dart';
import '../widgets/goal_card.dart';
import '../models/goal.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final financeProvider = Provider.of<FinanceProvider>(context);
    final goals = financeProvider.goals;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Goals'),
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: () => financeProvider.refreshData(),
        child: goals.isEmpty
            ? _buildEmptyState(context)
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: goals.length,
                itemBuilder: (context, index) {
                  final goal = goals[index];
                  return GoalCard(
                    goal: goal,
                    currentSavings: financeProvider.totalBalance,
                    onTap: () => _showGoalDialog(context, financeProvider, goal: goal),
                    onDelete: () => financeProvider.deleteGoal(goal),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Open with a subtle scale/fade animation
          showGeneralDialog(
            context: context,
            barrierDismissible: true,
            barrierLabel: 'Goal Dialog',
            transitionDuration: const Duration(milliseconds: 200),
            pageBuilder: (context, animation, secondaryAnimation) => const SizedBox.shrink(),
            transitionBuilder: (context, animation, secondaryAnimation, child) {
              final curvedAnim = CurvedAnimation(parent: animation, curve: Curves.easeOutQuad);
              return ScaleTransition(
                scale: Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnim),
                child: FadeTransition(
                  opacity: curvedAnim,
                  child: _GoalDialog(provider: financeProvider),
                ),
              );
            },
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Goal'),
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            children: [
              Lottie.asset(
                'assets/animations/laughing_cat.json',
                width: 150,
                height: 150,
                fit: BoxFit.contain,
                repeat: true,
                animate: true,
              ),
              const SizedBox(height: 24),
              Text(
                'No goals set yet',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Refactored Dialog to a separate Widget for easier animation
  void _showGoalDialog(BuildContext context, FinanceProvider provider, {Goal? goal}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Goal Dialog',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnim = CurvedAnimation(parent: animation, curve: Curves.easeOutQuad);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnim),
          child: FadeTransition(
            opacity: curvedAnim,
            child: _GoalDialog(provider: provider, goal: goal),
          ),
        );
      },
    );
  }
}

class _GoalDialog extends StatefulWidget {
  final FinanceProvider provider;
  final Goal? goal;

  const _GoalDialog({required this.provider, this.goal});

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  late TextEditingController titleController;
  late TextEditingController amountController;
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.goal?.title);
    amountController = TextEditingController(
      text: widget.goal == null ? '' : widget.goal!.targetAmount.toString(),
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.translucent,
      child: AlertDialog(
        title: Text(widget.goal == null ? 'Add New Goal' : 'Edit Goal'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Goal Title',
                  hintText: 'e.g., New Laptop',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'Enter title' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountController,
                decoration: InputDecoration(
                  labelText: 'Target Amount',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter amount';
                  final amount = double.tryParse(value);
                  if (amount == null) return 'Enter valid number';
                  if (amount <= 0) return 'Amount must be positive';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          Padding(
            padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
            child: ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final amount = double.parse(amountController.text);
                  if (widget.goal == null) {
                    widget.provider.addGoal(Goal(
                      id: const Uuid().v4(),
                      title: titleController.text,
                      targetAmount: amount,
                    ));
                  } else {
                    widget.goal!.title = titleController.text;
                    widget.goal!.targetAmount = amount;
                    widget.goal!.save();
                    widget.provider.refreshData();
                  }
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(widget.goal == null ? 'Add Goal' : 'Update Goal'),
            ),
          ),
        ],
      ),
    );
  }
}
