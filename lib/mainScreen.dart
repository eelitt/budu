import 'package:budu/add_event_dialog.dart';
import 'package:budu/core/app_router.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/screens/budget/budget_screen.dart';
import 'package:budu/features/budget/screens/summary/summary_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  final List<Widget> _screens = [
    const BudgetScreen(),  // Indeksi 0: Muokkaa budjettia
    const SummaryScreen(), // Indeksi 1: Yhteenveto
  ];

  void _onItemTapped(int index) async {
    if (index == 2) { // Uloskirjautuminen (indeksi 2)
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
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Budu'),
        actions: [
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
      body: _selectedIndex < 2 ? _screens[_selectedIndex] : const SizedBox.shrink(), // Estetään näyttämästä tyhjää sivua uloskirjautumiselle
      bottomNavigationBar: BottomNavigationBar(
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
            icon: Icon(Icons.logout),
            label: 'Kirjaudu ulos', // Uusi välilehti uloskirjautumiselle
          ),
        ],
        currentIndex: _selectedIndex < 2 ? _selectedIndex : 0, // Varmistetaan, että indeksi on validi
        onTap: _onItemTapped,
      ),
    );
  }
}