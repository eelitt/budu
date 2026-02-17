import 'package:budu/core/utils.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'summary_utils.dart';

/// Näyttää meno-tapahtumien jakautumisen piirakkakaaviona yhteenvetosivulla.
/// Nyt täysin yhteensopiva sekä henkilökohtaisen että yhteistalousbudjetin kanssa:
/// - Käyttää ExpenseProvider.events:iä toteutuneiden menojen laskemiseen (ryhmittely kategorioittain).
/// - Yhdistää pienet kategoriat "Muut"-kategoriaan (kuten ennen).
/// - Näyttää prosentit toteutuneesta kokonaissummasta.
/// - Dialogi näyttää alakategoriat "Muut"-kategorialle ja yksittäisen kategorian tiedot.
/// - Ei enää riipu BudgetProvider.budget:sta → toimii saumattomasti molemmille budjettityypeille,
///   koska SummaryScreen lataa aina oikeat tapahtumat loadExpenses-kutsulla.
/// - Jos ei menoja, näyttää selkeän viestin.
/// - Kaikki alkuperäinen toiminnallisuus (laajennus, kosketus, värit, legend, dialogit)
///   säilytetty täysin ennallaan – vain data-lähde vaihdettu toteutuneisiin menoihin.
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
    double totalSpent,
    Map<String, Map<String, double>> spentExpenses,
  ) {
    if (_isDialogOpen) return;
    _isDialogOpen = true;

    final percentage = totalSpent > 0 ? (amount / totalSpent) * 100 : 0.0;

    if (category == 'Muut') {
      final otherCategories = getOtherCategoryDetails(spentExpenses, totalSpent);
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
                  final subPercentage = totalSpent > 0 ? (entry.value / totalSpent) * 100 : 0.0;
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
      final subExpenses = spentExpenses[category] ?? {};
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(category),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Yhteensä: ${formatCurrency(amount)} (${percentage.toStringAsFixed(1)}%)'),
                if (subExpenses.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Alakategoriat:'),
                  ...subExpenses.entries.map((sub) {
                    final subPercentage = totalSpent > 0 ? (sub.value / totalSpent) * 100 : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: Text(sub.key)),
                          Text('${formatCurrency(sub.value)} (${subPercentage.toStringAsFixed(1)}%)'),
                        ],
                      ),
                    );
                  }).toList(),
                ],
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final events = expenseProvider.expenses ?? [];

    if (events.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
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
            onExpansionChanged: (expanded) => setState(() => _isExpanded = expanded),
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
            children: const [
              Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('Ei menoja näytettäväksi')),
              ),
            ],
          ),
        ),
      );
    }

    // Ryhmitellään toteutuneet menot kategorioittain ja alakategorioittain
    final Map<String, Map<String, double>> spentExpenses = {};
    double totalSpent = 0.0;

    for (final event in events) {
      final cat = event.category;
      final sub = event.subcategory ?? 'Ei alakategoriaa';
      final amount = event.amount;
      totalSpent += amount;

      spentExpenses.putIfAbsent(cat, () => {});
      spentExpenses[cat]!.update(sub, (v) => v + amount, ifAbsent: () => amount);
    }

    // Yhdistetään pienet kategoriat "Muut"-kategoriaan
    final combinedExpenses = combineSmallCategories(spentExpenses, totalSpent);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
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
          onExpansionChanged: (expanded) => setState(() => _isExpanded = expanded),
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
                        sections: combinedExpenses.entries.toList().asMap().entries.map((mapEntry) {
                          final index = mapEntry.key;
                          final entry = mapEntry.value;
                          final percentage = totalSpent > 0 ? (entry.value / totalSpent) * 100 : 0.0;
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
                                      style: const TextStyle(fontSize: 10, color: Colors.white),
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
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black87),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}