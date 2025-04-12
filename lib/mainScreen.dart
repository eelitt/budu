import 'package:budu/core/app_router.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/models/expense_event.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:budu/features/budget/screens/budget_screen.dart';
import 'package:budu/features/budget/screens/summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  final List<Widget> _screens = [
    const BudgetScreen(),  // Indeksi 0: Muokkaa budjettia
    const SummaryScreen(), // Indeksi 1: Yhteenveto
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showAddExpenseDialog(BuildContext context) {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    String? selectedCategory = budgetProvider.budget?.expenses.keys.first;
    final amountController = TextEditingController();
    String? errorMessage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Lisää meno'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: selectedCategory,
                isExpanded: true,
                items: budgetProvider.budget?.expenses.keys.map((key) {
                  return DropdownMenuItem<String>(
                    value: key,
                    child: Text(key),
                  );
                }).toList() ?? [],
                onChanged: (value) {
                  setState(() {
                    selectedCategory = value;
                  });
                },
              ),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Summa (€)',
                  border: const OutlineInputBorder(),
                  errorText: errorMessage,
                ),
                onChanged: (value) {
                  setState(() {
                    double? amount = double.tryParse(value);
                    if (amount == null || amount < 0) {
                      errorMessage = 'Syötä positiivinen numero';
                    } else {
                      errorMessage = null;
                    }
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Peruuta'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount < 0) {
                  setState(() {
                    errorMessage = 'Syötä positiivinen numero';
                  });
                  return;
                }
                if (selectedCategory != null && authProvider.user != null) {
                  final expense = ExpenseEvent(
                    id: const Uuid().v4(),
                    category: selectedCategory!,
                    amount: amount,
                    createdAt: DateTime.now(),
                    type: EventType.expense,
                    year: DateTime.now().year,
                    month: DateTime.now().month,
                  );
                  expenseProvider.addExpense(authProvider.user!.uid, expense);
                  Navigator.pop(context);
                }
              },
              child: const Text('Lisää'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddExpenseDialog(context),
            tooltip: 'Lisää meno',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authProvider.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, AppRouter.loginRoute);
              }
            },
            tooltip: 'Kirjaudu ulos',
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.edit),
            label: 'Muokkaa budjettia', // Indeksi 0
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Yhteenveto', // Indeksi 1
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, AppRouter.chatbotRoute);
        },
        child: const Icon(Icons.chat),
        backgroundColor: Colors.blueGrey[800],
      ),
    );
  }
}