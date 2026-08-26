import 'package:budu/core/app_router/app_router.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/domain/periods.dart';
import 'package:budu/features/budget/domain/shared_rules.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/shared_budget_provider.dart';
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
import 'package:uuid/uuid.dart';

/// Personal budget form. When [isShared], also name + invite queue.
class CreateBudgetScreen extends StatefulWidget {
  final BudgetModel? sourceBudget;
  final bool isShared;
  final String? householdName;
  final List<String> existingMemberIds;

  const CreateBudgetScreen({
    super.key,
    this.sourceBudget,
    this.isShared = false,
    this.householdName,
    this.existingMemberIds = const [],
  });

  @override
  State<CreateBudgetScreen> createState() => _CreateBudgetScreenState();
}

class _CreateBudgetScreenState extends State<CreateBudgetScreen> {
  late TextEditingController _incomeController;
  late TextEditingController _nameController;
  late TextEditingController _inviteEmailController;
  final Map<String, Map<String, TextEditingController>> _expenseControllers = {};
  String? _errorMessage;
  late BudgetInitializer _initializer;
  late BudgetCalculator _calculator;
  late BudgetSaver _saver;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _type;
  final List<String> _queuedInviteEmails = [];

  late final DateTime _initialStart;
  late final DateTime _initialEnd;
  late final String _initialType;
  Future<List<BudgetModel>>? _availableBudgetsFuture;

  @override
  void initState() {
    super.initState();
    _incomeController = TextEditingController();
    _nameController = TextEditingController(text: widget.householdName ?? '');
    _inviteEmailController = TextEditingController();
    final userId = Provider.of<AuthProvider>(context, listen: false).user?.uid;
    if (userId != null) {
      _availableBudgetsFuture =
        Provider.of<BudgetProvider>(context, listen: false)
          .getAvailableBudgets(userId);
    }
    if (widget.sourceBudget?.id != null) {
      final period = nextPeriodAfter(
        latestEnd: widget.sourceBudget!.endDate,
        type: widget.sourceBudget!.type,
      );
      _initialStart = period.start;
      _initialEnd = period.end;
      _initialType = widget.sourceBudget!.type;
    } else {
      final range = monthRange(DateTime.now());
      _initialStart = range.start;
      _initialEnd = range.end;
      _initialType = 'monthly';
    }
    _startDate = _initialStart;
    _endDate = _initialEnd;
    _type = _initialType;
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
    _saver = _buildSaver();
  }

  BudgetSaver _buildSaver() {
    return BudgetSaver(
      context: context,
      incomeController: _incomeController,
      expenseControllers: _expenseControllers,
      startDate: _startDate ?? _initialStart,
      endDate: _endDate ?? _initialEnd,
      type: _type ?? _initialType,
      totalIncome: _calculator.totalIncome,
      totalExpenses: _calculator.totalExpenses,
      budgetName: widget.isShared ? _nameController.text.trim() : null,
    );
  }

  @override
  void dispose() {
    _initializer.dispose();
    _incomeController.dispose();
    _nameController.dispose();
    _inviteEmailController.dispose();
    _expenseControllers.forEach((_, subControllers) {
      subControllers.forEach((_, controller) => controller.dispose());
    });
    super.dispose();
  }

  Future<void> _queueInvite() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final shared = Provider.of<SharedBudgetProvider>(context, listen: false);
    final email = _inviteEmailController.text;
    final result = await shared.validateNewInvite(
      inviterEmail: auth.user?.email ?? '',
      inviteeEmail: email,
      memberUids: householdUsersForNewPeriod(
        creatorId: auth.user?.uid ?? '',
        previousUsers: widget.existingMemberIds,
      ),
      queuedEmails: _queuedInviteEmails,
    );
    if (!mounted) return;
    if (result != InviteValidation.ok) {
      setState(() => _errorMessage = inviteValidationMessage(result));
      return;
    }
    setState(() {
      _queuedInviteEmails.add(normalizeInviteEmailForLookup(email));
      _inviteEmailController.clear();
      _errorMessage = null;
    });
  }

  Future<void> _save() async {
    if (_startDate == null || _endDate == null || _type == null) {
      setState(() {
        _errorMessage = 'Valitse budjetin tyyppi ja aikaväli';
      });
      await FirebaseCrashlytics.instance
          .log('Budjetin tallennus epäonnistui: Aikaväli tai tyyppi puuttuu');
      return;
    }
    if (_startDate!.isAfter(_endDate!)) {
      setState(() {
        _errorMessage = 'Alkamispäivä ei voi olla päättymispäivän jälkeen';
      });
      await FirebaseCrashlytics.instance
          .log('Budjetin tallennus epäonnistui: Virheellinen aikaväli');
      return;
    }
    if (widget.isShared && _nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Syötä budjetin nimi');
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    _saver = _buildSaver();
    try {
      if (widget.isShared) {
        await _saver.createBudget(
          sharedBudgetId: const Uuid().v4(),
          budgetName: _nameController.text.trim(),
          memberIds: householdUsersForNewPeriod(
            creatorId: auth.user!.uid,
            previousUsers: widget.existingMemberIds,
          ),
          inviteEmails: List<String>.from(_queuedInviteEmails),
          householdId: widget.sourceBudget?.householdId,
        );
      } else {
        await _saver.createBudget();
      }
    } catch (_) {
      // Saver already set errorMessage / showed dialogs.
    }
    if (mounted) {
      setState(() {
        _errorMessage = _saver.errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isShared ? 'Luo yhteistalousbudjetti' : 'Luo budjetti'),
        leading: userId != null
            ? FutureBuilder<List<BudgetModel>>(
            future: _availableBudgetsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Material(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final hasBudgets =
                      snapshot.hasData && snapshot.data!.isNotEmpty;
                  return IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      if (hasBudgets || widget.isShared) {
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
            if (widget.isShared) ...[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Budjetin nimi',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              if (widget.existingMemberIds.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Edellisen jakson jäsenet siirtyvät tähän budjettiin (${widget.existingMemberIds.length}).',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              const Text(
                'Kutsu käyttäjiä',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inviteEmailController,
                      decoration: const InputDecoration(
                        labelText: 'Sähköposti',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _queueInvite,
                    child: const Text('Kutsu'),
                  ),
                ],
              ),
              if (_queuedInviteEmails.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._queuedInviteEmails.map(
                  (email) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(email),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() => _queuedInviteEmails.remove(email));
                      },
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
            const Text(
              'Budjetin aikaväli',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            BudgetDateSection(
              initialStart: _initialStart,
              initialEnd: _initialEnd,
              initialType: _initialType,
              onTypeChanged: (type) {
                if (mounted) {
                  setState(() {
                    _type = type;
                    _saver = _buildSaver();
                  });
                }
              },
              onStartDateChanged: (startDate) {
                if (mounted) {
                  setState(() {
                    _startDate = startDate;
                    _saver = _buildSaver();
                  });
                }
              },
              onEndDateChanged: (endDate) {
                if (mounted) {
                  setState(() {
                    _endDate = endDate;
                    _saver = _buildSaver();
                  });
                }
              },
            ),
            const SizedBox(height: 24),
            IncomeSection(incomeController: _incomeController),
            const SizedBox(height: 24),
            ExpensesSection(
              expenseControllers: _expenseControllers,
              onUpdate: () => setState(() {}),
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
              totalIncome: _calculator.totalIncome,
              totalExpenses: _calculator.totalExpenses,
              startDate: _startDate,
              endDate: _endDate,
            ),
            const SizedBox(height: 24),
            SaveButton(onPressed: _save),
          ],
        ),
      ),
    );
  }
}
