import 'package:budu/core/constants.dart';
import 'package:budu/core/utils.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/budget_provider.dart';
import '../providers/expense_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/expense_event.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  late Future<void> _loadDataFuture;
  late BudgetProvider budgetProvider;
  late ExpenseProvider expenseProvider;
  int? touchedIndex;
  bool _isDataLoaded = false;
  bool _isDialogOpen = false;
  late int currentYear;
  late int currentMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    currentYear = now.year;
    currentMonth = now.month;
    budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isDataLoaded) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      _loadDataFuture = Future.wait([
        budgetProvider.loadBudget(authProvider.user!.uid, currentYear, currentMonth),
        expenseProvider.loadExpenses(authProvider.user!.uid, currentYear, currentMonth),
      ]);
      await _loadDataFuture;
      _isDataLoaded = true;
    } else {
      _loadDataFuture = Future.error('Käyttäjä ei ole kirjautunut');
      _isDataLoaded = true;
    }
  }

  Map<String, double> _combineSmallCategories(Map<String, double> expenses, double totalBudget) {
    const double threshold = 5.0;
    Map<String, double> combinedExpenses = {};
    double otherTotal = 0.0;

    expenses.forEach((category, amount) {
      final percentage = (amount / totalBudget) * 100;
      if (percentage < threshold) {
        otherTotal += amount;
      } else {
        combinedExpenses[category] = amount;
      }
    });

    if (otherTotal > 0) {
      combinedExpenses['Muut'] = otherTotal;
    }

    return combinedExpenses;
  }

  List<MapEntry<String, double>> _getOtherCategoryDetails(Map<String, double> expenses, double totalBudget) {
    const double threshold = 5.0;
    List<MapEntry<String, double>> otherCategories = [];

    expenses.forEach((category, amount) {
      final percentage = (amount / totalBudget) * 100;
      if (percentage < threshold) {
        otherCategories.add(MapEntry(category, amount));
      }
    });

    return otherCategories;
  }

  void _showCategoryDetails(BuildContext context, String category, double amount, double totalBudget, Map<String, double> originalExpenses) {
    if (_isDialogOpen) return;
    _isDialogOpen = true;

    final percentage = (amount / totalBudget) * 100;
    if (category == 'Muut') {
      final otherCategories = _getOtherCategoryDetails(originalExpenses, totalBudget);
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
                ...otherCategories.map((entry) {
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
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return FutureBuilder(
      future: _loadDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Virhe latauksessa: ${snapshot.error}'));
        }
        final budget = budgetProvider.budget;
        if (budget == null) {
          return const Center(child: Text('Luo budjetti ensin!'));
        }

        final categoryTotals = expenseProvider.getCategoryTotals();
        final totalBudget = budget.expenses.values.fold(0.0, (sum, value) => sum + value);
        final totalExpenses = expenseProvider.totalExpenses;
        final totalIncome = budget.income + expenseProvider.totalIncome;
        final balance = totalIncome - totalExpenses;
        final combinedExpenses = _combineSmallCategories(budget.expenses, totalBudget);

        // Määritellään unmappedExpenses ja muut muuttujat tässä
        final allMappedCategories = categoryMapping.values.expand((categories) => categories).toSet();
        final List<MapEntry<String, double>> unmappedExpenses = budget.expenses.entries
            .where((entry) => !allMappedCategories.contains(entry.key))
            .toList();
        final double unmappedBudget = unmappedExpenses.fold<double>(0.0, (sum, e) => sum + e.value);
        final double unmappedSpent = categoryTotals.entries
            .where((e) => !allMappedCategories.contains(e.key))
            .fold<double>(0.0, (sum, e) => sum + e.value);
        final double unmappedProgress = unmappedBudget > 0 ? unmappedSpent / unmappedBudget : 0.0;
        final double unmappedRemainingPercentage = unmappedBudget > 0 ? ((unmappedBudget - unmappedSpent) / unmappedBudget * 100).clamp(0, 100) : 0.0;

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Yhteenveto-osio
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          Text('Yhteenveto', style: Theme.of(context).textTheme.headlineSmall),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.arrow_upward, color: Colors.green),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Tulot yhteensä',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          Flexible(
                            child: Text(
                              formatCurrency(totalIncome),
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.arrow_downward, color: Colors.red),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Menot yhteensä',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          Flexible(
                            child: Text(
                              formatCurrency(totalExpenses),
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Saldo'),
                          Text(
                            formatCurrency(balance),
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: balance >= 0 ? Colors.green : Colors.red,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Budjettiseuranta-osio
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.pie_chart, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          Text('Budjettiseuranta', style: Theme.of(context).textTheme.headlineSmall),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...categoryMapping.entries.map((categoryEntry) {
                        final categoryName = categoryEntry.key;
                        final subCategories = categoryEntry.value;
                        final categoryExpenses = budget.expenses.entries
                            .where((entry) => subCategories.contains(entry.key))
                            .toList();

                        if (categoryExpenses.isEmpty) return const SizedBox.shrink();

                        final categoryBudget = categoryExpenses.fold<double>(0.0, (sum, e) => sum + e.value);
                        final categorySpent = categoryTotals.entries
                            .where((e) => subCategories.contains(e.key))
                            .fold<double>(0.0, (sum, e) => sum + e.value);
                        final progress = categoryBudget > 0 ? categorySpent / categoryBudget : 0.0;
                        final remainingPercentage = categoryBudget > 0 ? ((categoryBudget - categorySpent) / categoryBudget * 100).clamp(0, 100) : 100.0;

                        return Material(
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(horizontal: 0),
                            childrenPadding: const EdgeInsets.symmetric(horizontal: 0),
                            leading: Icon(
                              categoryName == "Asuminen"
                                  ? Icons.home
                                  : categoryName == "Liikkuminen"
                                      ? Icons.directions_car
                                      : categoryName == "Palvelut"
                                          ? Icons.subscriptions
                                          : categoryName == "Ruoka"
                                              ? Icons.fastfood
                                              : categoryName == "Terveys"
                                                  ? Icons.local_hospital
                                                  : categoryName == "Hygienia"
                                                      ? Icons.cleaning_services
                                                      : categoryName == "Viihde"
                                                          ? Icons.movie
                                                          : categoryName == "Lemmikit"
                                                              ? Icons.pets
                                                              : Icons.category,
                              color: Colors.blueGrey,
                              size: 24,
                            ),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Text(
                                      categoryName,
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${formatCurrency(categorySpent)} / ${formatCurrency(categoryBudget)}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.black54,
                                        fontSize: 14,
                                      ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                LinearProgressIndicator(
                                  value: progress > 1 ? 1 : progress,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation<Color>(progress > 1 ? Colors.red : Colors.blue),
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${remainingPercentage.toStringAsFixed(0)}% jäljellä',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                                ),
                              ],
                            ),
                            children: categoryExpenses.map((entry) {
                              final subCategory = entry.key;
                              final budgetAmount = entry.value;
                              final spentAmount = categoryTotals[subCategory] ?? 0.0;
                              final subProgress = budgetAmount > 0 ? spentAmount / budgetAmount : 0.0;
                              final subRemainingPercentage = budgetAmount > 0 ? ((budgetAmount - spentAmount) / budgetAmount * 100).clamp(0, 100) : 0.0;

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            subCategory,
                                            style: Theme.of(context).textTheme.bodyLarge,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Flexible(
                                          child: Text(
                                            '${formatCurrency(spentAmount)} / ${formatCurrency(budgetAmount)}',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    LinearProgressIndicator(
                                      value: subProgress > 1 ? 1 : subProgress,
                                      backgroundColor: Colors.grey[200],
                                      valueColor: AlwaysStoppedAnimation<Color>(subProgress > 1 ? Colors.red : Colors.blue),
                                      minHeight: 8,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${subRemainingPercentage.toStringAsFixed(0)}% jäljellä',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }).toList(),
                      // Lisätään tarkistus jäljelle jääville kuluille ja "Muut"-kategoria
                      if (unmappedExpenses.isNotEmpty) ...[
                        Material(
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(horizontal: 0),
                            childrenPadding: const EdgeInsets.symmetric(horizontal: 0),
                            leading: const Icon(
                              Icons.category,
                              color: Colors.blueGrey,
                              size: 24,
                            ),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Text(
                                      'Muut',
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${formatCurrency(unmappedSpent)} / ${formatCurrency(unmappedBudget)}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.black54,
                                        fontSize: 14,
                                      ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                LinearProgressIndicator(
                                  value: unmappedProgress > 1 ? 1 : unmappedProgress,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation<Color>(unmappedProgress > 1 ? Colors.red : Colors.blue),
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${unmappedRemainingPercentage.toStringAsFixed(0)}% jäljellä',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                                ),
                              ],
                            ),
                            children: unmappedExpenses.map((entry) {
                              final subCategory = entry.key;
                              final budgetAmount = entry.value;
                              final spentAmount = categoryTotals[subCategory] ?? 0.0;
                              final subProgress = budgetAmount > 0 ? spentAmount / budgetAmount : 0.0;
                              final subRemainingPercentage = budgetAmount > 0 ? ((budgetAmount - spentAmount) / budgetAmount * 100).clamp(0, 100) : 0.0;

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            subCategory,
                                            style: Theme.of(context).textTheme.bodyLarge,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Flexible(
                                          child: Text(
                                            '${formatCurrency(spentAmount)} / ${formatCurrency(budgetAmount)}',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    LinearProgressIndicator(
                                      value: subProgress > 1 ? 1 : subProgress,
                                      backgroundColor: Colors.grey[200],
                                      valueColor: AlwaysStoppedAnimation<Color>(subProgress > 1 ? Colors.red : Colors.blue),
                                      minHeight: 8,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${subRemainingPercentage.toStringAsFixed(0)}% jäljellä',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Budjetin jakautuminen -osio
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Budjetin jakautuminen',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                      ),
                      const SizedBox(height: 16),
                      totalBudget > 0
                          ? Column(
                              children: [
                                Container(
                                  height: 200,
                                  child: PieChart(
                                    PieChartData(
                                      sections: combinedExpenses.entries.toList().asMap().entries.map((mapEntry) {
                                        final index = mapEntry.key;
                                        final entry = mapEntry.value;
                                        final percentage = (entry.value / totalBudget) * 100;
                                        return PieChartSectionData(
                                          color: _getColorForCategory(entry.key, combinedExpenses.keys.toList()),
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
                                          print('Touch event: $event');
                                          print('Pie touch response: $pieTouchResponse');
                                          setState(() {
                                            if (pieTouchResponse == null ||
                                                pieTouchResponse.touchedSection == null) {
                                              touchedIndex = -1;
                                              return;
                                            }
                                            touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                            print('Touched index: $touchedIndex');
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
                                const SizedBox(height: 16),
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
                                            color: _getColorForCategory(category, combinedExpenses.keys.toList()),
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
                const SizedBox(height: 24),
                // Tapahtumat-osio
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.event, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          Text('Tapahtumat', style: Theme.of(context).textTheme.headlineSmall),
                        ],
                      ),
                      const SizedBox(height: 16),
                      expenseProvider.expenses.isEmpty
                          ? const Text('Ei vielä tapahtumia.')
                          : Column(
                              children: expenseProvider.expenses.asMap().entries.map((entry) {
                                final index = entry.key;
                                final expense = entry.value;
                                return Padding(
                                  padding: EdgeInsets.only(
                                    top: index == 0 ? 0 : 12,
                                    bottom: index == expenseProvider.expenses.length - 1 ? 0 : 12,
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        expense.type == EventType.income
                                                            ? Icons.arrow_upward
                                                            : Icons.arrow_downward,
                                                        color: expense.type == EventType.income
                                                            ? Colors.green
                                                            : Colors.red,
                                                        size: 16,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        expense.category,
                                                        style: Theme.of(context).textTheme.bodyLarge,
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${expense.createdAt.day}.${expense.createdAt.month}.${expense.createdAt.year} '
                                                    '${expense.createdAt.hour}:${expense.createdAt.minute.toString().padLeft(2, '0')}',
                                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                          color: Colors.black54,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              expense.type == EventType.income
                                                  ? '+${formatCurrency(expense.amount)}'
                                                  : '-${formatCurrency(expense.amount)}',
                                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                    color: expense.type == EventType.income
                                                        ? Colors.green
                                                        : Colors.red,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                                size: 20,
                                              ),
                                              onPressed: () async {
                                                final confirm = await showDialog<bool>(
                                                  context: context,
                                                  builder: (context) => AlertDialog(
                                                    title: const Text('Poista tapahtuma'),
                                                    content: Text('Haluatko varmasti poistaa tapahtuman "${expense.category}" (${formatCurrency(expense.amount)})?'),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () => Navigator.pop(context, false),
                                                        child: const Text('Peruuta'),
                                                      ),
                                                      TextButton(
                                                        onPressed: () => Navigator.pop(context, true),
                                                        child: const Text('Poista'),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                                if (confirm == true) {
                                                  try {
                                                    await expenseProvider.deleteExpense(authProvider.user!.uid, expense.id);
                                                  } catch (e) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('Virhe poistettaessa tapahtumaa: $e')),
                                                    );
                                                  }
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
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
      },
    );
  }

  Color _getColorForCategory(String category, List<String> categories) {
    final colors = [
      const Color(0xFF4CAF50),
      const Color(0xFF2196F3),
      const Color(0xFFFF9800),
      const Color(0xFFE91E63),
      const Color(0xFF9C27B0),
      const Color(0xFF00BCD4),
      const Color(0xFFFF5722),
      const Color(0xFF795548),
      const Color(0xFFCDDC39),
      const Color(0xFF673AB7),
      const Color(0xFF009688),
      const Color(0xFFFFC107),
    ];
    final index = categories.indexOf(category);
    return colors[index % colors.length];
  }
}