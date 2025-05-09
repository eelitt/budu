import 'package:budu/core/app_router/app_router.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/screens/budget/controllers/budget_screen_controller.dart';
import 'package:budu/features/budget/screens/budget/income_section.dart';
import 'package:budu/features/budget/screens/budget/widgets/budget_confirmation_dialogs.dart';
import 'package:budu/features/budget/screens/budget/widgets/budget_header.dart';
import 'package:budu/features/budget/screens/budget/widgets/budget_month_selector.dart';
import 'package:budu/features/budget/screens/budget/widgets/category_dialog.dart';
import 'package:budu/features/budget/screens/budget/widgets/category_list_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  BudgetScreenController? _controller;
  final ValueNotifier<int> _currentYear = ValueNotifier(DateTime.now().year);
  final ValueNotifier<int> _currentMonth = ValueNotifier(DateTime.now().month);
  List<Map<String, int>> _availableMonths = [];
  final ValueNotifier<Map<String, int>?> _selectedMonth = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _controller = BudgetScreenController(
      context: context,
      onStateChanged: () => setState(() {}),
    );
  }

  Future<void> _loadAvailableMonths() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      _availableMonths = await _controller!.loadAvailableMonths(
        userId: authProvider.user!.uid,
        selectedMonth: _selectedMonth,
        currentYear: _currentYear,
        currentMonth: _currentMonth,
      );
    }
  }

  Future<void> _resetBudgetExpenses() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      await _controller!.resetBudgetExpenses(
        userId: authProvider.user!.uid,
        year: _currentYear.value,
        month: _currentMonth.value,
      );
    }
  }

  Future<void> _deleteBudget() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      _availableMonths = await _controller!.deleteBudget(
        userId: authProvider.user!.uid,
        year: _currentYear.value,
        month: _currentMonth.value,
        availableMonths: _availableMonths,
        selectedMonth: _selectedMonth,
        currentYear: _currentYear,
        currentMonth: _currentMonth,
      );
    }
  }

  Future<void> _addCategory(String categoryName) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
      final now = DateTime.now();
      await budgetProvider.addCategory(
        userId: authProvider.user!.uid,
        year: now.year,
        month: now.month,
        category: categoryName,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadAvailableMonths(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Virhe latauksessa: ${snapshot.error}'));
        }

        return Consumer<BudgetProvider>(
          builder: (context, budgetProvider, child) {
            final budget = budgetProvider.budget;
            // Jos budjetti on null ja budjetteja ei ole jäljellä, ohjataan ChatbotScreen-näkymään
            if (budget == null && _availableMonths.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  Navigator.pushNamed(context, AppRouter.chatbotRoute);
                }
              });
              return const Center(child: Text('Luo budjetti ensin!'));
            }

            return SingleChildScrollView(
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BudgetHeader(selectedMonth: _selectedMonth.value),
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          BudgetMonthSelector(
                            availableMonths: _availableMonths,
                            selectedMonth: _selectedMonth.value,
                            onMonthSelected: (value) {
                              if (value != null) {
                                _selectedMonth.value = value;
                                _currentYear.value = value['year']!;
                                _currentMonth.value = value['month']!;
                                _controller!.loadBudget(
                                  userId: Provider.of<AuthProvider>(context, listen: false).user!.uid,
                                  year: _currentYear.value,
                                  month: _currentMonth.value,
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: () async {
                                  final confirmed = await showResetConfirmationDialog(context);
                                  if (confirmed) {
                                    await _resetBudgetExpenses();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueGrey[700],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.refresh, size: 16),
                                    SizedBox(width: 4),
                                    Text('Nollaa'),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  final confirmed = await showDeleteConfirmationDialog(
                                    context: context,
                                    isLastBudget: _availableMonths.length == 1,
                                    customMessage: _availableMonths.length == 1
                                        ? 'Haluatko varmasti poistaa tämän budjetin? Tämä on viimeinen budjettisi, joten sinut ohjataan luomaan uutta budjettia.'
                                        : 'Haluatko varmasti poistaa tämän budjetin? Näet seuraavan budjettisi poiston jälkeen.',
                                  );
                                  if (confirmed) {
                                    await _deleteBudget();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueGrey[900],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.delete, size: 16),
                                    SizedBox(width: 4),
                                    Text('Poista'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const IncomeSection(),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Kategoriat',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    final selectedCategory = await showAddCategoryDialog(
                                      context: context,
                                      currentExpenses: budget!.expenses,
                                    );
                                    if (selectedCategory != null) {
                                      await _addCategory(selectedCategory);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueGrey[800],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add, size: 16),
                                      SizedBox(width: 4),
                                      Text('Lisää kategoria'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            CategoryListWrapper(budget: budget!),
                          ],
                        ),
                      ),
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