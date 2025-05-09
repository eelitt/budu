import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/screens/create_budget/budget_calculator.dart';
import 'package:budu/features/budget/screens/create_budget/budget_initializer.dart';
import 'package:budu/features/budget/screens/create_budget/budget_saver.dart';
import 'package:budu/features/budget/screens/create_budget/sections/create_budget_income_section.dart';
import 'package:budu/features/budget/screens/create_budget/sections/expense_section.dart';
import 'package:budu/features/budget/screens/create_budget/save_button.dart';
import 'package:budu/features/budget/screens/create_budget/sections/create_budget_summary_section.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CreateBudgetScreen extends StatefulWidget {
  final BudgetModel? sourceBudget;
  final int newYear;
  final int newMonth;

  const CreateBudgetScreen({
    super.key,
    this.sourceBudget,
    required this.newYear,
    required this.newMonth,
  });

  @override
  State<CreateBudgetScreen> createState() => _CreateBudgetScreenState();
}

class _CreateBudgetScreenState extends State<CreateBudgetScreen> {
  late TextEditingController _incomeController;
  final Map<String, Map<String, TextEditingController>> _expenseControllers = {};
  String? _errorMessage;
  late BudgetInitializer _initializer;
  late BudgetCalculator _calculator;
  late BudgetSaver _saver;

  @override
  void initState() {
    super.initState();
    _incomeController = TextEditingController();
    _initializer = BudgetInitializer(
      sourceBudget: widget.sourceBudget,
      incomeController: _incomeController,
      expenseControllers: _expenseControllers,
      updateSummary: () => _calculator.updateSummary(),
    );
    _initializer.initialize();
    _calculator = BudgetCalculator(
      incomeController: _incomeController,
      expenseControllers: _expenseControllers,
      setStateCallback: () => setState(() {}),
    );
    _saver = BudgetSaver(
      context: context,
      incomeController: _incomeController,
      expenseControllers: _expenseControllers,
      newYear: widget.newYear,
      newMonth: widget.newMonth,
      totalIncome: _calculator.totalIncome,
      totalExpenses: _calculator.totalExpenses,
    );
  }

  @override
  void dispose() {
    _initializer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final userId = authProvider.user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text('Luo budjetti (${widget.newMonth}/${widget.newYear})'),
        leading: userId != null
            ? FutureBuilder<List<Map<String, int>>>(
                future: budgetProvider.getAvailableBudgetMonths(userId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Material(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final hasBudgets = snapshot.hasData && snapshot.data!.isNotEmpty;
                  return IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      if (hasBudgets) {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/main',
                          (route) => false,
                          arguments: {'index': 0}, // Asetetaan MainScreen-näkymän initialIndex arvoon 0 (BudgetScreen)
                        );
                      } else {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/chatbot',
                          (route) => false,
                        );
                      }
                    },
                  );
                },
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/chatbot',
                    (route) => false,
                  );
                },
              ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IncomeSection(incomeController: _incomeController),
            const SizedBox(height: 24),
            ExpensesSection(
              expenseControllers: _expenseControllers,
              onUpdate: () => setState(() {}),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ],
            const SizedBox(height: 24),
            SummarySection(
              totalIncome: _calculator.totalIncome,
              totalExpenses: _calculator.totalExpenses,
            ),
            const SizedBox(height: 24),
            SaveButton(
              onPressed: () async {
                await _saver.createBudget();
                setState(() {
                  _errorMessage = _saver.errorMessage;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}