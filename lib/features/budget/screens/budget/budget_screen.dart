import 'package:budu/core/app_router/app_router.dart';
import 'package:budu/core/constants.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/screens/budget/controllers/budget_screen_controller.dart';
import 'package:budu/features/budget/screens/budget/income_section.dart';
import 'package:budu/features/budget/screens/budget/widgets/budget_confirmation_dialogs.dart';
import 'package:budu/features/budget/screens/budget/widgets/budget_month_selector.dart';
import 'package:budu/features/budget/screens/budget/widgets/category_dialog.dart';
import 'package:budu/features/budget/screens/budget/widgets/category_list_wrapper.dart';
import 'package:budu/features/notification/providers/notification_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  BudgetScreenController? _controller;
  late ValueNotifier<int> _currentYear;
  late ValueNotifier<int> _currentMonth;
  List<Map<String, int>> _availableMonths = [];
  final ValueNotifier<Map<String, int>?> _selectedMonth = ValueNotifier(null);
  bool _isLoadingBudget = true;

  @override
  void initState() {
    super.initState();
    _controller = BudgetScreenController(
      context: context,
      onStateChanged: () => setState(() {}),
    );
    _initializeBudget();
  }

  Future<void> _initializeBudget() async {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);

    if (budgetProvider.budget != null) {
      _currentYear = ValueNotifier(budgetProvider.budget!.year);
      _currentMonth = ValueNotifier(budgetProvider.budget!.month);
    } else {
      _currentYear = ValueNotifier(DateTime.now().year);
      _currentMonth = ValueNotifier(DateTime.now().month);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user != null) {
        await _controller!.loadBudget(
          userId: authProvider.user!.uid,
          year: _currentYear.value,
          month: _currentMonth.value,
        );
      }
    }

    if (mounted) {
      setState(() {
        _isLoadingBudget = false;
      });
    }
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

      if (_availableMonths.isNotEmpty) {
        final nextMonth = _availableMonths.first;
        _selectedMonth.value = nextMonth;
        _currentYear.value = nextMonth['year']!;
        _currentMonth.value = nextMonth['month']!;
        await _controller!.loadBudget(
          userId: authProvider.user!.uid,
          year: _currentYear.value,
          month: _currentMonth.value,
        );
      } else {
      if (context.mounted) {
        Provider.of<NotificationProvider>(context, listen: false).clearNotification();
          Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
            AppRouter.chatbotRoute,
            (Route<dynamic> route) => false, // Poistaa kaikki aiemmat reitit
          );
        }
      }
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
        if (snapshot.connectionState == ConnectionState.waiting || _isLoadingBudget) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Virhe latauksessa: ${snapshot.error}'));
        }

        return Consumer<BudgetProvider>(
          builder: (context, budgetProvider, child) {
            final budget = budgetProvider.budget;

            if (budget == null) {
              if (_availableMonths.isEmpty) {
                return const Center(child: Text('Luo budjetti ensin!'));
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            }

            final availableCategories = categoryMapping.keys
                .where((category) => !budget.expenses.containsKey(category))
                .toList();

            return SingleChildScrollView(
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
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
                              children: [
                                Icon(
                                  Icons.edit_document,
                                  color: Colors.blueGrey,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Muokkaa budjettia',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black87,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
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
                                        ? 'Haluatko varmasti poistaa budjetin?\nKaikki siihen liittyvät tapahtumat poistetaan.\nKoska tämä on ainoa budjettisi, sinut ohjataan luomaan uusi.'
                                        : 'Haluatko varmasti poistaa tämän budjetin? Budjetin tulo- ja menotapahtumat poistetaan samalla.',
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
                                      currentExpenses: budget.expenses,
                                    );
                                    if (selectedCategory != null) {
                                      await _addCategory(selectedCategory);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: availableCategories.isEmpty ? Colors.grey[400] : Colors.blueGrey[800],
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
                            CategoryListWrapper(budget: budget),
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