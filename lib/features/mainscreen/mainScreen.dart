import 'package:budu/core/app_router/app_router.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/mainscreen/services/main_screen_actions_service.dart';
import 'package:budu/features/mainscreen/services/main_screen_budget_status_service.dart';
import 'package:budu/features/mainscreen/services/main_screen_update_dialog_service.dart';
import 'package:budu/features/mainscreen/widgets/main_screen_app_bar.dart';
import 'package:budu/features/mainscreen/widgets/main_screen_bottom_nav_bar.dart';
import 'package:budu/features/notification/banner/notification_banner.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with RouteAware {
  late int _selectedIndex;
  bool _hasBudgetLoadError = false;
  bool _nextMonthBudgetExists = false;
  BudgetModel? _lastBudget;

  final MainScreenBudgetStatusService _budgetStatusService = MainScreenBudgetStatusService();
  final MainScreenUpdateDialogService _updateDialogService = MainScreenUpdateDialogService();
  final MainScreenActionsService _mainScreenActions = MainScreenActionsService();

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>(); // Lisätty ScaffoldKey

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    print('MainScreen: initState - _selectedIndex asetettu arvoon $_selectedIndex');
    _checkBudgetStatus();
    _updateDialogService.checkForUpdateDialog(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute? route = ModalRoute.of(context);
    if (route != null) {
      AppRouter.routeObserver.subscribe(this, route as PageRoute);
    }
  }

  @override
  void dispose() {
    AppRouter.routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    print('MainScreen: didPopNext - Päivitetaan budjetin tila');
    _checkBudgetStatus();
  }

  @override
  void didPush() {
    print('MainScreen: didPush - Päivitetaan budjetin tila');
    _checkBudgetStatus();
  }

  Future<void> _retryLoadBudget() async {
    if (mounted) {
      setState(() {
        _hasBudgetLoadError = false;
      });
    }
    await _checkBudgetStatus();
  }

  Future<void> _checkBudgetStatus() async {
    await _budgetStatusService.checkBudgetStatus(
      context,
      (exists) {
        if (mounted && _nextMonthBudgetExists != exists) {
          print('MainScreen: _checkBudgetStatus - _nextMonthBudgetExists asetettu arvoon $exists');
          setState(() => _nextMonthBudgetExists = exists);
        }
      },
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
    String routeName;
    switch (index) {
      case 0:
        routeName = AppRouter.budgetRoute;
        break;
      case 1:
        routeName = AppRouter.summaryRoute;
        break;
      case 2:
        routeName = AppRouter.historyRoute;
        break;
      default:
        routeName = AppRouter.budgetRoute;
    }
    print('MainScreen: _onItemTapped - Navigoidaan reittiin: $routeName (index: $index)');
    await _checkBudgetStatus();
    if (mounted) {
      _navigatorKey.currentState?.pushReplacementNamed(routeName);
    }
  }

  String _getInitialRoute() {
    switch (_selectedIndex) {
      case 0:
        return AppRouter.budgetRoute;
      case 1:
        return AppRouter.summaryRoute;
      case 2:
        return AppRouter.historyRoute;
      default:
        return AppRouter.budgetRoute;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userFirstName = authProvider.user?.user!.displayName?.split(' ').first ?? '';

    return Scaffold(
      key: _scaffoldKey, // Lisätty ScaffoldKey
      appBar: MainScreenAppBar(
        userFirstName: userFirstName,
        nextMonthBudgetExists: _nextMonthBudgetExists,
        onMenuSelected: (value) => _mainScreenActions.handleMenuSelection(value, context),
      ),
      body: Column(
        children: [
          const NotificationBanner(),
          Expanded(
            child: Consumer<BudgetProvider>(
              builder: (context, budgetProvider, child) {
                if (budgetProvider.budget != _lastBudget) {
                  _lastBudget = budgetProvider.budget;
                  _checkBudgetStatus();
                }

                if (_hasBudgetLoadError) {
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

                final initialRoute = _getInitialRoute();
                print('MainScreen: build - initialRoute asetettu: $initialRoute (index: $_selectedIndex)');

                return Navigator(
                  key: _navigatorKey,
                  initialRoute: initialRoute,
                  onGenerateRoute: AppRouter.generateRoute,
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Color.fromARGB(255, 253, 228, 190),
              Color(0xFFFFFCF5),
            ],
          ),
        ),
        child: MainScreenBottomNavigationBar(
          selectedIndex: _selectedIndex < 3 ? _selectedIndex : 0,
          onItemTapped: _onItemTapped,
        ),
      ),
    );
  }
}