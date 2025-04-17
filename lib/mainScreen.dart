import 'package:budu/add_event_dialog.dart';
import 'package:budu/core/app_router.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/screens/budget/budget_screen.dart';
import 'package:budu/features/budget/screens/summary/summary_screen.dart';
import 'package:budu/features/history/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _selectedIndex;
  late Future<void> _loadBudgetFuture;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _loadBudget();
  }

  Future<void> _loadBudget() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    if (authProvider.user != null) {
      final now = DateTime.now();
      _loadBudgetFuture = budgetProvider.loadBudget(authProvider.user!.uid, now.year, now.month);
      await _loadBudgetFuture;
    } else {
      _loadBudgetFuture = Future.error('Käyttäjä ei ole kirjautunut');
    }
  }

  final List<Widget> _screens = [
    const BudgetScreen(),  // Indeksi 0: Muokkaa budjettia
    const SummaryScreen(), // Indeksi 1: Yhteenveto
    const HistoryScreen(), // Indeksi 2: Historia
  ];

  void _onItemTapped(int index) async {
    if (index == 3) { // Uloskirjautuminen (indeksi 3)
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.signOut();
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, AppRouter.loginRoute);
      }
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BudgetProvider>(
      builder: (context, budgetProvider, child) {
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('Budu'),
            actions: [
              if (budgetProvider.budget != null) // Näytetään painike vain, jos budjetti on ladattu
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => const AddEventDialog(),
                      );
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Lisää tapahtuma'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
            ],
          ),
          body: _selectedIndex < _screens.length ? _screens[_selectedIndex] : const SizedBox.shrink(),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.edit),
                label: 'Muokkaa budjettia',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart),
                label: 'Yhteenveto',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history),
                label: 'Historia',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.logout),
                label: 'Kirjaudu ulos',
              ),
            ],
            currentIndex: _selectedIndex < _screens.length ? _selectedIndex : 0,
            onTap: _onItemTapped,
          ),
        );
      },
    );
  }
}