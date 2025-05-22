import 'package:budu/core/changelog.dart';
import 'package:budu/features/mainscreen/services/main_screen_update_dialog_service.dart';
import 'package:budu/features/update/update_manager.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
}