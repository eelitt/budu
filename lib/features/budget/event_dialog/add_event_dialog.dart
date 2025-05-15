import 'package:budu/core/utils.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/event_dialog/category_selector.dart';
import 'package:budu/features/budget/event_dialog/event_type_selector.dart';
import 'package:budu/features/budget/event_dialog/event_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Tarvitaan inputFormatters-ominaisuutta varten
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
  String? _amountError;
  String? _descriptionError;
  String? _categoryError;
  String? _subcategoryError;
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

    // Tarkista, onko budjetissa yhtään alakategoriaa
    bool hasSubcategories = false;
    if (budgetProvider.budget != null) {
      for (var category in budgetProvider.budget!.expenses.keys) {
        if (budgetProvider.budget!.expenses[category]!.isNotEmpty) {
          hasSubcategories = true;
          break;
        }
      }
    }

    // Näytä SnackBar ja sulje dialogi, jos alakategorioita ei ole
    if (_isExpense && !hasSubcategories) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showSnackBar(
          context,
          'Lisää ensin alakategoria budjettiin!',
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.blueGrey[700],
        );
        Navigator.pop(context);
      });
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

    // Nollaa aiemmat virheet
    setState(() {
      _amountError = null;
      _descriptionError = null;
      _categoryError = null;
      _subcategoryError = null;
    });

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
        if (error.contains('Syötä positiivinen numero') || error.contains('Summa voi olla enintään 99999')) {
          _amountError = error;
        } else if (error.contains('Kuvaus voi olla enintään 75 merkkiä')) {
          _descriptionError = error;
        } else if (error.contains('Valitse kategoria')) {
          _categoryError = error;
        } else if (error.contains('Valitse alakategoria')) {
          _subcategoryError = error;
        } else if (error.contains('Käyttäjä ei ole kirjautunut')) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showSnackBar(
              context,
              error,
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.blueGrey[700],
            );
            if (mounted) {
              Navigator.pop(context, true);
            }
          });
        }
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
      print('AddEventDialog: Tapahtuma tallennettu, yritetään sulkea dialogi');
      if (mounted) {
        Navigator.pop(context, {'success': true, 'isExpense': _isExpense});
      } else {
        print('AddEventDialog: Widget ei ole enää kiinnitetty, ei voida sulkea dialogia');
      }
    } catch (e) {
      print('AddEventDialog: Virhe tallennuksessa: $e');
      if (mounted) {
        showSnackBar(
          context,
          'Virhe tallennettaessa tapahtumaa: $e',
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.blueGrey[700],
        );
        Navigator.pop(context);
      }
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
            minWidth: 300,
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
                    _amountError = null;
                    _descriptionError = null;
                    _categoryError = null;
                    _subcategoryError = null;
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
                  errorText: _amountError,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9]')), // Sallitaan vain numerot
                  LengthLimitingTextInputFormatter(5), // Rajoitetaan syöte 5 merkkiin
                ],
                onChanged: (value) {
                  setState(() {
                    _amountError = null;
                  });
                },
              ),
              const SizedBox(height: 16),
              CategorySelector(
                isExpense: _isExpense,
                selectedCategory: _selectedCategory,
                selectedSubcategory: _selectedSubcategory,
                categoryError: _categoryError,
                subcategoryError: _subcategoryError,
                onCategoryChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                    _selectedSubcategory = null;
                    _categoryError = null;
                    _subcategoryError = null;
                    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
                    final subCategories = budgetProvider.budget?.expenses[value]?.keys.toList() ?? [];
                    _selectedSubcategory = subCategories.isNotEmpty ? subCategories.first : null;
                  });
                },
                onSubcategoryChanged: (value) {
                  setState(() {
                    _selectedSubcategory = value;
                    _subcategoryError = null;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Kuvaus (valinnainen)',
                  border: const OutlineInputBorder(),
                  errorText: _descriptionError,
                ),
                maxLines: 2,
                maxLength: 75,
                onChanged: (value) {
                  setState(() {
                    _descriptionError = null;
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
          width: 85,
          child: TextButton(
            onPressed: () {
              print('AddEventDialog: Peruuta-painike painettu, suljetaan dialogi');
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: Text(
              'Peruuta',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
        SizedBox(
          width: 135,
          child: ElevatedButton(
            onPressed: () => _saveEvent(context),
            child: Text(
              _isExpense ? 'Tallenna meno' : 'Tallenna tulo',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).elevatedButtonTheme.style?.foregroundColor?.resolve({}),
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}