import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/screens/budget/budget_category_section.dart';
import 'package:budu/features/budget/screens/budget/income_section.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  late Future<void> _loadBudgetFuture;
  late BudgetProvider budgetProvider;
  late int currentYear;
  late int currentMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    currentYear = now.year;
    currentMonth = now.month;
    budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    _loadBudget();
  }

  Future<void> _loadBudget() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      _loadBudgetFuture = budgetProvider.loadBudget(authProvider.user!.uid, currentYear, currentMonth);
      await _loadBudgetFuture;
    } else {
      _loadBudgetFuture = Future.error('Käyttäjä ei ole kirjautunut');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _loadBudgetFuture,
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

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IncomeSection(income: budget.income),
                BudgetCategorySection(categoryName: "Asuminen"),
                BudgetCategorySection(categoryName: "Liikkuminen"),
                BudgetCategorySection(categoryName: "Kodin kulut"),
                BudgetCategorySection(categoryName: "Viihde"),
                BudgetCategorySection(categoryName: "Harrastukset"),
                BudgetCategorySection(categoryName: "Ruoka"),
                BudgetCategorySection(categoryName: "Terveys"),
                BudgetCategorySection(categoryName: "Hygienia"),
                BudgetCategorySection(categoryName: "Lemmikit"),
                BudgetCategorySection(categoryName: "Sijoittaminen"),
                 BudgetCategorySection(categoryName: "Velat"),
                BudgetCategorySection(categoryName: "Muut"),
              ],
            ),
          ),
        );
      },
    );
  }
}