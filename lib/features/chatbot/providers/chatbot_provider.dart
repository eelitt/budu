import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../../budget/models/budget_model.dart';
import '../../budget/providers/budget_provider.dart';

class ChatbotProvider with ChangeNotifier {
  List<ChatMessage> _messages = [];
  int _step = 0;
  Map<String, double> _expenses = {};
  double _income = 0.0;
  bool _isCompleted = false;
  bool _isMultipleChoice = false;
  List<String> _currentOptions = [];
  String? _housingType; // Vuokralla, Omakotitalo, Ilman kuluja
  String? _carOwnership; // Oma, Rahoitettu, Ei autoa
  bool _rentsParkingSpace = false; // Vuokraako autopaikkaa
  bool _hasTireService = false; // Onko renkaiden vaihto- ja säilytyspalvelu
  bool _useAverageCarMaintenance = false; // Käytetäänkö keskimääräisiä huoltokuluja
  bool _hasPets = false; // Onko lemmikkejä
  bool _hasOtherExpenses = false; // Onko muita säännöllisiä menoja
  bool _hasCarLoan = false; // Onko autorahoitusta
bool _hasOtherDebts = false; // Onko muita velkoja
double _debtAmount = 0.0; // Velkojen kuukausittainen maksusumma

  List<ChatMessage> get messages => _messages;
  bool get isCompleted => _isCompleted;
  bool get isMultipleChoice => _isMultipleChoice;
  List<String> get currentOptions => _currentOptions;
  int get step => _step;

  ChatbotProvider() {
    _startChat();
  }

  void _startChat() {
    _messages.add(ChatMessage(
      text: "Hei! Autan sinua luomaan budjetin. Paljonko saat tuloja kuukaudessa (esim. palkka, tuet)?",
      isUser: false,
      createdAt: DateTime.now(),
    ));
    notifyListeners();
  }

  void handleUserResponse(String response) {
    _messages.add(ChatMessage(
      text: response,
      isUser: true,
      createdAt: DateTime.now(),
    ));

    // Tarkistetaan, onko kysymys monivalinta vai numeerinen
    final questions = _getQuestions();
    final currentQuestion = questions[_step];
    if (_isMultipleChoice) {
      _processResponse(response);
      _step++; // Siirrytään seuraavaan kysymykseen
    } else {
      // Numeerinen syöte: validoidaan
      double? value = double.tryParse(response.replaceAll('€', '').trim());
      if (value == null || value < 0) {
        _messages.add(ChatMessage(
          text: "Syötä kelvollinen positiivinen numero (esim. 100). Yritä uudelleen.",
          isUser: false,
          createdAt: DateTime.now(),
        ));
        notifyListeners();
        return; // Ei siirrytä eteenpäin, odotetaan uutta syötettä
      }
      _processResponse(response);
      _step++; // Siirrytään seuraavaan kysymykseen
    }

    // Päivitetään kysymyslista uudelleen, koska se on dynaaminen
    final updatedQuestions = _getQuestions();
    if (_step < updatedQuestions.length) {
      _askNextQuestion();
    } else {
      // Varmistetaan, että viimeinen numeerinen kysymys on vastattu
      if (_hasOtherExpenses && _expenses.containsKey('Muut') && _expenses['Muut']! >= 0) {
        _isCompleted = true;
      } else if (!_hasOtherExpenses) {
        _isCompleted = true;
      }
    }

    notifyListeners();
  }

  List<String> _getQuestions() {
  List<String> questions = [
    "Hei! Paljonko saat tuloja kuukaudessa (esim. palkka, tuet)?",
    "Asutko vuokralla, omakotitalossa vai ilman asuntokuluja?",
  ];

  if (_housingType == "Vuokralla") {
    questions.addAll([
      "Paljonko maksat vuokraa kuukaudessa?",
      "Paljonko maksat vesimaksua kuukaudessa (jos sisältyy vuokraan, syötä 0)?",
      "Paljonko kotivakuutuksesi maksaa vuodessa?",
    ]);
  } else if (_housingType == "Omakotitalossa") {
    questions.addAll([
      "Paljonko maksat asuntolainaa kuukaudessa (jos ei lainaa, syötä 0)?",
      "Paljonko lämmityskulusi ovat kuukaudessa?",
      "Paljonko kiinteistöverosi on vuodessa?",
      "Paljonko maksat jätehuollosta kuukaudessa?",
      "Paljonko kotivakuutuksesi maksaa vuodessa?",
    ]);
  }

  questions.add("Onko sinulla autoa?");

  if (_carOwnership == "Kyllä") {
    questions.add("Onko autosi oma vai maksatko siitä rahoitusta?");
    if (_expenses.containsKey('Auton rahoitus')) {
      questions.add("Paljonko maksat Auton rahoitusta kuukaudessa?");
    }
    if (_housingType == "Vuokralla") {
      questions.add("Vuokraatko autopaikkaa (esim. pihapaikka, autotalli)?");
    }
    if (_rentsParkingSpace) {
      questions.add("Paljonko maksat autopaikan vuokraa kuukaudessa?");
    }
    questions.addAll([
      "Paljonko auton polttoainekulut ovat kuukaudessa?",
      "Paljonko auton vakuutukset maksavat vuodessa?",
      "Paljonko maksat ajoneuvoveroa vuodessa?",
      "Onko sinulla renkaiden vaihto- ja säilytyspalvelu?",
    ]);
    if (_hasTireService) {
      questions.add("Paljonko maksat renkaiden vaihto- ja säilytyspalvelusta vuodessa?");
    }
    questions.add("Haluatko syöttää auton huolto- ja korjauskulut itse vai käyttää suomalaisten keskimääräisiä kuluja?");
    if (!_useAverageCarMaintenance) {
      questions.add("Paljonko auton huolto- ja korjauskulut ovat vuodessa?");
    }
  }

  questions.addAll([
    "Paljonko sähkölaskusi on keskimäärin kuukaudessa?",
    "Onko sinulla kuukausimaksullisia palveluita (esim. Netflix, Spotify)?",
  ]);

  if (_expenses.containsKey('Viihde-Palvelut')) {
    questions.add("Paljonko palveluihin menee rahaa kuukaudessa?");
  }

  questions.addAll([
    "Paljonko varaat ruokaan ja päivittäistavaroihin kuukaudessa?",
    "Paljonko käytät rahaa terveyteen liittyviin kuluihin kuukaudessa (esim. lääkärikäynnit, lääkkeet)?",
    "Paljonko käytät rahaa hygieniaan liittyviin kuluihin kuukaudessa (esim. puhdistusaineet, WC-paperit, muut vessassa ja keittiössä tarvittavat kulutustuotteet)?",
    "Paljonko käytät rahaa harrastuksiin kuukaudessa (esim. urheilu, kulttuuri, pelit)?",
    "Onko sinulla lemmikkejä?",
  ]);

  if (_hasPets) {
    questions.add("Paljonko lemmikeistä aiheutuu kuluja kuukaudessa (esim. ruoka, tarvikkeet, eläinlääkäri)?");
  }

  questions.addAll([
    "Paljonko maksat puhelinlaskua kuukaudessa?",
    "Paljonko maksat nettiliittymästä kuukaudessa?",
  ]);

  // Lisätään velka- ja säästämiskysymykset
  if (_housingType == "Vuokralla") {
    if (_carOwnership == "Kyllä" && _hasCarLoan) {
      questions.add("Maksatko muita kuukausittaisia velkoja autorahoituksen lisäksi? (Kyllä/Ei)");
    } else {
      questions.add("Maksatko kuukausittain velkoja (Esim. osamaksuja)? (Kyllä/Ei)");
    }
  } else if (_housingType == "Omakotitalossa") {
    if (_expenses['Asuntolaina']! > 0) {
      if (_carOwnership == "Kyllä" && _hasCarLoan) {
        questions.add("Maksatko muita kuukausittaisia velkoja autorahoituksen lisäksi? (Kyllä/Ei)");
      } else {
        questions.add("Maksatko kuukausittain muita velkoja (Esim. osamaksuja) kuin omakotitalovelkaa? (Kyllä/Ei)");
      }
    } else {
      if (_carOwnership == "Kyllä" && _hasCarLoan) {
        questions.add("Maksatko muita kuukausittaisia velkoja autorahoituksen lisäksi? (Kyllä/Ei)");
      } else {
        questions.add("Maksatko kuukausittain velkoja (Esim. osamaksuja)? (Kyllä/Ei)");
      }
    }
  }

  if (_hasOtherDebts) {
    questions.add("Paljonko maksat velkoja kuukausittain?");
  }

  questions.add("Paljonko varaat kuukausittain säästämiseen tai sijoittamiseen?");

  // Viimeinen kysymys
  questions.add("Onko muita säännöllisiä menoja?");
  if (_expenses.containsKey('Muut')) {
    questions.add("Paljonko muihin menoihin menee rahaa kuukaudessa?");
  }

  return questions;
}

  void _askNextQuestion() {
  final questions = _getQuestions();
  if (_step < questions.length) {
    _isMultipleChoice = questions[_step] == "Asutko vuokralla, omakotitalossa vai ilman asuntokuluja?" ||
        questions[_step] == "Onko sinulla autoa?" ||
        questions[_step] == "Onko sinulla kuukausimaksullisia palveluita (esim. Netflix, Spotify)?" ||
        questions[_step] == "Onko muita säännöllisiä menoja?" ||
        questions[_step] == "Onko autosi oma vai maksatko siitä rahoitusta?" ||
        questions[_step] == "Vuokraatko autopaikkaa (esim. pihapaikka, autotalli)?" ||
        questions[_step] == "Onko sinulla renkaiden vaihto- ja säilytyspalvelu?" ||
        questions[_step] == "Haluatko syöttää auton huolto- ja korjauskulut itse vai käyttää suomalaisten keskimääräisiä kuluja?" ||
        questions[_step] == "Onko sinulla lemmikkejä?" ||
        questions[_step].contains("(Kyllä/Ei)"); // Lisätään velkakysymykset monivalinnoiksi
    _currentOptions = _getOptionsForStep(_step);
    Future.delayed(const Duration(milliseconds: 500), () {
      _messages.add(ChatMessage(
        text: questions[_step],
        isUser: false,
        createdAt: DateTime.now(),
      ));
      notifyListeners();
    });
  }
}

  List<String> _getOptionsForStep(int step) {
  final questions = _getQuestions();
  if (step < questions.length) {
    if (questions[step].contains("(Kyllä/Ei)")) {
      return ["Kyllä", "Ei"];
    }
    switch (questions[step]) {
      case "Asutko vuokralla, omakotitalossa vai ilman asuntokuluja?":
        return ["Vuokralla", "Omakotitalossa", "Ilman asuntokuluja"];
      case "Onko sinulla autoa?":
        return ["Kyllä", "Ei"];
      case "Onko autosi oma vai maksatko siitä rahoitusta?":
        return ["Oma", "Rahoitettu"];
      case "Onko sinulla kuukausimaksullisia palveluita (esim. Netflix, Spotify)?":
        return ["Kyllä", "Ei"];
      case "Onko muita säännöllisiä menoja?":
        return ["Kyllä", "Ei"];
      case "Vuokraatko autopaikkaa (esim. pihapaikka, autotalli)?":
        return ["Kyllä", "Ei"];
      case "Onko sinulla renkaiden vaihto- ja säilytyspalvelu?":
        return ["Kyllä", "Ei"];
      case "Haluatko syöttää auton huolto- ja korjauskulut itse vai käyttää suomalaisten keskimääräisiä kuluja?":
        return ["Lisää summa", "Käytä suomalaisten keskim. huolto- ja korjauskustannuksia (1070 € vuodessa)"];
      case "Onko sinulla lemmikkejä?":
        return ["Kyllä", "Ei"];
    }
  }
  return [];
}

  void _processResponse(String response) {
  double? value = double.tryParse(response.replaceAll('€', '').trim());
  final questions = _getQuestions();
  switch (questions[_step]) {
    case "Hei! Paljonko saat tuloja kuukaudessa (esim. palkka, tuet)?":
      _income = value ?? 0.0;
      break;
    case "Asutko vuokralla, omakotitalossa vai ilman asuntokuluja?":
      _housingType = response;
      if (response == "Vuokralla") {
        _expenses['Vuokra'] = 0.0;
        _expenses['Vesimaksu'] = 0.0;
        _expenses['Kotivakuutus'] = 0.0;
      }
      if (response == "Omakotitalossa") {
        _expenses['Asuntolaina'] = 0.0;
        _expenses['Lämmitys'] = 0.0;
        _expenses['Kiinteistövero'] = 0.0;
        _expenses['Jätehuolto'] = 0.0;
        _expenses['Kotivakuutus'] = 0.0;
      }
      break;
    case "Paljonko maksat vuokraa kuukaudessa?":
      if (_expenses.containsKey('Vuokra')) _expenses['Vuokra'] = value ?? 0.0;
      break;
    case "Paljonko maksat vesimaksua kuukaudessa (jos sisältyy vuokraan, syötä 0)?":
      if (_housingType == "Vuokralla") _expenses['Vesimaksu'] = value ?? 0.0;
      break;
    case "Paljonko kotivakuutuksesi maksaa vuodessa?":
      if (_housingType == "Vuokralla") _expenses['Kotivakuutus'] = (value ?? 0.0) / 12;
      if (_housingType == "Omakotitalossa") _expenses['Kotivakuutus'] = (value ?? 0.0) / 12;
      break;
    case "Paljonko maksat asuntolainaa kuukaudessa (jos ei lainaa, syötä 0)?":
      if (_expenses.containsKey('Asuntolaina')) _expenses['Asuntolaina'] = value ?? 0.0;
      break;
    case "Paljonko lämmityskulusi ovat kuukaudessa?":
      if (_expenses.containsKey('Lämmitys')) _expenses['Lämmitys'] = value ?? 0.0;
      break;
    case "Paljonko kiinteistöverosi on vuodessa?":
      if (_expenses.containsKey('Kiinteistövero')) _expenses['Kiinteistövero'] = (value ?? 0.0) / 12;
      break;
    case "Paljonko maksat jätehuollosta kuukaudessa?":
      if (_expenses.containsKey('Jätehuolto')) _expenses['Jätehuolto'] = value ?? 0.0;
      break;
    case "Onko sinulla autoa?":
      _carOwnership = response;
      if (response == "Kyllä") {
        _expenses['Polttoaine'] = 0.0;
        _expenses['Autovakuutus'] = 0.0;
        _expenses['Ajoneuvovero'] = 0.0;
        _expenses['Auton huolto'] = 0.0;
      }
      break;
    case "Onko autosi oma vai maksatko siitä rahoitusta?":
      if (response == "Rahoitettu") {
        _expenses['Auton rahoitus'] = 0.0;
        _hasCarLoan = true;
      } else {
        _hasCarLoan = false;
      }
      break;
    case "Paljonko maksat Auton rahoitusta kuukaudessa?":
      if (_expenses.containsKey('Auton rahoitus')) _expenses['Auton rahoitus'] = value ?? 0.0;
      break;
    case "Vuokraatko autopaikkaa (esim. pihapaikka, autotalli)?":
      _rentsParkingSpace = response == "Kyllä";
      if (_rentsParkingSpace) _expenses['AutopaikanVuokra'] = 0.0;
      break;
    case "Paljonko maksat autopaikan vuokraa kuukaudessa?":
      if (_expenses.containsKey('AutopaikanVuokra')) _expenses['AutopaikanVuokra'] = value ?? 0.0;
      break;
    case "Paljonko auton polttoainekulut ovat kuukaudessa?":
      if (_carOwnership == "Kyllä") _expenses['Polttoaine'] = value ?? 0.0;
      break;
    case "Paljonko auton vakuutukset maksavat vuodessa?":
      if (_carOwnership == "Kyllä") _expenses['Autovakuutus'] = (value ?? 0.0) / 12;
      break;
    case "Paljonko maksat ajoneuvoveroa vuodessa?":
      if (_carOwnership == "Kyllä") _expenses['Ajoneuvovero'] = (value ?? 0.0) / 12;
      break;
    case "Onko sinulla renkaiden vaihto- ja säilytyspalvelu?":
      _hasTireService = response == "Kyllä";
      if (_hasTireService) _expenses['Renkaiden vaihto ja säilytys'] = 0.0;
      break;
    case "Paljonko maksat renkaiden vaihto- ja säilytyspalvelusta vuodessa?":
      if (_expenses.containsKey('Renkaiden vaihto ja säilytys')) _expenses['Renkaiden vaihto ja säilytys'] = (value ?? 0.0) / 12;
      break;
    case "Haluatko syöttää auton huolto- ja korjauskulut itse vai käyttää suomalaisten keskimääräisiä kuluja?":
      _useAverageCarMaintenance = response == "Käytä suomalaisten keskim. huolto- ja korjauskustannuksia (1070 € vuodessa)";
      if (_useAverageCarMaintenance) _expenses['Auton huolto'] = 1070.0 / 12;
      break;
    case "Paljonko auton huolto- ja korjauskulut ovat vuodessa?":
      if (_carOwnership == "Kyllä") _expenses['Auton huolto'] = (value ?? 0.0) / 12;
      break;
    case "Paljonko sähkölaskusi on keskimäärin kuukaudessa?":
      _expenses['Sähkö'] = value ?? 0.0;
      break;
    case "Onko sinulla kuukausimaksullisia palveluita (esim. Netflix, Spotify)?":
      if (response == "Kyllä") _expenses['Viihde-Palvelut'] = 0.0;
      break;
    case "Paljonko palveluihin menee rahaa kuukaudessa?":
      if (_expenses.containsKey('Viihde-Palvelut')) _expenses['Viihde-Palvelut'] = value ?? 0.0;
      break;
    case "Paljonko varaat ruokaan ja päivittäistavaroihin kuukaudessa?":
      _expenses['Ruoka'] = value ?? 0.0;
      break;
    case "Paljonko käytät rahaa terveyteen liittyviin kuluihin kuukaudessa (esim. lääkärikäynnit, lääkkeet)?":
      _expenses['Terveys'] = value ?? 0.0;
      break;
    case "Paljonko käytät rahaa hygieniaan liittyviin kuluihin kuukaudessa (esim. puhdistusaineet, WC-paperit, muut vessassa ja keittiössä tarvittavat kulutustuotteet)?":
      _expenses['Hygienia'] = value ?? 0.0;
      break;
    case "Paljonko käytät rahaa harrastuksiin kuukaudessa (esim. urheilu, kulttuuri, pelit)?":
      _expenses['Harrastukset'] = value ?? 0.0;
      break;
    case "Onko sinulla lemmikkejä?":
      _hasPets = response == "Kyllä";
      if (_hasPets) _expenses['Lemmikit'] = 0.0;
      break;
    case "Paljonko lemmikeistä aiheutuu kuluja kuukaudessa (esim. ruoka, tarvikkeet, eläinlääkäri)?":
      if (_expenses.containsKey('Lemmikit')) _expenses['Lemmikit'] = value ?? 0.0;
      break;
    case "Paljonko maksat puhelinlaskua kuukaudessa?":
      _expenses['Puhelinlasku'] = value ?? 0.0;
      break;
    case "Paljonko maksat nettiliittymästä kuukaudessa?":
      _expenses['Nettiliittymä'] = value ?? 0.0;
      break;
    case "Maksatko muita kuukausittaisia velkoja autorahoituksen lisäksi? (Kyllä/Ei)":
    case "Maksatko kuukausittain velkoja (Esim. osamaksuja)? (Kyllä/Ei)":
    case "Maksatko kuukausittain muita velkoja (Esim. osamaksuja) kuin omakotitalovelkaa? (Kyllä/Ei)":
      _hasOtherDebts = response == "Kyllä";
      break;
    case "Paljonko maksat velkoja kuukausittain?":
      _debtAmount = value ?? 0.0;
      _expenses['Velat'] = value ?? 0.0; // Tallennetaan budjettiin
      break;
    case "Paljonko varaat kuukausittain säästämiseen tai sijoittamiseen?":
      _expenses['Sijoittaminen'] = value ?? 0.0;
      break;
    case "Onko muita säännöllisiä menoja?":
      _hasOtherExpenses = response == "Kyllä";
      if (_hasOtherExpenses) _expenses['Muut'] = 0.0;
      break;
    case "Paljonko muihin menoihin menee rahaa kuukaudessa?":
      if (_expenses.containsKey('Muut')) _expenses['Muut'] = value ?? 0.0;
      break;
  }
}

  Future<void> saveBudget(BuildContext context, String userId) async {
    if (_isCompleted) {
      final budget = BudgetModel(
        income: _income,
        expenses: _expenses,
        createdAt: DateTime.now(),
        year: DateTime.now().year,
        month: DateTime.now().month,
      );
      print('Saving budget: ${budget.toMap()}');
      await Provider.of<BudgetProvider>(context, listen: false).saveBudget(userId, budget);
    }
  }
}