import 'package:flutter/material.dart';

/// Näyttää vahvistusdialogin budjetin menojen nollaamiselle.
/// Palauttaa true, jos käyttäjä vahvistaa nollauksen, muuten false.
Future<bool> showResetConfirmationDialog(BuildContext context) async {
  // Näytetään dialogi, jossa kysytään käyttäjältä vahvistusta menojen nollaamiseen
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white, // Dialogin taustaväri
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
        // Peruuta-painike, joka sulkee dialogin ja palauttaa false
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Peruuta',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        // Nollaa-painike, joka vahvistaa toiminnon ja palauttaa true
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
  // Palautetaan vahvistus (true/false), oletusarvoisesti false, jos dialogi suljetaan ilman valintaa
  return confirmed ?? false;
}

/// Näyttää vahvistusdialogin budjetin tai kategorian poistamiselle.
/// [isLastBudget] määrittää, onko kyseessä viimeinen budjetti, jolloin näytetään erilainen viesti.
/// [customMessage] mahdollistaa mukautetun viestin dialogissa.
/// [onDontShowAgainChanged] on callback, jota käytetään, jos "Älä näytä enää" -valinta on käytössä.
/// Palauttaa true, jos käyttäjä vahvistaa poiston, muuten false.
Future<bool> showDeleteConfirmationDialog({
  required BuildContext context,
  required bool isLastBudget,
  String? customMessage,
  Function(bool)? onDontShowAgainChanged,
}) async {
  bool dontShowAgain = false; // Seuraa, onko "Älä näytä enää" -valinta aktivoitu

  // Näytetään dialogi, jossa kysytään käyttäjältä vahvistusta poistolle
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white, // Dialogin taustaväri
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
            // Dialogin sisältö: mukautettu viesti tai oletusviesti riippuen isLastBudget-arvosta
            Text(
              customMessage ??
                  (isLastBudget
                      ? 'Haluatko varmasti poistaa tämän budjetin? Myös budjetin tulo- ja menotapahtumat poistetaan. Tämä on ainut budjettisi, joten sinut ohjataan luomaan uusi budjetti.'
                      : 'Haluatko varmasti poistaa tämän budjetin? Myös budjetin tulo- ja menotapahtumat poistetaan.'),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.black87,
                  ),
            ),
            const SizedBox(height: 8),
            // Näytetään "Älä näytä enää" -valinta, jos callback on annettu
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
        // Peruuta-painike, joka sulkee dialogin ja palauttaa false
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Peruuta',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        // Poista-painike, joka vahvistaa toiminnon ja palauttaa true
        ElevatedButton(
          onPressed: () {
            if (onDontShowAgainChanged != null) {
              onDontShowAgainChanged(dontShowAgain); // Ilmoitetaan "Älä näytä enää" -valinta
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
  // Palautetaan vahvistus (true/false), oletusarvoisesti false, jos dialogi suljetaan ilman valintaa
  return confirmed ?? false;
}