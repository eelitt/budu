import 'package:flutter/material.dart';
import 'chatbot_questions.dart';
import 'chatbot_response_processor.dart';
import 'chatbot_options.dart';
import 'chatbot_budget_saver.dart';
import '../models/chat_message.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class ChatbotProvider with ChangeNotifier {
  List<ChatMessage> _messages = [];
  int _step = 0;
  Map<String, Map<String, double>> _expenses = {};
  double _income = 0.0;
  bool _isCompleted = false;
  bool _isMultipleChoice = false;
  List<String> _currentOptions = [];
  String? _budgetType; // monthly, biweekly
  String? _housingType;
  String? _carOwnership;
  bool _rentsParkingSpace = false;
  bool _hasPets = false;
  bool _hasCarLoan = false;
  bool _hasOtherDebts = false;
  double _debtAmount = 0.0;
  DateTime? _startDate;
  DateTime? _endDate;

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
      text: "Haluatko luoda kuukausibudjetin vai 2 viikon budjetin?",
      isUser: false,
      createdAt: DateTime.now(),
    ));
    _isMultipleChoice = true;
    _currentOptions = ["Kuukausi", "2 viikkoa"];
    notifyListeners();
  }

  void handleUserResponse(String response, BuildContext context) {
    _messages.add(ChatMessage(
      text: response,
      isUser: true,
      createdAt: DateTime.now(),
    ));
    notifyListeners();

    final questions = _getQuestions();
    final currentQuestion = questions[_step];

    if (_isMultipleChoice) {
      if (!_currentOptions.contains(response)) {
        _messages.add(ChatMessage(
          text: "Valitse yksi vaihtoehdoista: ${_currentOptions.join(', ')}",
          isUser: false,
          createdAt: DateTime.now(),
        ));
        notifyListeners();
        return;
      }
      _processResponse(response, context);
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

      // Maksimiarvon validointi
      double maxValue = currentQuestion.contains("tuloja") ? 100000.0 : 10000.0;
      if (value > maxValue) {
        _messages.add(ChatMessage(
          text: "Syötä pienempi arvo (maksimi $maxValue €). Yritä uudelleen.",
          isUser: false,
          createdAt: DateTime.now(),
        ));
        notifyListeners();
        return;
      }

      _processResponse(response, context);
      _step++;
    }

    final updatedQuestions = _getQuestions();
    if (_step < updatedQuestions.length) {
      _askNextQuestion();
    } else if (_step == updatedQuestions.length) {
      _isCompleted = true;
      _messages.add(ChatMessage(
        text: "Budjetti valmis! Tallennetaan budjetti ajanjaksolle ${_budgetType == 'monthly' ? 'kuukausi' : '2 viikkoa'}.",
        isUser: false,
        createdAt: DateTime.now(),
      ));
      notifyListeners();
    }
  }

  List<String> _getQuestions() {
    return ChatbotQuestions(
      budgetType: _budgetType,
      housingType: _housingType,
      carOwnership: _carOwnership,
      rentsParkingSpace: _rentsParkingSpace,
      hasTireService: false,
      useAverageCarMaintenance: false,
      hasPets: _hasPets,
      hasOtherExpenses: false,
      hasCarLoan: _hasCarLoan,
      hasOtherDebts: _hasOtherDebts,
      expenses: _expenses,
    ).getQuestions();
  }

  void _processResponse(String response, BuildContext context) {
    final questions = _getQuestions();
    final processor = ChatbotResponseProcessor(
      questions: questions,
      expenses: _expenses,
      income: _income,
      budgetType: _budgetType,
      housingType: _housingType,
      carOwnership: _carOwnership,
      rentsParkingSpace: _rentsParkingSpace,
      hasTireService: false,
      useAverageCarMaintenance: false,
      hasPets: _hasPets,
      hasOtherExpenses: false,
      hasCarLoan: _hasCarLoan,
      hasOtherDebts: _hasOtherDebts,
      debtAmount: _debtAmount,
      startDate: _startDate,
      endDate: _endDate,
    );
    processor.processResponse(response, _step, context);
    _income = processor.income;
    _budgetType = processor.budgetType;
    _housingType = processor.housingType;
    _carOwnership = processor.carOwnership;
    _rentsParkingSpace = processor.rentsParkingSpace;
    _hasPets = processor.hasPets;
    _hasCarLoan = processor.hasCarLoan;
    _hasOtherDebts = processor.hasOtherDebts;
    _debtAmount = processor.debtAmount;
    _startDate = processor.startDate;
    _endDate = processor.endDate;
  }

  void _askNextQuestion() {
    final questions = _getQuestions();
    if (_step < questions.length) {
      _isMultipleChoice = questions[_step] == "Haluatko luoda kuukausibudjetin vai 2 viikon budjetin?" ||
          questions[_step] == "Mikä seuraavista kuvaa parhaiten asumistasi?" ||
          questions[_step] == "Onko sinulla autoa?" ||
          questions[_step] == "Onko autosi oma vai maksatko siitä rahoitusta?" ||
          questions[_step] == "Vuokraatko autopaikkaa?" ||
          questions[_step] == "Onko sinulla lemmikki/lemmikkejä?" ||
          questions[_step] == "Maksatko muita kuukausittaisia velkoja autorahoituksen ja asuntolainan lisäksi?" ||
          questions[_step] == "Maksatko asuntolainan lisäksi muita velkoja?" ||
          questions[_step] == "Maksatko muita kuukausittaisia velkoja autorahoituksen lisäksi?" ||
          questions[_step] == "Onko sinulla velkoja?";
      _currentOptions = ChatbotOptions(questions: questions, step: _step).getOptionsForStep();
      _messages.add(ChatMessage(
        text: questions[_step],
        isUser: false,
        createdAt: DateTime.now(),
      ));
      notifyListeners();
    }
  }

  Future<void> saveBudget(BuildContext context, String userId) async {
    if (_startDate == null || _endDate == null || _budgetType == null) {
      await FirebaseCrashlytics.instance.log('Chatbot: Budjetin tallennus epäonnistui, aikaväli tai tyyppi puuttuu');
      _messages.add(ChatMessage(
        text: "Budjetin tallennus epäonnistui: Valitse budjetin tyyppi ja aikaväli.",
        isUser: false,
        createdAt: DateTime.now(),
      ));
      notifyListeners();
      return;
    }
    await ChatbotBudgetSaver(
      isCompleted: _isCompleted,
      income: _income,
      expenses: _expenses,
      budgetType: _budgetType!,
      startDate: _startDate!,
      endDate: _endDate!,
    ).saveBudget(context, userId);
  }
}