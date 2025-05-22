import 'package:budu/core/utils.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/event_dialog/category_selector.dart';
import 'package:budu/features/budget/event_dialog/event_type_selector.dart';
import 'package:budu/features/budget/event_dialog/event_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../models/expense_event.dart';
import '../providers/budget_provider.dart';
import '../providers/expense_provider.dart';

/// Dialogi uuden meno- tai tulotapahtuman lisäämiseksi.
/// Käyttäjä voi valita tapahtuman tyypin, summan, kategorian, päivämäärän ja lisätä valinnaisen kuvauksen.
class AddEventDialog extends StatefulWidget {
  final String? initialCategory; // Esivalittu kategoria, jos sellainen on annettu

  const AddEventDialog({super.key, this.initialCategory});

  @override
  State<AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<AddEventDialog> {
  bool _isExpense = true; // Oletuksena meno, voidaan vaihtaa tuloksi
  final TextEditingController _amountController = TextEditingController(); // Summan syöttökenttä
  final TextEditingController _descriptionController = TextEditingController(); // Kuvauksen syöttökenttä
  String? _selectedCategory; // Valittu kategoria
  String? _selectedSubcategory; // Valittu alakategoria
  DateTime _selectedDate = DateTime.now(); // Valittu päivämäärä
  String? _amountError; // Virheilmoitus summalle
  String? _descriptionError; // Virheilmoitus kuvalle
  String? _categoryError; // Virheilmoitus kategorialle
  String? _subcategoryError; // Virheilmoitus alakategorialle
  final EventValidator _validator = EventValidator(); // Validointiluokka

  @override
  void initState() {
    super.initState();
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    // Asetetaan esivalittu kategoria, jos initialCategory on annettu, muuten otetaan budjetin ensimmäinen kategoria
    _selectedCategory = widget.initialCategory ?? budgetProvider.budget?.expenses.keys.first;
    if (_selectedCategory != null && budgetProvider.budget != null) {
      final subCategories = budgetProvider.budget!.expenses[_selectedCategory]?.keys.toList() ?? [];
      _selectedSubcategory = subCategories.isNotEmpty ? subCategories.first : null;
    }
    // Tarkistetaan, onko budjetissa alakategorioita; jos ei, näytetään virheilmoitus ja suljetaan dialogi
    _checkForSubcategories();
  }

  @override
  void dispose() {
    // Vapautetaan resurssit
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Tarkistaa, onko budjetissa alakategorioita. Jos ei, näytetään virheilmoitus ja suljetaan dialogi.
  void _checkForSubcategories() {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    bool hasSubcategories = false;
    if (budgetProvider.budget != null) {
      for (var category in budgetProvider.budget!.expenses.keys) {
        if (budgetProvider.budget!.expenses[category]!.isNotEmpty) {
          hasSubcategories = true;
          break;
        }
      }
    }
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

  /// Näyttää päivämäärävalitsimen ja asettaa valitun päivämäärän.
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

  /// Tallentaa tapahtuman Firestoreen ja päivittää budjetin, jos kyseessä on tulo.
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

    // Validoidaan syötteet
    final validationResult = _validator.validateEvent(
      isExpense: _isExpense,
      amountText: _amountController.text,
      description: _descriptionController.text,
      selectedCategory: _selectedCategory,
      selectedSubcategory: _selectedSubcategory,
      authProvider: authProvider,
      budgetProvider: budgetProvider,
    );

    if (validationResult != null) {
      // Näytetään validointivirheet asianomaisissa kentissä
      setState(() {
        if (validationResult.contains('Syötä positiivinen numero') || validationResult.contains('Summa voi olla enintään 99999')) {
          _amountError = validationResult;
        } else if (validationResult.contains('Kuvaus voi olla enintään 75 merkkiä')) {
          _descriptionError = validationResult;
        } else if (validationResult.contains('Valitse kategoria')) {
          _categoryError = validationResult;
        } else if (validationResult.contains('Valitse alakategoria')) {
          _subcategoryError = validationResult;
        } else if (validationResult.contains('Käyttäjä ei ole kirjautunut')) {
          showSnackBar(
            context,
            validationResult,
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.blueGrey[700],
          );
          Navigator.pop(context);
        }
      });
      return;
    }

    try {
      // Muunnetaan summa double-tyypiksi
      final amount = double.parse(_amountController.text);
      // Luodaan uusi ExpenseEvent-olio
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
      // Tallennetaan tapahtuma Firestoreen
      await expenseProvider.addExpense(authProvider.user!.uid, event, budgetProvider);
      // Suljetaan dialogi ja palautetaan onnistumistieto
      Navigator.pop(context, {'success': true, 'isExpense': _isExpense});
    } catch (e) {
      // Raportoidaan virhe Crashlyticsiin
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current, reason: 'Tapahtuman tallennus epäonnistui');
      // Näytetään virheilmoitus käyttäjälle
      showSnackBar(
        context,
        'Virhe tallennettaessa tapahtumaa: ${e.toString()}',
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.redAccent,
      );
      Navigator.pop(context);
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
              // Tapahtuman tyypin valinta (meno tai tulo)
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
              // Summan syöttökenttä
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Summa (€)',
                  border: const OutlineInputBorder(),
                  errorText: _amountError,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9]')), // Sallii vain numerot
                  LengthLimitingTextInputFormatter(5), // Enintään 5 numeroa
                ],
                onChanged: (value) {
                  setState(() {
                    _amountError = null; // Poistetaan virhe, kun käyttäjä muokkaa kenttää
                  });
                },
              ),
              const SizedBox(height: 16),
              // Kategorian ja alakategorian valitsin
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
              // Kuvauksen syöttökenttä
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Kuvaus (valinnainen)',
                  border: const OutlineInputBorder(),
                  errorText: _descriptionError,
                ),
                maxLines: 2,
                maxLength: 75, // Enintään 75 merkkiä
                onChanged: (value) {
                  setState(() {
                    _descriptionError = null; // Poistetaan virhe, kun käyttäjä muokkaa kenttää
                  });
                },
              ),
              const SizedBox(height: 16),
              // Päivämäärän valinta
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
              Navigator.pop(context); // Suljetaan dialogi
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
            onPressed: () => _saveEvent(context), // Tallennetaan tapahtuma
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