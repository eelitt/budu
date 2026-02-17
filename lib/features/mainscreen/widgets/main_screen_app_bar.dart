import 'package:budu/features/auth/providers/user_provider.dart';
import 'package:budu/features/mainscreen/widgets/app_bar_debug.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Sovelluksen yläpalkki, joka näyttää sovelluksen nimen, käyttäjän nimen ja
/// toimintovalikon (lisää tapahtuma, luo budjetti, luo yhteistalousbudjetti, asetukset, uloskirjautuminen).
/// Näyttää kehittäjävalikon, jos käyttäjä on admin.
class MainScreenAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String userFirstName; // Käyttäjän etunimi näytettäväksi
  final bool nextMonthBudgetExists; // Onko seuraavan ajanjakson budjetti olemassa
  final Function(String) onMenuSelected; // Toimintovalikon valintakäsittelijä

  const MainScreenAppBar({
    super.key,
    required this.userFirstName,
    required this.nextMonthBudgetExists,
    required this.onMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final appBarDebug = AppBarDebug();

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
        if (userProvider.isAdmin)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.developer_mode, color: Colors.black),
              onSelected: (value) async {
                switch (value) {
                  case 'check_update':
                    await appBarDebug.checkForUpdate(context);
                    break;
                  case 'toggle_debug_update':
                    await appBarDebug.toggleDebugUpdate(context);
                    break;
                  case 'show_changelog':
                    await appBarDebug.showChangelog(context);
                    break;
                    case 'test_single_invite':
          AppBarDebug.testSingleInviteNotification(context);
          break;
        case 'test_multiple_invites':
          AppBarDebug.testMultipleInviteNotifications(context);
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
                PopupMenuItem(
                  value: 'toggle_debug_update',
                  child: ListTile(
                    leading: const Icon(Icons.bug_report, color: Colors.black),
                    title: Text(
                      'Kytke testitila päälle/pois',
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
                 const PopupMenuDivider(height: 1),
                 PopupMenuItem(
                  value: 'test_single_invite',
                  child: ListTile(
                    leading: const Icon(Icons.mail, color: Colors.black),
                    title: Text(
                      'Test Invite Notification (Single)', 
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black,
                            fontSize: 14,),
                          ),
                          ),
                          ),
                  const PopupMenuDivider(height: 1),
                  PopupMenuItem(
                  value: 'test_multiple_invites',
                  child: ListTile(
                    leading: const Icon(Icons.email, color: Colors.black),
                    title: Text(
                      'Test Invite Notification (Multiple)', 
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black,
                            fontSize: 14,),
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
                      'Luo uusi budjetti',
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
                value: 'create_shared_budget',
                child: ListTile(
                  leading: const Icon(Icons.group, color: Colors.black),
                  title: Text(
                    'Luo yhteistalousbudjetti',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black,
                          fontSize: 14,
                        ),
                  ),
                ),
              ),
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