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
  bool _hasPets = false;
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
      text: "Paljonko saat tuloja kuukaudessa (esim. palkka, tuet, pääomatulot)?",
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
    notifyListeners(); // Ilmoitetaan viestin lisäyksestä

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
        notifyListeners(); // Ilmoitetaan virheilmoituksen lisäyksestä
        return;
      }
      _processResponse(response);
      _step++;
    }

    final updatedQuestions = _getQuestions();
    if (_step < updatedQuestions.length) {
      _askNextQuestion();
    } else if (_step == updatedQuestions.length) {
      _isCompleted = true;
      notifyListeners(); // Ilmoitetaan, että chatbot on valmis
    }
  }

  List<String> _getQuestions() {
    return ChatbotQuestions(
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

  void _processResponse(String response) {
    final questions = _getQuestions();
    final processor = ChatbotResponseProcessor(
      questions: questions,
      expenses: _expenses,
      income: _income,
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
    );
    processor.processResponse(response, _step);
    _income = processor.income;
    _housingType = processor.housingType;
    _carOwnership = processor.carOwnership;
    _rentsParkingSpace = processor.rentsParkingSpace;
    _hasPets = processor.hasPets;
    _hasCarLoan = processor.hasCarLoan;
    _hasOtherDebts = processor.hasOtherDebts;
    _debtAmount = processor.debtAmount;
  }

  void _askNextQuestion() {
    final questions = _getQuestions();
    if (_step < questions.length) {
      _isMultipleChoice = questions[_step] == "Mikä seuraavista kuvaa parhaiten asumistasi?" ||
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
      notifyListeners(); // Ilmoitetaan uuden kysymyksen lisäyksestä
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