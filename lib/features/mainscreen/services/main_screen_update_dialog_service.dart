// mainscreen/services/main_screen_update_dialog_service.dart
import 'package:budu/core/changelog.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainScreenUpdateDialogService {
  Future<void> checkForUpdateDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final isUpdated = prefs.getBool('isUpdated') ?? false;
    final updatedVersion = prefs.getString('updatedVersion');

    if (isUpdated && updatedVersion != null) {
      try {
        final changes = await Changelog.fetchChanges(updatedVersion);
        if (changes != null) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) {
              return AlertDialog(
                title: Text('Sovellus päivitetty versioon $updatedVersion'),
                content: SingleChildScrollView(
                  child: Text(changes),
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      await prefs.setBool('isUpdated', false);
                      await prefs.remove('updatedVersion');
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