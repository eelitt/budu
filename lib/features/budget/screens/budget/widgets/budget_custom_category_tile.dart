import 'package:flutter/material.dart';

/// Mukautettu laajennettava widget, joka näyttää otsikon ja laajennettavan sisällön.
/// Käyttää animaatiota laajentamiseen ja supistamiseen, ja tukee tilan hallintaa ulkoisen ValueNotifierin kautta.
class CustomExpansionTile extends StatefulWidget {
  final Widget title; // Otsikko, joka näytetään aina ja toimii laajennuspainikkeena
  final List<Widget> children; // Laajennettava sisältö, joka näytetään, kun kategoria on laajennettu
  final ValueNotifier<bool> isExpanded; // Seuraa, onko kategoria laajennettu vai supistettu
  final void Function(bool) onExpansionChanged; // Callback-funktio, jota kutsutaan, kun laajennustila muuttuu

  const CustomExpansionTile({
    super.key,
    required this.title,
    required this.children,
    required this.isExpanded,
    required this.onExpansionChanged,
  });

  @override
  State<CustomExpansionTile> createState() => _CustomExpansionTileState();
}

/// CustomExpansionTile:n tilallinen tila, joka hallinnoi laajennusanimaatiota ja tilan muutoksia.
class _CustomExpansionTileState extends State<CustomExpansionTile> {
  /// Vaihtaa laajennustilan (laajennettu/supistettu) ja kutsuu onExpansionChanged-callbackia.
  void _toggleExpanded() {
    widget.onExpansionChanged(!widget.isExpanded.value);
  }

  @override
  Widget build(BuildContext context) {
    // Kuuntelee isExpanded-muuttujaa ja päivittää käyttöliittymän, kun tila muuttuu
    return ValueListenableBuilder<bool>(
      valueListenable: widget.isExpanded,
      builder: (context, isExpanded, child) {
        return Column(
          children: [
            // Otsikkoalue, joka reagoi napautuksiin ja vaihtaa laajennustilan
            GestureDetector(
              onTap: _toggleExpanded, // Kutsutaan laajennustilan vaihtavaa funktiota napautettaessa
              behavior: HitTestBehavior.opaque, // Varmistaa, että koko alue on napautettavissa
              child: widget.title, // Näyttää annetun otsikon
            ),
            // Animoitu siirtymä laajennettavan sisällön näyttämiseen/piilottamiseen
            AnimatedCrossFade(
              firstChild: Container(), // Tyhjä widget, kun kategoria on supistettu
              secondChild: Column(
                children: widget.children, // Näyttää laajennettavan sisällön, kun kategoria on laajennettu
              ),
              crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst, // Määrittää animaation tilan
              duration: const Duration(milliseconds: 200), // Animaation kesto
            ),
          ],
        );
      },
    );
  }
}