import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:budu/features/budget/screens/budget/widgets/budget_month_selector.dart';
import 'package:budu/features/budget/screens/summary/budget_distribution_section.dart';
import 'package:budu/features/budget/screens/summary/budget_tracking/budget_tracking_section.dart';
import 'package:budu/features/budget/screens/summary/event_section.dart';
import 'package:budu/features/budget/screens/summary/summary_section.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  late Future<Map<String, dynamic>> _loadDataFuture;
  late BudgetProvider budgetProvider;
  late ExpenseProvider expenseProvider;
  late BudgetModel? selectedBudget;
  List<BudgetModel> availableBudgets = [];

  @override
  void initState() {
    super.initState();
    budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    selectedBudget = null;
    _loadDataFuture = _loadInitialData();
  }

  Future<Map<String, dynamic>> _loadInitialData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) {
      throw Exception('Käyttäjä ei ole kirjautunut');
    }

    // Ladataan saatavilla olevat budjetit
    availableBudgets = await budgetProvider.getAvailableBudgets(authProvider.user!.uid);

    if (availableBudgets.isNotEmpty) {
      selectedBudget = availableBudgets.first;
      // Ladataan budjetti ja kulutustiedot valitulle budjetille
      await budgetProvider.loadBudget(authProvider.user!.uid, selectedBudget!.id!);
      await expenseProvider.loadExpenses(authProvider.user!.uid, selectedBudget!.id!);
    }

    return {
      'availableBudgets': availableBudgets,
      'selectedBudget': selectedBudget,
    };
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null && selectedBudget != null) {
      await Future.wait([
        budgetProvider.loadBudget(authProvider.user!.uid, selectedBudget!.id!),
        expenseProvider.loadExpenses(authProvider.user!.uid, selectedBudget!.id!),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Virhe latauksessa: ${snapshot.error}'));
        }

        return Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (availableBudgets.isNotEmpty) ...[
                    BudgetMonthSelector(
                      isSharedBudget: false,
                      availableBudgets: availableBudgets,
                      availableSharedBudgets: [],
                      selectedBudget: selectedBudget,
                      selectedSharedBudget: selectedBudget!,
                      onBudgetSelected: (value) async {
                        if (value != null) {
                          setState(() {
                            selectedBudget = value;
                          });
                          await _loadData();
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  Consumer<BudgetProvider>(
                    builder: (context, budgetProvider, child) {
                      final budget = budgetProvider.budget;
                      if (budget == null) {
                        return const Center(child: Text('Luo budjetti ensin!'));
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SummarySection(
                            selectedBudget: selectedBudget,
                          ),
                          const SizedBox(height: 24),
                          BudgetTrackingSection(
                            budget: budget,
                          ),
                          const SizedBox(height: 24),
                          BudgetDistributionSection(),
                          const SizedBox(height: 24),
                          EventsSection(),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}