import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:budu/features/budget/screens/summary/budget_distribution_section.dart';
import 'package:budu/features/budget/screens/summary/budget_tracking_section.dart';
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
  late Future<void> _loadDataFuture;
  late BudgetProvider budgetProvider;
  late ExpenseProvider expenseProvider;
  bool _isDataLoaded = false;
  late int currentYear;
  late int currentMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    currentYear = now.year;
    currentMonth = now.month;
    budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isDataLoaded) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      _loadDataFuture = Future.wait([
        budgetProvider.loadBudget(authProvider.user!.uid, currentYear, currentMonth),
        expenseProvider.loadExpenses(authProvider.user!.uid, currentYear, currentMonth),
      ]);
      await _loadDataFuture;
      _isDataLoaded = true;
    } else {
      _loadDataFuture = Future.error('Käyttäjä ei ole kirjautunut');
      _isDataLoaded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _loadDataFuture,
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

        return Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SummarySection(),
                  const SizedBox(height: 24),
                  BudgetTrackingSection(),
                  const SizedBox(height: 24),
                  BudgetDistributionSection(),
                  const SizedBox(height: 24),
                  EventsSection(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}