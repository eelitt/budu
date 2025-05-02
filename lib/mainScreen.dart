import 'package:budu/add_event_dialog.dart';
import 'package:budu/core/app_router.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/screens/budget/budget_screen.dart';
import 'package:budu/features/budget/screens/create_budget_screen.dart';
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
  Future<void> _loadBudgetFuture = Future.value();
  bool _hasBudgetLoadError = false;
  bool _nextMonthBudgetExists = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _loadBudget();
    _checkNextMonthBudget();
  }

  Future<void> _loadBudget() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    if (authProvider.user != null) {
      try {
        final now = DateTime.now();
        _loadBudgetFuture = budgetProvider.loadBudget(authProvider.user!.uid, now.year, now.month);
        await _loadBudgetFuture;
      } catch (e) {
        print('Error in _loadBudget: $e');
        setState(() {
          _hasBudgetLoadError = true;
        });
      }
    } else {
      _loadBudgetFuture = Future.error('Käyttäjä ei ole kirjautunut');
      setState(() {
        _hasBudgetLoadError = true;
      });
    }
  }

  Future<void> _checkNextMonthBudget() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    if (authProvider.user != null) {
      final now = DateTime.now();
      final nextMonthDate = DateTime(now.year, now.month + 1);
      final exists = await budgetProvider.budgetExists(
        authProvider.user!.uid,
        nextMonthDate.year,
        nextMonthDate.month,
      );
      setState(() {
        _nextMonthBudgetExists = exists;
      });
    }
  }

  Future<void> _retryLoadBudget() async {
    setState(() {
      _hasBudgetLoadError = false;
    });
    await _loadBudget();
  }

  final List<Widget> _screens = [
    const BudgetScreen(),
    const SummaryScreen(),
    const HistoryScreen(),
  ];

  void _onItemTapped(int index) async {
    if (index == 3) {
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

  Future<void> _createBudgetForNextMonth(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    if (authProvider.user == null) return;

    // Haetaan saatavilla olevat budjettikuukaudet
    final availableMonths = await budgetProvider.getAvailableBudgetMonths(authProvider.user!.uid);
    final now = DateTime.now();
    int targetYear = now.year;
    int targetMonth = now.month;

    // Tarkistetaan, onko budjettia jo kuluvalle kuulle
    final currentMonthExists = availableMonths.any((month) =>
        month['year'] == targetYear && month['month'] == targetMonth);

    if (!currentMonthExists) {
      // Jos budjettia ei ole kuluvalle kuulle, luodaan se
      targetYear = now.year;
      targetMonth = now.month;
    } else {
      // Jos budjetti on jo kuluvalle kuulle, luodaan budjetti seuraavalle kuulle
      final nextDate = DateTime(now.year, now.month + 1);
      targetYear = nextDate.year;
      targetMonth = nextDate.month;
    }

    // Haetaan viimeisin budjetti pohjaksi
    if (availableMonths.isNotEmpty) {
      await budgetProvider.loadBudget(
        authProvider.user!.uid,
        availableMonths.first['year']!,
        availableMonths.first['month']!,
      );
    }

    // Tarkistetaan, että budjetti on saatavilla
    final latestBudget = budgetProvider.budget;
    if (latestBudget != null) {
      // Ohjataan CreateBudgetScreen-näkymään
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateBudgetScreen(
            sourceBudget: latestBudget,
            newYear: targetYear,
            newMonth: targetMonth,
          ),
        ),
      ).then((_) => _checkNextMonthBudget());
    } else {
      // Jos budjettia ei ole, näytetään virhe tai ohjataan luomaan ensimmäinen budjetti
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Luo ensin budjetti kuluvalle kuulle!')),
      );
    }
  }

  void _handleMenuSelection(String value, BuildContext context) {
    if (value == 'add_event') {
      showDialog(
        context: context,
        builder: (context) => const AddEventDialog(),
      );
    } else if (value == 'create_budget') {
      _createBudgetForNextMonth(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BudgetProvider>(
      builder: (context, budgetProvider, child) {
        return FutureBuilder(
          future: _loadBudgetFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || _hasBudgetLoadError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Virhe budjetin latauksessa. Yritä uudelleen.'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _retryLoadBudget,
                      child: const Text('Yritä uudelleen'),
                    ),
                  ],
                ),
              );
            }

            return Scaffold(
              appBar: AppBar(
                automaticallyImplyLeading: false,
                title: const Text('Budu'),
                actions: [
                  if (budgetProvider.budget != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.menu, color: Colors.black),
                        onSelected: (value) => _handleMenuSelection(value, context),
                        position: PopupMenuPosition.under, // Laajenee ikonin alapuolelle
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'add_event',
                            child: Text(
                              'Lisää tapahtuma',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.black,
                                    fontSize: 14,
                                  ),
                            ),
                          ),
                          if (!_nextMonthBudgetExists) ...[
                            const PopupMenuDivider(height: 1),
                            PopupMenuItem(
                              value: 'create_budget',
                              child: Text(
                                'Luo budjetti seuraavalle kuulle',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.black,
                                      fontSize: 14,
                                    ),
                              ),
                            ),
                          ],
                        ],
                        color: Colors.white,
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
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
      },
    );
  }
}