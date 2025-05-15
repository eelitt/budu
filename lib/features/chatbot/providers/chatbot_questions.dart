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
      "Paljonko saat tuloja kuukaudessa (esim. palkka, tuet, pääomatulot)?",
      "Mikä seuraavista kuvaa parhaiten asumistasi?",
    ];

    // Kysymykset asumistilanteen mukaan
    if (housingType == "Vuokra-asunto") {
      questions.addAll([
        "Paljonko maksat vuokraa kuukaudessa?",
        "Paljonko maksat vesimaksua kuukaudessa (jos sisältyy vuokraan, syötä 0)?",
        "Paljonko kotivakuutuksesi maksaa vuodessa?",
      ]);
    } else if (housingType == "Omistusasunto omakotitalossa") {
      questions.addAll([
        "Paljonko maksat asuntolainaa kuukaudessa? (jos ei lainaa, syötä 0)?",
        "Paljonko kiinteistöverosi on vuodessa?",
        "Paljonko maksat jätehuollosta (Roskien tyhjennys) kuukaudessa?",
        "Paljonko kotivakuutuksesi maksaa vuodessa?",
        "Paljonko maksat vesimaksua kuukaudessa (vesi + jätevesi)?",
      ]);
    } else if (housingType == "Omistusasunto kerros-/rivitalossa (esim. yhtiövastiketta maksava)") {
      questions.addAll([
        "Paljonko maksat yhtiövastiketta kuukaudessa?",
        "Paljonko maksat vesimaksua kuukaudessa (jos sisältyy vastikkeeseen, syötä 0)?",
        "Paljonko kotivakuutuksesi maksaa vuodessa?",
      ]);
    }

    // Yleiset laskut
    questions.addAll([
      "Paljonko maksat sähkölaskua kuukaudessa?",
      "Paljonko maksat puhelinlaskua kuukaudessa?",
      "Paljonko maksat nettiliittymästä kuukaudessa (Syötä 0, jos ei ole nettiliittymää)?",
    ]);

    // Autokysymykset
    questions.add("Onko sinulla autoa?");
    if (carOwnership == "Kyllä") {
      questions.add("Onko autosi oma vai maksatko siitä rahoitusta?");
      if (hasCarLoan) {
        questions.add("Paljonko maksat auton rahoitusta kuukaudessa?");
      }
      // Lisätään autopaikan vuokrauskysymys, jos asuu vuokralla
      if (housingType == "Vuokra-asunto") {
        questions.add("Vuokraatko autopaikkaa?");
        if (rentsParkingSpace) {
          questions.add("Paljonko maksat autopaikasta kuukaudessa?");
        }
      }
      questions.addAll([
        "Paljonko auton polttoainekulut ovat kuukaudessa?",
        "Paljonko auton vakuutukset maksavat vuodessa?",
        "Paljonko maksat käyttövoima- ja ajoneuvoveroa vuodessa?",
        "Paljonko maksat autosta muita kuluja vuodessa (Esim. Renkaiden säilytys, huolto (Suomessa huolto keskim. 600-1000€/vuosi))?",
      ]);
    }

    // Ruoka
    questions.add("Paljonko varaat ruokaan kuukaudessa?");

    // Terveys
    questions.add("Paljonko käytät rahaa terveyteen liittyviin kuluihin kuukaudessa (Lääkkeet, lääkärikäynnit)?");

    // Hygienia
    questions.add("Paljonko käytät rahaa hygieniaan liittyviin kuluihin kuukaudessa (Kosmetiikka, Siivous- ja wc-tarvikkeet)?");

    // Sijoittaminen ja säästäminen
    questions.addAll([
      "Paljonko varaat sijoittamiseen kuukaudessa (esim. osakkeet, rahastot, kryptovaluutat)?",
      "Paljonko varaat säästämiseen kuukaudessa (esim. pahanpäivän kassa, lomareissut)?",
    ]);

    // Velat
    if (housingType == "Omistusasunto omakotitalossa" || housingType == "Omistusasunto kerros-/rivitalossa (esim. yhtiövastiketta maksava)") {
      if (expenses['Asuminen']?['Asuntolaina'] != null && expenses['Asuminen']!['Asuntolaina']! > 0) {
        if (carOwnership == "Kyllä" && hasCarLoan) {
          questions.add("Maksatko muita kuukausittaisia velkoja autorahoituksen ja asuntolainan lisäksi?");
        } else {
          questions.add("Maksatko asuntolainan lisäksi muita velkoja?");
        }
      } else {
        if (carOwnership == "Kyllä" && hasCarLoan) {
          questions.add("Maksatko muita kuukausittaisia velkoja autorahoituksen lisäksi?");
        } else {
          questions.add("Onko sinulla velkoja?");
        }
      }
    } else if (housingType == "Vuokra-asunto") {
      if (carOwnership == "Kyllä" && hasCarLoan) {
        questions.add("Maksatko muita kuukausittaisia velkoja autorahoituksen lisäksi?");
      } else {
        questions.add("Onko sinulla velkoja?");
      }
    }
    if (hasOtherDebts) {
      questions.add("Paljonko maksat velkaa kuukaudessa?");
    }

    // Harrastukset
    questions.add("Paljonko varaat harrastuksiin kuukaudessa (esim. kuntosali, välineet, tapahtumat)?");

    // Viihde
    questions.addAll([
      "Paljonko käytät rahaa suoratoistopalveluihin kuukaudessa (esim. Spotify, Netflix)?",
      "Paljonko käytät rahaa muuhun viihteeseen kuukaudessa (esim. pelit, elokuvat, lehdet, konsertit)?",
    ]);

    // Lemmikit
    questions.add("Onko sinulla lemmikki/lemmikkejä?");
    if (hasPets) {
      questions.add("Paljonko varaat lemmikkikuluihin kuukaudessa (Ruoka, tarvikkeet, Lääkärikäynnit)?");
    }

    return questions;
  }
}