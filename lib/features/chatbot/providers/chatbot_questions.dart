class ChatbotQuestions {
  final String? budgetType; // monthly, biweekly
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
    required this.budgetType,
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
      "Haluatko luoda kuukausibudjetin vai 2 viikon budjetin?",
      "Paljonko saat tuloja ${budgetType == 'monthly' ? 'kuukaudessa' : '2 viikon jaksolla'} (esim. palkka, tuet, pääomatulot)?",
      "Mikä seuraavista kuvaa parhaiten asumistasi?",
    ];

    // Kysymykset asumistilanteen mukaan
    if (housingType == "Vuokra-asunto") {
      questions.addAll([
        "Paljonko maksat vuokraa ${budgetType == 'monthly' ? 'kuukaudessa' : '2 viikon jaksolla'}?",
        "Paljonko maksat vesimaksua ${budgetType == 'monthly' ? 'kuukaudessa' : '2 viikon jaksolla'} (jos sisältyy vuokraan, syötä 0)?",
        "Paljonko kotivakuutuksesi maksaa vuodessa?",
      ]);
    } else if (housingType == "Omistusasunto omakotitalossa") {
      questions.addAll([
        "Paljonko maksat asuntolainaa ${budgetType == 'monthly' ? 'kuukaudessa' : '2 viikon jaksolla'}? (jos ei lainaa, syötä 0)?",
        "Paljonko kiinteistöverosi on vuodessa?",
        "Paljonko maksat jätehuollosta (esim. roskien tyhjennys) ${budgetType == 'monthly' ? 'kuukaudessa' : '2 viikon jaksolla'}?",
        "Paljonko kotivakuutuksesi maksaa vuodessa?",
        "Paljonko maksat vesimaksua ${budgetType == 'monthly' ? 'kuukaudessa' : '2 viikon jaksolla'} (vesi + jätevesi)?",
      ]);
    } else if (housingType == "Omistusasunto kerros-/rivitalossa (esim. yhtiövastiketta maksava)") {
      questions.addAll([
        "Paljonko maksat yhtiövastiketta ${budgetType == 'monthly' ? 'kuukaudessa' : '2 viikon jaksolla'}?",
        "Paljonko maksat vesimaksua ${budgetType == 'monthly' ? 'kuukaudessa' : '2 viikon jaksolla'} (jos sisältyy vastikkeeseen, syötä 0)?",
        "Paljonko kotivakuutuksesi maksaa vuodessa?",
      ]);
    }

    // Yleiset laskut
    questions.addAll([
      "Paljonko maksat sähkölaskua ${budgetType == 'monthly' ? 'kuukaudessa' : '2 viikon jaksolla'}?",
      "Paljonko maksat puhelinlaskua ${budgetType == 'monthly' ? 'kuukaudessa' : '2 viikon jaksolla'}?",
      "Paljonko maksat nettiliittymästä ${budgetType == 'monthly' ? 'kuukaudessa' : '2 viikon jaksolla'} (syötä 0, jos ei ole nettiliittymää)?",
    ]);

    // Autokysymykset
    questions.add("Onko sinulla autoa?");
    if (carOwnership == "Kyllä") {
      questions.add("Onko autosi oma vai maksatko siitä rahoitusta?");
      if (hasCarLoan) {
        questions.add("Paljonko maksat auton rahoitusta ${budgetType == 'monthly' ? 'kuukaudessa' : '2 viikon jaksolla'}?");
      }
      if (housingType == "Vuokra-asunto") {
        questions.add("Vuokraatko autopaikkaa?");
        if (rentsParkingSpace) {
          questions.add("Paljonko maksat autopaikasta ${budgetType == 'monthly' ? 'kuukaudessa' : '2 viikon jaksolla'}?");
        }
      }
      questions.addAll([
        "Paljonko auton polttoainekulut ovat ${budgetType == 'monthly' ? 'kuukaudessa' : '2 viikon jaksolla'}?",
        "Paljonko auton vakuutukset maksavat vuodessa?",
        "Paljonko maksat käyttövoima- ja ajoneuvoveroa vuodessa?",
        "Paljonko maksat autosta muita kuluja vuodessa (esim. renkaiden säilytys, huolto, keskim. 600-1000 €/vuosi)?",
      ]);
    }

    // Ruoka
    questions.add("Paljonko varaat ruokaan ${budgetType == 'monthly' ? 'kuukaudessa' : '2 viikon jaksolla'}?");

    // Terveys
    questions.add("Paljonko käytät rahaa terveyteen liittyviin kuluihin ${budgetType == 'monthly' ? 'kuukaudessa' : '2 viikon jaksolla'} (lääkkeet, lääkärikäynnit)?");

    // Hygienia
    questions.add("Paljonko käytät rahaa hygieniaan liittyviin kuluihin ${budgetType == 'monthly' ? 'kuukaudessa' : '2 viikon jaksolla'} (kosmetiikka, siivous- ja wc-tarvikkeet)?");

    // Sijoittaminen ja säästäminen
    questions.addAll([
      "Paljonko varaat sijoittamiseen ${budgetType == 'monthly' ? 'kuukaudessa' : '2 viikon jaksolla'} (esim. osakkeet, rahastot, kryptovaluutat)?",
      "Paljonko varaat säästämiseen ${budgetType == 'monthly' ? 'kuukaudessa' : '2 viikon jaksolla'} (esim. pahan päivän kassa, lomareissut)?",
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
      questions.add("Paljonko maksat velkaa ${budgetType == 'monthly' ? 'kuukaudessa' : '2 viikon jaksolla'}?");
    }

    // Harrastukset
    questions.add("Paljonko varaat harrastuksiin ${budgetType == 'monthly' ? 'kuukaudessa' : '2 viikon jaksolla'} (esim. kuntosali, välineet, tapahtumat)?");

    // Viihde
    questions.addAll([
      "Paljonko käytät rahaa suoratoistopalveluihin ${budgetType == 'monthly' ? 'kuukaudessa' : '2 viikon jaksolla'} (esim. Spotify, Netflix)?",
      "Paljonko käytät rahaa muuhun viihteeseen ${budgetType == 'monthly' ? 'kuukaudessa' : '2 viikon jaksolla'} (esim. pelit, elokuvat, lehdet, konsertit)?",
    ]);

    // Lemmikit
    questions.add("Onko sinulla lemmikki/lemmikkejä?");
    if (hasPets) {
      questions.add("Paljonko varaat lemmikkikuluihin ${budgetType == 'monthly' ? 'kuukaudessa' : '2 viikon jaksolla'} (ruoka, tarvikkeet, lääkärikäynnit)?");
    }

    return questions;
  }
}