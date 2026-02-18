import 'dart:async';
import 'package:budu/core/app_router/app_router.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/auth/providers/user_provider.dart';
import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:budu/features/budget/screens/budget/budget_screen.dart';
import 'package:budu/features/mainscreen/services/main_screen_actions_service.dart';
import 'package:budu/features/mainscreen/services/main_screen_budget_status_service.dart';
import 'package:budu/features/mainscreen/widgets/main_screen_app_bar.dart';
import 'package:budu/features/mainscreen/widgets/main_screen_bottom_nav_bar.dart';
import 'package:budu/features/notification/banner/notification_banner.dart';
import 'package:budu/features/notification/widgets/invite_notification_handler.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Pääsivu, joka näyttää budjetin, yhteenvedon ja historian navigointipalkin kautta.
/// Käsittelee budjettitilan tarkistuksen ja päivittää käyttöliittymän reaaliajassa.
class MainScreen extends StatefulWidget {
  final int initialIndex; // Alkuvalikon indeksi (budjetti, yhteenveto, historia)

  const MainScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

/// MainScreenin tilallinen tila, joka hallinnoi navigointipalkin valintaa ja budjettitilaa.
class _MainScreenState extends State<MainScreen> {
  late int _selectedIndex; // Navigointipalkin valittu indeksi
  bool _hasBudgetLoadError = false; // Onko budjetin latauksessa virhe
  final ValueNotifier<bool> _nextMonthBudgetExists = ValueNotifier<bool>(false); // Seuraavan kuukauden budjetin olemassaolo
  final MainScreenBudgetStatusService _budgetStatusService = MainScreenBudgetStatusService(); // Palvelu budjettitilan tarkistamiseen
  final MainScreenActionsService _mainScreenActions = MainScreenActionsService(); // Palvelu toimintovalikon käsittelyyn

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>(); // Avain sisäisen Navigatorin hallintaan
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>(); // Avain Scaffoldin hallintaan
    bool _hasLoadedInvitations = false;
  @override
  void initState() {
    super.initState();
    // Alustetaan navigointipalkin indeksi annetulla arvolla
    _selectedIndex = widget.initialIndex;
    print('MainScreen: initState - _selectedIndex asetettu arvoon $_selectedIndex');
    // Suoritetaan budjettitilan tarkistus build-vaiheen jälkeen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBudgetStatus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Haetaan AuthProvider, UserProvider ja BudgetProvider kontekstista
    final authProvider = Provider.of<AuthProvider>(context);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    // Varmistetaan, että UserProvider-tiedot on haettu, jos käyttäjä on autentikoitu
    if (authProvider.authState == AuthState.authenticated && authProvider.user != null && !_hasLoadedInvitations) {
      userProvider.fetchUserData(authProvider.user!.uid);

   // Defer load until after current build frame (safe from build-phase notify)
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final sharedProvider = Provider.of<SharedBudgetProvider>(context, listen: false);
        final userEmail = authProvider.user!.email!;
        
        // Optional: Log for debug
       // print('SharedBudgetProvider: Haetaan odottavat kutsut email:lle $userEmail');
        await sharedProvider.fetchSharedBudgets(authProvider.user!.uid);
        await sharedProvider.fetchPendingInvitations(userEmail);
      });
      _hasLoadedInvitations = true; // Varmistetaan, että kutsut haetaan vain kerran

    } else if (authProvider.authState == AuthState.unauthenticated && context.mounted) {
      // Lykätään navigointi login-sivulle build-vaiheen jälkeen, jos käyttäjä ei ole autentikoitu
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

  @override
  void dispose() {
    // Vapautetaan resurssit
    _nextMonthBudgetExists.dispose();
    super.dispose();
  }

  /// Yrittää ladata budjetin uudelleen, jos lataus epäonnistui.
  Future<void> _retryLoadBudget() async {
    if (mounted) {
      setState(() {
        _hasBudgetLoadError = false;
      });
    }
    await _checkBudgetStatus();
  }

  /// Tarkistaa budjetin tilan ja päivittää seuraavan kuukauden budjetin olemassaolon.
  Future<void> _checkBudgetStatus() async {
    print('MainScreen: _checkBudgetStatus - Aloitetaan budjettitilan tarkistus');
    try {
      await _budgetStatusService.checkBudgetStatus(
        context,
        (exists) {
          if (_nextMonthBudgetExists.value != exists) {
            print('MainScreen: _checkBudgetStatus - _nextMonthBudgetExists asetettu arvoon $exists');
            _nextMonthBudgetExists.value = exists;
          }
        },
        () => _mainScreenActions.createBudgetForNextMonth(
          context,
          () => _checkBudgetStatus(),
        ),
      );
    } catch (e) {
      print('MainScreen: _checkBudgetStatus - Virhe budjettitilan tarkistuksessa: $e');
    }
  }

  /// Käsittelee navigointipalkin valinnat ja päivittää näkymän.
  /// [index] on valittu indeksi navigointipalkista.
  void _onItemTapped(int index) async {
    if (_selectedIndex == index) return; // Vältetään turha navigointi, jos sama välilehti on jo valittuna

    setState(() {
      _selectedIndex = index;
    });
    // Määritetään reitti indeksin perusteella
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
    // Tarkistetaan budjettitila navigoinnin jälkeen
    await _checkBudgetStatus();
    if (mounted) {
      _navigatorKey.currentState?.pushReplacementNamed(routeName);
    }
  }

  /// Määrittää alkuvalikon reitin navigointipalkin indeksin perusteella.
  /// Palauttaa reitin nimen (esim. AppRouter.budgetRoute) indeksin perusteella.
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
    // Haetaan AuthProvider tarkistaaksemme käyttäjän autentikointitilan
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Jos käyttäjä ei ole autentikoitu, näytetään tyhjä widget ja odotetaan navigointia
    if (authProvider.authState != AuthState.authenticated || authProvider.user == null) {
      return const SizedBox.shrink();
    }

    // Haetaan käyttäjän etunimi näytettäväksi yläpalkissa
    final userFirstName = authProvider.user?.user!.displayName?.split(' ').first ?? '';

    return Scaffold(
      key: _scaffoldKey, // Avain Scaffoldin hallintaan
      appBar: MainScreenAppBar(
        userFirstName: userFirstName,
        nextMonthBudgetExists: _nextMonthBudgetExists.value,
        onMenuSelected: (value) => _mainScreenActions.handleMenuSelection(value, context),
      ),
      body: Column(
        children: [
          const NotificationBanner(), // Näyttää ilmoitusbannerin (esim. budjetin luomisen kehotukset)
          const InviteNotificationHandler(),
          Expanded(
            child: _hasBudgetLoadError
                ? Center(
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
                  )
                : Navigator(
                    key: _navigatorKey,
                    initialRoute: _getInitialRoute(),
                    onGenerateRoute: (settings) {
                      // Välitetään onBudgetDeleted-callback BudgetScreenille
                      if (settings.name == AppRouter.budgetRoute) {
                        return AppRouter.generateRoute(
                          RouteSettings(
                            name: settings.name,
                            arguments: BudgetScreen(
                              onBudgetDeleted: _checkBudgetStatus, // Välitetään callback
                            ),
                          ),
                        );
                      }
                      return AppRouter.generateRoute(settings);
                    },
                    onGenerateInitialRoutes: (NavigatorState navigator, String initialRoute) {
                      print('MainScreen: build - initialRoute asetettu: $initialRoute (index: $_selectedIndex)');
                      return [
                        AppRouter.generateRoute(
                          RouteSettings(
                            name: initialRoute,
                            arguments: initialRoute == AppRouter.budgetRoute
                                ? BudgetScreen(
                                    onBudgetDeleted: _checkBudgetStatus, // Välitetään callback
                                  )
                                : null,
                          ),
                        )!,
                      ];
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
              Color.fromARGB(255, 253, 228, 190), // Alareunan gradient-väri
              Color(0xFFFFFCF5), // Yläreunan gradient-väri
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