import 'package:flutter/material.dart';
import 'chatbot_questions.dart';
import 'chatbot_response_processor.dart';
import 'chatbot_options.dart';
import 'chatbot_budget_saver.dart';
import '../models/chat_message.dart';

class ChatbotProvider with ChangeNotifier {
  List<ChatMessage> _messages = [];
  int _step = 0;
  Map<String, Map<String, double>> _expenses = {};
  double _income = 0.0;
  bool _isCompleted = false;
  bool _isMultipleChoice = false;
  List<String> _currentOptions = [];
  String? _housingType;
  String? _carOwnership;
  bool _rentsParkingSpace = false;
  bool _hasTireService = false;
  bool _useAverageCarMaintenance = false;
  bool _hasPets = false;
  bool _hasOtherExpenses = false;
  bool _hasCarLoan = false;
  bool _hasOtherDebts = false;
  double _debtAmount = 0.0;

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
    return ChatbotQuestions(
      housingType: _housingType,
      carOwnership: _carOwnership,
      rentsParkingSpace: _rentsParkingSpace,
      hasTireService: _hasTireService,
      useAverageCarMaintenance: _useAverageCarMaintenance,
      hasPets: _hasPets,
      hasOtherExpenses: _hasOtherExpenses,
      hasCarLoan: _hasCarLoan,
      hasOtherDebts: _hasOtherDebts,
      expenses: _expenses,
    ).getQuestions();
  }

  void _processResponse(String response) {
    final questions = _getQuestions();
    final processor = ChatbotResponseProcessor(
      questions: questions,
      expenses: _expenses,
      income: _income,
      housingType: _housingType,
      carOwnership: _carOwnership,
      rentsParkingSpace: _rentsParkingSpace,
      hasTireService: _hasTireService,
      useAverageCarMaintenance: _useAverageCarMaintenance,
      hasPets: _hasPets,
      hasOtherExpenses: _hasOtherExpenses,
      hasCarLoan: _hasCarLoan,
      hasOtherDebts: _hasOtherDebts,
      debtAmount: _debtAmount,
    );
    processor.processResponse(response, _step);
    _income = processor.income;
    _housingType = processor.housingType;
    _carOwnership = processor.carOwnership;
    _rentsParkingSpace = processor.rentsParkingSpace;
    _hasTireService = processor.hasTireService;
    _useAverageCarMaintenance = processor.useAverageCarMaintenance;
    _hasPets = processor.hasPets;
    _hasOtherExpenses = processor.hasOtherExpenses;
    _hasCarLoan = processor.hasCarLoan;
    _hasOtherDebts = processor.hasOtherDebts;
    _debtAmount = processor.debtAmount;
  }

  void _askNextQuestion() {
    final questions = _getQuestions();
    if (_step < questions.length) {
      _isMultipleChoice = questions[_step] == "Asutko vuokralla, omakotitalossa vai ilman asuntokuluja?" ||
          questions[_step] == "Onko sinulla autoa?" ||
          questions[_step] == "Onko sinulla kuukausimaksullisia palveluita, esimerkiksi Netflix tai Spotify?" ||
          questions[_step] == "Onko muita säännöllisiä menoja?" ||
          questions[_step] == "Onko autosi oma vai maksatko siitä rahoitusta?" ||
          questions[_step] == "Vuokraatko autopaikkaa, esimerkiksi pihapaikkaa tai autotallia?" ||
          questions[_step] == "Onko sinulla renkaiden vaihto- ja säilytyspalvelua?" ||
          questions[_step] == "Haluatko syöttää auton huolto- ja korjauskulut itse vai käyttää suomalaisten keskimääräisiä kuluja?" ||
          questions[_step] == "Onko sinulla lemmikkejä?" ||
          questions[_step] == "Maksatko muita kuukausittaisia velkoja autorahoituksen lisäksi?" ||
          questions[_step] == "Maksatko kuukausittain velkoja, esimerkiksi osamaksuja?" ||
          questions[_step] == "Maksatko kuukausittain omakotitalovelan lisäksi muita velkoja (Esim. osamaksuja)?";
      _currentOptions = ChatbotOptions(questions: questions, step: _step).getOptionsForStep();
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

  Future<void> saveBudget(BuildContext context, String userId) async {
    await ChatbotBudgetSaver(
      isCompleted: _isCompleted,
      income: _income,
      expenses: _expenses,
    ).saveBudget(context, userId);
  }
}