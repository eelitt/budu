import 'package:budu/core/changelog.dart';
import 'package:budu/core/utils.dart';
import 'package:budu/features/budget/screens/create_budget/shared_budget/invitation_dialog.dart';
import 'package:budu/features/budget/screens/create_budget/shared_budget/pending_invites_dialog.dart';
import 'package:budu/features/mainscreen/services/main_screen_update_dialog_service.dart';
import 'package:budu/features/notification/models/notification_message.dart';
import 'package:budu/features/notification/providers/notification_provider.dart';
import 'package:budu/features/update/update_manager.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kapseloi kehittäjävalikon debug-toiminnot MainScreenAppBar:lle.
/// Sisältää metodit päivitystarkistukseen, testitilan kytkemiseen ja changelogin näyttämiseen.
class AppBarDebug {
  /// Näyttää sovelluksen changelogin kehittäjävalikosta (simuloitu dialogi).
  Future<void> showChangelog(BuildContext context) async {
    try {

       final packageInfo = await PackageInfo.fromPlatform();
      final changelog = await Changelog.fetchChanges(packageInfo.version);

       if (context.mounted && changelog != null) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              title: Text(
                'Sovellus päivitetty versioon ${packageInfo.version}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              content: SingleChildScrollView(
                child: Text(
                 changelog,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      
      // Näytä ystävällinen virheilmoitus käyttäjälle
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Changelogin näyttäminen epäonnistui: $e')),
        );
      }
    }
  }

  /// Tarkistaa päivitykset ja mahdollistaa päivitysdialogin testauksen kehittäjävalikosta.
  Future<void> checkForUpdate(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDebugUpdate = prefs.getBool('debug_update_enabled') ?? false;

      if (isDebugUpdate) {
        // Debug-tila: Simuloi päivitysdialogi
        final dialog = MainScreenUpdateDialogService();
        await dialog.checkForUpdateDialog(
          context,
          debugVersion: '99.9.9', // Simuloitu "uusin versio"
        );
      } else {
        // Normaali päivitystarkistus UpdateManager:illa
        final updateManager = UpdateManager();
        await updateManager.checkAndHandleUpdate(context);
      }
    } catch (e) {
      
      // Näytä ystävällinen virheilmoitus käyttäjälle
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Päivitystarkistus epäonnistui: $e')),
        );
      }
    }
  }

  /// Kytkee päivityksen testitilan päälle/pois kehittäjävalikosta.
  Future<void> toggleDebugUpdate(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDebugUpdate = prefs.getBool('debug_update_enabled') ?? false;
      await prefs.setBool('debug_update_enabled', !isDebugUpdate);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !isDebugUpdate
                  ? 'Päivityksen testitila kytketty päälle'
                  : 'Päivityksen testitila kytketty pois',
            ),
          ),
        );
      }
    } catch (e) {
  
      // Näytä ystävällinen virheilmoitus käyttäjälle
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Testitilan kytkeminen epäonnistui: $e')),
        );
      }
    }
  }

  /// Debug: Simuloi yhden odottavan kutsun (näyttää Hyväksy/Hylkää-painikkeet)
  static void testSingleInviteNotification(BuildContext context) {
    _showDummyInviteNotification(context, count: 1);
  }

  /// Debug: Simuloi useita odottavia kutsuja (näyttää lukumäärä + Näytä kaikki)
  static void testMultipleInviteNotifications(BuildContext context) {
    _showDummyInviteNotification(context, count: 2);
  }

  /// Yhteinen apumetodi dummy-kutsuilmoituksen näyttämiseen
  /// (transient → ei tallenneta Firestoreen, katoaa sulkiessa)
  static void _showDummyInviteNotification(
    BuildContext context, {
    required int count,
  }) {
    final notificationProvider =
        Provider.of<NotificationProvider>(context, listen: false);

    // Poistetaan mahdollinen vanha dummy (estää duplikaatit)
    notificationProvider.removeTransientNotificationById('debug_pending_invites');

    late final String message;
    VoidCallback? primaryAction;
    String? primaryText;
    VoidCallback? secondaryAction;
    String? secondaryText;

    if (count == 1) {
      message = 'Uusi kutsu yhteistalousbudjettiin';

      primaryText = 'Hyväksy';
      primaryAction = () {
        showSnackBar(context, 'DEBUG: Kutsu hyväksytty (dummy)', backgroundColor: Colors.green);
      };

      secondaryText = 'Hylkää';
      secondaryAction = () {
        showSnackBar(context, 'DEBUG: Kutsu hylätty (dummy)');
      };
    } else {
      message = 'Sinulla on $count odottavaa kutsua';
      primaryText = 'Näytä kaikki';
      primaryAction = () {
        showDialog(
          context: context,
          builder: (_) => const PendingInvitesDialog(),
        );
      };
    }

    notificationProvider.showTransientNotification(
      NotificationMessage(
        message: message,
        type: NotificationType.warning,
        notificationId: 'debug_pending_invites', // Yksilöivä ID debug-testaukseen
        actionText: primaryText,
        onAction: primaryAction,
        secondaryActionText: secondaryText,
        onSecondaryAction: secondaryAction,
        isTransient: true,
      ),
    );

    showSnackBar(context, 'Debug: Kutsuilmoitus näytetty ($count kpl)');
  }

  // ... existing _showDebugMenu method – add new entries below ...

  /// Näyttää debug-valikon (pitkä painallus AppBarissa tai muu triggeri)
  static void showDebugMenu(BuildContext context) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(100, 80, 16, 0), // Säädä sijaintia tarvittaessa
      items: [
        // ... existing items (Update check, Toggle debug update, Changelog, etc.) ...

        const PopupMenuItem(
          value: 'test_single_invite',
          child: Text('Test Invite Notification (Single)'),
        ),
        const PopupMenuItem(
          value: 'test_multiple_invites',
          child: Text('Test Invite Notification (Multiple)'),
        ),

        // ... other existing items ...
      ],
    ).then((value) {
      if (value == null) return;

      switch (value) {
        // ... existing cases ...

        case 'test_single_invite':
          testSingleInviteNotification(context);
          break;
        case 'test_multiple_invites':
          testMultipleInviteNotifications(context);
          break;
      }
    });
  }
}