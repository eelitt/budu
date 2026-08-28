import 'package:budu/core/utils.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/data/budget_type_prefs.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:budu/features/budget/screens/budget/widgets/budget_month_selector.dart';
import 'package:budu/features/budget/screens/summary/budget_distribution_section.dart';
import 'package:budu/features/budget/screens/summary/budget_overview_section.dart';
import 'package:budu/features/budget/screens/summary/budget_tracking/budget_tracking_section.dart';
import 'package:budu/features/budget/screens/summary/event_section.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Summary tab: personal/shared toggle, period selector, tracking / pie / events.
///
/// [isActive] is true when the main-shell Summary tab is selected. First network
/// load runs on activation; later activations refresh the personal budget list.
class SummaryScreen extends StatefulWidget {
  final bool isActive;

  const SummaryScreen({super.key, this.isActive = true});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  bool _isSharedBudget = false;
  bool _isLoading = true;
  bool _hasLoadedOnce = false;
  String? _focusedCategory;
  int _focusToken = 0;

  List<BudgetModel> _availablePersonalBudgets = [];
  BudgetModel? _selectedSharedBudget;

  void _focusOverspentCategory(String categoryName) {
    setState(() {
      _focusedCategory = categoryName;
      _focusToken++;
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadPreferencesAndBudgets();
      });
    }
  }

  @override
  void didUpdateWidget(SummaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      if (!_hasLoadedOnce) {
        _loadPreferencesAndBudgets();
      } else {
        _refreshPersonalBudgets();
      }
    }
  }

  Future<void> _loadPreferencesAndBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final savedIsShared = BudgetTypePrefs.read(prefs, BudgetTypePrefs.summary);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final sharedProvider =
        Provider.of<SharedBudgetProvider>(context, listen: false);
    final expenseProvider =
        Provider.of<ExpenseProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasLoadedOnce = true;
        });
      }
      return;
    }

    List<BudgetModel> personalBudgets = [];
    try {
      personalBudgets = await budgetProvider.getAvailableBudgets(user.uid);
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, 'Budjettien lataus epäonnistui');
      }
    }
    if (!mounted) return;

    BudgetModel? initialShared;
    if (sharedProvider.sharedBudgets.isNotEmpty) {
      final sorted = List<BudgetModel>.from(sharedProvider.sharedBudgets)
        ..sort((a, b) => b.startDate.compareTo(a.startDate));
      initialShared = sorted.first;
    }

    setState(() {
      _availablePersonalBudgets = personalBudgets;
      _isSharedBudget = sharedProvider.hasSharedBudget && savedIsShared;
      _selectedSharedBudget = initialShared;
      _isLoading = false;
      _hasLoadedOnce = true;
    });

    final initialBudgetId = _getCurrentBudgetId();
    if (initialBudgetId != null && mounted) {
      await _loadExpensesFor(
        expenseProvider: expenseProvider,
        userId: user.uid,
        budgetId: initialBudgetId,
        isSharedBudget: _isSharedBudget,
      );
    }
  }

  Future<void> _refreshPersonalBudgets() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    try {
      final personalBudgets = await budgetProvider.getAvailableBudgets(user.uid);
      if (!mounted) return;
      setState(() => _availablePersonalBudgets = personalBudgets);
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, 'Budjettien lataus epäonnistui');
      }
    }
  }

  String? _getCurrentBudgetId() {
    if (_isSharedBudget) {
      return _selectedSharedBudget?.id;
    }
    return Provider.of<BudgetProvider>(context, listen: false).budget?.id;
  }

  Future<void> _loadExpensesFor({
    required ExpenseProvider expenseProvider,
    required String userId,
    required String budgetId,
    required bool isSharedBudget,
  }) async {
    try {
      await expenseProvider.loadExpenses(
        userId,
        budgetId,
        isSharedBudget: isSharedBudget,
      );
    } catch (_) {
      if (!mounted) return;
      final message =
          expenseProvider.errorMessage ?? 'Tapahtumien lataus epäonnistui';
      showErrorSnackBar(context, message);
    }
  }

  Future<void> _savePreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await BudgetTypePrefs.write(prefs, BudgetTypePrefs.summary, value);
  }

  Future<void> _onToggleChanged(bool value) async {
    await _savePreference(value);
    if (!mounted) return;

    setState(() {
      _isSharedBudget = value;
      if (value &&
          _selectedSharedBudget == null &&
          Provider.of<SharedBudgetProvider>(context, listen: false)
              .sharedBudgets
              .isNotEmpty) {
        final sorted = List<BudgetModel>.from(
          Provider.of<SharedBudgetProvider>(context, listen: false)
              .sharedBudgets,
        )..sort((a, b) => b.startDate.compareTo(a.startDate));
        _selectedSharedBudget = sorted.first;
      }
    });

    if (!value) {
      await _refreshPersonalBudgets();
    }

    final budgetId = _getCurrentBudgetId();
    if (budgetId != null && mounted) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final expense = Provider.of<ExpenseProvider>(context, listen: false);
      final user = auth.user;
      if (user == null) return;
      await _loadExpensesFor(
        expenseProvider: expense,
        userId: user.uid,
        budgetId: budgetId,
        isSharedBudget: _isSharedBudget,
      );
    }
  }

  Future<void> _onBudgetSelected(dynamic selected) async {
    if (selected == null) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final expenseProvider =
        Provider.of<ExpenseProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) return;

    if (_isSharedBudget) {
      setState(() => _selectedSharedBudget = selected);
    } else {
      await budgetProvider.loadBudget(user.uid, selected.id!);
      if (!mounted) return;
    }

    await _loadExpensesFor(
      expenseProvider: expenseProvider,
      userId: user.uid,
      budgetId: selected.id!,
      isSharedBudget: _isSharedBudget,
    );
  }

  BudgetModel? get _currentBudget {
    return _isSharedBudget
        ? _selectedSharedBudget
        : Provider.of<BudgetProvider>(context, listen: false).budget;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Consumer3<BudgetProvider, SharedBudgetProvider, ExpenseProvider>(
      builder: (context, budgetProvider, sharedProvider, expenseProvider, child) {
        final showToggle = sharedProvider.hasSharedBudget;
        final currentBudget = _currentBudget;

        if (currentBudget == null) {
          return const Center(child: Text('Luo budjetti ensin!'));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (showToggle) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Henkilökohtainen',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontSize: 16,
                            fontWeight: _isSharedBudget
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                    ),
                    Switch(
                      value: _isSharedBudget,
                      onChanged: _onToggleChanged,
                      activeTrackColor: Colors.blueGrey[700],
                      inactiveThumbColor: Colors.blueGrey[300],
                    ),
                    Text(
                      'Yhteistalous',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontSize: 16,
                            fontWeight: _isSharedBudget
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
              BudgetMonthSelector(
                isSharedBudget: _isSharedBudget,
                availableBudgets: _availablePersonalBudgets,
                availableSharedBudgets: sharedProvider.sharedBudgets,
                selectedBudget: budgetProvider.budget,
                selectedSharedBudget: _selectedSharedBudget,
                onBudgetSelected: _onBudgetSelected,
              ),
              const SizedBox(height: 24),
              BudgetOverviewSection(
                budget: currentBudget,
                onOverspentCategoryTap: _focusOverspentCategory,
              ),
              const SizedBox(height: 24),
              BudgetTrackingSection(
                budget: currentBudget,
                isSharedBudget: _isSharedBudget,
                focusedCategory: _focusedCategory,
                focusToken: _focusToken,
              ),
              const SizedBox(height: 24),
              const BudgetDistributionSection(),
              const SizedBox(height: 24),
              EventsSection(
                budget: currentBudget,
                isSharedBudget: _isSharedBudget,
              ),
            ],
          ),
        );
      },
    );
  }
}
