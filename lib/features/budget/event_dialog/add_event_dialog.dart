import 'package:budu/features/budget/event_dialog/managers/add_event_dialog_state_manager.dart';
import 'package:budu/features/budget/event_dialog/amount_input_field.dart';
import 'package:budu/features/budget/event_dialog/selectors/budget_selector.dart';
import 'package:budu/features/budget/event_dialog/selectors/category_selector.dart';
import 'package:budu/features/budget/event_dialog/selectors/date_selector.dart';
import 'package:budu/features/budget/event_dialog/description_input_field.dart';
import 'package:budu/features/budget/event_dialog/selectors/event_type_selector.dart';
import 'package:budu/features/budget/event_dialog/event_validator.dart';
import 'package:budu/features/budget/event_dialog/services/budget_selection_service.dart';
import 'package:budu/features/budget/event_dialog/services/event_saving_service.dart';
import 'package:flutter/material.dart';

/// Dialogi uuden meno- tai tulotapahtuman lisäämiseksi.
/// Nyt tukee sekä henkilökohtaista että yhteistalousbudjettia:
/// - Lisätty valinnainen isSharedBudget-parametri widget:iin.
/// - Välittää isSharedBudget BudgetSelectionService:lle ja EventSavingService:lle.
/// - Kaikki muu toiminnallisuus (alustus, date picker, validointi, UI-osat)
///   säilytetty ennallaan – vain lisätty tuki yhteistalousbudjetille.
class AddEventDialog extends StatefulWidget {
  final String? initialCategory;
  final String? initialBudgetId;
  final bool isSharedBudget; // Lisätty: Määrittää, onko yhteistalousbudjetti

  const AddEventDialog({
    super.key,
    this.initialCategory,
    this.initialBudgetId,
    this.isSharedBudget = false, // Oletus: Henkilökohtainen
  });

  @override
  State<AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<AddEventDialog> {
  late AddEventDialogStateManager _stateManager;
  late BudgetSelectionService _budgetSelectionService;
  late EventSavingService _eventSavingService;
  final EventValidator _validator = EventValidator();

  @override
  void initState() {
    super.initState();
    _budgetSelectionService = BudgetSelectionService(context);
    _eventSavingService = EventSavingService(context);
    // Alustetaan stateManager initialCategory-arvolla
    _stateManager = AddEventDialogStateManager(
      selectedCategory: widget.initialCategory,
    );
    _initializeDialog();
  }

  @override
  void dispose() {
    _stateManager.dispose();
    super.dispose();
  }

  Future<void> _initializeDialog() async {
    await _budgetSelectionService.initializeBudgetSelection(
      stateManager: _stateManager,
      initialBudgetId: widget.initialBudgetId,
      onNoBudgets: () {
        if (mounted) {
          Navigator.pop(context);
        }
      },
      isSharedBudget: widget.isSharedBudget, // Välitetään budjettityyppi
    );

    if (_stateManager.selectedBudgetId != null) {
      await _budgetSelectionService.loadSelectedBudget(
        selectedBudgetId: _stateManager.selectedBudgetId!,
        stateManager: _stateManager,
        initialCategory: widget.initialCategory,
        onNoSubcategories: () {
          if (mounted) {
            Navigator.pop(context);
          }
        },
        isSharedBudget: widget.isSharedBudget, // Välitetään budjettityyppi
      );
    }

    if (mounted) {
      print('isLoading after initialization: ${_stateManager.isLoading}');
      setState(() {});
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _stateManager.selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _stateManager.selectedDate) {
      setState(() {
        _stateManager.updateSelectedDate(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_stateManager.isLoading) {
      print('Showing loading indicator, isLoading: ${_stateManager.isLoading}');
      return const AlertDialog(
        content: Center(child: CircularProgressIndicator()),
      );
    }

    print('Rendering dialog content, isLoading: ${_stateManager.isLoading}');
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
              // Lisätty: Teksti budjettityypistä ennen dropdownia
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  widget.isSharedBudget ? 'Lisää tapahtuma yhteistalousbudjettiin' : 'Lisää tapahtuma henkilökohtaiseen budjettiin',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              BudgetSelector(
                selectedBudgetId: _stateManager.selectedBudgetId,
                availableBudgets: _stateManager.availableBudgets,
                onChanged: (value) {
                  setState(() {
                    _stateManager.updateBudgetSelection(value);
                  });
                  if (_stateManager.selectedBudgetId != null) {
                    _budgetSelectionService.loadSelectedBudget(
                      selectedBudgetId: _stateManager.selectedBudgetId!,
                      stateManager: _stateManager,
                      initialCategory: widget.initialCategory,
                      onNoSubcategories: () {
                        if (mounted) {
                          Navigator.pop(context);
                        }
                      },
                      isSharedBudget: widget.isSharedBudget, // Välitetään budjettityyppi
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
              EventTypeSelector(
                isExpense: _stateManager.isExpense,
                onTypeChanged: (isExpense) {
                  setState(() {
                    _stateManager.updateEventType(isExpense);
                  });
                },
              ),
              const SizedBox(height: 16),
              AmountInputField(
                controller: _stateManager.amountController,
                errorText: _stateManager.amountError,
                onChanged: (value) {
                  setState(() {
                    _stateManager.updateAmountError(null);
                  });
                },
              ),
              const SizedBox(height: 16),
              CategorySelector(
                isExpense: _stateManager.isExpense,
                selectedCategory: _stateManager.selectedCategory,
                selectedSubcategory: _stateManager.selectedSubcategory,
                categoryError: _stateManager.categoryError,
                subcategoryError: _stateManager.subcategoryError,
                onCategoryChanged: (value) {
                  setState(() {
                    _stateManager.updateCategory(value, _stateManager.currentBudget);
                  });
                },
                onSubcategoryChanged: (value) {
                  setState(() {
                    _stateManager.updateSubcategory(value);
                  });
                },
                budget: _stateManager.currentBudget,
                hasSubcategoriesForSelectedCategory: _stateManager.hasSubcategoriesForSelectedCategory,
              ),
              const SizedBox(height: 16),
              DescriptionInputField(
                controller: _stateManager.descriptionController,
                errorText: _stateManager.descriptionError,
                onChanged: (value) {
                  setState(() {
                    _stateManager.updateDescriptionError(null);
                  });
                },
              ),
              const SizedBox(height: 16),
              DateSelector(
                selectedDate: _stateManager.selectedDate,
                onSelectDate: () => _selectDate(),
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
              Navigator.pop(context);
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
            onPressed: (_stateManager.isExpense && !_stateManager.hasSubcategoriesForSelectedCategory)
                ? null
                : () => _eventSavingService.saveEvent(
                      stateManager: _stateManager,
                      validator: _validator,
                      onSuccess: () {
                        Navigator.pop(context, {'success': true, 'isExpense': _stateManager.isExpense});
                      },
                      onFailure: () {
                        Navigator.pop(context);
                      },
                      isSharedBudget: widget.isSharedBudget, // Välitetään budjettityyppi
                    ),
            child: Text(
              _stateManager.isExpense ? 'Tallenna meno' : 'Tallenna tulo',
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