import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:budu/features/budget/screens/budget/widgets/budget_month_selector.dart';
import 'package:budu/features/budget/screens/summary/budget_distribution_section.dart';
import 'package:budu/features/budget/screens/summary/budget_tracking/budget_tracking_section.dart';
import 'package:budu/features/budget/screens/summary/event_section.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Yhteenvetonäkymä (SummaryScreen).
/// Nyt täysin yhteensopiva sekä henkilökohtaisen että yhteistalousbudjetin kanssa.
/// - Toggle-näkyy vain, jos yhteistalousbudjetteja on.
/// - Toggle-valinta tallennetaan erikseen ('isSharedBudget_summary') – ei häiritse BudgetScreenin valintaa.
/// - Kuukausivalitsin toimii molemmille budjettityypeille.
/// - Vaihtaessa budjettityyppiä tai kuukautta ladataan aina oikeat menot/tapahtumat ExpenseProvideriin (loadExpenses).
/// - Henkilökohtaiset budjetit haetaan kerran initissä (getAvailableBudgets) – tehokas.
/// - BudgetTrackingSection saa passed BudgetModel:in suunnitellut summat.
/// - BudgetDistributionSection ja EventsSection käyttävät ExpenseProvider.events – toimii molemmille, koska expenses ladataan oikein.
/// - Kaikki olemassa oleva toiminnallisuus säilytetty, vain lisätty tuki yhteistalousbudjetille.
class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  bool _isSharedBudget = false;
  bool _isLoading = true;

  List<BudgetModel> _availablePersonalBudgets = [];
  BudgetModel? _selectedSharedBudget;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPreferencesAndBudgets();
    });
  }

  /// Lataa valinnat, budjettilistat ja alkumenot.
  Future<void> _loadPreferencesAndBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIsShared = prefs.getBool('isSharedBudget_summary') ?? false;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final sharedProvider = Provider.of<SharedBudgetProvider>(context, listen: false);
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);

    // Henkilökohtaiset budjetit (kerran – tehokas Firestore-kutsu)
    final personalBudgets = await budgetProvider.getAvailableBudgets(authProvider.user!.uid);

    // Valitse uusin yhteistalousbudjetti, jos sellaisia on
    BudgetModel? initialShared;
    if (sharedProvider.sharedBudgets.isNotEmpty) {
      final sorted = List<BudgetModel>.from(sharedProvider.sharedBudgets)
        ..sort((a, b) => b.startDate!.compareTo(a.startDate!));
      initialShared = sorted.first;
    }

    if (mounted) {
      setState(() {
        _availablePersonalBudgets = personalBudgets;
        _isSharedBudget = sharedProvider.hasSharedBudget && savedIsShared;
        _selectedSharedBudget = initialShared;
        _isLoading = false;
      });
    }

    // Lataa alkumenot nykyiselle budjetille
    final initialBudgetId = _getCurrentBudgetId();
    if (initialBudgetId != null && mounted) {
      await expenseProvider.loadExpenses(authProvider.user!.uid, initialBudgetId);
    }
  }

  String? _getCurrentBudgetId() {
    if (_isSharedBudget) {
      return _selectedSharedBudget?.id;
    }
    return Provider.of<BudgetProvider>(context, listen: false).budget?.id;
  }

  Future<void> _savePreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isSharedBudget_summary', value);
  }

  /// Toggle-vaihto: tallenna valinta ja lataa oikeat menot.
  Future<void> _onToggleChanged(bool value) async {
    await _savePreference(value);

    setState(() {
      _isSharedBudget = value;
      if (value && _selectedSharedBudget == null && Provider.of<SharedBudgetProvider>(context, listen: false).sharedBudgets.isNotEmpty) {
        final sorted = List<BudgetModel>.from(Provider.of<SharedBudgetProvider>(context, listen: false).sharedBudgets)
          ..sort((a, b) => b.startDate!.compareTo(a.startDate!));
        _selectedSharedBudget = sorted.first;
      }
    });

    final budgetId = _getCurrentBudgetId();
    if (budgetId != null && mounted) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final expense = Provider.of<ExpenseProvider>(context, listen: false);
      await expense.loadExpenses(auth.user!.uid, budgetId);
    }
  }

  /// Kuukausivalinta: lataa valittu budjetti (henkilökohtainen) ja aina menot.
  Future<void> _onBudgetSelected(dynamic selected) async {
    if (selected == null) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);

    if (_isSharedBudget) {
      setState(() => _selectedSharedBudget = selected);
    } else {
      // Lataa henkilökohtainen budjetti provideriin (tarvitaan suunnitellut summat)
      await budgetProvider.loadBudget(auth.user!.uid, selected.id!);
    }

    // Lataa menot/tapahtumat – toimii molemmille budjettityypeille
    await expenseProvider.loadExpenses(auth.user!.uid, selected.id!, isSharedBudget: _isSharedBudget);
  }

  BudgetModel? get _currentBudget {
    return _isSharedBudget ? _selectedSharedBudget : Provider.of<BudgetProvider>(context, listen: false).budget;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Consumer3<BudgetProvider, SharedBudgetProvider, ExpenseProvider>(
      builder: (context, budgetProvider, sharedProvider, expenseProvider, child) {
        final showToggle = sharedProvider.hasSharedBudget;
        final currentBudget = _currentBudget;

        if (currentBudget == null) {
          return const Center(child: Text('Luo budjetti ensin!'));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (showToggle) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Henkilökohtainen',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontSize: 16,
                              fontWeight: _isSharedBudget ? FontWeight.normal : FontWeight.bold,
                            )),
                    Switch(
                      value: _isSharedBudget,
                      onChanged: _onToggleChanged,
                      activeColor: Colors.blueGrey[700],
                      inactiveThumbColor: Colors.blueGrey[300],
                    ),
                    Text('Yhteistalous',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontSize: 16,
                              fontWeight: _isSharedBudget ? FontWeight.bold : FontWeight.normal,
                            )),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              BudgetMonthSelector(
                isSharedBudget: _isSharedBudget,
                availableBudgets: _availablePersonalBudgets,
                availableSharedBudgets: sharedProvider.sharedBudgets,
                selectedBudget: budgetProvider.budget,
                selectedSharedBudget: _selectedSharedBudget,
                onBudgetSelected: _onBudgetSelected,
              ),

              const SizedBox(height: 24),

              BudgetTrackingSection(budget: currentBudget, isSharedBudget: _isSharedBudget),

              const SizedBox(height: 24),

              const BudgetDistributionSection(),

              const SizedBox(height: 24),

              EventsSection(budget: currentBudget, isSharedBudget: _isSharedBudget),
            ],
          ),
        );
      },
    );
  }
}