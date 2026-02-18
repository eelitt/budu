import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/models/expense_event.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:budu/features/history/event_filter_section.dart';
import 'package:budu/features/history/event_list_item.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Näyttää tapahtumahistorian suodatettuna kategorian, tyypin, budjetin ja hakukyselyn perusteella.
/// Tukee sekä henkilökohtaista että yhteistalousbudjettia toggle:lla.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isSharedBudget = false;
  String? _selectedCategory;
  String? _selectedType;
  String? _selectedBudgetId;
  String _searchQuery = '';
  List<BudgetModel> _availableBudgets = [];

  bool _isLoadingEvents = false; // ← NEW: Loading state for the events area

  @override
  void initState() {
    super.initState();
    _selectedBudgetId = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPreferencesAndData();
    });
  }

  Future<void> _loadPreferencesAndData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIsShared = prefs.getBool('isSharedBudget') ?? false;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final sharedProvider = Provider.of<SharedBudgetProvider>(context, listen: false);
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);

    setState(() {
      _isSharedBudget = savedIsShared;
      _isLoadingEvents = true; // ← Start loading
    });

    // Load budgets of the current type
    List<BudgetModel> budgets;
    if (_isSharedBudget) {
      budgets = sharedProvider.sharedBudgets;
    } else {
      budgets = await budgetProvider.getAvailableBudgets(authProvider.user!.uid);
    }

    if (mounted) {
      setState(() => _availableBudgets = budgets);
    }

    // Load events
    if (authProvider.user != null) {
      if (_isSharedBudget) {
        await expenseProvider.loadAllExpenses(context, authProvider.user!.uid);
      } else {
        await expenseProvider.loadAllExpenses(context, authProvider.user!.uid);
      }
    }

    if (mounted) {
      setState(() => _isLoadingEvents = false); // ← Stop loading
    }
  }

  Future<void> _onToggleChanged(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isSharedBudget', value);

    setState(() {
      _isSharedBudget = value;
      _selectedBudgetId = null;
      _isLoadingEvents = true; // ← Start loading when toggle changes
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);

    if (value) {
      final sharedProvider = Provider.of<SharedBudgetProvider>(context, listen: false);
      setState(() => _availableBudgets = sharedProvider.sharedBudgets);
      await expenseProvider.loadAllExpenses(context, authProvider.user!.uid);
    } else {
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
      final personal = await budgetProvider.getAvailableBudgets(authProvider.user!.uid);
      setState(() => _availableBudgets = personal);
      await expenseProvider.loadAllExpenses(context, authProvider.user!.uid);
    }

    if (mounted) setState(() => _isLoadingEvents = false);
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final events = expenseProvider.expenses;

    final dateFormat = DateFormat('d.M.yyyy');
    final budgetOptions = [
      'Kaikki budjetit',
      ..._availableBudgets.map((budget) {
        final prefix = _isSharedBudget ? 'Yhteistalous: ' : '';
        return '$prefix${dateFormat.format(budget.startDate)} - ${dateFormat.format(budget.endDate)}';
      }),
    ];

    final filteredEvents = events.where((event) {
      final matchesCategory = _selectedCategory == null ||
          _selectedCategory == 'Kaikki kategoriat' ||
          event.category == _selectedCategory;
      final matchesType = _selectedType == null ||
          _selectedType == 'Kaikki' ||
          (_selectedType == 'Tulot' && event.type == EventType.income) ||
          (_selectedType == 'Menot' && event.type == EventType.expense);
      final matchesQuery = _searchQuery.isEmpty ||
          (event.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      final matchesBudget = _selectedBudgetId == null || event.budgetId == _selectedBudgetId;
      return matchesCategory && matchesType && matchesQuery && matchesBudget;
    }).toList();

    return Column(
      children: [
        // Toggle at the top
        if (Provider.of<SharedBudgetProvider>(context, listen: false).hasSharedBudget)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Henkilökohtainen',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: _isSharedBudget ? FontWeight.normal : FontWeight.bold,
                        )),
                Switch(
                  value: _isSharedBudget,
                  onChanged: _onToggleChanged,
                  activeColor: Colors.blueGrey[700],
                ),
                Text('Yhteistalous',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: _isSharedBudget ? FontWeight.bold : FontWeight.normal,
                        )),
              ],
            ),
          ),

        EventFilterSection(
          availableBudgets: budgetOptions,
          onCategoryChanged: (category) => setState(() => _selectedCategory = category),
          onTypeChanged: (type) => setState(() => _selectedType = type),
          onBudgetChanged: (budget) async {
            setState(() {
              _selectedBudgetId = budget == 'Kaikki budjetit'
                  ? null
                  : _availableBudgets[budgetOptions.indexOf(budget!) - 1].id;
              _isLoadingEvents = true;
            });

            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);

            if (_selectedBudgetId != null) {
              await expenseProvider.loadExpenses(
                authProvider.user!.uid,
                _selectedBudgetId!,
                isSharedBudget: _isSharedBudget,
              );
            } else {
              await expenseProvider.loadAllExpenses(context, authProvider.user!.uid);
            }

            if (mounted) setState(() => _isLoadingEvents = false);
          },
          onSearchQueryChanged: (query) => setState(() => _searchQuery = query),
        ),

        Expanded(
          child: _isLoadingEvents
              ? const Center(
                  child: CircularProgressIndicator(), // ← LOADING INDICATOR HERE
                )
              : filteredEvents.isEmpty
                  ? const Center(child: Text('Ei tapahtumia'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredEvents.length,
                      itemBuilder: (context, index) => EventListItem(event: filteredEvents[index]),
                    ),
        ),
      ],
    );
  }
}