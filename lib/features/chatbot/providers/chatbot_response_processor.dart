class ChatbotResponseProcessor {
  final List<String> questions;
  final Map<String, Map<String, double>> expenses;
  double income;
  String? housingType;
  String? carOwnership;
  bool rentsParkingSpace;
  bool hasTireService;
  bool useAverageCarMaintenance;
  bool hasPets;
  bool hasOtherExpenses;
  bool hasCarLoan;
  bool hasOtherDebts;
  double debtAmount;

  ChatbotResponseProcessor({
    required this.questions,
    required this.expenses,
    required this.income,
    required this.housingType,
    required this.carOwnership,
    required this.rentsParkingSpace,
    required this.hasTireService,
    required this.useAverageCarMaintenance,
    required this.hasPets,
    required this.hasOtherExpenses,
    required this.hasCarLoan,
    required this.hasOtherDebts,
    required this.debtAmount,
  });

  void processResponse(String response, int step) {
    double? value = double.tryParse(response.replaceAll('€', '').trim());
    switch (questions[step]) {
      case "Paljonko saat tuloja kuukaudessa (esim. palkka, tuet, pääomatulot)?":
        income = value ?? 0.0;
        break;
      case "Mikä seuraavista kuvaa parhaiten asumistasi?":
        housingType = response;
        if (response != "Asun ilman asuntokuluja (esim. vanhempien luona tai ilmaiseksi)") {
          expenses['Asuminen'] = {};
          expenses['Vakuutukset'] = {'Kotivakuutus': 0.0};
        }
        break;
      case "Paljonko maksat vuokraa kuukaudessa?":
        if (expenses.containsKey('Asuminen')) expenses['Asuminen']!['Vuokra'] = value ?? 0.0;
        break;
      case "Paljonko maksat vesimaksua kuukaudessa (jos sisältyy vuokraan, syötä 0)?": // Vuokra-asunto
      case "Paljonko maksat vesimaksua kuukaudessa (vesi + jätevesi)?": // Omakotitalo
      case "Paljonko maksat vesimaksua kuukaudessa (jos sisältyy vastikkeeseen, syötä 0)?": // Kerrostalo/rivitalo
        expenses['Laskut ja palvelut'] = expenses['Laskut ja palvelut'] ?? {};
        expenses['Laskut ja palvelut']!['Vesi'] = value ?? 0.0;
        break;
      case "Paljonko maksat yhtiövastiketta kuukaudessa?":
        if (expenses.containsKey('Asuminen')) expenses['Asuminen']!['Yhtiövastike'] = value ?? 0.0;
        break;
      case "Paljonko maksat asuntolainaa kuukaudessa? (jos ei lainaa, syötä 0)?": // Omakotitalo
        if (expenses.containsKey('Asuminen')) expenses['Asuminen']!['Asuntolaina'] = value ?? 0.0;
        break;
      case "Paljonko kotivakuutuksesi maksaa vuodessa?": // Omakotitalo
        if (expenses.containsKey('Vakuutukset')) expenses['Vakuutukset']!['Kotivakuutus'] = (value ?? 0.0) / 12;
        break;
      case "Paljonko kiinteistöverosi on vuodessa?":
        if (expenses.containsKey('Asuminen')) expenses['Asuminen']!['Kiinteistövero'] = (value ?? 0.0) / 12;
        break;
      case "Paljonko maksat jätehuollosta (Roskien tyhjennys) kuukaudessa?":
        if (expenses.containsKey('Asuminen')) expenses['Asuminen']!['Jätehuolto'] = value ?? 0.0;
        break;
      case "Paljonko maksat sähkölaskua kuukaudessa?":
        expenses['Laskut ja palvelut'] = expenses['Laskut ja palvelut'] ?? {};
        expenses['Laskut ja palvelut']!['Sähkö'] = value ?? 0.0;
        break;
      case "Paljonko maksat puhelinlaskua kuukaudessa?":
        if (expenses.containsKey('Laskut ja palvelut')) expenses['Laskut ja palvelut']!['Puhelinlasku'] = value ?? 0.0;
        break;
      case "Paljonko maksat nettiliittymästä kuukaudessa (Syötä 0, jos ei ole nettiliittymää)?":
        if (expenses.containsKey('Laskut ja palvelut')) expenses['Laskut ja palvelut']!['Nettiliittymä'] = value ?? 0.0;
        break;
      case "Onko sinulla autoa?":
        carOwnership = response;
        if (response == "Kyllä") {
          expenses['Liikkuminen'] = {
            'Polttoaine': 0.0,
            'auton verot': 0.0,
            'Auton ylläpito': 0.0,
          };
          expenses['Vakuutukset'] = expenses['Vakuutukset'] ?? {};
          expenses['Vakuutukset']!['Autovakuutus'] = 0.0;
        }
        break;
      case "Onko autosi oma vai maksatko siitä rahoitusta?":
        if (response == "Rahoitettu") {
          if (expenses.containsKey('Liikkuminen')) {
            expenses['Liikkuminen']!['Auton rahoitus'] = 0.0;
          }
          hasCarLoan = true;
        } else {
          hasCarLoan = false;
          if (expenses.containsKey('Liikkuminen')) {
            expenses['Liikkuminen']!.remove('Auton rahoitus');
          }
        }
        break;
      case "Paljonko maksat auton rahoitusta kuukaudessa?":
        if (expenses.containsKey('Liikkuminen')) expenses['Liikkuminen']!['Auton rahoitus'] = value ?? 0.0;
        break;
      case "Vuokraatko autopaikkaa?":
        rentsParkingSpace = response == "Kyllä";
        if (rentsParkingSpace) {
          if (expenses.containsKey('Liikkuminen')) {
            expenses['Liikkuminen']!['Autopaikan vuokra'] = 0.0;
          }
        } else {
          if (expenses.containsKey('Liikkuminen')) {
            expenses['Liikkuminen']!.remove('Autopaikan vuokra');
          }
        }
        break;
      case "Paljonko maksat autopaikasta kuukaudessa?":
        if (expenses.containsKey('Liikkuminen')) expenses['Liikkuminen']!['Autopaikan vuokra'] = value ?? 0.0;
        break;
      case "Paljonko auton polttoainekulut ovat kuukaudessa?":
        if (carOwnership == "Kyllä") expenses['Liikkuminen']!['Polttoaine'] = value ?? 0.0;
        break;
      case "Paljonko auton vakuutukset maksavat vuodessa?":
        if (carOwnership == "Kyllä") expenses['Vakuutukset']!['Autovakuutus'] = (value ?? 0.0) / 12;
        break;
      case "Paljonko maksat käyttövoima- ja ajoneuvoveroa vuodessa?":
        if (carOwnership == "Kyllä") expenses['Liikkuminen']!['auton verot'] = (value ?? 0.0) / 12;
        break;
      case "Paljonko maksat autosta muita kuluja vuodessa (Esim. Renkaiden säilytys, huolto (Suomessa huolto keskim. 600-1000€/vuosi))?":
        if (carOwnership == "Kyllä") expenses['Liikkuminen']!['Auton ylläpito'] = (value ?? 0.0) / 12;
        break;
      case "Paljonko varaat ruokaan kuukaudessa?":
        expenses['Ruoka'] = {'Ruokakauppa': value ?? 0.0};
        break;
      case "Paljonko käytät rahaa terveyteen liittyviin kuluihin kuukaudessa (Lääkkeet, lääkärikäynnit)?":
        expenses['Terveys'] = {'Terveyskulut': value ?? 0.0};
        break;
      case "Paljonko käytät rahaa hygieniaan liittyviin kuluihin kuukaudessa (Kosmetiikka, Siivous- ja wc-tarvikkeet)?":
        expenses['Hygienia'] = {'Hygieniakulut': value ?? 0.0};
        break;
      case "Paljonko varaat sijoittamiseen kuukaudessa (esim. osakkeet, rahastot, kryptovaluutat)?": // Sijoittaminen ja säästäminen
        expenses['Sijoittaminen ja säästäminen'] = expenses['Sijoittaminen ja säästäminen'] ?? {};
        expenses['Sijoittaminen ja säästäminen']!['Sijoittaminen'] = value ?? 0.0;
        break;
      case "Paljonko varaat säästämiseen kuukaudessa (esim. pahanpäivän kassa, lomareissut)?": // Sijoittaminen ja säästäminen
        if (expenses.containsKey('Sijoittaminen ja säästäminen')) expenses['Sijoittaminen ja säästäminen']!['Säästäminen'] = value ?? 0.0;
        break;
      case "Maksatko muita kuukausittaisia velkoja autorahoituksen ja asuntolainan lisäksi?":
      case "Maksatko asuntolainan lisäksi muita velkoja?":
      case "Maksatko muita kuukausittaisia velkoja autorahoituksen lisäksi?":
      case "Onko sinulla velkoja?":
        hasOtherDebts = response == "Kyllä";
        if (hasOtherDebts) expenses['Velat'] = {'Velat': 0.0};
        break;
      case "Paljonko maksat velkaa kuukaudessa?":
        if (expenses.containsKey('Velat')) expenses['Velat']!['Velat'] = value ?? 0.0;
        break;
      case "Paljonko varaat harrastuksiin kuukaudessa (esim. kuntosali, välineet, tapahtumat)?": // Harrastukset
        expenses['Harrastukset'] = {'Harrastuskulut': value ?? 0.0};
        break;
      case "Paljonko käytät rahaa suoratoistopalveluihin kuukaudessa (esim. Spotify, Netflix)?": // Viihde
        expenses['Viihde'] = {'Suoratoistopalvelut': value ?? 0.0};
        break;
      case "Paljonko käytät rahaa muuhun viihteeseen kuukaudessa (esim. pelit, elokuvat, lehdet, konsertit)?": // Viihde
        if (expenses.containsKey('Viihde')) expenses['Viihde']!['Viihdekulut'] = value ?? 0.0;
        break;
      case "Onko sinulla lemmikki/lemmikkejä?":
        hasPets = response == "Kyllä";
        if (hasPets) expenses['Lemmikit'] = {'Lemmikkikulut': 0.0};
        break;
      case "Paljonko varaat lemmikkikuluihin kuukaudessa (Ruoka, tarvikkeet, Lääkärikäynnit)?": // Lemmikit
        if (expenses.containsKey('Lemmikit')) expenses['Lemmikit']!['Lemmikkikulut'] = value ?? 0.0;
        break;
    }
  }
}