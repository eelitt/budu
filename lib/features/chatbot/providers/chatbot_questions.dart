class ChatbotQuestions {
  final String? housingType;
  final String? carOwnership;
  final bool rentsParkingSpace;
  final bool hasTireService;
  final bool useAverageCarMaintenance;
  final bool hasPets;
  final bool hasOtherExpenses;
  final bool hasCarLoan;
  final bool hasOtherDebts;
  final Map<String, Map<String, double>> expenses;

  ChatbotQuestions({
    required this.housingType,
    required this.carOwnership,
    required this.rentsParkingSpace,
    required this.hasTireService,
    required this.useAverageCarMaintenance,
    required this.hasPets,
    required this.hasOtherExpenses,
    required this.hasCarLoan,
    required this.hasOtherDebts,
    required this.expenses,
  });

  List<String> getQuestions() {
    List<String> questions = [
      "Hei! Paljonko saat tuloja kuukaudessa (esim. palkka, tuet)?",
      "Asutko vuokralla, omakotitalossa vai ilman asuntokuluja?",
    ];

    if (housingType == "Vuokralla") {
      questions.addAll([
        "Paljonko maksat vuokraa kuukaudessa?",
        "Paljonko maksat vesimaksua kuukaudessa (jos sisältyy vuokraan, syötä 0)?",
        "Paljonko kotivakuutuksesi maksaa vuodessa?",
      ]);
    } else if (housingType == "Omakotitalossa") {
      questions.addAll([
        "Paljonko maksat asuntolainaa kuukaudessa? (jos ei lainaa, syötä 0)?",
        "Paljonko kiinteistöverosi on vuodessa?",
        "Paljonko maksat jätehuollosta kuukaudessa?",
        "Paljonko kotivakuutuksesi maksaa vuodessa?",
      ]);
    }

    questions.add("Onko sinulla autoa?");

    if (carOwnership == "Kyllä") {
      questions.add("Onko autosi oma vai maksatko siitä rahoitusta?");
      if (expenses.containsKey('Liikkuminen') && expenses['Liikkuminen']!.containsKey('Auton rahoitus')) {
        questions.add("Paljonko maksat Auton rahoitusta kuukaudessa?");
      }
      if (housingType == "Vuokralla") {
        questions.add("Vuokraatko autopaikkaa, esimerkiksi pihapaikkaa tai autotallia?");
      }
      if (rentsParkingSpace) {
        questions.add("Paljonko maksat autopaikan vuokraa kuukaudessa?");
      }
      questions.addAll([
        "Paljonko auton polttoainekulut ovat kuukaudessa?",
        "Paljonko auton vakuutukset maksavat vuodessa?",
        "Paljonko maksat ajoneuvoveroa vuodessa?",
        "Onko sinulla renkaiden vaihto- ja säilytyspalvelua?",
      ]);
      if (hasTireService) {
        questions.add("Paljonko maksat renkaiden vaihto- ja säilytyspalvelusta vuodessa?");
      }
      questions.add("Haluatko syöttää auton huolto- ja korjauskulut itse vai käyttää suomalaisten keskimääräisiä kuluja?");
      if (!useAverageCarMaintenance) {
        questions.add("Paljonko auton huolto- ja korjauskulut ovat vuodessa?");
      }
    }

    questions.addAll([
      "Paljonko sähkölaskusi on keskimäärin kuukaudessa?",
      "Onko sinulla kuukausimaksullisia palveluita, esimerkiksi Netflix tai Spotify?",
    ]);

    if (expenses.containsKey('Viihde') && expenses['Viihde']!.containsKey('Viihde-Palvelut')) {
      questions.add("Paljonko palveluihin menee rahaa kuukaudessa?");
    }

    questions.addAll([
      "Paljonko varaat ruokaan ja päivittäistavaroihin kuukaudessa?",
      "Paljonko käytät rahaa terveyteen liittyviin kuluihin kuukaudessa, esimerkiksi lääkärikäynteihin tai lääkkeisiin?",
      "Paljonko käytät rahaa hygieniaan liittyviin kuluihin kuukaudessa, esimerkiksi puhdistusaineisiin, WC-paperiin tai muihin vessassa ja keittiössä tarvittaviin kulutustuotteisiin?",
      "Paljonko käytät rahaa harrastuksiin kuukaudessa, esimerkiksi urheiluun, kulttuuriin tai peleihin?",
      "Onko sinulla lemmikkejä?",
    ]);

    if (hasPets) {
      questions.add("Paljonko lemmikeistä aiheutuu kuluja kuukaudessa, esimerkiksi ruokaan, tarvikkeisiin tai eläinlääkäriin?");
    }

    questions.addAll([
      "Paljonko maksat puhelinlaskua kuukaudessa?",
      "Paljonko maksat nettiliittymästä kuukaudessa?",
    ]);

    if (housingType == "Vuokralla") {
      if (carOwnership == "Kyllä" && hasCarLoan) {
        questions.add("Maksatko muita kuukausittaisia velkoja autorahoituksen lisäksi?");
      } else {
        questions.add("Maksatko kuukausittain velkoja, esimerkiksi osamaksuja?");
      }
    } else if (housingType == "Omakotitalossa") {
      if (expenses['Asuminen']?['Asuntolaina'] != null && expenses['Asuminen']!['Asuntolaina']! > 0) {
        if (carOwnership == "Kyllä" && hasCarLoan) {
          questions.add("Maksatko muita kuukausittaisia velkoja autorahoituksen lisäksi?");
        } else {
          questions.add("Maksatko kuukausittain omakotitalovelan lisäksi muita velkoja (Esim. osamaksuja)?");
        }
      } else {
        if (carOwnership == "Kyllä" && hasCarLoan) {
          questions.add("Maksatko muita kuukausittaisia velkoja autorahoituksen lisäksi?");
        } else {
          questions.add("Maksatko kuukausittain velkoja, esimerkiksi osamaksuja?");
        }
      }
    }

    if (hasOtherDebts) {
      questions.add("Paljonko maksat velkoja kuukausittain?");
    }

    questions.add("Paljonko varaat kuukausittain säästämiseen tai sijoittamiseen?");

    return questions;
  }
}