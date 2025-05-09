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
  late Future<void> _loadDataFuture;
  late BudgetProvider budgetProvider;
  late ExpenseProvider expenseProvider;
  bool _isDataLoaded = false;
  late int currentYear;
  late int currentMonth;
  List<Map<String, int>> availableMonths = [];
  Map<String, int>? selectedMonth;

  @override
  void initState() {
    super.initState();
    _loadDataFuture = Future.value();
    final now = DateTime.now();
    currentYear = now.year;
    currentMonth = now.month;
    budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    _loadAvailableMonths();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isDataLoaded) {
      _loadAvailableMonths();
    }
  }

  Future<void> _loadAvailableMonths() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      availableMonths = await budgetProvider.getAvailableBudgetMonths(authProvider.user!.uid);
      if (availableMonths.isNotEmpty) {
        selectedMonth = availableMonths.first;
        currentYear = selectedMonth!['year']!;
        currentMonth = selectedMonth!['month']!;
        await _loadData();
      } else {
        _loadDataFuture = Future.value();
      }
      _isDataLoaded = true;
      setState(() {});
    } else {
      _loadDataFuture = Future.error('Käyttäjä ei ole kirjautunut');
      _isDataLoaded = true;
      setState(() {});
    }
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      _loadDataFuture = Future.wait([
        expenseProvider.loadExpenses(authProvider.user!.uid, currentYear, currentMonth),
      ]);
      await _loadDataFuture;
    } else {
      _loadDataFuture = Future.error('Käyttäjä ei ole kirjautunut');
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
                          final authProvider = Provider.of<AuthProvider>(context, listen: false);
                          if (authProvider.user != null) {
                            await budgetProvider.loadBudget(authProvider.user!.uid, currentYear, currentMonth);
                            await _loadData();
                          }
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