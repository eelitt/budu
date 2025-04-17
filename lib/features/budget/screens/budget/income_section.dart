import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Oletetaan, että BudgetProvider ja AuthProvider ovat määritelty muualla
class IncomeSection extends StatefulWidget {
  const IncomeSection({super.key, required double income});

  @override
  State<IncomeSection> createState() => _IncomeSectionState();
}

class _IncomeSectionState extends State<IncomeSection> {
  bool _isEditing = false;
  final TextEditingController _amountController = TextEditingController();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    _amountController.text = budgetProvider.budget?.income.toStringAsFixed(2) ?? '0.00';
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
      _amountController.text = budgetProvider.budget?.income.toStringAsFixed(2) ?? '0.00';
      _errorMessage = null;
    });
  }

  void _saveChanges() {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount < 0) {
      setState(() {
        _errorMessage = 'Syötä positiivinen numero';
      });
      return;
    }

    if (authProvider.user != null) {
      budgetProvider.updateIncome(
        userId: authProvider.user!.uid,
        year: DateTime.now().year,
        month: DateTime.now().month,
        income: amount,
      );
      setState(() {
        _isEditing = false;
        _errorMessage = null;
      });
    }
  }

 @override
Widget build(BuildContext context) {
  final budgetProvider = Provider.of<BudgetProvider>(context);
  final income = budgetProvider.budget?.income ?? 0.0;

  return Container(
    margin: const EdgeInsets.only(bottom: 16), // Lisätään 16 pikselin marginaali alaosaan
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
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
            Expanded(
              child: Text(
                'Tulot',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            _isEditing
                ? Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          ),
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: _startEditing,
                      ),
                    ],
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