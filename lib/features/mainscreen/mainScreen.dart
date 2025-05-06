// mainscreen/main_screen.dart
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/screens/budget/budget_screen.dart';
import 'package:budu/features/budget/screens/summary/summary_screen.dart';
import 'package:budu/features/history/history_screen.dart';
import 'package:budu/features/mainscreen/services/main_screen_actions_service.dart';
import 'package:budu/features/mainscreen/services/main_screen_budget_service.dart';
import 'package:budu/features/mainscreen/services/main_screen_budget_status_service.dart';
import 'package:budu/features/mainscreen/services/main_screen_update_dialog_service.dart';
import 'package:budu/features/mainscreen/widgets/main_screen_app_bar.dart';
import 'package:budu/features/mainscreen/widgets/main_screen_bottom_nav_bar.dart';
import 'package:budu/features/notification/banner/notification_banner.dart';
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

  // Palvelut
  final MainScreenBudgetService _budgetService = MainScreenBudgetService();
  final MainScreenBudgetStatusService _budgetStatusService = MainScreenBudgetStatusService();
  final MainScreenUpdateDialogService _updateDialogService = MainScreenUpdateDialogService();
  final MainScreenActionsService _mainScreenActions = MainScreenActionsService();

  final List<Widget> _screens = [
    const BudgetScreen(),
    const SummaryScreen(),
    const HistoryScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _loadBudget();
    _checkBudgetStatus();
    _updateDialogService.checkForUpdateDialog(context);
  }

  Future<void> _loadBudget() async {
    try {
      _loadBudgetFuture = _budgetService.loadBudget(context);
      await _loadBudgetFuture;
    } catch (e) {
      setState(() {
        _hasBudgetLoadError = true;
      });
    }
  }

  Future<void> _retryLoadBudget() async {
    setState(() {
      _hasBudgetLoadError = false;
    });
    await _loadBudget();
    await _checkBudgetStatus();
  }

  Future<void> _checkBudgetStatus() async {
    await _budgetStatusService.checkBudgetStatus(
      context,
      (exists) => setState(() => _nextMonthBudgetExists = exists),
      () => _mainScreenActions.createBudgetForNextMonth(
        context,
        () => _checkBudgetStatus(),
      ),
    );
  }

  void _onItemTapped(int index) async {
    setState(() {
      _selectedIndex = index;
    });
    await _checkBudgetStatus();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userFirstName = authProvider.user?.user!.displayName?.split(' ').first ?? '';

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
              appBar: MainScreenAppBar(
                userFirstName: userFirstName,
                nextMonthBudgetExists: _nextMonthBudgetExists,
                onMenuSelected: (value) => _mainScreenActions.handleMenuSelection(value, context),
              ),
              body: Column(
                children: [
                  const NotificationBanner(),
                  Expanded(
                    child: _selectedIndex < _screens.length
                        ? _screens[_selectedIndex]
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
              bottomNavigationBar: MainScreenBottomNavigationBar(
                selectedIndex: _selectedIndex < _screens.length ? _selectedIndex : 0,
                onItemTapped: _onItemTapped,
              ),
            );
          },
        );
      },
    );
  }
}