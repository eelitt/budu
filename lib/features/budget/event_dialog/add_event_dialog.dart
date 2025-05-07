import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/event_dialog/category_selector.dart';
import 'package:budu/features/budget/event_dialog/event_type_selector.dart';
import 'package:budu/features/budget/event_dialog/event_validator.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/expense_event.dart';
import '../providers/budget_provider.dart';
import '../providers/expense_provider.dart';

class AddEventDialog extends StatefulWidget {
  const AddEventDialog({super.key});

  @override
  State<AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<AddEventDialog> {
  bool _isExpense = true;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _selectedCategory;
  String? _selectedSubcategory;
  DateTime _selectedDate = DateTime.now();
  String? _errorMessage;
  final EventValidator _validator = EventValidator();

  @override
  void initState() {
    super.initState();
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    _selectedCategory = budgetProvider.budget?.expenses.keys.first;
    if (_selectedCategory != null && budgetProvider.budget != null) {
      final subCategories = budgetProvider.budget!.expenses[_selectedCategory]?.keys.toList() ?? [];
      _selectedSubcategory = subCategories.isNotEmpty ? subCategories.first : null;
    }
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

  void _saveEvent(BuildContext context) async {
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final error = _validator.validateEvent(
      isExpense: _isExpense,
      amountText: _amountController.text,
      description: _descriptionController.text,
      selectedCategory: _selectedCategory,
      selectedSubcategory: _selectedSubcategory,
      authProvider: authProvider,
      budgetProvider: budgetProvider,
    );
    if (error != null) {
      setState(() {
        _errorMessage = error;
      });
      return;
    }

    try {
      final amount = double.parse(_amountController.text);
      final event = ExpenseEvent(
        id: const Uuid().v4(),
        category: _isExpense ? _selectedCategory! : 'Tulo',
        subcategory: _isExpense ? _selectedSubcategory : null,
        amount: amount,
        createdAt: _selectedDate,
        type: _isExpense ? EventType.expense : EventType.income,
        year: _selectedDate.year,
        month: _selectedDate.month,
        description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
      );
      await expenseProvider.addExpense(authProvider.user!.uid, event, budgetProvider);
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _errorMessage = 'Virhe tallennettaessa tapahtumaa: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 8,
      title: const Text('Lisää tapahtuma'),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 300, // Asetetaan dialogin minimi leveys
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EventTypeSelector(
                isExpense: _isExpense,
                onTypeChanged: (isExpense) {
                  setState(() {
                    _isExpense = isExpense;
                    _selectedSubcategory = null;
                    _errorMessage = null;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Summa (€)',
                  border: const OutlineInputBorder(),
                  errorText: _errorMessage?.contains('Syötä positiivinen numero') ?? false ? _errorMessage : null,
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
              CategorySelector(
                isExpense: _isExpense,
                selectedCategory: _selectedCategory,
                selectedSubcategory: _selectedSubcategory,
                onCategoryChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                    _selectedSubcategory = null;
                    _errorMessage = null;
                    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
                    final subCategories = budgetProvider.budget?.expenses[value]?.keys.toList() ?? [];
                    _selectedSubcategory = subCategories.isNotEmpty ? subCategories.first : null;
                  });
                },
                onSubcategoryChanged: (value) {
                  setState(() {
                    _selectedSubcategory = value;
                    _errorMessage = null;
                  });
                },
              ),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Kuvaus (valinnainen)',
                  border: const OutlineInputBorder(),
                  errorText: _errorMessage?.contains('Kuvaus voi olla enintään 75 merkkiä') ?? false ? _errorMessage : null,
                ),
                maxLines: 2,
                maxLength: 75,
                onChanged: (value) {
                  setState(() {
                    if (value.length > 75) {
                      _errorMessage = 'Kuvaus voi olla enintään 75 merkkiä';
                    } else {
                      _errorMessage = null;
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
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
      ),
      actions: [
        SizedBox(
          width: 85, // Rajoitetaan "Peruuta"-painikkeen leveys
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Peruuta',
              style: Theme.of(context).textTheme.bodyLarge, 
            ),
          ),
        ),
        SizedBox(
          width: 135, // Rajoitetaan "Tallenna"-painikkeen leveys
          child: ElevatedButton(
            onPressed: () => _saveEvent(context),
            child: Text(
              _isExpense ? 'Tallenna meno' : 'Tallenna tulo',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).elevatedButtonTheme.style?.foregroundColor?.resolve({}),
                  ),
              textAlign: TextAlign.center, // Keskitetään teksti
            ),
          ),
        ),
      ],
    );
  }
}