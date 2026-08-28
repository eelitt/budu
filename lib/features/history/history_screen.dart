import 'package:budu/core/utils.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/data/budget_type_prefs.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:budu/features/history/domain/history_filters.dart';
import 'package:budu/features/history/event_filter_section.dart';
import 'package:budu/features/history/event_list_item.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Näyttää tapahtumahistorian suodatettuna kategorian, tyypin, budjetin ja hakukyselyn perusteella.
/// Tukee sekä henkilökohtaista että yhteistalousbudjettia toggle:lla.
///
/// [isActive] is true when the main-shell History tab is selected. Network load
/// starts on first activation so IndexedStack does not fan out reads at startup.
class HistoryScreen extends StatefulWidget {
  final bool isActive;

  const HistoryScreen({super.key, this.isActive = false});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isSharedBudget = false;
  String _selectedCategory = historyAllCategoriesLabel;
  String _selectedType = historyAllTypesLabel;
  String? _selectedBudgetId;
  String _selectedBudgetLabel = historyAllBudgetsLabel;
  String _searchQuery = '';
  List<BudgetModel> _availableBudgets = [];
  bool _isLoadingEvents = false;
  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadPreferencesAndData();
      });
    }
  }

  @override
  void didUpdateWidget(HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive && !_hasLoadedOnce) {
      _loadPreferencesAndData();
    }
  }

  Future<void> _loadPreferencesAndData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final savedIsShared = BudgetTypePrefs.read(prefs, BudgetTypePrefs.history);

    setState(() {
      _isSharedBudget = savedIsShared;
      _selectedBudgetId = null;
      _selectedBudgetLabel = historyAllBudgetsLabel;
      _isLoadingEvents = true;
      _hasLoadedOnce = true;
    });

    await _reloadBudgetsAndEvents(isSharedBudget: savedIsShared);
  }

  Future<void> _onToggleChanged(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await BudgetTypePrefs.write(prefs, BudgetTypePrefs.history, value);
    if (!mounted) return;

    setState(() {
      _isSharedBudget = value;
      _selectedBudgetId = null;
      _selectedBudgetLabel = historyAllBudgetsLabel;
      _isLoadingEvents = true;
    });

    await _reloadBudgetsAndEvents(isSharedBudget: value);
  }

  Future<void> _reloadBudgetsAndEvents({required bool isSharedBudget}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) {
      if (mounted) setState(() => _isLoadingEvents = false);
      return;
    }

    try {
      final budgets = await _budgetsForSide(isSharedBudget: isSharedBudget);
      if (!mounted) return;
      setState(() => _availableBudgets = budgets);

      await expenseProvider.loadHistoryExpenses(
        user.uid,
        isSharedBudget: isSharedBudget,
        budgets: budgets,
      );
    } catch (_) {
      if (mounted) {
        final message =
            Provider.of<ExpenseProvider>(context, listen: false).errorMessage ??
                'Tapahtumien lataus epäonnistui';
        showErrorSnackBar(context, message);
      }
    } finally {
      if (mounted) setState(() => _isLoadingEvents = false);
    }
  }

  Future<List<BudgetModel>> _budgetsForSide({required bool isSharedBudget}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (isSharedBudget) {
      final sharedProvider =
          Provider.of<SharedBudgetProvider>(context, listen: false);
      if (sharedProvider.sharedBudgets.isEmpty && authProvider.user != null) {
        await sharedProvider.fetchSharedBudgets(authProvider.user!.uid);
      }
      final sorted = List<BudgetModel>.from(sharedProvider.sharedBudgets)
        ..sort((a, b) => b.startDate.compareTo(a.startDate));
      return sorted;
    }

    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    return budgetProvider.getAvailableBudgets(authProvider.user!.uid);
  }

  Future<void> _onBudgetLabelChanged(String label) async {
    final dateFormat = DateFormat('d.M.yyyy');
    String? budgetId;
    if (label != historyAllBudgetsLabel) {
      for (final budget in _availableBudgets) {
        final prefix = _isSharedBudget ? 'Yhteistalous: ' : '';
        final budgetLabel =
            '$prefix${dateFormat.format(budget.startDate)} - ${dateFormat.format(budget.endDate)}';
        if (budgetLabel == label) {
          budgetId = budget.id;
          break;
        }
      }
    }

    setState(() {
      _selectedBudgetLabel = label;
      _selectedBudgetId = budgetId;
      _isLoadingEvents = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) {
      if (mounted) setState(() => _isLoadingEvents = false);
      return;
    }

    try {
      final budgets = budgetId == null
          ? _availableBudgets
          : _availableBudgets.where((b) => b.id == budgetId).toList();
      await expenseProvider.loadHistoryExpenses(
        user.uid,
        isSharedBudget: _isSharedBudget,
        budgets: budgets,
      );
    } catch (_) {
      if (mounted) {
        final message = expenseProvider.errorMessage ??
            'Tapahtumien lataus epäonnistui';
        showErrorSnackBar(context, message);
      }
    } finally {
      if (mounted) setState(() => _isLoadingEvents = false);
    }
  }

  List<String> _budgetLabels() {
    final dateFormat = DateFormat('d.M.yyyy');
    return [
      historyAllBudgetsLabel,
      ..._availableBudgets.map((budget) {
        final prefix = _isSharedBudget ? 'Yhteistalous: ' : '';
        return '$prefix${dateFormat.format(budget.startDate)} - ${dateFormat.format(budget.endDate)}';
      }),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final events = expenseProvider.historyExpenses;
    final categories = events.map((e) => e.category).toSet().toList()..sort();
    final filteredEvents = filterHistoryEvents(
      events: events,
      category: _selectedCategory,
      type: _selectedType,
      query: _searchQuery,
      budgetId: _selectedBudgetId,
    );

    return CustomScrollView(
      slivers: [
        if (Provider.of<SharedBudgetProvider>(context).hasSharedBudget)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Henkilökohtainen',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: _isSharedBudget
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                  ),
                  Switch(
                    value: _isSharedBudget,
                    onChanged: _onToggleChanged,
                    activeColor: Colors.blueGrey[700],
                  ),
                  Text(
                    'Yhteistalous',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: _isSharedBudget
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                  ),
                ],
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: EventFilterSection(
            categories: categories,
            availableBudgetLabels: _budgetLabels(),
            selectedCategory: _selectedCategory,
            selectedType: _selectedType,
            selectedBudgetLabel: _selectedBudgetLabel,
            onCategoryChanged: (category) =>
                setState(() => _selectedCategory = category),
            onTypeChanged: (type) => setState(() => _selectedType = type),
            onBudgetLabelChanged: _onBudgetLabelChanged,
            onSearchQueryChanged: (query) =>
                setState(() => _searchQuery = query),
          ),
        ),
        if (_isLoadingEvents)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (filteredEvents.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('Ei tapahtumia')),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    EventListItem(event: filteredEvents[index]),
                childCount: filteredEvents.length,
              ),
            ),
          ),
      ],
    );
  }
}
