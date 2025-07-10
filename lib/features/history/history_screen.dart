import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/models/expense_event.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:budu/features/history/event_filter_section.dart';
import 'package:budu/features/history/event_list_item.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Näyttää tapahtumahistorian suodatettuna kategorian, tyypin, budjetin ja hakukyselyn perusteella.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String? _selectedCategory;
  String? _selectedType;
  String? _selectedBudgetId;
  String _searchQuery = '';
  List<BudgetModel> _availableBudgets = [];

  @override
  void initState() {
    super.initState();
    _selectedBudgetId = null; // Oletus: ei budjettisuodatusta
    _loadBudgetsAndEvents();
  }

  /// Lataa budjetit ja tapahtumat asynkronisesti
  Future<void> _loadBudgetsAndEvents() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      if (authProvider.user != null) {
        final budgets = await budgetProvider.getAvailableBudgets(authProvider.user!.uid);
        if (mounted) {
          setState(() {
            _availableBudgets.clear();
            _availableBudgets.addAll(budgets);
          });
          // Ladataan tapahtumat kaikille budjeteille tai valitulle budjetille
          if (_selectedBudgetId != null) {
            await expenseProvider.loadExpenses(authProvider.user!.uid, _selectedBudgetId!);
          } else {
            await expenseProvider.loadAllExpenses(context, authProvider.user!.uid);
          }
          await FirebaseCrashlytics.instance.log('HistoryScreen: Budjetit ja tapahtumat ladattu, budjetteja: ${_availableBudgets.length}');
        }
      }
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to load budgets or events in HistoryScreen',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Budjettien tai tapahtumien lataus epäonnistui: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final events = expenseProvider.expenses;

    // Muotoile budjetit näyttöön aikaväleinä
    final dateFormat = DateFormat('d.M.yyyy');
    final budgetOptions = [
      'Kaikki budjetit',
      ..._availableBudgets.map((budget) =>
          '${dateFormat.format(budget.startDate)} - ${dateFormat.format(budget.endDate)}'),
    ];

    // Suodata tapahtumat
    final filteredEvents = events.where((event) {
      final matchesCategory =
          _selectedCategory == null || _selectedCategory == 'Kaikki kategoriat' || event.category == _selectedCategory;
      final matchesType = _selectedType == null ||
          _selectedType == 'Kaikki' ||
          (_selectedType == 'Tulot' && event.type == EventType.income) ||
          (_selectedType == 'Menot' && event.type == EventType.expense);
      final matchesQuery = _searchQuery.isEmpty || (event.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      final matchesBudget = _selectedBudgetId == null || event.budgetId == _selectedBudgetId;
      return matchesCategory && matchesType && matchesQuery && matchesBudget;
    }).toList();

    return Column(
      children: [
        EventFilterSection(
          availableBudgets: budgetOptions,
          onCategoryChanged: (category) {
            if (mounted) {
              setState(() {
                _selectedCategory = category;
              });
            }
          },
          onTypeChanged: (type) {
            if (mounted) {
              setState(() {
                _selectedType = type;
              });
            }
          },
          onBudgetChanged: (budget) async {
            if (mounted) {
              setState(() {
                _selectedBudgetId = budget == 'Kaikki budjetit'
                    ? null
                    : _availableBudgets[budgetOptions.indexOf(budget!) - 1].id;
              });
              // Ladataan tapahtumat valitulle budjetille
              try {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
                if (authProvider.user != null) {
                  if (_selectedBudgetId != null) {
                    await expenseProvider.loadExpenses(authProvider.user!.uid, _selectedBudgetId!);
                  } else {
                    await expenseProvider.loadAllExpenses(context, authProvider.user!.uid);
                  }
                  await FirebaseCrashlytics.instance.log('HistoryScreen: Tapahtumat ladattu budjetille: $_selectedBudgetId');
                }
              } catch (e, stackTrace) {
                await FirebaseCrashlytics.instance.recordError(
                  e,
                  stackTrace,
                  reason: 'Failed to load events for budget $_selectedBudgetId',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Tapahtumien lataus epäonnistui: $e')),
                  );
                }
              }
            }
          },
          onSearchQueryChanged: (query) {
            if (mounted) {
              setState(() {
                _searchQuery = query;
              });
            }
          },
        ),
        Expanded(
          child: filteredEvents.isEmpty
              ? const Center(child: Text('Ei tapahtumia'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredEvents.length,
                  itemBuilder: (context, index) {
                    return EventListItem(event: filteredEvents[index]);
                  },
                ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}