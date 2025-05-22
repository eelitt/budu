import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';

class UserProvider with ChangeNotifier {
  // Käyttäjän yksilöllinen tunniste (UID)
  String? _userId;
  // Onko käyttäjä admin (esim. kehittäjävalikon näyttämistä varten)
  bool _isAdmin = false;
  // Onko käyttäjä premium-tilaaja
  bool _isPremium = false;
  // Yhteistalousbudjetin tunniste (käytetään tulevaisuudessa yhteistalousominaisuutta varten)
  String? _sharedBudgetId;

  // Getterit muuttujille
  String? get userId => _userId;
  bool get isAdmin => _isAdmin;
  bool get isPremium => _isPremium;
  String? get sharedBudgetId => _sharedBudgetId;

  /// Hakee käyttäjän profiilitiedot Firestoresta annetulla userId:llä.
  /// Asettaa _isAdmin, _isPremium ja _sharedBudgetId arvot Firestore-dokumentin perusteella.
  /// Jos dokumenttia ei ole olemassa, asettaa oletusarvot (false/null).
  Future<void> fetchUserData(String userId) async {
    _userId = userId;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        _isAdmin = userDoc.data()?['isAdmin'] ?? false;
        _isPremium = userDoc.data()?['isPremium'] ?? false;
        _sharedBudgetId = userDoc.data()?['sharedBudgetId'];
      } else {
        // Dokumenttia ei löydy, asetetaan oletusarvot
        _isAdmin = false;
        _isPremium = false;
        _sharedBudgetId = null;
      }
      notifyListeners();
    } catch (e) {
      // Raportoidaan virhe Crashlyticsiin
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to fetch user data from Firestore',
      );

      // Tunnistetaan virhetyyppi ja lisätään kontekstia
      if (e is FirebaseException) {
        await FirebaseCrashlytics.instance.setCustomKey('error_code', e.code);
        await FirebaseCrashlytics.instance.setCustomKey('error_message', e.message ?? 'Unknown Firestore error');
      }
      // Asetetaan oletusarvot virheen sattuessa
      _isAdmin = false;
      _isPremium = false;
      _sharedBudgetId = null;

    }
  }

  /// Päivittää käyttäjän profiilitiedot Firestoreen annetulla userId:llä ja datalla.
  /// Käyttää merge-optiota, jotta olemassa olevia kenttiä ei ylikirjoiteta.
  /// Päivittää tiedot kutsumalla fetchUserData-metodia.
  Future<void> updateUserData(String userId, Map<String, dynamic> data) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set(data, SetOptions(merge: true));

      await fetchUserData(userId); // Päivitä tiedot Firestoresta
    } catch (e) {
      // Raportoidaan virhe Crashlyticsiin
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to update user data in Firestore',
      );

      // Tunnistetaan virhetyyppi ja lisätään kontekstia
      if (e is FirebaseException) {
        await FirebaseCrashlytics.instance.setCustomKey('error_code', e.code);
        await FirebaseCrashlytics.instance.setCustomKey('error_message', e.message ?? 'Unknown Firestore error');
      }

      // Heitetään virhe kutsujalle, jotta se voidaan käsitellä
      throw e;
    }
  }

  /// Nollaa kaikki käyttäjän profiilitiedot.
  /// Käytetään esimerkiksi uloskirjautumisen yhteydessä.
  void clearUserData() {
    _userId = null;
    _isAdmin = false;
    _isPremium = false;
    _sharedBudgetId = null;
    notifyListeners();
  }
}