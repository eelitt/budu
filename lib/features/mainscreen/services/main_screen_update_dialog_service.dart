import 'package:budu/core/changelog.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainScreenUpdateDialogService {
  Future<void> checkForUpdateDialog(BuildContext context,{String? debugVersion}) async {
    String?  updatedVersion;
    bool shouldShowDialog = false;
    SharedPreferences? prefs;

    if (debugVersion != null) {
      // Debug-tila: Käytetään annettua debugVersion-arvoa
      updatedVersion = debugVersion;
      shouldShowDialog = true;
    } else {
      // Normaali tila: Tarkistetaan SharedPreferences
      prefs = await SharedPreferences.getInstance();
      final isUpdated = prefs.getBool('isUpdated') ?? false;
      updatedVersion = prefs.getString('updatedVersion');
      shouldShowDialog = isUpdated && updatedVersion != null;
    }

    if (shouldShowDialog) {
      try {
        final changes = await Changelog.fetchChanges(updatedVersion!);
        if (changes != null) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) {
              return AlertDialog(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                title: Text(
                  'Sovellus päivitetty versioon $updatedVersion',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                content: SingleChildScrollView(
                  child: Text(
                    changes,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () async {
                      if (prefs != null) {
                        await prefs.setBool('isUpdated', false);
                        await prefs.remove('updatedVersion');
                      }
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      }
    }
  }
}