import 'package:flutter/material.dart';

class UpdateDialog extends StatelessWidget {
  final String currentVersion;
  final String latestVersion;
  final String apkUrl;
  final Function(String, String) onUpdate;

  const UpdateDialog({
    super.key,
    required this.currentVersion,
    required this.latestVersion,
    required this.apkUrl,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Uusi versio saatavilla'),
      content: Text(
        'Nykyinen versio: $currentVersion\nUusi versio: $latestVersion\nHaluatko ladata päivityksen?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Ei'),
        ),
        TextButton(
          onPressed: () {
            onUpdate(apkUrl, latestVersion);
          },
          child: const Text('Kyllä'),
        ),
      ],
      backgroundColor: Colors.black.withValues(alpha: 0.8),
      titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
      contentTextStyle: const TextStyle(color: Colors.white70),
    );
  }
}