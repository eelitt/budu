import 'package:budu/core/changelog.dart';
import 'package:budu/core/utils.dart';

import 'package:budu/features/mainscreen/services/main_screen_update_dialog_service.dart';
import 'package:budu/features/notification/providers/notification_provider.dart';
import 'package:budu/features/update/update_manager.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Developer-menu handlers for [MainScreenAppBar].
/// User-facing errors go through [showErrorSnackBar] (same util as actions service).
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
      if (context.mounted) {
        showErrorSnackBar(context, 'Changelogin näyttäminen epäonnistui: $e');
      }
    }
  }

  /// Tarkistaa päivitykset ja mahdollistaa päivitysdialogin testauksen kehittäjävalikosta.
  Future<void> checkForUpdate(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!context.mounted) return;
      final isDebugUpdate = prefs.getBool('debug_update_enabled') ?? false;

      if (isDebugUpdate) {
        final dialog = MainScreenUpdateDialogService();
        await dialog.checkForUpdateDialog(
          context,
          debugVersion: '99.9.9',
        );
      } else {
        final updateManager = UpdateManager();
        await updateManager.checkAndHandleUpdate(context);
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Päivitystarkistus epäonnistui: $e');
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
        showSnackBar(
          context,
          !isDebugUpdate
              ? 'Päivityksen testitila kytketty päälle'
              : 'Päivityksen testitila kytketty pois',
        );
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Testitilan kytkeminen epäonnistui: $e');
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

  /// Debug: upsert pending-invite banner via [NotificationProvider.syncPendingInvites].
  static void _showDummyInviteNotification(
    BuildContext context, {
    required int count,
  }) {
    Provider.of<NotificationProvider>(context, listen: false)
        .syncPendingInvites(count);
    showSnackBar(context, 'Debug: Kutsuilmoitus näytetty ($count kpl)');
  }
}
