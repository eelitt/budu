import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/models/expense_event.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class AddEventDialog extends StatefulWidget {
  const AddEventDialog({super.key});

  @override
  State<AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<AddEventDialog> {
  bool _isExpense = true; // Oletus: Meno
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Asetetaan oletuskategoria vain menoille
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    _selectedCategory = budgetProvider.budget?.expenses.keys.first;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveEvent(BuildContext context) {
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount < 0) {
      setState(() {
        _errorMessage = 'Syötä positiivinen numero';
      });
      return;
    }

    // Kategoriavalinta vaaditaan vain menoille
    if (_isExpense && _selectedCategory == null) {
      setState(() {
        _errorMessage = 'Valitse kategoria';
      });
      return;
    }

    if (authProvider.user != null) {
      final event = ExpenseEvent(
        id: const Uuid().v4(),
        category: _isExpense ? _selectedCategory! : 'Tulo', // Tulolle asetetaan kategoria "Tulo"
        amount: amount,
        createdAt: _selectedDate,
        type: _isExpense ? EventType.expense : EventType.income,
        year: _selectedDate.year,
        month: _selectedDate.month,
        description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
      );
      expenseProvider.addExpense(authProvider.user!.uid, event);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final budgetProvider = Provider.of<BudgetProvider>(context);

    return AlertDialog(
      backgroundColor: Colors.white, // Valkoinen tausta
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), // Pyöristetyt kulmat
      ),
      elevation: 8, // Varjostus
      title: const Text('Lisää tapahtuma'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tulo/Meno-valinta
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ChoiceChip(
                  label: const Text('Tulo'),
                  selected: !_isExpense,
                  onSelected: (selected) {
                    setState(() {
                      _isExpense = !selected;
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('Meno'),
                  selected: _isExpense,
                  onSelected: (selected) {
                    setState(() {
                      _isExpense = selected;
                    });
                  },
                  selectedColor: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Summa
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Summa (€)',
                border: const OutlineInputBorder(),
                errorText: _errorMessage,
              ),
              onChanged: (value) {
                setState(() {
                  double? amount = double.tryParse(value);
                  if (amount == null || amount < 0) {
                    _errorMessage = 'Syötä positiivinen numero';
                  } else {
                    _errorMessage = null;
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            // Kategoria (vain menoille)
            if (_isExpense)
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Kategoria',
                  border: OutlineInputBorder(),
                ),
                items: budgetProvider.budget?.expenses.keys.map((key) {
                  return DropdownMenuItem<String>(
                    value: key,
                    child: Text(key),
                  );
                }).toList() ?? [],
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
              ),
            if (_isExpense) const SizedBox(height: 16),
            // Kuvaus (valinnainen, näytetään sekä tuloille että menoille)
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Kuvaus (valinnainen)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            // Päivämäärä
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Päivämäärä: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () => _selectDate(context),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Peruuta'),
        ),
        ElevatedButton(
          onPressed: () => _saveEvent(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
          ),
          child: Text(_isExpense ? 'Tallenna meno' : 'Tallenna tulo'),
        ),
      ],
    );
  }
}