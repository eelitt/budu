import 'package:budu/features/auth/providers/auth_provider.dart';
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
  late int currentYear;
  late int currentMonth;
  List<Map<String, int>> availableMonths = [];
  Map<String, int>? selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    currentYear = now.year;
    currentMonth = now.month;
    budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    _loadDataFuture = _loadInitialData();
  }

  Future<Map<String, dynamic>> _loadInitialData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) {
      throw Exception('Käyttäjä ei ole kirjautunut');
    }

    // Ladataan saatavilla olevat budjettikuukaudet
    availableMonths = await budgetProvider.getAvailableBudgetMonths(authProvider.user!.uid);

    if (availableMonths.isNotEmpty) {
      selectedMonth = availableMonths.first;
      currentYear = selectedMonth!['year']!;
      currentMonth = selectedMonth!['month']!;
      // Ladataan budjetti ja kulutustiedot valitulle kuukaudelle
      await budgetProvider.loadBudget(authProvider.user!.uid, currentYear, currentMonth);
      await expenseProvider.loadExpenses(authProvider.user!.uid, currentYear, currentMonth);
    }

    return {
      'availableMonths': availableMonths,
      'selectedMonth': selectedMonth,
    };
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      await Future.wait([
        budgetProvider.loadBudget(authProvider.user!.uid, currentYear, currentMonth),
        expenseProvider.loadExpenses(authProvider.user!.uid, currentYear, currentMonth),
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
                  if (availableMonths.isNotEmpty) ...[
                    BudgetMonthSelector(
                      availableMonths: availableMonths,
                      selectedMonth: selectedMonth,
                      onMonthSelected: (value) async {
                        if (value != null) {
                          setState(() {
                            selectedMonth = value;
                            currentYear = value['year']!;
                            currentMonth = value['month']!;
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
                            selectedMonth: selectedMonth,
                          ),
                          const SizedBox(height: 24),
                          BudgetTrackingSection(),
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