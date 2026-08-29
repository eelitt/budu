import 'package:budu/core/app_router/app_router.dart';
import 'package:budu/core/utils.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/domain/periods.dart';
import 'package:budu/features/budget/domain/save_result.dart';
import 'package:budu/features/budget/domain/shared_rules.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:budu/features/budget/screens/create_budget/budget_saver.dart';
import 'package:budu/features/budget/screens/create_budget/create_budget_draft.dart';
import 'package:budu/features/budget/screens/create_budget/sections/budget_date_section.dart';
import 'package:budu/features/budget/screens/create_budget/sections/create_budget_income_section.dart';
import 'package:budu/features/budget/screens/create_budget/sections/expense_section.dart';
import 'package:budu/features/budget/screens/create_budget/sections/create_budget_summary_section.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:uuid/uuid.dart';

/// Personal budget form. When [isShared], also name + invite queue.
///
/// [sourceBudget] copies planned income/categories only. Pass [initialStart] /
/// [initialEnd] / [initialType] when the caller already knows the target period
/// (e.g. reminder-driven current/next month).
class CreateBudgetScreen extends StatefulWidget {
  final BudgetModel? sourceBudget;
  final bool isShared;
  final String? householdName;
  final List<String> existingMemberIds;
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final String? initialType;

  const CreateBudgetScreen({
    super.key,
    this.sourceBudget,
    this.isShared = false,
    this.householdName,
    this.existingMemberIds = const [],
    this.initialStart,
    this.initialEnd,
    this.initialType,
  });

  @override
  State<CreateBudgetScreen> createState() => _CreateBudgetScreenState();
}

class _CreateBudgetScreenState extends State<CreateBudgetScreen> {
  late final CreateBudgetDraft _draft;
  late final TextEditingController _nameController;
  late final TextEditingController _inviteEmailController;
  String? _errorMessage;
  final List<String> _queuedInviteEmails = [];
  Future<List<BudgetModel>>? _availableBudgetsFuture;

  @override
  void initState() {
    super.initState();
    _draft = CreateBudgetDraft(onChanged: () {
      if (mounted) setState(() {});
    });
    _nameController = TextEditingController(text: widget.householdName ?? '');
    _inviteEmailController = TextEditingController();
    final userId = Provider.of<AuthProvider>(context, listen: false).user?.uid;
    if (userId != null) {
      _availableBudgetsFuture =
          Provider.of<BudgetProvider>(context, listen: false)
              .getAvailableBudgets(userId);
    }
    final period = resolveCreateBudgetInitialPeriod(
      initialStart: widget.initialStart,
      initialEnd: widget.initialEnd,
      initialType: widget.initialType,
      sourceId: widget.sourceBudget?.id,
      sourceEnd: widget.sourceBudget?.endDate,
      sourceType: widget.sourceBudget?.type,
    );
    _draft.setPeriod(
      type: period.type,
      start: period.start,
      end: period.end,
    );
    _draft.loadAmounts(sourceBudget: widget.sourceBudget);
  }

  @override
  void dispose() {
    _draft.dispose();
    _nameController.dispose();
    _inviteEmailController.dispose();
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

  Future<void> _handleBack({required bool goToMainFallback}) async {
    final nav = Navigator.of(context);
    final popped = await nav.maybePop();
    if (popped || !mounted) return;
    if (goToMainFallback) {
      await nav.pushReplacementNamed(
        AppRouter.mainRoute,
        arguments: {'index': 0},
      );
    } else {
      await nav.pushReplacementNamed(AppRouter.chatbotRoute);
    }
  }

  Future<void> _leaveAfterSuccess(String budgetId) async {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop(budgetId);
      return;
    }
    showSnackBar(
      context,
      'Budjetti tallennettu onnistuneesti',
      duration: const Duration(seconds: 3),
      backgroundColor: Colors.green,
    );
    await nav.pushReplacementNamed(
      AppRouter.mainRoute,
      arguments: {'index': 0},
    );
  }

  Future<void> _save() async {
    if (_draft.startDate.isAfter(_draft.endDate)) {
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
    final saver = BudgetSaver(
      context: context,
      incomeController: _draft.incomeController,
      expenseControllers: _draft.expenseControllers,
      startDate: _draft.startDate,
      endDate: _draft.endDate,
      type: _draft.type,
      budgetName: widget.isShared ? _nameController.text.trim() : null,
    );
    final BudgetSaveResult result;
    if (widget.isShared) {
      result = await saver.createBudget(
        sharedBudgetId: const Uuid().v4(),
        memberIds: householdUsersForNewPeriod(
          creatorId: auth.user!.uid,
          previousUsers: widget.existingMemberIds,
        ),
        inviteEmails: List<String>.from(_queuedInviteEmails),
        householdId: widget.sourceBudget?.householdId,
      );
    } else {
      result = await saver.createBudget();
    }
    if (!mounted) return;
    switch (result.status) {
      case BudgetSaveStatus.ok:
        await _leaveAfterSuccess(result.budgetId!);
      case BudgetSaveStatus.cancelled:
        setState(() => _errorMessage = null);
      case BudgetSaveStatus.failed:
        setState(() => _errorMessage = result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isShared ? 'Luo yhteistalousbudjetti' : 'Luo budjetti',
        ),
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
                    onPressed: () => _handleBack(
                      goToMainFallback: hasBudgets || widget.isShared,
                    ),
                  );
                },
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _handleBack(goToMainFallback: false),
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
              type: _draft.type,
              startDate: _draft.startDate,
              endDate: _draft.endDate,
              onPeriodChanged: ({
                required type,
                required start,
                required end,
              }) {
                setState(() {
                  _draft.setPeriod(type: type, start: start, end: end);
                });
              },
            ),
            const SizedBox(height: 24),
            IncomeSection(incomeController: _draft.incomeController),
            const SizedBox(height: 24),
            ExpensesSection(
              expenseControllers: _draft.expenseControllers,
              onUpdate: () => setState(() {}),
              attachController: _draft.attachExpenseController,
              detachController: _draft.detachExpenseController,
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
              totalIncome: _draft.totalIncome,
              totalExpenses: _draft.totalExpenses,
              startDate: _draft.startDate,
              endDate: _draft.endDate,
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context)
                      .elevatedButtonTheme
                      .style
                      ?.backgroundColor
                      ?.resolve({}),
                  foregroundColor: Theme.of(context)
                      .elevatedButtonTheme
                      .style
                      ?.foregroundColor
                      ?.resolve({}),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: Text(
                  'Tallenna budjetti',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context)
                            .elevatedButtonTheme
                            .style
                            ?.foregroundColor
                            ?.resolve({}),
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
