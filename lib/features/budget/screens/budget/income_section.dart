import 'package:budu/core/utils.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/models/budget_model.dart';

import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Widget, joka näyttää budjetin tulot ja budjetoitut menot.
/// Mahdollistaa tulojen muokkaamisen ja näyttää reaaliajassa päivittyvän budjetoitujen menojen summan.
class IncomeSection extends StatefulWidget {
  final bool isSharedBudget;
  final BudgetModel? selectedSharedBudget;

  const IncomeSection({
    super.key,
    this.isSharedBudget = false,
    this.selectedSharedBudget,
  });

  @override
  State<IncomeSection> createState() => _IncomeSectionState();
}

/// IncomeSectionin tilallinen tila, joka hallinnoi tulojen muokkaustilaa ja virheviestejä.
class _IncomeSectionState extends State<IncomeSection> {
  bool _isEditing = false;
  final TextEditingController _amountController = TextEditingController();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _updateAmountController();
  }

  @override
  void didUpdateWidget(covariant IncomeSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSharedBudget != oldWidget.isSharedBudget || widget.selectedSharedBudget != oldWidget.selectedSharedBudget) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateAmountController();
      });
    }
  }

  void _updateAmountController() {
    if (widget.isSharedBudget && widget.selectedSharedBudget != null) {
      _amountController.text = widget.selectedSharedBudget!.income.toStringAsFixed(2);
    } else {
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
      _amountController.text = budgetProvider.budget?.income.toStringAsFixed(2) ?? '0.00';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  /// Aloittaa tulojen muokkaustilan.
  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
  }

  /// Peruuttaa muokkaustilan ja palauttaa alkuperäisen tulojen summan.
  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _updateAmountController();
      _errorMessage = null;
    });
  }

  /// Tallentaa muokatun tulojen summan Firestoreen ja validoi syötteen.
  void _saveChanges() {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final sharedBudgetProvider = Provider.of<SharedBudgetProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    // Validoinnit euromäärälle
    if (amount == null || amount < 0) {
      setState(() {
        _errorMessage = 'Syötä positiivinen numero';
      });
      return;
    }

    if (amount > 1000000) {
      setState(() {
        _errorMessage = 'Euromäärä voi olla enintään 1 000 000 €';
      });
      return;
    }

    final decimalPlaces = amountText.contains('.') ? amountText.split('.')[1].length : 0;
    if (decimalPlaces > 2) {
      setState(() {
        _errorMessage = 'Euromäärä voi sisältää enintään 2 desimaalia';
      });
      return;
    }

    // Päivitetään tulot Firestoreen
    if (authProvider.user == null) {
      setState(() {
        _errorMessage = 'Käyttäjä ei ole kirjautunut';
      });
      return;
    }

    try {
      if (widget.isSharedBudget && widget.selectedSharedBudget != null) {
        // Yhteistalousbudjetti
        final budget = widget.selectedSharedBudget!;
        sharedBudgetProvider.updateSharedBudget(
          sharedBudgetId: budget.id.toString(),
          income: amount,
          expenses: budget.expenses,
          startDate: budget.startDate,
          endDate: budget.endDate,
          type: budget.type,
          isPlaceholder: budget.isPlaceholder,
        );
      } else if (budgetProvider.budget?.id != null) {
        // Henkilökohtainen budjetti
        budgetProvider.updateIncome(
          userId: authProvider.user!.uid,
          budgetId: budgetProvider.budget!.id!,
          income: amount,
        );
      } else {
        setState(() {
          _errorMessage = 'Budjettia ei ole valittu';
        });
        return;
      }

      setState(() {
        _isEditing = false;
        _errorMessage = null;
      });
      showSnackBar(
        context,
        'Tulot tallennettu onnistuneesti',
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.blueGrey[700],
      );
      FirebaseCrashlytics.instance.log('IncomeSection: Tulot tallennettu, isSharedBudget: ${widget.isSharedBudget}');
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to save income, isSharedBudget: ${widget.isSharedBudget}',
      );
      setState(() {
        _errorMessage = 'Tulojen tallennus epäonnistui: $e';
      });
    }
  }

  /// Laskee budjetoitujen menojen kokonaissumman.
  double _calculateTotalExpenses(Map<String, Map<String, double>> expenses) {
    double total = 0.0;
    expenses.forEach((category, subcategories) {
      subcategories.forEach((subcategory, amount) {
        total += amount;
      });
    });
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final income = widget.isSharedBudget ? widget.selectedSharedBudget?.income ?? 0.0 : budgetProvider.budget?.income ?? 0.0;
    final expenses = widget.isSharedBudget ? widget.selectedSharedBudget?.expenses ?? {} : budgetProvider.budget?.expenses ?? {};
    final totalExpenses = _calculateTotalExpenses(expenses);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.arrow_upward,
                    color: Colors.green,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Tulot',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              _isEditing
                  ? Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: _saveChanges,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: _cancelEditing,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Text(
                          '${income.toStringAsFixed(2)} €',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.black54),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: _startEditing,
                        ),
                      ],
                    ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.arrow_downward,
                    color: Colors.red,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Budjetoidut menot',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              Text(
                '${totalExpenses.toStringAsFixed(2)} €',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.black54),
              ),
            ],
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }
}