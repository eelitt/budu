import 'package:flutter/material.dart';
import '../services/update_service.dart';

class UpdateDialog extends StatelessWidget {
  final UpdateService updateService;
  final String currentVersion;
  final String latestVersion;
  final String apkUrl;
  final BuildContext scaffoldContext;

  const UpdateDialog({
    super.key,
    required this.updateService,
    required this.currentVersion,
    required this.latestVersion,
    required this.apkUrl,
    required this.scaffoldContext,
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
          onPressed: () async {
            Navigator.pop(context);
            await updateService.downloadAndOpenApk(scaffoldContext, apkUrl, latestVersion);
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