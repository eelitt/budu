import 'package:shared_preferences/shared_preferences.dart';

/// Luokka, joka hallinnoi kategorian poiston vahvistusdialogin näyttämisen tilaa.
/// Tallentaa ja lataa tilan SharedPreferencesiin, jotta se säilyy sovelluksen uudelleenkäynnistyksen yli.
class DeleteDialogStateManager {
  /// Tarkistaa, näytetäänkö poiston vahvistusdialogi.
  /// Palauttaa true, jos dialogi näytetään, muuten false. Oletusarvo on true, jos arvoa ei ole tallennettu.
  Future<bool> shouldShowDeleteDialog() async {
    // Haetaan SharedPreferences-instanssi
    final prefs = await SharedPreferences.getInstance();
    // Ladataan tila avaimella 'showDeleteCategoryDialog', oletusarvo true
    return prefs.getBool('showDeleteCategoryDialog') ?? true;
  }

  /// Asettaa, näytetäänkö poiston vahvistusdialogi, ja tallentaa tilan SharedPreferencesiin.
  /// [show] määrittää, näytetäänkö dialogi (true) vai ei (false).
  Future<void> setShowDeleteDialog(bool show) async {
    // Haetaan SharedPreferences-instanssi
    final prefs = await SharedPreferences.getInstance();
    // Tallennetaan tila avaimella 'showDeleteCategoryDialog'
    await prefs.setBool('showDeleteCategoryDialog', show);
  }
}