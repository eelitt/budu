import 'package:flutter/material.dart';

class MainScreenBottomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const MainScreenBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: const TextStyle(fontSize: 12),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.edit),
          label: 'Muokkaa budjettia',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart),
          label: 'Seuranta',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history),
          label: 'Historia',
        ),
      ],
      currentIndex: selectedIndex,
      onTap: onItemTapped,
    );
  }
}