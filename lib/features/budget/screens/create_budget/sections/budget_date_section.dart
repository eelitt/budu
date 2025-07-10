import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Widget budjetin tyypin ja aikavälin valintaan.
/// Käyttää PopupMenuButton:ia budjetin tyypille ja päivämäärävalitsimia aloitus- ja päättymispäivälle.
/// Käyttää valkoista taustaa pyöristetyin reunoin ja varjostuksin.
class BudgetDateSection extends StatefulWidget {
  final Function(String?) onTypeChanged; // Callback tyypin muutokselle
  final Function(DateTime?) onStartDateChanged; // Callback aloituspäivän muutokselle
  final Function(DateTime?) onEndDateChanged; // Callback päättymispäivän muutokselle

  const BudgetDateSection({
    super.key,
    required this.onTypeChanged,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
  });

  @override
  State<BudgetDateSection> createState() => _BudgetDateSectionState();
}

class _BudgetDateSectionState extends State<BudgetDateSection> {
  String? _selectedType = 'monthly'; // Oletustyyppi
  DateTime? _suggestedStartDate; // Ehdotettu aloituspäivä
  DateTime? _suggestedEndDate; // Ehdotettu päättymispäivä
  late TextEditingController _startDateController; // Ohjain aloituspäivälle
  late TextEditingController _endDateController; // Ohjain päättymispäivälle
  bool _isLoading = true; // Lataustila budjettien tarkistamiseen
  String? _errorMessage; // Virheviesti aikavälin validoinnille

  // Budjetin tyyppien lista ja niiden näyttönimet
  final Map<String, String> _budgetTypes = {
    'monthly': 'Kuukausittainen',
    'biweekly': '2 viikkoa',
    'custom': 'Mukautettu',
  };

  @override
  void initState() {
    super.initState();
    _startDateController = TextEditingController();
    _endDateController = TextEditingController();
    // Ladataan ehdotettu aikaväli build-vaiheen jälkeen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadSuggestedPeriod();
      }
    });
  }

  /// Lataa ehdotettu aikaväli viimeisimmän budjetin perusteella
  Future<void> _loadSuggestedPeriod() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
      if (authProvider.user != null) {
        final budgets = await budgetProvider.getAvailableBudgets(authProvider.user!.uid);
        DateTime startDate;
        DateTime endDate;

        if (budgets.isNotEmpty) {
          // Viimeisin budjetti endDate:n perusteella
          final latestBudget = budgets.reduce((a, b) => a.endDate.isAfter(b.endDate) ? a : b);
          startDate = latestBudget.endDate.add(Duration(days: 1));
          if (_selectedType == 'monthly') {
            endDate = DateTime(startDate.year, startDate.month + 1, 0); // Kuukauden viimeinen päivä
          } else if (_selectedType == 'biweekly') {
            endDate = startDate.add(Duration(days: 13)); // 2 viikon jakso (13 päivää + startDate)
          } else {
            endDate = startDate.add(Duration(days: 30)); // Oletus 30 päivää
          }
        } else {
          // Oletus: Nykyinen kuukausi
          final now = DateTime.now();
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 0);
        }

        if (mounted) {
          setState(() {
            _suggestedStartDate = startDate;
            _suggestedEndDate = endDate;
            _startDateController.text = DateFormat('d.M.yyyy').format(startDate);
            _endDateController.text = DateFormat('d.M.yyyy').format(endDate);
            _isLoading = false;
            widget.onTypeChanged(_selectedType);
            widget.onStartDateChanged(startDate);
            widget.onEndDateChanged(endDate);
          });
        }
      } else {
        await FirebaseCrashlytics.instance.log('Käyttäjä ei ole kirjautunut, aikaväliä ei ladattu');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Kirjaudu sisään valitaksesi aikaväli';
          });
        }
      }
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to load suggested budget period',
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Aikavälin lataus epäonnistui: $e';
        });
      }
    }
  }

  /// Näyttää päivämäärävalitsimen ja palauttaa valitun päivän
  Future<DateTime?> _selectDate(BuildContext context, DateTime initialDate) async {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
  }

  /// Tarkistaa aikavälin ja päivittää budjetin tyypin automaattisesti
  void _validatePeriodType() {
    if (_suggestedStartDate == null || _suggestedEndDate == null) return;

    final duration = _suggestedEndDate!.difference(_suggestedStartDate!).inDays;
    final isMonth = _suggestedStartDate!.day == 1 &&
        _suggestedEndDate!.day == DateTime(_suggestedEndDate!.year, _suggestedEndDate!.month + 1, 0).day;

    if (_selectedType == 'monthly' && (!isMonth || duration < 28 || duration > 31)) {
      // Jos aikaväli ei vastaa kuukautta, vaihdetaan custom:iin
      _selectedType = 'custom';
      widget.onTypeChanged(_selectedType);
    } else if (duration == 13 && _selectedType != 'biweekly') {
      // Jos aikaväli on täsmälleen 2 viikkoa (13 päivää + startDate), vaihdetaan biweekly:iin
      _selectedType = 'biweekly';
      widget.onTypeChanged(_selectedType);
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
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
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          // Budjetin tyypin valinta PopupMenuButton:illa
          PopupMenuButton<String>(
            onSelected: (value) {
              if (mounted) {
                setState(() {
                  _selectedType = value;
                  // Päivitä ehdotettu aikaväli tyypin mukaan
                  if (value == 'monthly') {
                    _suggestedStartDate = _suggestedStartDate ?? DateTime.now();
                    _suggestedEndDate = DateTime(_suggestedStartDate!.year, _suggestedStartDate!.month + 1, 0);
                  } else if (value == 'biweekly') {
                    _suggestedStartDate = _suggestedStartDate ?? DateTime.now();
                    _suggestedEndDate = _suggestedStartDate!.add(Duration(days: 13));
                  } else {
                    _suggestedEndDate = _suggestedStartDate!.add(Duration(days: 30));
                  }
                  _startDateController.text = DateFormat('d.M.yyyy').format(_suggestedStartDate!);
                  _endDateController.text = DateFormat('d.M.yyyy').format(_suggestedEndDate!);
                  widget.onTypeChanged(value);
                  widget.onStartDateChanged(_suggestedStartDate);
                  widget.onEndDateChanged(_suggestedEndDate);
                });
              }
            },
            itemBuilder: (BuildContext context) {
              return _budgetTypes.entries.map((entry) {
                return PopupMenuItem<String>(
                  value: entry.key,
                  child: Text(
                    entry.value,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.black87,
                          fontSize: 15,
                        ),
                  ),
                );
              }).toList();
            },
            color: Colors.white, // Valkoinen tausta valikolle
            position: PopupMenuPosition.under, // Aukeaa valikon alle
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _budgetTypes[_selectedType] ?? 'Valitse budjetin tyyppi',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.black87,
                            fontSize: 16,
                          ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_drop_down,
                    color: Colors.black87,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Aikavälin valinta
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _startDateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Alkamispäivä',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: () async {
                    final selectedDate = await _selectDate(context, _suggestedStartDate ?? DateTime.now());
                    if (selectedDate != null && mounted) {
                      setState(() {
                        _suggestedStartDate = selectedDate;
                        _startDateController.text = DateFormat('d.M.yyyy').format(selectedDate);
                        widget.onStartDateChanged(selectedDate);
                        // Validointi: Varmista, että endDate ei ole ennen startDate:ä
                        if (_suggestedEndDate!.isBefore(selectedDate)) {
                          _suggestedEndDate = selectedDate.add(Duration(days: 1));
                          _endDateController.text = DateFormat('d.M.yyyy').format(_suggestedEndDate!);
                          widget.onEndDateChanged(_suggestedEndDate);
                        }
                        _validatePeriodType();
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _endDateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Päättymispäivä',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: () async {
                    final selectedDate = await _selectDate(context, _suggestedEndDate ?? DateTime.now());
                    if (selectedDate != null && mounted) {
                      setState(() {
                        _suggestedEndDate = selectedDate;
                        _endDateController.text = DateFormat('d.M.yyyy').format(selectedDate);
                        widget.onEndDateChanged(selectedDate);
                        // Validointi: Varmista, että startDate ei ole jälkeen endDate:n
                        if (_suggestedStartDate!.isAfter(selectedDate)) {
                          _suggestedStartDate = selectedDate.subtract(Duration(days: 1));
                          _startDateController.text = DateFormat('d.M.yyyy').format(_suggestedStartDate!);
                          widget.onStartDateChanged(_suggestedStartDate);
                        }
                        _validatePeriodType();
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          // Näyttää virheviestin, jos aikavälin lataus epäonnistuu
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}