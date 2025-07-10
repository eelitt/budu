import 'package:budu/core/app_router/app_router.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/screens/create_budget/budget_calculator.dart';
import 'package:budu/features/budget/screens/create_budget/budget_initializer.dart';
import 'package:budu/features/budget/screens/create_budget/budget_saver.dart';
import 'package:budu/features/budget/screens/create_budget/sections/budget_date_section.dart';
import 'package:budu/features/budget/screens/create_budget/sections/create_budget_income_section.dart';
import 'package:budu/features/budget/screens/create_budget/sections/expense_section.dart';
import 'package:budu/features/budget/screens/create_budget/save_button.dart';
import 'package:budu/features/budget/screens/create_budget/sections/create_budget_summary_section.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Näkymä, jossa käyttäjä voi luoda uuden budjetin.
/// Näyttää aikavälin valinnan, tulot, menot ja yhteenvedon, ja tallentaa budjetin Firestoreen.
class CreateBudgetScreen extends StatefulWidget {
  final BudgetModel? sourceBudget; // Lähdebudjetti, josta tiedot kopioidaan (valinnainen)

  const CreateBudgetScreen({
    super.key,
    this.sourceBudget,
  });

  @override
  State<CreateBudgetScreen> createState() => _CreateBudgetScreenState();
}

class _CreateBudgetScreenState extends State<CreateBudgetScreen> {
  late TextEditingController _incomeController; // Tekstikentän ohjain tulojen syöttämiseen
  final Map<String, Map<String, TextEditingController>> _expenseControllers = {}; // Kategorioiden ja alakategorioiden ohjaimet
  String? _errorMessage; // Virheviesti tallennuksen epäonnistuessa
  late BudgetInitializer _initializer; // Budjetin alustaja
  late BudgetCalculator _calculator; // Budjetin laskin
  late BudgetSaver _saver; // Budjetin tallentaja
  DateTime? _startDate; // Valittu aloituspäivä
  DateTime? _endDate; // Valittu päättymispäivä
  String? _type; // Valittu budjetin tyyppi

  @override
  void initState() {
    super.initState();
    _incomeController = TextEditingController();
    _initializer = BudgetInitializer(
      sourceBudget: widget.sourceBudget,
      incomeController: _incomeController,
      expenseControllers: _expenseControllers,
      updateSummary: () => _calculator.updateSummary(),
    );
    _calculator = BudgetCalculator(
      incomeController: _incomeController,
      expenseControllers: _expenseControllers,
      setStateCallback: () => setState(() {}),
    );
    _initializer.initialize();
    // Alustetaan BudgetSaver oletusarvoilla, päivitetään aikavälin valinnan jälkeen
    _saver = BudgetSaver(
      context: context,
      incomeController: _incomeController,
      expenseControllers: _expenseControllers,
      startDate: DateTime.now(),
      endDate: DateTime.now(),
      type: 'monthly',
      totalIncome: _calculator.totalIncome,
      totalExpenses: _calculator.totalExpenses,
    );
  }

  @override
  void dispose() {
    _initializer.dispose();
    _incomeController.dispose();
    _expenseControllers.forEach((_, subControllers) {
      subControllers.forEach((_, controller) => controller.dispose());
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final userId = authProvider.user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text('Luo budjetti'),
        leading: userId != null
            ? FutureBuilder<List<BudgetModel>>(
                future: budgetProvider.getAvailableBudgets(userId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Material(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final hasBudgets = snapshot.hasData && snapshot.data!.isNotEmpty;
                  return IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      if (hasBudgets) {
                        Navigator.pushNamed(
                          context,
                          AppRouter.mainRoute,
                          arguments: {'index': 0},
                        );
                      } else {
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
                  Navigator.pushNamed(
                    context,
                    AppRouter.chatbotRoute,
                  );
                },
              ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Otsikko budjetin aikavälille
            const Text(
              'Budjetin aikaväli',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Aikavälin valinta
            BudgetDateSection(
              onTypeChanged: (type) {
                if (mounted) {
                  setState(() {
                    _type = type;
                    // Päivitä BudgetSaver
                    _saver = BudgetSaver(
                      context: context,
                      incomeController: _incomeController,
                      expenseControllers: _expenseControllers,
                      startDate: _startDate ?? DateTime.now(),
                      endDate: _endDate ?? DateTime.now(),
                      type: _type ?? 'monthly',
                      totalIncome: _calculator.totalIncome,
                      totalExpenses: _calculator.totalExpenses,
                    );
                  });
                }
              },
              onStartDateChanged: (startDate) {
                if (mounted) {
                  setState(() {
                    _startDate = startDate;
                    // Päivitä BudgetSaver
                    _saver = BudgetSaver(
                      context: context,
                      incomeController: _incomeController,
                      expenseControllers: _expenseControllers,
                      startDate: _startDate ?? DateTime.now(),
                      endDate: _endDate ?? DateTime.now(),
                      type: _type ?? 'monthly',
                      totalIncome: _calculator.totalIncome,
                      totalExpenses: _calculator.totalExpenses,
                    );
                  });
                }
              },
              onEndDateChanged: (endDate) {
                if (mounted) {
                  setState(() {
                    _endDate = endDate;
                    // Päivitä BudgetSaver
                    _saver = BudgetSaver(
                      context: context,
                      incomeController: _incomeController,
                      expenseControllers: _expenseControllers,
                      startDate: _startDate ?? DateTime.now(),
                      endDate: _endDate ?? DateTime.now(),
                      type: _type ?? 'monthly',
                      totalIncome: _calculator.totalIncome,
                      totalExpenses: _calculator.totalExpenses,
                    );
                  });
                }
              },
            ),
            const SizedBox(height: 24),
            // Tulot-osio
            IncomeSection(incomeController: _incomeController),
            const SizedBox(height: 24),
            // Menot-osio
            ExpensesSection(
              expenseControllers: _expenseControllers,
              onUpdate: () => setState(() {}),
            ),
            // Näyttää virheviestin
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ],
            const SizedBox(height: 24),
            // Yhteenveto-osio
            SummarySection(
              totalIncome: _calculator.totalIncome,
              totalExpenses: _calculator.totalExpenses,
              startDate: _startDate,
              endDate: _endDate,
            ),
            const SizedBox(height: 24),
            // Tallenna-painike
            SaveButton(
              onPressed: () async {
                if (_startDate == null || _endDate == null || _type == null) {
                  setState(() {
                    _errorMessage = 'Valitse budjetin tyyppi ja aikaväli';
                  });
                  await FirebaseCrashlytics.instance.log('Budjetin tallennus epäonnistui: Aikaväli tai tyyppi puuttuu');
                  return;
                }
                if (_startDate!.isAfter(_endDate!)) {
                  setState(() {
                    _errorMessage = 'Alkamispäivä ei voi olla päättymispäivän jälkeen';
                  });
                  await FirebaseCrashlytics.instance.log('Budjetin tallennus epäonnistui: Virheellinen aikaväli');
                  return;
                }
                await _saver.createBudget();
                if (mounted) {
                  setState(() {
                    _errorMessage = _saver.errorMessage;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}