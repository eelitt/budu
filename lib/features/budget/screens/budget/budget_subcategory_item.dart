import 'package:budu/core/utils.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BudgetSubcategoryItem extends StatefulWidget {
  final String subCategory;
  final double budgetAmount;
  final double spentAmount;
  final double subProgress;
  final double subRemainingPercentage;

  const BudgetSubcategoryItem({
    super.key,
    required this.subCategory,
    required this.budgetAmount,
    required this.spentAmount,
    required this.subProgress,
    required this.subRemainingPercentage,
  });

  @override
  State<BudgetSubcategoryItem> createState() => _BudgetSubcategoryItemState();
}

class _BudgetSubcategoryItemState extends State<BudgetSubcategoryItem> {
  bool _isEditing = false;
  final TextEditingController _amountController = TextEditingController();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.budgetAmount.toStringAsFixed(2);
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
      _amountController.text = widget.budgetAmount.toStringAsFixed(2);
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
      budgetProvider.updateExpense(
        userId: authProvider.user!.uid,
        year: DateTime.now().year,
        month: DateTime.now().month,
        category: widget.subCategory,
        amount: amount,
      );
      setState(() {
        _isEditing = false;
        _errorMessage = null;
      });
    }
  }

  void _deleteSubcategory() async {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Poista alakategoria'),
        content: Text('Haluatko varmasti poistaa alakategorian "${widget.subCategory}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Peruuta'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Poista'),
          ),
        ],
      ),
    );

    if (confirm == true && authProvider.user != null) {
      budgetProvider.deleteExpense(
        userId: authProvider.user!.uid,
        year: DateTime.now().year,
        month: DateTime.now().month,
        category: widget.subCategory,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                widget.subCategory,
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
                        formatCurrency(widget.budgetAmount),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: _startEditing,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                        onPressed: _deleteSubcategory,
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
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: widget.subProgress > 1 ? 1 : widget.subProgress,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(widget.subProgress > 1 ? Colors.red : Colors.blue),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 4),
        Text(
          '${widget.subRemainingPercentage.toStringAsFixed(0)}% jäljellä',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
        ),
      ],
    );
  }
}