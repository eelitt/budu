import 'package:budu/features/auth/providers/user_provider.dart';
import 'package:budu/features/mainscreen/services/main_screen_update_dialog_service.dart';
import 'package:budu/features/update/services/update_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
// Admin debuggaukseen
  void _showChangelog(BuildContext context) async {
     final service = UpdateService();
     final dialog = MainScreenUpdateDialogService();
   
    dialog.checkForUpdateDialog(context, debugVersion: await service.getAppVersion());
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    return AppBar(
      automaticallyImplyLeading: false,
      title: const Text(
        'Budu',
        style: TextStyle(color: Colors.black),
      ),
      titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.black,
            fontSize: 20,
          ),
      actions: [
        // Kehittäjävalikko (näkyy vain, jos isAdmin on true)
        if (userProvider.isAdmin)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.developer_mode, color: Colors.black),
              onSelected: (value) {
                switch (value) {
                  case 'check_update':
                  //  MainScreenUpdateDialogService().checkForAppUpdate(context);
                    break;
                  case 'show_changelog':
                    _showChangelog(context);
                    break;
                }
              },
              position: PopupMenuPosition.under,
              color: Colors.white,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'check_update',
                  child: ListTile(
                    leading: const Icon(Icons.update, color: Colors.black),
                    title: Text(
                      'Tarkista päivitys',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black,
                            fontSize: 14,
                          ),
                    ),
                  ),
                ),
                const PopupMenuDivider(height: 1),
                PopupMenuItem(
                  value: 'show_changelog',
                  child: ListTile(
                    leading: const Icon(Icons.history, color: Colors.black),
                    title: Text(
                      'Näytä changelog',
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
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Center(
            child: Text(
              userFirstName,
              style: const TextStyle(color: Colors.black, fontSize: 14),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: PopupMenuButton<String>(
            icon: const Icon(Icons.menu, color: Colors.black),
            onSelected: onMenuSelected,
            position: PopupMenuPosition.under,
            color: Colors.white,
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
              Color.fromARGB(255, 253, 228, 190),
              Color(0xFFFFFCF5),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}