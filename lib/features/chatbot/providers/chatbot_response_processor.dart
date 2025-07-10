import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChatbotResponseProcessor {
  final List<String> questions;
  final Map<String, Map<String, double>> expenses;
  double income;
  String? budgetType; // monthly, biweekly
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
  DateTime? startDate;
  DateTime? endDate;

  ChatbotResponseProcessor({
    required this.questions,
    required this.expenses,
    required this.income,
    this.budgetType,
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
    this.startDate,
    this.endDate,
  });

  Future<void> _calculatePeriod(BuildContext context) async {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final availableBudgets = await budgetProvider.getAvailableBudgets(context.read<AuthProvider>().user!.uid);
    if (availableBudgets.isNotEmpty) {
      // Viimeisin budjetti endDate:n perusteella
      final latestBudget = availableBudgets.reduce((a, b) => a.endDate.isAfter(b.endDate) ? a : b);
      startDate = latestBudget.endDate.add(Duration(days: 1));
      if (budgetType == 'monthly') {
        endDate = DateTime(startDate!.year, startDate!.month + 1, 0); // Kuukauden viimeinen päivä
      } else if (budgetType == 'biweekly') {
        endDate = startDate!.add(Duration(days: 13)); // 2 viikon jakso
      }
    } else {
      // Oletus: Nykyinen kuukausi
      final now = DateTime.now();
      startDate = DateTime(now.year, now.month, 1);
      endDate = budgetType == 'monthly' ? DateTime(now.year, now.month + 1, 0) : startDate!.add(Duration(days: 13));
    }
  }

  void processResponse(String response, int step, BuildContext context) {
    double? value = double.tryParse(response.replaceAll('€', '').trim());
    if (questions[step] != "Haluatko luoda kuukausibudjetin vai 2 viikon budjetin?" &&
        questions[step] != "Mikä seuraavista kuvaa parhaiten asumistasi?" &&
        questions[step] != "Onko sinulla autoa?" &&
        questions[step] != "Onko autosi oma vai maksatko siitä rahoitusta?" &&
        questions[step] != "Vuokraatko autopaikkaa?" &&
        questions[step] != "Onko sinulla lemmikki/lemmikkejä?" &&
        questions[step] != "Maksatko muita kuukausittaisia velkoja autorahoituksen ja asuntolainan lisäksi?" &&
        questions[step] != "Maksatko asuntolainan lisäksi muita velkoja?" &&
        questions[step] != "Maksatko muita kuukausittaisia velkoja autorahoituksen lisäksi?" &&
        questions[step] != "Onko sinulla velkoja?") {
      value = value ?? 0.0;
      // Skaalataan kulut, jos budjettityyppi on biweekly
      if (budgetType == 'biweekly') {
        value = value / 2; // Muunnetaan kuukausikulut 2 viikon jaksolle
      }
    }

    switch (questions[step]) {
      case "Haluatko luoda kuukausibudjetin vai 2 viikon budjetin?":
        budgetType = response == "Kuukausi" ? 'monthly' : 'biweekly';
        _calculatePeriod(context); // Lasketaan startDate ja endDate
        break;
      case "Paljonko saat tuloja kuukaudessa (esim. palkka, tuet, pääomatulot)?":
      case "Paljonko saat tuloja 2 viikon jaksolla (esim. palkka, tuet, pääomatulot)?": // Tulot
        income = value ?? 0.0;
        break;
      case "Mikä seuraavista kuvaa parhaiten asumistasi?":
        housingType = response;
        expenses['Asuminen'] = {};
        expenses['Vakuutukset'] = {'Kotivakuutus': 0.0};
        break;
      case "Paljonko maksat vuokraa kuukaudessa?":
      case "Paljonko maksat vuokraa 2 viikon jaksolla?":
        if (expenses.containsKey('Asuminen')) expenses['Asuminen']!['Vuokra'] = value ?? 0.0;
        break;
      case "Paljonko maksat vesimaksua kuukaudessa (jos sisältyy vuokraan, syötä 0)?": // Vuokra-asunto
      case "Paljonko maksat vesimaksua kuukaudessa (vesi + jätevesi)?": // Omakotitalo
      case "Paljonko maksat vesimaksua 2 viikon jaksolla (jos sisältyy vuokraan, syötä 0)?": // Vuokra-asunto
      case "Paljonko maksat vesimaksua 2 viikon jaksolla (vesi + jätevesi)?": // Omakotitalo
        expenses['Laskut ja palvelut'] = expenses['Laskut ja palvelut'] ?? {};
        expenses['Laskut ja palvelut']!['Vesi'] = value ?? 0.0;
        break;
      case "Paljonko maksat yhtiövastiketta kuukaudessa?":
      case "Paljonko maksat yhtiövastiketta 2 viikon jaksolla?":
        if (expenses.containsKey('Asuminen')) expenses['Asuminen']!['Yhtiövastike'] = value ?? 0.0;
        break;
      case "Paljonko maksat asuntolainaa kuukaudessa? (jos ei lainaa, syötä 0)?": // Omakotitalo
      case "Paljonko maksat asuntolainaa 2 viikon jaksolla? (jos ei lainaa, syötä 0)?": // Omakotitalo
        if (expenses.containsKey('Asuminen')) expenses['Asuminen']!['Asuntolaina'] = value ?? 0.0;
        break;
      case "Paljonko kotivakuutuksesi maksaa vuodessa?": // Omakotitalo
        if (expenses.containsKey('Vakuutukset')) expenses['Vakuutukset']!['Kotivakuutus'] = (value ?? 0.0) / 12;
        break;
      case "Paljonko kiinteistöverosi on vuodessa?":
        if (expenses.containsKey('Asuminen')) expenses['Asuminen']!['Kiinteistövero'] = (value ?? 0.0) / 12;
        break;
      case "Paljonko maksat jätehuollosta (esim. roskien tyhjennys) kuukaudessa?":
      case "Paljonko maksat jätehuollosta (esim. roskien tyhjennys) 2 viikon jaksolla?":
        if (expenses.containsKey('Asuminen')) expenses['Asuminen']!['Jätehuolto'] = value ?? 0.0;
        break;
      case "Paljonko maksat sähkölaskua kuukaudessa?":
      case "Paljonko maksat sähkölaskua 2 viikon jaksolla?":
        expenses['Laskut ja palvelut'] = expenses['Laskut ja palvelut'] ?? {};
        expenses['Laskut ja palvelut']!['Sähkö'] = value ?? 0.0;
        break;
      case "Paljonko maksat puhelinlaskua kuukaudessa?":
      case "Paljonko maksat puhelinlaskua 2 viikon jaksolla?":
        if (expenses.containsKey('Laskut ja palvelut')) expenses['Laskut ja palvelut']!['Puhelinlasku'] = value ?? 0.0;
        break;
      case "Paljonko maksat nettiliittymästä kuukaudessa (syötä 0, jos ei ole nettiliittymää)?":
      case "Paljonko maksat nettiliittymästä 2 viikon jaksolla (syötä 0, jos ei ole nettiliittymää)?": // Nettiliittymä
        if (expenses.containsKey('Laskut ja palvelut')) expenses['Laskut ja palvelut']!['Nettiliittymä'] = value ?? 0.0;
        break;
      case "Onko sinulla autoa?":
        carOwnership = response;
        if (response == "Kyllä") {
          expenses['Liikkuminen'] = {
            'Polttoaine': 0.0,
            'Auton verot': 0.0,
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
      case "Paljonko maksat auton rahoitusta 2 viikon jaksolla?":
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
      case "Paljonko maksat autopaikasta 2 viikon jaksolla?":
        if (expenses.containsKey('Liikkuminen')) expenses['Liikkuminen']!['Autopaikan vuokra'] = value ?? 0.0;
        break;
      case "Paljonko auton polttoainekulut ovat kuukaudessa?":
      case "Paljonko auton polttoainekulut ovat 2 viikon jaksolla?":
        if (carOwnership == "Kyllä") expenses['Liikkuminen']!['Polttoaine'] = value ?? 0.0;
        break;
      case "Paljonko auton vakuutukset maksavat vuodessa?":
        if (carOwnership == "Kyllä") expenses['Vakuutukset']!['Autovakuutus'] = (value ?? 0.0) / 12;
        break;
      case "Paljonko maksat käyttövoima- ja ajoneuvoveroa vuodessa?":
        if (carOwnership == "Kyllä") expenses['Liikkuminen']!['Auton verot'] = (value ?? 0.0) / 12;
        break;
      case "Paljonko maksat autosta muita kuluja vuodessa (esim. renkaiden säilytys, huolto, keskim. 600-1000 €/vuosi)?": // Auton ylläpito
        if (carOwnership == "Kyllä") expenses['Liikkuminen']!['Auton ylläpito'] = (value ?? 0.0) / 12;
        break;
      case "Paljonko varaat ruokaan kuukaudessa?":
      case "Paljonko varaat ruokaan 2 viikon jaksolla?":
        expenses['Ruoka'] = {'Ruokakauppa': value ?? 0.0};
        break;
      case "Paljonko käytät rahaa terveyteen liittyviin kuluihin kuukaudessa (lääkkeet, lääkärikäynnit)?": // Terveys
      case "Paljonko käytät rahaa terveyteen liittyviin kuluihin 2 viikon jaksolla (lääkkeet, lääkärikäynnit)?": // Terveys
        expenses['Terveys'] = {'Terveyskulut': value ?? 0.0};
        break;
      case "Paljonko käytät rahaa hygieniaan liittyviin kuluihin kuukaudessa (kosmetiikka, siivous- ja wc-tarvikkeet)?": // Hygienia
      case "Paljonko käytät rahaa hygieniaan liittyviin kuluihin 2 viikon jaksolla (kosmetiikka, siivous- ja wc-tarvikkeet)?": // Hygienia
        expenses['Hygienia'] = {'Hygieniakulut': value ?? 0.0};
        break;
      case "Paljonko varaat sijoittamiseen kuukaudessa (esim. osakkeet, rahastot, kryptovaluutat)?": // Sijoittaminen ja säästäminen
      case "Paljonko varaat sijoittamiseen 2 viikon jaksolla (esim. osakkeet, rahastot, kryptovaluutat)?": // Sijoittaminen ja säästäminen
        expenses['Sijoittaminen ja säästäminen'] = expenses['Sijoittaminen ja säästäminen'] ?? {};
        expenses['Sijoittaminen ja säästäminen']!['Sijoittaminen'] = value ?? 0.0;
        break;
      case "Paljonko varaat säästämiseen kuukaudessa (esim. pahan päivän kassa, lomareissut)?": // Sijoittaminen ja säästäminen
      case "Paljonko varaat säästämiseen 2 viikon jaksolla (esim. pahan päivän kassa, lomareissut)?": // Sijoittaminen ja säästäminen
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
      case "Paljonko maksat velkaa 2 viikon jaksolla?":
        if (expenses.containsKey('Velat')) expenses['Velat']!['Velat'] = value ?? 0.0;
        break;
      case "Paljonko varaat harrastuksiin kuukaudessa (esim. kuntosali, välineet, tapahtumat)?": // Harrastukset
      case "Paljonko varaat harrastuksiin 2 viikon jaksolla (esim. kuntosali, välineet, tapahtumat)?": // Harrastukset
        expenses['Harrastukset'] = {'Harrastuskulut': value ?? 0.0};
        break;
      case "Paljonko käytät rahaa suoratoistopalveluihin kuukaudessa (esim. Spotify, Netflix)?": // Viihde
      case "Paljonko käytät rahaa suoratoistopalveluihin 2 viikon jaksolla (esim. Spotify, Netflix)?": // Viihde
        expenses['Viihde'] = {'Suoratoistopalvelut': value ?? 0.0};
        break;
      case "Paljonko käytät rahaa muuhun viihteeseen kuukaudessa (esim. pelit, elokuvat, lehdet, konsertit)?": // Viihde
      case "Paljonko käytät rahaa muuhun viihteeseen 2 viikon jaksolla (esim. pelit, elokuvat, lehdet, konsertit)?": // Viihde
        if (expenses.containsKey('Viihde')) expenses['Viihde']!['Viihdekulut'] = value ?? 0.0;
        break;
      case "Onko sinulla lemmikki/lemmikkejä?":
        hasPets = response == "Kyllä";
        if (hasPets) expenses['Lemmikit'] = {'Lemmikkikulut': 0.0};
        break;
      case "Paljonko varaat lemmikkikuluihin kuukaudessa (ruoka, tarvikkeet, lääkärikäynnit)?": // Lemmikit
      case "Paljonko varaat lemmikkikuluihin 2 viikon jaksolla (ruoka, tarvikkeet, lääkärikäynnit)?": // Lemmikit
        if (expenses.containsKey('Lemmikit')) expenses['Lemmikit']!['Lemmikkikulut'] = value ?? 0.0;
        break;
    }
  }
}