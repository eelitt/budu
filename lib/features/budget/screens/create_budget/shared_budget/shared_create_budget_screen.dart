import 'package:budu/core/app_router/app_router.dart';
import 'package:budu/core/utils.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/models/budget_model.dart'; // Päivitetty: Vain BudgetModel tarvitaan, koska mallit yhdistetty
import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:budu/features/budget/screens/create_budget/budget_calculator.dart';
import 'package:budu/features/budget/screens/create_budget/budget_initializer.dart';
import 'package:budu/features/budget/screens/create_budget/budget_saver.dart';
import 'package:budu/features/budget/screens/create_budget/sections/budget_date_section.dart';
import 'package:budu/features/budget/screens/create_budget/sections/create_budget_income_section.dart';
import 'package:budu/features/budget/screens/create_budget/sections/create_budget_summary_section.dart';
import 'package:budu/features/budget/screens/create_budget/sections/expense_section.dart';
import 'package:budu/features/budget/screens/create_budget/save_button.dart';
import 'package:budu/features/budget/screens/create_budget/shared_budget/invite_to_budget_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Lisätty batch-writea varten
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Näkymä yhteistalousbudjetin luomiseen tai muokkaamiseen.
/// Käyttää olemassa olevia komponentteja modulaarisuuden säilyttämiseksi.
/// Optimoitu Firestore-kirjoituksilla (batch) kulujen vähentämiseksi.
/// Päivitetty: Käytetään yhdistettyä BudgetModel:ia (sisältää shared-kentät), poistettu turha konversio.
/// Lisätty: Null-safety sharedBudget:iin (?. ja ??), 'isNew' check skippaamaan haku (optimoi kuluja uudelle budjetille).
class SharedCreateBudgetScreen extends StatefulWidget {
  final String sharedBudgetId;
  final String user1Id;
  final String? user2Id;
  final String budgetName;
  final String? inviteeEmail;
  final bool isNew; // Lisätty: Kertoo, onko uusi budjetti (skippaa haku, jos true)

  const SharedCreateBudgetScreen({
    super.key,
    required this.sharedBudgetId,
    required this.user1Id,
    this.user2Id,
    required this.budgetName,
    this.inviteeEmail,
    this.isNew = false, // Oletus: false (hae existing)
  });

  @override
  State<SharedCreateBudgetScreen> createState() => _SharedCreateBudgetScreenState();
}

class _SharedCreateBudgetScreenState extends State<SharedCreateBudgetScreen> {
  late TextEditingController _incomeController; // Tulojen syöttöohjain
  final Map<String, Map<String, TextEditingController>> _expenseControllers = {}; // Menojen ohjaimet
  String? _errorMessage; // Virheviesti tallennuksessa
  late BudgetInitializer _initializer; // Budjetin alustaja
  late BudgetCalculator _calculator; // Budjetin laskin
  late BudgetSaver _saver; // Budjetin tallentaja (päivitetään uudella instanssilla kenttien muutoksissa)
  DateTime? _startDate;
  DateTime? _endDate;
  String? _type;
  bool _isEditing = false;
  BudgetModel? _existingBudget;
  String? _invitedUserEmail;
  bool _isLoading = true; // Latausindikaattori existing-budjetille

  @override
  void initState() {
    super.initState();
    _incomeController = TextEditingController();
    _calculator = BudgetCalculator(
      incomeController: _incomeController,
      expenseControllers: _expenseControllers,
      setStateCallback: () => setState(() {}),
    );
    _initializer = BudgetInitializer(
      sourceBudget: null,
      incomeController: _incomeController,
      expenseControllers: _expenseControllers,
      updateSummary: () => _calculator.updateSummary(),
    );
    // Alusta saver oletuksilla, päivitä myöhemmin
    _saver = BudgetSaver(
      context: context,
      incomeController: _incomeController,
      expenseControllers: _expenseControllers,
      startDate: DateTime.now(),
      endDate: DateTime.now(),
      type: 'monthly',
      totalIncome: _calculator.totalIncome,
      totalExpenses: _calculator.totalExpenses,
      isEditing: _isEditing,
      budgetName: widget.budgetName,
    );
    // Lataa existing-budjetti ja alusta sen jälkeen
    _loadAndInitializeBudget();
  }

 /// Lataa olemassa oleva budjetti ja alustaa initializerin sen perusteella.
/// Minimoi redundantit kutsut initStatessa.
/// Käsittelee permission-denied virheen ei-olemassa olevalle dokumentille (uusi budjetti) palauttamalla null.
/// Optimoitu: Jos widget.isNew == true, skippaa haku (turha kutsu uudelle, säästää kuluja).
Future<void> _loadAndInitializeBudget() async {
  try {
    BudgetModel? sharedBudget;
    if (!widget.isNew) { // Lisätty: Skippaa haku, jos uusi (optimoi)
      final sharedBudgetProvider = Provider.of<SharedBudgetProvider>(context, listen: false);
      try {
        sharedBudget = await sharedBudgetProvider.getSharedBudgetById(widget.sharedBudgetId);
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          // Odota tapaus uudelle budjetille: Dokumenttia ei ole, joten kohdellaan null:ina (ei heitetä virhettä)
          await FirebaseCrashlytics.instance.log('SharedCreateBudgetScreen: Permission-denied haussa ei-olemassa olevalle sharedBudgetId:lle ${widget.sharedBudgetId} - kohdellaan uutena budjettina');
          sharedBudget = null;
        } else {
          rethrow; // Muut virheet heitetään normaalisti
        }
      }
    }

    if (sharedBudget != null && mounted) {
      setState(() {
        _isEditing = true;
        // Poistettu konversio: sharedBudget on jo BudgetModel (yhdistetty malli, säilytetään suoraan)
        _existingBudget = sharedBudget;
        _startDate = sharedBudget?.startDate;
        _endDate = sharedBudget?.endDate;
        _type = sharedBudget?.type;
        _incomeController.text = sharedBudget!.income.toStringAsFixed(2); // Lisätty: toStringAsFixed null-safetyyn
        _expenseControllers.clear();
        sharedBudget.expenses.forEach((category, subcategories) {
          _expenseControllers[category] = subcategories.map((subcategory, amount) => MapEntry(
            subcategory,
            TextEditingController(text: amount.toStringAsFixed(2)), // Lisätty: toStringAsFixed null-safetyyn
          ));
        });
        _updateSaverFields(); // Päivitä saver kentittäin
      });
    } else {
      _initializer.initialize(); // Alusta vain jos ei existing (tai permission-denied uudelle)
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _errorMessage = 'Budjetin lataus epäonnistui: $e';
      });
    }
    await FirebaseCrashlytics.instance.recordError(
      e,
      StackTrace.current,
      reason: 'Virhe budjetin latauksessa SharedCreateBudgetScreen:ssä',
    );
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

  /// Päivittää BudgetSaverin luomalla uuden instanssin (koska kentät ovat final, vältetään setter-virheet).
  /// Parantaa suorituskykyä verrattuna uuteen instanssiin joka callbackissa, mutta varmistaa päivityksen.
  void _updateSaverFields() {
    _saver = BudgetSaver(
      context: context,
      incomeController: _incomeController,
      expenseControllers: _expenseControllers,
      startDate: _startDate ?? DateTime.now(),
      endDate: _endDate ?? DateTime.now(),
      type: _type ?? 'monthly',
      totalIncome: _calculator.totalIncome,
      totalExpenses: _calculator.totalExpenses,
      isEditing: _isEditing,
      budgetName: widget.budgetName,
    );
  }

  @override
  void dispose() {
    _incomeController.dispose();
    _expenseControllers.forEach((_, subControllers) {
      subControllers.forEach((_, controller) => controller.dispose());
    });
    super.dispose();
  }

  /// Tallentaa shared-budjetin batch-write:lla optimoituna.
  /// Käsittelee invitation automaattisesti, jos annettu.
  Future<void> _saveSharedBudget() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final sharedBudgetProvider = Provider.of<SharedBudgetProvider>(context, listen: false);
    final userId = authProvider.user!.uid;

    if (_startDate == null || _endDate == null || _type == null) {
      setState(() {
        _errorMessage = 'Valitse budjetin tyyppi ja aikaväli';
      });
      return;
    }
    if (_startDate!.isAfter(_endDate!)) {
      setState(() {
        _errorMessage = 'Alkamispäivä ei voi olla päättymispäivän jälkeen';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final batch = FirebaseFirestore.instance.batch(); // Optimoi kirjoitukset yhteen operaatioon

    try {
      final budgetId = await _saver.createBudget(
        budgetId: _isEditing ? _existingBudget?.id : null, // Null-tarkistus
        sharedBudgetId: widget.sharedBudgetId,
        budgetName: widget.budgetName,
        batch: batch, // Välitä batch saverille, jos se tukee (muuta BudgetSaver:ia tarvittaessa)
      );

      if (widget.inviteeEmail != null && !_isEditing) {
        // Lisää invitation batchiin
        final invitationRef = FirebaseFirestore.instance.collection('invitations').doc();
        batch.set(invitationRef, {
          'sharedBudgetId': widget.sharedBudgetId,
          'inviterId': userId,
          'inviteeEmail': widget.inviteeEmail,
          // Lisää muut kentät SharedBudgetProvider.createInvitationForExistingBudget:sta
        });
      }

      await batch.commit(); // Suorita kaikki kirjoitukset kerralla

      await FirebaseCrashlytics.instance.log('SharedCreateBudgetScreen: Yhteistalousbudjetti ${_isEditing ? 'muokattu' : 'tallennettu'}, sharedBudgetId: ${widget.sharedBudgetId}, budgetId: $budgetId');
      if (mounted) {
        showSnackBar(
          context,
          _isEditing ? 'Budjetti muokattu: ${widget.budgetName}' : 'Budjetti tallennettu: ${widget.budgetName}',
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.blueGrey[700],
        );
        Navigator.pushNamed(
          context,
          AppRouter.mainRoute,
          arguments: {'index': 0},
        );
      }
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to save shared budget',
      );
      setState(() {
        _errorMessage = 'Budjetin tallennus epäonnistui: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Kutsuu käyttäjän dialogilla ja päivittää _invitedUserEmail.
  Future<void> _inviteUser() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => InviteToExistingBudgetDialog(
        sharedBudgetId: widget.sharedBudgetId,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _invitedUserEmail = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Muokkaa yhteistaloutta: ${widget.budgetName}' : 'Yhteistalous: ${widget.budgetName}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushNamed(
              context,
              AppRouter.mainRoute,
              arguments: {'index': 0},
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _inviteUser,
            tooltip: 'Kutsu käyttäjä',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_invitedUserEmail != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'Lisäsit budjettiin käyttäjän $_invitedUserEmail',
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const Text(
              'Budjetin aikaväli',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            BudgetDateSection(
              onTypeChanged: (type) {
                if (mounted) {
                  setState(() {
                    _type = type;
                    _updateSaverFields(); // Päivitä kentät
                  });
                }
              },
              onStartDateChanged: (startDate) {
                if (mounted) {
                  setState(() {
                    _startDate = startDate;
                    _updateSaverFields();
                  });
                }
              },
              onEndDateChanged: (endDate) {
                if (mounted) {
                  setState(() {
                    _endDate = endDate;
                    _updateSaverFields();
                  });
                }
              },
            ),
            const SizedBox(height: 24),
            IncomeSection(incomeController: _incomeController),
            const SizedBox(height: 24),
            const Text(
              'Jaetut menot',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ExpensesSection(
              expenseControllers: _expenseControllers,
              onUpdate: () => setState(() {
                _updateSaverFields(); // Päivitä laskelmat muutoksissa
              }),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ],
            const SizedBox(height: 24),
            SummarySection(
              totalIncome: double.tryParse(_incomeController.text) ?? 0.0,
              totalExpenses: _calculator.totalExpenses,
              startDate: _startDate,
              endDate: _endDate,
            ),
            const SizedBox(height: 24),
            SaveButton(
              onPressed: _saveSharedBudget,
              label: _isEditing ? 'Tallenna muutokset' : 'Tallenna budjetti',
            ),
          ],
        ),
      ),
    );
  }
}