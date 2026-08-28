import 'package:budu/core/utils.dart';
import 'package:budu/features/budget/domain/tracking.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:budu/features/budget/screens/summary/summary_section_card.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Color _colorForCategory(String category, List<String> categories) {
  const colors = <Color>[
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.amber,
    Colors.cyan,
    Colors.indigo,
  ];
  final index = categories.indexOf(category);
  return colors[index % colors.length];
}

/// Pie chart of actual expense amounts by category (income excluded).
class BudgetDistributionSection extends StatefulWidget {
  const BudgetDistributionSection({super.key});

  @override
  State<BudgetDistributionSection> createState() =>
      _BudgetDistributionSectionState();
}

class _BudgetDistributionSectionState extends State<BudgetDistributionSection> {
  int? touchedIndex;
  bool _isDialogOpen = false;
  bool _isExpanded = true;

  Future<void> _showCategoryDetails(
    BuildContext context,
    String category,
    double amount,
    double totalSpent,
    Map<String, Map<String, double>> spentExpenses,
  ) async {
    if (_isDialogOpen) return;
    _isDialogOpen = true;

    final percentage = totalSpent > 0 ? (amount / totalSpent) * 100 : 0.0;

    try {
      if (category == 'Muut') {
        final otherCategories =
            getOtherCategoryDetails(spentExpenses, totalSpent);
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Muut-kategorian tiedot'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yhteensä: ${formatCurrency(amount)} (${percentage.toStringAsFixed(1)}%)',
                  ),
                  const SizedBox(height: 8),
                  const Text('Sisältää:'),
                  ...otherCategories.entries.map((entry) {
                    final subPercentage =
                        totalSpent > 0 ? (entry.value / totalSpent) * 100 : 0.0;
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
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Sulje'),
              ),
            ],
          ),
        );
      } else {
        final subExpenses = spentExpenses[category] ?? {};
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(category),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yhteensä: ${formatCurrency(amount)} (${percentage.toStringAsFixed(1)}%)',
                  ),
                  if (subExpenses.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Alakategoriat:'),
                    ...subExpenses.entries.map((sub) {
                      final subPercentage =
                          totalSpent > 0 ? (sub.value / totalSpent) * 100 : 0.0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(child: Text(sub.key)),
                            Text(
                              '${formatCurrency(sub.value)} (${subPercentage.toStringAsFixed(1)}%)',
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Sulje'),
              ),
            ],
          ),
        );
      }
    } finally {
      _isDialogOpen = false;
    }
  }

  Widget _expansionShell({required List<Widget> children}) {
    return SummarySectionCard(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _isExpanded,
          onExpansionChanged: (expanded) =>
              setState(() => _isExpanded = expanded),
          tilePadding: EdgeInsets.zero,
          leading: const Padding(
            padding: EdgeInsets.only(left: 2),
            child: Icon(Icons.pie_chart_sharp, color: Colors.blueGrey),
          ),
          title: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              'Menojen jakautuminen',
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
          children: children,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final grouped = groupExpenseAmountsByCategory(expenseProvider.expenses);
    final spentExpenses = grouped.byCategory;
    final totalSpent = grouped.total;

    if (totalSpent <= 0) {
      return _expansionShell(
        children: const [
          Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: Text('Ei menoja näytettäväksi')),
          ),
        ],
      );
    }

    final combinedExpenses = combineSmallCategories(spentExpenses, totalSpent);
    final categoryKeys = combinedExpenses.keys.toList();

    return _expansionShell(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              SizedBox(
                height: 220,
                child: PieChart(
                  PieChartData(
                    sections: combinedExpenses.entries
                        .toList()
                        .asMap()
                        .entries
                        .map((mapEntry) {
                      final index = mapEntry.key;
                      final entry = mapEntry.value;
                      final percentage =
                          totalSpent > 0 ? (entry.value / totalSpent) * 100 : 0.0;
                      return PieChartSectionData(
                        color: _colorForCategory(entry.key, categoryKeys),
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
                          if (pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            touchedIndex = -1;
                            return;
                          }
                          touchedIndex = pieTouchResponse
                              .touchedSection!.touchedSectionIndex;
                          if (touchedIndex != null && touchedIndex != -1) {
                            final touchedCategory =
                                categoryKeys.elementAt(touchedIndex!);
                            final touchedAmount =
                                combinedExpenses[touchedCategory]!;
                            _showCategoryDetails(
                              context,
                              touchedCategory,
                              touchedAmount,
                              totalSpent,
                              spentExpenses,
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
                children: categoryKeys.map((category) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: _colorForCategory(category, categoryKeys),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        category,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.black87),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
