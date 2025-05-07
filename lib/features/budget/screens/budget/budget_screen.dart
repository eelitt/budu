import 'package:budu/core/app_router.dart';
import 'package:budu/core/constants.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/screens/budget/budget_category_section.dart';
import 'package:budu/features/budget/screens/budget/income_section.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  Future<void> _loadBudgetFuture = Future.value();
  late BudgetProvider budgetProvider;
  int currentYear = DateTime.now().year;
  int currentMonth = DateTime.now().month;
  List<Map<String, int>> availableMonths = [];
  Map<String, int>? selectedMonth;

  @override
  void initState() {
    super.initState();
    budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    _loadAvailableMonths();
  }

  Future<void> _loadBudget() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      _loadBudgetFuture = budgetProvider.loadBudget(authProvider.user!.uid, currentYear, currentMonth);
      await _loadBudgetFuture;
    } else {
      _loadBudgetFuture = Future.error('Käyttäjä ei ole kirjautunut');
    }
  }

  Future<void> _loadAvailableMonths() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      final months = await budgetProvider.getAvailableBudgetMonths(authProvider.user!.uid);
      availableMonths = months.toSet().toList();
      if (availableMonths.isNotEmpty) {
        selectedMonth = availableMonths.first;
        currentYear = selectedMonth!['year']!;
        currentMonth = selectedMonth!['month']!;
        // Poistettu _loadBudget-kutsu, koska budjettidata on jo haettu LoginScreenissä
      }
      setState(() {});
    }
  }

  Future<void> _resetBudgetExpenses() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      await budgetProvider.resetBudgetExpenses(authProvider.user!.uid, currentYear, currentMonth);
    }
  }

  Future<void> _deleteBudget() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      await budgetProvider.deleteBudget(authProvider.user!.uid, currentYear, currentMonth);
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRouter.chatbotRoute);
      }
    }
  }

  Future<void> _showResetConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nollaa budjetin menot'),
        content: const Text('Haluatko varmasti nollata kaikki budjetin menot? Tämä asettaa kaikkien kategorioiden arvot nollaan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Peruuta'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Nollaa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _resetBudgetExpenses();
    }
  }

  Future<void> _showDeleteConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Poista budjetti'),
        content: const Text('Haluatko varmasti poistaa tämän budjetin? Sinut ohjataan luomaan uusi budjetti.'),
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

    if (confirmed == true) {
      await _deleteBudget();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BudgetProvider>(
      builder: (context, budgetProvider, child) {
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

            final List<String> sortedCategories = categoryMapping.keys.toList()..sort();

            final List<Widget> categoryWidgets = [];
            for (int i = 0; i < sortedCategories.length; i++) {
              final categoryName = sortedCategories[i];
              categoryWidgets.add(BudgetCategorySection(categoryName: categoryName));
              if (i < sortedCategories.length - 1) {
                categoryWidgets.add(const SizedBox(height: 16));
              }
            }

            return SingleChildScrollView(
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          availableMonths.isNotEmpty
                              ? Container(
                                  constraints: const BoxConstraints(maxWidth: 150),
                                  child: DropdownButton<Map<String, int>>(
                                    isExpanded: true,
                                    value: selectedMonth,
                                    items: availableMonths.map((monthData) {
                                      return DropdownMenuItem<Map<String, int>>(
                                        value: monthData,
                                        child: Text(
                                          '${monthData['month']}/${monthData['year']}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          selectedMonth = value;
                                          currentYear = value['year']!;
                                          currentMonth = value['month']!;
                                        });
                                        _loadBudget();
                                      }
                                    },
                                  ),
                                )
                              : const Text('Ei saatavilla olevia budjetteja'),
                          ElevatedButton(
                            onPressed: _showResetConfirmationDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              textStyle: const TextStyle(fontSize: 14),
                            ),
                            child: const Text('Nollaa'),
                          ),
                          ElevatedButton(
                            onPressed: _showDeleteConfirmationDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              textStyle: const TextStyle(fontSize: 14),
                            ),
                            child: const Text('Poista'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const IncomeSection(),
                      const SizedBox(height: 16),
                      ...categoryWidgets,
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}