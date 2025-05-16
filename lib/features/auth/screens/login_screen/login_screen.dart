import 'package:budu/core/utils.dart';
import 'package:budu/features/auth/screens/login_screen/login_button.dart';
import 'package:budu/features/auth/screens/login_screen/update_dialog_wrapper.dart';
import 'package:budu/features/auth/screens/login_screen/update_handler.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final UpdateHandler _updateHandler;
  bool _isLoggingIn = false;

  @override
  void initState() {
    super.initState();
    _updateHandler = UpdateHandler();
    _checkForAppUpdate();
  }

  Future<void> _checkForAppUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    final updateDialogWrapper = UpdateDialogWrapper(
      updateHandler: _updateHandler,
      currentVersion: currentVersion,
    );
    final shouldUpdate = await updateDialogWrapper.show(context);

    if (shouldUpdate && _updateHandler.apkUrl != null && _updateHandler.latestVersion != null) {
      await _startDownload(_updateHandler.apkUrl!, _updateHandler.latestVersion!);
    }
  }

  Future<void> _startDownload(String apkUrl, String latestVersion) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StreamBuilder<Map<String, dynamic>>(
          stream: _updateHandler.startDownload(apkUrl, latestVersion),
          builder: (context, snapshot) {
            double progress = _updateHandler.downloadProgress;
            if (snapshot.hasData && snapshot.data!.containsKey('progress')) {
              progress = snapshot.data!['progress'] as double;
            }

            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Ladataan päivitystä...", style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: progress / 100),
                  const SizedBox(height: 8),
                  Text('${progress.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white)),
                ],
              ),
              backgroundColor: Colors.black87,
            );
          },
        );
      },
    );

    try {
      await for (var event in _updateHandler.startDownload(apkUrl, latestVersion)) {
        if (event.containsKey('result')) {
          final result = event['result'] as OpenResult;
          if (result.type != ResultType.done && result.message.contains("REQUEST_INSTALL_PACKAGES")) {
            await _updateHandler.requestInstallPermission(context, apkUrl, latestVersion);
            await _startDownload(apkUrl, latestVersion);
          }
        } else if (event.containsKey('error')) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) {
              return AlertDialog(
                title: const Text('Päivityksen lataaminen epäonnistui'),
                content: Text('Virhe: ${event['error']}\nHaluatko yrittää uudelleen?'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _startDownload(apkUrl, latestVersion);
                    },
                    child: const Text('Kyllä'),
                  ),
                ],
              );
            },
          );
        }
      }
    } finally {
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const SizedBox.shrink(),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'lib/assets/images/budgetLogo2.png',
                  width: 150,
                  height: 150,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Budu',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sisäänkirjautuminen',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
              ),
              const SizedBox(height: 32),
              LoginButton(
                isLoggingIn: _isLoggingIn,
                isUpdateRequired: _updateHandler.isUpdateRequired,
                isDownloading: _updateHandler.isDownloading,
                onLoginStart: () {
                  setState(() {
                    _isLoggingIn = true;
                  });
                },
                onLoginEnd: () {
                  setState(() {
                    _isLoggingIn = false;
                  });
                },
                onError: (context, error) {
                  showErrorSnackBar(context, error);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}