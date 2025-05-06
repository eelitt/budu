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
      title: const Text('Budu'),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Center(child: Text(userFirstName)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: PopupMenuButton<String>(
            icon: const Icon(Icons.menu, color: Colors.black),
            onSelected: onMenuSelected,
            position: PopupMenuPosition.under,
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
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}