import 'package:flutter/material.dart';

Future<bool> showResetConfirmationDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text(
        'Nollaa budjetin menot',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
      ),
      content: Text(
        'Haluatko varmasti nollata kaikki budjetin menot? Tämä asettaa kaikkien kategorioiden arvot nollaan.',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.black87,
            ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Peruuta',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            'Nollaa',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

Future<bool> showDeleteConfirmationDialog({
  required BuildContext context,
  required bool isLastBudget,
  String? customMessage,
  Function(bool)? onDontShowAgainChanged,
}) async {
  bool dontShowAgain = false;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text(
        customMessage != null ? 'Poista' : 'Poista budjetti',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              customMessage ??
                  (isLastBudget
                      ? 'Haluatko varmasti poistaa tämän budjetin? Tämä on ainut budjettisi, joten sinut ohjataan luomaan uusi budjetti.'
                      : 'Haluatko varmasti poistaa tämän budjetin? Näet seuraavan budjettisi poiston jälkeen.'),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.black87,
                  ),
            ),
            const SizedBox(height: 8),
            if (onDontShowAgainChanged != null)
              Row(
                children: [
                  Checkbox(
                    value: dontShowAgain,
                    onChanged: (value) {
                      dontShowAgain = value ?? false;
                      (context as Element).markNeedsBuild(); // Päivitetään dialogin tila
                    },
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Älä näytä enää',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.black87,
                        ),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Peruuta',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        ElevatedButton(
          onPressed: () {
            if (onDontShowAgainChanged != null) {
              onDontShowAgainChanged(dontShowAgain);
            }
            Navigator.pop(context, true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey[900],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontSize: 14,
                ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Poista'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}