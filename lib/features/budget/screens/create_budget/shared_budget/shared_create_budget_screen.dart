import 'package:budu/core/app_router/app_router.dart';
import 'package:budu/core/utils.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/models/budget_model.dart';
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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Screen for creating or editing a shared (group) budget.
/// Now supports sequential shared budgets:
/// - When widget.isNew == true, the screen can template from the user's latest existing shared budget (if any).
/// - Income, expenses, period type and dates are pre-filled and advanced to the next logical period.
/// - Group members (users array) are carried over automatically (handled by navigation passing user1Id/user2Id).
/// - Invite button is hidden when the group already has 2 members (widget.user2Id != null).
class SharedCreateBudgetScreen extends StatefulWidget {
  final String sharedBudgetId;
  final String user1Id;
  final String? user2Id;
  final String budgetName;
  final String? inviteeEmail;
  final bool isNew;

  const SharedCreateBudgetScreen({
    super.key,
    required this.sharedBudgetId,
    required this.user1Id,
    this.user2Id,
    required this.budgetName,
    this.inviteeEmail,
    this.isNew = false,
  });

  @override
  State<SharedCreateBudgetScreen> createState() => _SharedCreateBudgetScreenState();
}

class _SharedCreateBudgetScreenState extends State<SharedCreateBudgetScreen> {
  late TextEditingController _incomeController;
  final Map<String, Map<String, TextEditingController>> _expenseControllers = {};
  String? _errorMessage;
  late BudgetInitializer _initializer;
  late BudgetCalculator _calculator;
  late BudgetSaver _saver;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _type;
  bool _isEditing = false;
  BudgetModel? _existingBudget;
  String? _invitedUserEmail;
  bool _isLoading = true;

  // Templating support for sequential shared budgets
  BudgetModel? _templateBudget;
  late bool _canInvite; // true → show invite button (group has <2 members)

  @override
  void initState() {
    super.initState();
    _incomeController = TextEditingController();

    final sharedProvider = context.read<SharedBudgetProvider>();

    // Load latest shared budget for possible templating
    _templateBudget = sharedProvider.latestSharedBudget;
    _canInvite = widget.user2Id == null;

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

    _loadAndInitializeBudget();
  }

  /// Loads existing budget (if not new) and initialises fields.
  /// For new sequential budgets (widget.isNew == true), skips load and templates later.
  Future<void> _loadAndInitializeBudget() async {
    try {
      BudgetModel? sharedBudget;
      if (!widget.isNew) {
        final sharedBudgetProvider = Provider.of<SharedBudgetProvider>(context, listen: false);
        try {
          sharedBudget = await sharedBudgetProvider.getSharedBudgetById(widget.sharedBudgetId);
        } on FirebaseException catch (e) {
          if (e.code == 'permission-denied') {
            await FirebaseCrashlytics.instance.log('SharedCreateBudgetScreen: Permission-denied for non-existent sharedBudgetId ${widget.sharedBudgetId} – treating as new');
            sharedBudget = null;
          } else {
            rethrow;
          }
        }
      }

      if (sharedBudget != null && mounted) {
        setState(() {
          _isEditing = true;
          _existingBudget = sharedBudget!;
          _startDate = sharedBudget.startDate;
          _endDate = sharedBudget.endDate;
          _type = sharedBudget.type;
          _incomeController.text = sharedBudget.income.toStringAsFixed(2);
          _expenseControllers.clear();
          sharedBudget.expenses.forEach((category, subcategories) {
            _expenseControllers[category] = subcategories.map((subcategory, amount) => MapEntry(
                  subcategory,
                  TextEditingController(text: amount.toStringAsFixed(2)),
                ));
          });
          _updateSaverFields();
        });
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
        setState(() => _isLoading = false);

        // New budget handling (including sequential templating)
        if (_existingBudget == null) {
          if (_templateBudget != null) {
            // Sequential shared budget – template from latest existing
            final template = _templateBudget!;
            setState(() {
              _type = template.type ?? 'monthly';
              _incomeController.text = template.income.toStringAsFixed(0);

              // Advance dates to next logical period
              if (_type == 'monthly') {
                final currentEnd = template.endDate!;
                final nextMonth = currentEnd.month + 1;
                final nextYear = currentEnd.year + (nextMonth > 12 ? 1 : 0);
                final adjustedMonth = nextMonth > 12 ? nextMonth - 12 : nextMonth;
                _startDate = DateTime(nextYear, adjustedMonth, 1);
                _endDate = DateTime(nextYear, adjustedMonth + 1, 0);
              } else {
                // Custom – preserve duration
                final duration = template.endDate!.difference(template.startDate!);
                _startDate = template.endDate!.add(const Duration(days: 1));
                _endDate = _startDate!.add(duration);
              }

              // Prefill expenses
              _expenseControllers.clear();
              template.expenses.forEach((category, subcategories) {
                final subMap = <String, TextEditingController>{};
                subcategories.forEach((sub, amount) {
                  final ctrl = TextEditingController(text: amount.toStringAsFixed(2));
                  // Ensure changes trigger UI updates (mirrors typical onChanged behaviour)
                  ctrl.addListener(() {
                    _updateSaverFields();
                    setState(() {});
                  });
                  subMap[sub] = ctrl;
                });
                _expenseControllers[category] = subMap;
              });

              // Recreate calculator with pre-filled data
              _calculator = BudgetCalculator(
                incomeController: _incomeController,
                expenseControllers: _expenseControllers,
                setStateCallback: () => setState(() {}),
              );

              _updateSaverFields();
            });
          } else {
            // Completely new group budget – use default initialisation
            _initializer.initialize();
          }
        }
      }
    }
  }

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

  Future<void> _saveSharedBudget() async {
    // Existing validation and save logic unchanged (kept concise)
    // Note: users array is built from widget.user1Id / widget.user2Id in BudgetSaver or navigation
    // (no changes needed here for carrying over members)
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final sharedBudgetProvider = Provider.of<SharedBudgetProvider>(context, listen: false);

    if (_startDate == null || _endDate == null || _type == null) {
      setState(() => _errorMessage = 'Valitse budjetin tyyppi ja aikaväli');
      return;
    }
    if (_startDate!.isAfter(_endDate!)) {
      setState(() => _errorMessage = 'Alkamispäivä ei voi olla päättymispäivän jälkeen');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final batch = FirebaseFirestore.instance.batch();

    try {
      final budgetId = await _saver.createBudget(
        budgetId: _isEditing ? _existingBudget?.id : null,
        sharedBudgetId: widget.sharedBudgetId,
        budgetName: widget.budgetName,
        batch: batch,
      );

      if (widget.inviteeEmail != null && !_isEditing) {
        final invitationRef = FirebaseFirestore.instance.collection('invitations').doc();
        batch.set(invitationRef, {
          'sharedBudgetId': widget.sharedBudgetId,
          'inviterId': authProvider.user!.uid,
          'inviteeEmail': widget.inviteeEmail,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      await FirebaseCrashlytics.instance.log('SharedCreateBudgetScreen: Yhteistalousbudjetti ${_isEditing ? 'muokattu' : 'tallennettu'}');
      if (mounted) {
        showSnackBar(
          context,
          _isEditing ? 'Budjetti muokattu' : 'Budjetti tallennettu',
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.blueGrey[700],
        );
        Navigator.pushNamed(context, AppRouter.mainRoute, arguments: {'index': 0});
      }
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(e, stackTrace, reason: 'Failed to save shared budget');
      setState(() => _errorMessage = 'Budjetin tallennus epäonnistui: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _inviteUser() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => InviteToExistingBudgetDialog(sharedBudgetId: widget.sharedBudgetId),
    );
    if (result != null && mounted) {
      setState(() => _invitedUserEmail = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Muokkaa yhteistaloutta: ${widget.budgetName}' : 'Yhteistalous: ${widget.budgetName}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushNamed(context, AppRouter.mainRoute, arguments: {'index': 0}),
        ),
        actions: _canInvite
            ? [
                IconButton(
                  icon: const Icon(Icons.person_add),
                  onPressed: _inviteUser,
                  tooltip: 'Kutsu käyttäjä',
                ),
              ]
            : null,
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
                  style: const TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
            const Text('Budjetin aikaväli', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            BudgetDateSection(
              onTypeChanged: (type) => setState(() {
                _type = type;
                _updateSaverFields();
              }),
              onStartDateChanged: (startDate) => setState(() {
                _startDate = startDate;
                _updateSaverFields();
              }),
              onEndDateChanged: (endDate) => setState(() {
                _endDate = endDate;
                _updateSaverFields();
              }),
            ),
            const SizedBox(height: 24),
            IncomeSection(incomeController: _incomeController),
            const SizedBox(height: 24),
            const Text('Jaetut menot', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ExpensesSection(
              expenseControllers: _expenseControllers,
              onUpdate: () => setState(() => _updateSaverFields()),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 14)),
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