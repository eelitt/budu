import 'package:budu/core/app_router/app_router.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/screens/create_budget/budget_calculator.dart';
import 'package:budu/features/budget/screens/create_budget/budget_initializer.dart';
import 'package:budu/features/budget/screens/create_budget/budget_saver.dart';
import 'package:budu/features/budget/screens/create_budget/sections/create_budget_income_section.dart';
import 'package:budu/features/budget/screens/create_budget/sections/expense_section.dart';
import 'package:budu/features/budget/screens/create_budget/save_button.dart';
import 'package:budu/features/budget/screens/create_budget/sections/create_budget_summary_section.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Näkymä, jossa käyttäjä voi luoda uuden budjetin.
/// Näyttää tulot, menot ja yhteenvedon, ja tallentaa budjetin Firestoreen.
class CreateBudgetScreen extends StatefulWidget {
  final BudgetModel? sourceBudget; // Lähdebudjetti, josta tiedot kopioidaan (valinnainen)
  final int newYear; // Uuden budjetin vuosi
  final int newMonth; // Uuden budjetin kuukausi

  const CreateBudgetScreen({
    super.key,
    this.sourceBudget,
    required this.newYear,
    required this.newMonth,
  });

  @override
  State<CreateBudgetScreen> createState() => _CreateBudgetScreenState();
}

/// CreateBudgetScreenin tilallinen tila, joka hallinnoi budjetin luontisivun tilaa ja logiikkaa.
class _CreateBudgetScreenState extends State<CreateBudgetScreen> {
  late TextEditingController _incomeController; // Tekstikentän ohjain tulojen syöttämiseen
  final Map<String, Map<String, TextEditingController>> _expenseControllers = {}; // Kategorioiden ja alakategorioiden ohjaimet
  String? _errorMessage; // Virheviesti tallennuksen epäonnistuessa
  late BudgetInitializer _initializer; // Budjetin alustaja
  late BudgetCalculator _calculator; // Budjetin laskin
  late BudgetSaver _saver; // Budjetin tallentaja

  @override
  void initState() {
    super.initState();
    // Alustetaan tulojen ohjain
    _incomeController = TextEditingController();
    // Alustetaan BudgetInitializer budjetin tietojen lataamista ja kuuntelijoiden asettamista varten
    _initializer = BudgetInitializer(
      sourceBudget: widget.sourceBudget,
      incomeController: _incomeController,
      expenseControllers: _expenseControllers,
      updateSummary: () => _calculator.updateSummary(),
    );
    _initializer.initialize();
    // Alustetaan BudgetCalculator tulojen ja menojen laskemista ja yhteenvedon päivitystä varten
    _calculator = BudgetCalculator(
      incomeController: _incomeController,
      expenseControllers: _expenseControllers,
      setStateCallback: () => setState(() {}),
    );
    // Alustetaan BudgetSaver budjetin tallentamista ja validointia varten
    _saver = BudgetSaver(
      context: context,
      incomeController: _incomeController,
      expenseControllers: _expenseControllers,
      newYear: widget.newYear,
      newMonth: widget.newMonth,
      totalIncome: _calculator.totalIncome,
      totalExpenses: _calculator.totalExpenses,
    );
  }

  @override
  void dispose() {
    // Vapautetaan resurssit ja poistetaan kuuntelijat
    _initializer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Haetaan AuthProvider ja BudgetProvider kontekstista
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final userId = authProvider.user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text('Luo budjetti (${widget.newMonth}/${widget.newYear})'), // Näyttää budjetin ajankohdan
        leading: userId != null
            ? FutureBuilder<List<Map<String, int>>>(
                future: budgetProvider.getAvailableBudgetMonths(userId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    // Näytetään latausindikaattori, jos budjettikuukausia ladataan
                    return const Material(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  // Tarkistetaan, onko budjetteja olemassa
                  final hasBudgets = snapshot.hasData && snapshot.data!.isNotEmpty;
                  return IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      if (hasBudgets) {
                        // Navigoidaan pääsivulle, jos budjetteja on olemassa
                        Navigator.pushNamed(
                          context,
                          AppRouter.mainRoute,
                          arguments: {'index': 0},
                        );
                      } else {
                        // Navigoidaan chatbot-sivulle, jos budjetteja ei ole
                        Navigator.pushNamed(
                          context,
                          AppRouter.chatbotRoute,
                        );
                      }
                    },
                  );
                },
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  // Navigoidaan chatbot-sivulle, jos käyttäjää ei ole autentikoitu
                  Navigator.pushNamed(
                    context,
                    AppRouter.chatbotRoute,
                  );
                },
              ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0), // Sisäinen välistys
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tulot-osio
            IncomeSection(incomeController: _incomeController),
            const SizedBox(height: 24), // Väli osioiden välillä
            // Menot-osio (kategoriat ja alakategoriat)
            ExpensesSection(
              expenseControllers: _expenseControllers,
              onUpdate: () => setState(() {}),
            ),
            // Näyttää virheviestin, jos tallennus epäonnistuu
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ],
            const SizedBox(height: 24), // Väli osioiden välillä
            // Yhteenveto-osio (tulot ja menot yhteensä)
            SummarySection(
              totalIncome: _calculator.totalIncome,
              totalExpenses: _calculator.totalExpenses,
            ),
            const SizedBox(height: 24), // Väli osioiden välillä
            // Tallenna-painike budjetin tallentamiseen
            SaveButton(
              onPressed: () async {
                await _saver.createBudget();
                setState(() {
                  _errorMessage = _saver.errorMessage;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}