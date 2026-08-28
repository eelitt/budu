import 'package:budu/core/utils.dart';
import 'package:budu/features/budget/domain/period_summary.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:budu/features/budget/screens/summary/summary_section_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Top-of-Summary plan vs actual overview for the selected period.
class BudgetOverviewSection extends StatelessWidget {
  final BudgetModel budget;
  final ValueChanged<String>? onOverspentCategoryTap;

  const BudgetOverviewSection({
    super.key,
    required this.budget,
    this.onOverspentCategoryTap,
  });

  String _formatPeriod(BudgetModel budget) {
    final dateFormat = DateFormat('d.M.yyyy');
    return '${dateFormat.format(budget.startDate)} - ${dateFormat.format(budget.endDate)}';
  }

  @override
  Widget build(BuildContext context) {
    final events = Provider.of<ExpenseProvider>(context).expenses;
    final summary = buildBudgetPeriodSummary(budget, events);
    final showWarning = summary.planDeficit ||
        summary.expensesOverPlan ||
        summary.overspentCategoryCount > 0;
    final topOverspent = summary.topOverspent(limit: 3);
    final planUsed = summary.planUsedProgress;
    final planUsedValue = planUsed > 1 ? 1.0 : planUsed;

    return SummarySectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet, color: Colors.blueGrey),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Yhteenveto',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (showWarning) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.warning, color: Colors.red, size: 20),
                        ],
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${_formatPeriod(budget)} budjetti',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _amountRow(
            context,
            icon: Icons.arrow_upward,
            iconColor: Colors.green,
            label: 'Suunnitellut tulot',
            amount: summary.plannedIncome,
          ),
          const SizedBox(height: 8),
          _amountRow(
            context,
            icon: Icons.arrow_upward,
            iconColor: Colors.green,
            label: 'Toteutuneet tulot',
            amount: summary.actualIncome,
          ),
          const SizedBox(height: 8),
          _amountRow(
            context,
            icon: Icons.arrow_downward,
            iconColor: Colors.red,
            label: 'Budjetoidut menot',
            amount: summary.plannedExpenses,
            amountColor: summary.planDeficit ? Colors.red : null,
          ),
          if (summary.planDeficit) ...[
            const SizedBox(height: 4),
            Text(
              'Menot ylittävät tulot!',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                  ),
            ),
          ],
          const SizedBox(height: 8),
          _amountRow(
            context,
            icon: Icons.arrow_downward,
            iconColor: Colors.red,
            label: 'Toteutuneet menot',
            amount: summary.actualExpenses,
            amountColor: summary.expensesOverPlan ? Colors.red : null,
          ),
          if (summary.expensesOverPlan) ...[
            const SizedBox(height: 4),
            Text(
              'Budjetti ylittynyt!',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                  ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            summary.plannedExpenses > 0
                ? 'Budjetista käytetty: ${(planUsed * 100).clamp(0, 999).toStringAsFixed(0)}%'
                : summary.actualExpenses > 0
                    ? 'Budjetista käytetty: yli suunnitelman'
                    : 'Budjetista käytetty: 0%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                ),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: summary.plannedExpenses <= 0 && summary.actualExpenses <= 0
                ? 0
                : planUsedValue,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              summary.planUsedOver ? Colors.red : Colors.green,
            ),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          if (summary.overspentCategoryCount > 0) ...[
            const SizedBox(height: 12),
            Text(
              'Ylittyneitä kategorioita: ${summary.overspentCategoryCount} (yhteensä ${formatCurrency(summary.overspentAmountTotal)})',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                  ),
            ),
            if (topOverspent.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: topOverspent.map((category) {
                  return ActionChip(
                    avatar: const Icon(Icons.warning, size: 16, color: Colors.red),
                    backgroundColor: Colors.white,
                    label: Text(
                      '${category.name} +${formatCurrency(category.overAmount)}',
                      style: Theme.of(context).textTheme.bodySmall
                    ),
                    onPressed: onOverspentCategoryTap == null
                        ? null
                        : () => onOverspentCategoryTap!(category.name),
                  );
                }).toList(),
              ),
            ],
          ],
          if (summary.unplannedExpenseTotal > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Suunnittelemattomat: ${formatCurrency(summary.unplannedExpenseTotal)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
            ),
          ],
          const Divider(height: 24),
          _leftoverRow(
            context,
            label: 'Saldo (suunnitelma)',
            amount: summary.plannedLeftover,
          ),
          const SizedBox(height: 8),
          _leftoverRow(
            context,
            label: 'Saldo (toteutunut)',
            amount: summary.actualLeftover,
          ),
        ],
      ),
    );
  }

  Widget _amountRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required double amount,
    Color? amountColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
        Flexible(
          child: Text(
            formatCurrency(amount),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: amountColor ?? Colors.black87,
                ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _leftoverRow(
    BuildContext context, {
    required String label,
    required double amount,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          formatCurrency(amount),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: amount >= 0 ? Colors.green : Colors.red,
              ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
