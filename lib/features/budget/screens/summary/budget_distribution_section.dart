import 'package:budu/core/utils.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'summary_utils.dart';

class BudgetDistributionSection extends StatefulWidget {
  const BudgetDistributionSection({super.key});

  @override
  State<BudgetDistributionSection> createState() => _BudgetDistributionSectionState();
}

class _BudgetDistributionSectionState extends State<BudgetDistributionSection> {
  int? touchedIndex;
  bool _isDialogOpen = false;
  bool _isExpanded = true;

  void _showCategoryDetails(
    BuildContext context,
    String category,
    double amount,
    double totalBudget,
    Map<String, Map<String, double>> originalExpenses,
  ) {
    if (_isDialogOpen) return;
    _isDialogOpen = true;

    final percentage = (amount / totalBudget) * 100;
    if (category == 'Muut') {
      final otherCategories = getOtherCategoryDetails(originalExpenses, totalBudget);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Muut-kategorian tiedot'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Yhteensä: ${formatCurrency(amount)} (${percentage.toStringAsFixed(1)}%)'),
                const SizedBox(height: 8),
                const Text('Sisältää:'),
                ...otherCategories.entries.map((entry) {
                  final subPercentage = (entry.value / totalBudget) * 100;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            entry.key,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            '${formatCurrency(entry.value)} (${subPercentage.toStringAsFixed(1)}%)',
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _isDialogOpen = false;
              },
              child: const Text('Sulje'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(category),
          content: Text('Summa: ${formatCurrency(amount)}\nOsuus: ${percentage.toStringAsFixed(1)}%'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _isDialogOpen = false;
              },
              child: const Text('Sulje'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final budget = budgetProvider.budget!;
    final totalBudget = budget.totalExpenses;
    final combinedExpenses = combineSmallCategories(budget.expenses, totalBudget);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _isExpanded,
          onExpansionChanged: (bool expanded) {
            setState(() {
              _isExpanded = expanded;
            });
          },
          tilePadding: EdgeInsets.zero,
          leading: const Padding(
            padding: EdgeInsets.only(left: 2),
            child: Icon(Icons.pie_chart_sharp, color: Colors.blueGrey),
          ),
          title: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              'Budjetin jakautuminen',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
            ),
          ),
          trailing: const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.expand_more),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  totalBudget > 0
                      ? Column(
                          children: [
                            SizedBox(
                              height: 220,
                              child: PieChart(
                                PieChartData(
                                  sections: combinedExpenses.entries.toList().asMap().entries.map((mapEntry) {
                                    final index = mapEntry.key;
                                    final entry = mapEntry.value;
                                    final percentage = (entry.value / totalBudget) * 100;
                                    return PieChartSectionData(
                                      color: getColorForCategory(entry.key, combinedExpenses.keys.toList()),
                                      value: entry.value,
                                      title: '${percentage.toStringAsFixed(1)}%',
                                      radius: 80,
                                      titleStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black26,
                                            blurRadius: 2,
                                            offset: Offset(1, 1),
                                          ),
                                        ],
                                      ),
                                      showTitle: percentage > 5,
                                      badgeWidget: touchedIndex == index
                                          ? Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.black54,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                entry.key,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            )
                                          : null,
                                      badgePositionPercentageOffset: 1.2,
                                    );
                                  }).toList(),
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 40,
                                  borderData: FlBorderData(show: false),
                                  startDegreeOffset: 90,
                                  pieTouchData: PieTouchData(
                                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                      if (event is! FlTapUpEvent) return;
                                      setState(() {
                                        if (pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                                          touchedIndex = -1;
                                          return;
                                        }
                                        touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                        if (touchedIndex != -1) {
                                          final touchedCategory = combinedExpenses.keys.elementAt(touchedIndex!);
                                          final touchedAmount = combinedExpenses[touchedCategory]!;
                                          _showCategoryDetails(
                                            context,
                                            touchedCategory,
                                            touchedAmount,
                                            totalBudget,
                                            budget.expenses,
                                          );
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              children: combinedExpenses.keys.map((category) {
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: getColorForCategory(category, combinedExpenses.keys.toList()),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      category,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Colors.black87,
                                          ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ],
                        )
                      : const Center(child: Text('Ei budjettitietoja näytettäväksi')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}