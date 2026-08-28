import 'dart:async';
import 'package:budu/core/app_router/app_router.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/auth/providers/user_provider.dart';
import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:budu/features/budget/screens/budget/budget_screen.dart';
import 'package:budu/features/budget/screens/summary/summary_screen.dart';
import 'package:budu/features/history/history_screen.dart';
import 'package:budu/features/mainscreen/services/main_screen_actions_service.dart';
import 'package:budu/features/mainscreen/services/main_screen_budget_status_service.dart';
import 'package:budu/features/mainscreen/widgets/main_screen_app_bar.dart';
import 'package:budu/features/mainscreen/widgets/main_screen_bottom_nav_bar.dart';
import 'package:budu/features/notification/banner/notification_banner.dart';
import 'package:budu/features/notification/widgets/invite_notification_handler.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Signed-in shell: app bar, banners, bottom nav, and tab bodies.
class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _selectedIndex;
  bool _nextMonthBudgetExists = false;
  final MainScreenBudgetStatusService _budgetStatusService =
      MainScreenBudgetStatusService();
  final MainScreenActionsService _mainScreenActions = MainScreenActionsService();
  bool _hasLoadedInvitations = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, 2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBudgetStatus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuthProvider>(context);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (authProvider.authState == AuthState.authenticated &&
        authProvider.user != null &&
        !_hasLoadedInvitations) {
      userProvider.fetchUserData(authProvider.user!.uid);

      // Defer load until after current build frame (safe from build-phase notify)
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final sharedProvider =
            Provider.of<SharedBudgetProvider>(context, listen: false);
        final userEmail = authProvider.user!.email;
        await sharedProvider.fetchSharedBudgets(authProvider.user!.uid);
        await sharedProvider.fetchPendingInvitations(userEmail);
      });
      _hasLoadedInvitations = true;
    } else if (authProvider.authState == AuthState.unauthenticated &&
        context.mounted) {
      // Shell owns login redirect (including after menu logout).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRouter.loginRoute,
            (route) => false,
          );
        }
      });
    }
  }

  Future<void> _checkBudgetStatus() async {
    try {
      await _budgetStatusService.checkBudgetStatus(
        context,
        (exists) {
          if (!mounted || _nextMonthBudgetExists == exists) return;
          setState(() {
            _nextMonthBudgetExists = exists;
          });
        },
      );
    } catch (_) {
      // Reminder refresh failures are non-fatal for the shell.
    }
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
    });
    // Reminder recheck must not block tab navigation.
    unawaited(_checkBudgetStatus());
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.authState != AuthState.authenticated ||
        authProvider.user == null) {
      return const SizedBox.shrink();
    }

    final userFirstName =
        authProvider.user?.user!.displayName?.split(' ').first ?? '';

    return Scaffold(
      appBar: MainScreenAppBar(
        userFirstName: userFirstName,
        nextMonthBudgetExists: _nextMonthBudgetExists,
        onMenuSelected: (value) => _mainScreenActions.handleMenuSelection(
          value,
          context,
          onStatusRefresh: _checkBudgetStatus,
        ),
      ),
      body: Column(
        children: [
          NotificationBanner(
            onReminderActionComplete: _checkBudgetStatus,
          ),
          const InviteNotificationHandler(),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                BudgetScreen(onBudgetDeleted: _checkBudgetStatus),
                SummaryScreen(isActive: _selectedIndex == 1),
                HistoryScreen(isActive: _selectedIndex == 2),
              ],
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
          selectedIndex: _selectedIndex,
          onItemTapped: _onItemTapped,
        ),
      ),
    );
  }
}
