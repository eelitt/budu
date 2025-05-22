import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Luokka, joka hallinnoi budjettikategorian laajennustilaa (laajennettu/supistettu).
/// Tallentaa ja lataa tilan SharedPreferencesiin, jotta se säilyy sovelluksen uudelleenkäynnistyksen yli.
class ExpansionStateManager {
  final String categoryName; // Kategorian nimi, jota laajennustila koskee
  final ValueNotifier<bool> isExpanded; // Seuraa, onko kategoria laajennettu vai supistettu

  ExpansionStateManager({
    required this.categoryName,
    required this.isExpanded,
  });

  /// Lataa kategorian laajennustilan SharedPreferencesistä.
  /// Asettaa oletusarvon false, jos tilaa ei ole tallennettu.
  Future<void> loadExpansionState() async {
    // Haetaan SharedPreferences-instanssi
    final prefs = await SharedPreferences.getInstance();
    // Ladataan laajennustila kategorian nimellä avaimena
    final isExpanded = prefs.getBool('expansion_$categoryName') ?? false;

    // Päivitetään ValueNotifier laajennustilan arvolla
    this.isExpanded.value = isExpanded;
  }

  /// Tallentaa kategorian laajennustilan SharedPreferencesiin ja päivittää tilan.
  /// [expanded] määrittää, onko kategoria laajennettu vai supistettu.
  /// [isManual] määrittää, tallennetaanko tila SharedPreferencesiin (true = manuaalinen muutos).
  Future<void> saveExpansionState(bool expanded, {bool isManual = true}) async {
    // Tallennetaan tila SharedPreferencesiin vain, jos muutos on manuaalinen
    if (isManual) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('expansion_$categoryName', expanded);
    }
    // Päivitetään ValueNotifier laajennustilan arvolla
    isExpanded.value = expanded;
  }

  /// Laajentaa kategorian ohjelmallisesti asettamalla tilan laajennetuksi.
  /// Ei tallenna tilaa SharedPreferencesiin, koska muutos ei ole manuaalinen.
  void expandProgrammatically() {
    isExpanded.value = true;
  }
}