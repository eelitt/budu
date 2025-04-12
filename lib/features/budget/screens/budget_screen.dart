import 'package:budu/core/constants.dart';
import 'package:budu/core/utils.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/budget_provider.dart';
import '../../auth/providers/auth_provider.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  late Future<void> _loadBudgetFuture;
  late Map<String, Map<String, TextEditingController>> _expenseControllers;
  late TextEditingController _incomeController;
  late int currentYear;
  late int currentMonth;
  bool _isDataLoaded = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    currentYear = now.year;
    currentMonth = now.month;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    if (authProvider.user != null) {
      _loadBudgetFuture = budgetProvider.loadBudget(authProvider.user!.uid, currentYear, currentMonth);
    } else {
      _loadBudgetFuture = Future.error('Käyttäjä ei ole kirjautunut');
    }

    _incomeController = TextEditingController();
    _expenseControllers = {};
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isDataLoaded) {
      _loadBudgetFuture.then((_) {
        setState(() {
          _isDataLoaded = true;
          _initializeControllers();
        });
      }).catchError((error) {
        setState(() {
          _isDataLoaded = true;
        });
      });
    }
  }

  void _initializeControllers() {
    final budget = Provider.of<BudgetProvider>(context, listen: false).budget;
    if (budget == null) return;

    // Alustetaan tulojen controller
    _incomeController.text = budget.income.toStringAsFixed(2);

    // Alustetaan menojen controllerit kategorioittain
    for (var category in categoryMapping.keys) {
      _expenseControllers[category] = {};
      for (var subCategory in categoryMapping[category]!) {
        final amount = budget.expenses[subCategory] ?? 0.0;
        _expenseControllers[category]![subCategory] = TextEditingController(
          text: amount.toStringAsFixed(2),
        );
      }
    }
  }

  void _saveBudget(BuildContext context, BudgetProvider budgetProvider, String userId) {
    Map<String, double> updatedExpenses = {};
    _expenseControllers.forEach((category, subCategories) {
      subCategories.forEach((subCategory, controller) {
        double? value = double.tryParse(controller.text.replaceAll('€', '').replaceAll(',', '.').trim());
        if (value != null && value > 0) {
          updatedExpenses[subCategory] = value;
        }
      });
    });

    double? updatedIncome = double.tryParse(_incomeController.text.replaceAll('€', '').replaceAll(',', '.').trim());

    // Varmistetaan, että kaikki syötteet ovat kelvollisia ennen tallennusta
    bool hasErrors = false;
    if (updatedIncome == null || updatedIncome < 0) {
      hasErrors = true;
    }
    _expenseControllers.forEach((category, subCategories) {
      subCategories.forEach((subCategory, controller) {
        double? value = double.tryParse(controller.text.replaceAll('€', '').replaceAll(',', '.').trim());
        if (value == null || value < 0) {
          hasErrors = true;
        }
      });
    });

    if (hasErrors) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Korjaa virheelliset syötteet ennen tallennusta')),
      );
      return;
    }

    final updatedBudget = BudgetModel(
      income: updatedIncome!,
      expenses: updatedExpenses,
      createdAt: budgetProvider.budget!.createdAt,
      year: currentYear,
      month: currentMonth,
    );

    budgetProvider.saveBudget(userId, updatedBudget).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Budjetti tallennettu!')),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Virhe tallennettaessa budjettia: $error')),
      );
    });
  }

  @override
  void dispose() {
    _expenseControllers.forEach((category, subCategories) {
      subCategories.forEach((subCategory, controller) {
        controller.dispose();
      });
    });
    _incomeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
 final expenseProvider = Provider.of<ExpenseProvider>(context);
    return FutureBuilder(
      future: _loadBudgetFuture,
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

        if (!_isDataLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        final categoryTotals = expenseProvider.getCategoryTotals();

        return Scaffold(
          appBar: AppBar(
            title: Text('Budjetti: $currentMonth/$currentYear'),
            actions: [
              TextButton(
                onPressed: () {
                  _saveBudget(context, budgetProvider, authProvider.user!.uid);
                },
                child: const Text(
                  'Tallenna',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _incomeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Arvioidut tulot',
                      suffixText: '€/kk',
                      border: const OutlineInputBorder(),
                      errorText: double.tryParse(_incomeController.text) == null ||
                              double.parse(_incomeController.text) < 0
                          ? 'Syötä positiivinen numero'
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('Menot:', style: Theme.of(context).textTheme.bodyLarge),
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

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        elevation: 2,
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  categoryName,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                  overflow: TextOverflow.ellipsis,
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
                          subtitle: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${remainingPercentage.toStringAsFixed(0)}% jäljellä',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.black54,
                                    ),
                              ),
                              Text(
                                '${(100 - remainingPercentage).toStringAsFixed(0)}%',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.black54,
                                    ),
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
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          subCategory,
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                fontSize: 16,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          SizedBox(
                                            width: 100,
                                            child: TextField(
                                              controller: _expenseControllers[categoryName]![subCategory],
                                              keyboardType: TextInputType.number,
                                              decoration: const InputDecoration(
                                                border: OutlineInputBorder(),
                                                contentPadding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 0.0),
                                              ),
                                              textAlign: TextAlign.right,
                                              onChanged: (value) {
                                                setState(() {
                                                  final newValue = double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
                                                  budget.expenses[subCategory] = newValue;
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                            onPressed: () {
                                              setState(() {
                                                budget.expenses.remove(subCategory);
                                                _expenseControllers[categoryName]!.remove(subCategory);
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${subRemainingPercentage.toStringAsFixed(0)}% jäljellä',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Colors.black54,
                                            ),
                                      ),
                                      Text(
                                        '${(100 - subRemainingPercentage).toStringAsFixed(0)}%',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Colors.black54,
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
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}