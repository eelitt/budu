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
      case "Hei! Paljonko saat tuloja kuukaudessa (esim. palkka, tuet)?":
        income = value ?? 0.0;
        break;
      case "Asutko vuokralla, omakotitalossa vai ilman asuntokuluja?":
        housingType = response;
        if (response == "Vuokralla") {
          expenses['Asuminen'] = {
            'Vuokra': 0.0,
            'Vesimaksu': 0.0,
            'Kotivakuutus': 0.0,
          };
        }
        if (response == "Omakotitalossa") {
          expenses['Asuminen'] = {
            'Asuntolaina': 0.0,
            'Lämmitys': 0.0,
            'Kiinteistövero': 0.0,
            'Jätehuolto': 0.0,
            'Kotivakuutus': 0.0,
          };
        }
        break;
      case "Paljonko maksat vuokraa kuukaudessa?":
        if (expenses.containsKey('Asuminen')) expenses['Asuminen']!['Vuokra'] = value ?? 0.0;
        break;
      case "Paljonko maksat vesimaksua kuukaudessa (jos sisältyy vuokraan, syötä 0)?":
        if (housingType == "Vuokralla") expenses['Asuminen']!['Vesimaksu'] = value ?? 0.0;
        break;
      case "Paljonko kotivakuutuksesi maksaa vuodessa?":
        if (housingType == "Vuokralla") expenses['Asuminen']!['Kotivakuutus'] = (value ?? 0.0) / 12;
        if (housingType == "Omakotitalossa") expenses['Asuminen']!['Kotivakuutus'] = (value ?? 0.0) / 12;
        break;
      case "Paljonko maksat asuntolainaa kuukaudessa (jos ei lainaa, syötä 0)?":
        if (expenses.containsKey('Asuminen')) expenses['Asuminen']!['Asuntolaina'] = value ?? 0.0;
        break;
      case "Paljonko kiinteistöverosi on vuodessa?":
        if (expenses.containsKey('Asuminen')) expenses['Asuminen']!['Kiinteistövero'] = (value ?? 0.0) / 12;
        break;
      case "Paljonko maksat jätehuollosta kuukaudessa?":
        if (expenses.containsKey('Asuminen')) expenses['Asuminen']!['Jätehuolto'] = value ?? 0.0;
        break;
      case "Onko sinulla autoa?":
        carOwnership = response;
        if (response == "Kyllä") {
          expenses['Liikkuminen'] = {
            'Polttoaine': 0.0,
            'Autovakuutus': 0.0,
            'Ajoneuvovero': 0.0,
            'Auton huolto': 0.0,
          };
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
        }
        break;
      case "Paljonko maksat Auton rahoitusta kuukaudessa?":
        if (expenses.containsKey('Liikkuminen')) expenses['Liikkuminen']!['Auton rahoitus'] = value ?? 0.0;
        break;
      case "Vuokraatko autopaikkaa (esim. pihapaikka, autotalli)?":
        rentsParkingSpace = response == "Kyllä";
        if (rentsParkingSpace) {
          if (expenses.containsKey('Liikkuminen')) {
            expenses['Liikkuminen']!['AutopaikanVuokra'] = 0.0;
          }
        }
        break;
      case "Paljonko maksat autopaikan vuokraa kuukaudessa?":
        if (expenses.containsKey('Liikkuminen')) expenses['Liikkuminen']!['AutopaikanVuokra'] = value ?? 0.0;
        break;
      case "Paljonko auton polttoainekulut ovat kuukaudessa?":
        if (carOwnership == "Kyllä") expenses['Liikkuminen']!['Polttoaine'] = value ?? 0.0;
        break;
      case "Paljonko auton vakuutukset maksavat vuodessa?":
        if (carOwnership == "Kyllä") expenses['Liikkuminen']!['Autovakuutus'] = (value ?? 0.0) / 12;
        break;
      case "Paljonko maksat ajoneuvoveroa vuodessa?":
        if (carOwnership == "Kyllä") expenses['Liikkuminen']!['Ajoneuvovero'] = (value ?? 0.0) / 12;
        break;
      case "Onko sinulla renkaiden vaihto- ja säilytyspalvelu?":
        hasTireService = response == "Kyllä";
        if (hasTireService) {
          if (expenses.containsKey('Liikkuminen')) {
            expenses['Liikkuminen']!['Renkaiden vaihto ja säilytys'] = 0.0;
          }
        }
        break;
      case "Paljonko maksat renkaiden vaihto- ja säilytyspalvelusta vuodessa?":
        if (expenses.containsKey('Liikkuminen')) expenses['Liikkuminen']!['Renkaiden vaihto ja säilytys'] = (value ?? 0.0) / 12;
        break;
      case "Haluatko syöttää auton huolto- ja korjauskulut itse vai käyttää suomalaisten keskimääräisiä kuluja?":
        useAverageCarMaintenance = response == "Käytä suomalaisten keskim. huolto- ja korjauskustannuksia (1070 € vuodessa)";
        if (useAverageCarMaintenance) expenses['Liikkuminen']!['Auton huolto'] = 1070.0 / 12;
        break;
      case "Paljonko auton huolto- ja korjauskulut ovat vuodessa?":
        if (carOwnership == "Kyllä") expenses['Liikkuminen']!['Auton huolto'] = (value ?? 0.0) / 12;
        break;
      case "Paljonko sähkölaskusi on keskimäärin kuukaudessa?":
        expenses['Kodin kulut'] = {
          'Sähkö': value ?? 0.0,
          'Nettiliittymä': 0.0,
          'Puhelinlasku': 0.0,
        };
        break;
      case "Onko sinulla kuukausimaksullisia palveluita (esim. Netflix, Spotify)?":
        if (response == "Kyllä") expenses['Viihde'] = {'Viihde-Palvelut': 0.0};
        break;
      case "Paljonko palveluihin menee rahaa kuukaudessa?":
        if (expenses.containsKey('Viihde')) expenses['Viihde']!['Viihde-Palvelut'] = value ?? 0.0;
        break;
      case "Paljonko varaat ruokaan ja päivittäistavaroihin kuukaudessa?":
        expenses['Ruoka'] = {'Ruoka': value ?? 0.0};
        break;
      case "Paljonko käytät rahaa terveyteen liittyviin kuluihin kuukaudessa (esim. lääkärikäynnit, lääkkeet)?":
        expenses['Terveys'] = {'Terveys': value ?? 0.0};
        break;
      case "Paljonko käytät rahaa hygieniaan liittyviin kuluihin kuukaudessa (esim. puhdistusaineet, WC-paperit, muut vessassa ja keittiössä tarvittavat kulutustuotteet)?":
        expenses['Hygienia'] = {'Hygienia': value ?? 0.0};
        break;
      case "Paljonko käytät rahaa harrastuksiin kuukaudessa (esim. urheilu, kulttuuri, pelit)?":
        expenses['Harrastukset'] = {'Harrastukset': value ?? 0.0};
        break;
      case "Onko sinulla lemmikkejä?":
        hasPets = response == "Kyllä";
        if (hasPets) expenses['Lemmikit'] = {'Lemmikit': 0.0};
        break;
      case "Paljonko lemmikeistä aiheutuu kuluja kuukaudessa (esim. ruoka, tarvikkeet, eläinlääkäri)?":
        if (expenses.containsKey('Lemmikit')) expenses['Lemmikit']!['Lemmikit'] = value ?? 0.0;
        break;
      case "Paljonko maksat puhelinlaskua kuukaudessa?":
        if (expenses.containsKey('Kodin kulut')) expenses['Kodin kulut']!['Puhelinlasku'] = value ?? 0.0;
        break;
      case "Paljonko maksat nettiliittymästä kuukaudessa?":
        if (expenses.containsKey('Kodin kulut')) expenses['Kodin kulut']!['Nettiliittymä'] = value ?? 0.0;
        break;
      case "Maksatko muita kuukausittaisia velkoja autorahoituksen lisäksi? (Kyllä/Ei)":
      case "Maksatko kuukausittain velkoja (Esim. osamaksuja)? (Kyllä/Ei)":
      case "Maksatko kuukausittain muita velkoja (Esim. osamaksuja) kuin omakotitalovelkaa? (Kyllä/Ei)":
        hasOtherDebts = response == "Kyllä";
        break;
      case "Paljonko maksat velkoja kuukausittain?":
        debtAmount = value ?? 0.0;
        expenses['Velat'] = {'Velat': value ?? 0.0};
        break;
      case "Paljonko varaat kuukausittain säästämiseen tai sijoittamiseen?":
        expenses['Sijoittaminen'] = {'Sijoittaminen': value ?? 0.0};
        break;
      case "Onko muita säännöllisiä menoja?":
        hasOtherExpenses = response == "Kyllä";
        if (hasOtherExpenses) expenses['Muut'] = {'Muut': 0.0};
        break;
      case "Paljonko muihin menoihin menee rahaa kuukaudessa?":
        if (expenses.containsKey('Muut')) expenses['Muut']!['Muut'] = value ?? 0.0;
        break;
    }
  }
}