import 'package:flutter/material.dart';

/// Google sign-in button. Starts login via [onLoginRequested]; does not navigate.
class LoginButton extends StatelessWidget {
  final bool isLoggingIn;
  final bool isUpdateRequired;
  final bool isDownloading;
  final VoidCallback onLoginRequested;

  const LoginButton({
    super.key,
    required this.isLoggingIn,
    required this.isUpdateRequired,
    required this.isDownloading,
    required this.onLoginRequested,
  });

  @override
  Widget build(BuildContext context) {
    return isLoggingIn
        ? Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).primaryColor,
            ),
          )
        : ElevatedButton.icon(
            onPressed: isUpdateRequired || isDownloading
                ? null
                : onLoginRequested,
            icon: Icon(
              Icons.g_mobiledata,
              size: 24,
              color: Theme.of(context)
                  .elevatedButtonTheme
                  .style
                  ?.foregroundColor
                  ?.resolve({}),
            ),
            label: Text(
              'Kirjaudu Googlella',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 16,
                    color: Theme.of(context)
                        .elevatedButtonTheme
                        .style
                        ?.foregroundColor
                        ?.resolve({}),
                  ),
            ),
            style: Theme.of(context).elevatedButtonTheme.style?.copyWith(
                  minimumSize: WidgetStateProperty.all(const Size(250, 48)),
                ),
          );
  }
}
