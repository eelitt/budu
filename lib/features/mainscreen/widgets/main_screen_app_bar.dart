import 'package:flutter/material.dart';

class MainScreenAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String userFirstName;
  final bool nextMonthBudgetExists;
  final Function(String) onMenuSelected;

  const MainScreenAppBar({
    super.key,
    required this.userFirstName,
    required this.nextMonthBudgetExists,
    required this.onMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      title: const Text(
        'Budu',
        style: TextStyle(color: Colors.black), // Otsikon väri mustaksi
      ),
      titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.black, // Varmistetaan otsikon väri
            fontSize: 20,
          ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Center(
            child: Text(
              userFirstName,
              style: const TextStyle(color: Colors.black, fontSize: 14), // Käyttäjän nimi mustaksi
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: PopupMenuButton<String>(
            icon: const Icon(Icons.menu, color: Colors.black), // Valikon ikoni mustaksi
            onSelected: onMenuSelected,
            position: PopupMenuPosition.under,
            color: Colors.white, // Pudotusvalikon taustaväri valkoiseksi
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'add_event',
                child: ListTile(
                  leading: const Icon(Icons.add, color: Colors.black),
                  title: Text(
                    'Lisää tapahtuma',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black,
                          fontSize: 14,
                        ),
                  ),
                ),
              ),
              if (!nextMonthBudgetExists) ...[
                const PopupMenuDivider(height: 1),
                PopupMenuItem(
                  value: 'create_budget',
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today, color: Colors.black),
                    title: Text(
                      'Luo budjetti\nseuraavalle kuulle',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black,
                            fontSize: 14,
                          ),
                    ),
                  ),
                ),
              ],
              const PopupMenuDivider(height: 1),
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: const Icon(Icons.settings, color: Colors.black),
                  title: Text(
                    'Asetukset',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black,
                          fontSize: 14,
                        ),
                  ),
                ),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.black),
                  title: Text(
                    'Kirjaudu ulos',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black,
                          fontSize: 14,
                        ),
                  ),
                ),
              ),
            ],
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
               Color.fromARGB(255, 253, 228, 190), // Aloitetaan taustaväristä (ylhäältä)
              Color(0xFFFFFCF5), // Päättyy keskivaaleaan oranssiin (alhaalla)
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

           