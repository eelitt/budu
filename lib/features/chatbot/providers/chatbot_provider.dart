import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../../budget/models/budget_model.dart';
import '../../budget/providers/budget_provider.dart';


class ChatbotProvider with ChangeNotifier {
  List<ChatMessage> _messages = [];
  int _step = 0;
  Map<String, Map<String, double>> _expenses = {};
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

    final questions = _getQuestions();
    final currentQuestion = questions[_step];
    if (_isMultipleChoice) {
      _processResponse(response);
      _step++;
    } else {
      double? value = double.tryParse(response.replaceAll('€', '').trim());
      if (value == null || value < 0) {
        _messages.add(ChatMessage(
          text: "Syötä kelvollinen positiivinen numero (esim. 100). Yritä uudelleen.",
          isUser: false,
          createdAt: DateTime.now(),
        ));
        notifyListeners();
        return;
      }
      _processResponse(response);
      _step++;
    }

    final updatedQuestions = _getQuestions();
    if (_step < updatedQuestions.length) {
      _askNextQuestion();
    } else {
      if (_hasOtherExpenses && _expenses.containsKey('Muut') && _expenses['Muut']!['Muut']! >= 0) {
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
      if (_expenses.containsKey('Liikkuminen') && _expenses['Liikkuminen']!.containsKey('Auton rahoitus')) {
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

    if (_expenses.containsKey('Viihde') && _expenses['Viihde']!.containsKey('Viihde-Palvelut')) {
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

    if (_housingType == "Vuokralla") {
      if (_carOwnership == "Kyllä" && _hasCarLoan) {
        questions.add("Maksatko muita kuukausittaisia velkoja autorahoituksen lisäksi? (Kyllä/Ei)");
      } else {
        questions.add("Maksatko kuukausittain velkoja (Esim. osamaksuja)? (Kyllä/Ei)");
      }
    } else if (_housingType == "Omakotitalossa") {
      if (_expenses['Asuminen']?['Asuntolaina'] != null && _expenses['Asuminen']!['Asuntolaina']! > 0) {
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

    questions.add("Onko muita säännöllisiä menoja?");
    if (_expenses.containsKey('Muut') && _expenses['Muut']!.containsKey('Muut')) {
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
          questions[_step].contains("(Kyllä/Ei)");
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
          _expenses['Asuminen'] = {
            'Vuokra': 0.0,
            'Vesimaksu': 0.0,
            'Kotivakuutus': 0.0,
          };
        }
        if (response == "Omakotitalossa") {
          _expenses['Asuminen'] = {
            'Asuntolaina': 0.0,
            'Lämmitys': 0.0,
            'Kiinteistövero': 0.0,
            'Jätehuolto': 0.0,
            'Kotivakuutus': 0.0,
          };
        }
        break;
      case "Paljonko maksat vuokraa kuukaudessa?":
        if (_expenses.containsKey('Asuminen')) _expenses['Asuminen']!['Vuokra'] = value ?? 0.0;
        break;
      case "Paljonko maksat vesimaksua kuukaudessa (jos sisältyy vuokraan, syötä 0)?":
        if (_housingType == "Vuokralla") _expenses['Asuminen']!['Vesimaksu'] = value ?? 0.0;
        break;
      case "Paljonko kotivakuutuksesi maksaa vuodessa?":
        if (_housingType == "Vuokralla") _expenses['Asuminen']!['Kotivakuutus'] = (value ?? 0.0) / 12;
        if (_housingType == "Omakotitalossa") _expenses['Asuminen']!['Kotivakuutus'] = (value ?? 0.0) / 12;
        break;
      case "Paljonko maksat asuntolainaa kuukaudessa (jos ei lainaa, syötä 0)?":
        if (_expenses.containsKey('Asuminen')) _expenses['Asuminen']!['Asuntolaina'] = value ?? 0.0;
        break;
      case "Paljonko lämmityskulusi ovat kuukaudessa?":
        if (_expenses.containsKey('Asuminen')) _expenses['Asuminen']!['Lämmitys'] = value ?? 0.0;
        break;
      case "Paljonko kiinteistöverosi on vuodessa?":
        if (_expenses.containsKey('Asuminen')) _expenses['Asuminen']!['Kiinteistövero'] = (value ?? 0.0) / 12;
        break;
      case "Paljonko maksat jätehuollosta kuukaudessa?":
        if (_expenses.containsKey('Asuminen')) _expenses['Asuminen']!['Jätehuolto'] = value ?? 0.0;
        break;
      case "Onko sinulla autoa?":
        _carOwnership = response;
        if (response == "Kyllä") {
          _expenses['Liikkuminen'] = {
            'Polttoaine': 0.0,
            'Autovakuutus': 0.0,
            'Ajoneuvovero': 0.0,
            'Auton huolto': 0.0,
          };
        }
        break;
      case "Onko autosi oma vai maksatko siitä rahoitusta?":
        if (response == "Rahoitettu") {
          if (_expenses.containsKey('Liikkuminen')) {
            _expenses['Liikkuminen']!['Auton rahoitus'] = 0.0;
          }
          _hasCarLoan = true;
        } else {
          _hasCarLoan = false;
        }
        break;
      case "Paljonko maksat Auton rahoitusta kuukaudessa?":
        if (_expenses.containsKey('Liikkuminen')) _expenses['Liikkuminen']!['Auton rahoitus'] = value ?? 0.0;
        break;
      case "Vuokraatko autopaikkaa (esim. pihapaikka, autotalli)?":
        _rentsParkingSpace = response == "Kyllä";
        if (_rentsParkingSpace) {
          if (_expenses.containsKey('Liikkuminen')) {
            _expenses['Liikkuminen']!['AutopaikanVuokra'] = 0.0;
          }
        }
        break;
      case "Paljonko maksat autopaikan vuokraa kuukaudessa?":
        if (_expenses.containsKey('Liikkuminen')) _expenses['Liikkuminen']!['AutopaikanVuokra'] = value ?? 0.0;
        break;
      case "Paljonko auton polttoainekulut ovat kuukaudessa?":
        if (_carOwnership == "Kyllä") _expenses['Liikkuminen']!['Polttoaine'] = value ?? 0.0;
        break;
      case "Paljonko auton vakuutukset maksavat vuodessa?":
        if (_carOwnership == "Kyllä") _expenses['Liikkuminen']!['Autovakuutus'] = (value ?? 0.0) / 12;
        break;
      case "Paljonko maksat ajoneuvoveroa vuodessa?":
        if (_carOwnership == "Kyllä") _expenses['Liikkuminen']!['Ajoneuvovero'] = (value ?? 0.0) / 12;
        break;
      case "Onko sinulla renkaiden vaihto- ja säilytyspalvelu?":
        _hasTireService = response == "Kyllä";
        if (_hasTireService) {
          if (_expenses.containsKey('Liikkuminen')) {
            _expenses['Liikkuminen']!['Renkaiden vaihto ja säilytys'] = 0.0;
          }
        }
        break;
      case "Paljonko maksat renkaiden vaihto- ja säilytyspalvelusta vuodessa?":
        if (_expenses.containsKey('Liikkuminen')) _expenses['Liikkuminen']!['Renkaiden vaihto ja säilytys'] = (value ?? 0.0) / 12;
        break;
      case "Haluatko syöttää auton huolto- ja korjauskulut itse vai käyttää suomalaisten keskimääräisiä kuluja?":
        _useAverageCarMaintenance = response == "Käytä suomalaisten keskim. huolto- ja korjauskustannuksia (1070 € vuodessa)";
        if (_useAverageCarMaintenance) _expenses['Liikkuminen']!['Auton huolto'] = 1070.0 / 12;
        break;
      case "Paljonko auton huolto- ja korjauskulut ovat vuodessa?":
        if (_carOwnership == "Kyllä") _expenses['Liikkuminen']!['Auton huolto'] = (value ?? 0.0) / 12;
        break;
      case "Paljonko sähkölaskusi on keskimäärin kuukaudessa?":
        _expenses['Kodin kulut'] = {
          'Sähkö': value ?? 0.0,
          'Nettiliittymä': 0.0,
          'Puhelinlasku': 0.0,
        };
        break;
      case "Onko sinulla kuukausimaksullisia palveluita (esim. Netflix, Spotify)?":
        if (response == "Kyllä") _expenses['Viihde'] = {'Viihde-Palvelut': 0.0};
        break;
      case "Paljonko palveluihin menee rahaa kuukaudessa?":
        if (_expenses.containsKey('Viihde')) _expenses['Viihde']!['Viihde-Palvelut'] = value ?? 0.0;
        break;
      case "Paljonko varaat ruokaan ja päivittäistavaroihin kuukaudessa?":
        _expenses['Ruoka'] = {'Ruoka': value ?? 0.0};
        break;
      case "Paljonko käytät rahaa terveyteen liittyviin kuluihin kuukaudessa (esim. lääkärikäynnit, lääkkeet)?":
        _expenses['Terveys'] = {'Terveys': value ?? 0.0};
        break;
      case "Paljonko käytät rahaa hygieniaan liittyviin kuluihin kuukaudessa (esim. puhdistusaineet, WC-paperit, muut vessassa ja keittiössä tarvittavat kulutustuotteet)?":
        _expenses['Hygienia'] = {'Hygienia': value ?? 0.0};
        break;
      case "Paljonko käytät rahaa harrastuksiin kuukaudessa (esim. urheilu, kulttuuri, pelit)?":
        _expenses['Harrastukset'] = {'Harrastukset': value ?? 0.0};
        break;
      case "Onko sinulla lemmikkejä?":
        _hasPets = response == "Kyllä";
        if (_hasPets) _expenses['Lemmikit'] = {'Lemmikit': 0.0};
        break;
      case "Paljonko lemmikeistä aiheutuu kuluja kuukaudessa (esim. ruoka, tarvikkeet, eläinlääkäri)?":
        if (_expenses.containsKey('Lemmikit')) _expenses['Lemmikit']!['Lemmikit'] = value ?? 0.0;
        break;
      case "Paljonko maksat puhelinlaskua kuukaudessa?":
        if (_expenses.containsKey('Kodin kulut')) _expenses['Kodin kulut']!['Puhelinlasku'] = value ?? 0.0;
        break;
      case "Paljonko maksat nettiliittymästä kuukaudessa?":
        if (_expenses.containsKey('Kodin kulut')) _expenses['Kodin kulut']!['Nettiliittymä'] = value ?? 0.0;
        break;
      case "Maksatko muita kuukausittaisia velkoja autorahoituksen lisäksi? (Kyllä/Ei)":
      case "Maksatko kuukausittain velkoja (Esim. osamaksuja)? (Kyllä/Ei)":
      case "Maksatko kuukausittain muita velkoja (Esim. osamaksuja) kuin omakotitalovelkaa? (Kyllä/Ei)":
        _hasOtherDebts = response == "Kyllä";
        break;
      case "Paljonko maksat velkoja kuukausittain?":
        _debtAmount = value ?? 0.0;
        _expenses['Velat'] = {'Velat': value ?? 0.0};
        break;
      case "Paljonko varaat kuukausittain säästämiseen tai sijoittamiseen?":
        _expenses['Sijoittaminen'] = {'Sijoittaminen': value ?? 0.0};
        break;
      case "Onko muita säännöllisiä menoja?":
        _hasOtherExpenses = response == "Kyllä";
        if (_hasOtherExpenses) _expenses['Muut'] = {'Muut': 0.0};
        break;
      case "Paljonko muihin menoihin menee rahaa kuukaudessa?":
        if (_expenses.containsKey('Muut')) _expenses['Muut']!['Muut'] = value ?? 0.0;
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