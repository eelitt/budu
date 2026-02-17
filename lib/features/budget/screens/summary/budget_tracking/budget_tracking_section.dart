import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:budu/features/budget/screens/summary/budget_tracking/category_expansion_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Näyttää budjetin kategorioiden seurannan yhteenvetosivulla.
/// Tukee nyt täysin sekä henkilökohtaista että yhteistalousbudjettia:
/// - Suunnitellut summat (kategoriat, alakategoriat, kokonaisbudjetti) otetaan suoraan
///   välitetystä widget.budget-parametrista (joko henkilökohtainen tai yhteistalous).
/// - Toteutuneet summat (categoryTotals) haetaan ExpenseProvider:stä – toimii molemmille,
///   koska SummaryScreen lataa aina oikeat menot/tapahtumat loadExpenses-kutsulla.
/// - Ei enää riipu BudgetProvider.budget:sta – poistaa ristiriidat yhteistalousbudjetin kanssa.
/// - Kaikki alkuperäinen toiminnallisuus (laajennus, lajittelu, yhteensä-teksti, virheenkäsittely)
///   säilytetty täysin ennallaan.
/// - Tehokas: Ei ylimääräisiä Firestore-kutsuja, käyttää välitettyä BudgetModel:ia suunniteltuihin
///   ja ExpenseProvider:ia toteutuneisiin.
class BudgetTrackingSection extends StatefulWidget {
  final BudgetModel budget; // Valittu budjetti (henkilökohtainen tai yhteistalous)
final bool isSharedBudget;
  const BudgetTrackingSection({
    super.key,
    required this.budget,
    this.isSharedBudget = false,
  });

  @override
  State<BudgetTrackingSection> createState() => _BudgetTrackingSectionState();
}

class _BudgetTrackingSectionState extends State<BudgetTrackingSection> {
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    // Ladataan menot/tapahtumat build-vaiheen jälkeen (varmistaa oikea budgetId)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadExpenses();
      }
    });
  }

  /// Lataa menot/tapahtumat välitetylle budjetille (henkilökohtainen tai yhteistalous).
  Future<void> _loadExpenses() async {
    try {
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user != null) {
        await expenseProvider.loadExpenses(authProvider.user!.uid, widget.budget.id!, isSharedBudget: widget.isSharedBudget);
      }
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to load expenses for budget ${widget.budget.id}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tapahtumien lataus epäonnistui: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final categoryTotals = expenseProvider.getCategoryTotals();

    // Käytetään suoraan välitettyä budjettia (ei BudgetProvider.budget:ia)
    final budget = widget.budget;

    // Haetaan kategoriat budjetista ja lajitellaan aakkosjärjestykseen
    final budgetCategories = budget.expenses.keys.toList()..sort();

    // Luo kategoriatilet
    final List<Widget> categoryWidgets = budgetCategories.map((categoryName) {
      final categoryExpenses = budget.expenses[categoryName]!.entries
          .map((e) => MapEntry(e.key, e.value))
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      final categoryBudget = categoryExpenses.fold<double>(0.0, (sum, e) => sum + e.value);
      final categorySpent = categoryTotals[categoryName] ?? 0.0;

      return CategoryExpansionTile(
        categoryName: categoryName,
        categoryBudget: categoryBudget,
        categorySpent: categorySpent,
        categoryExpenses: categoryExpenses,
        budgetId: budget.id!,
        isSharedBudget: widget.isSharedBudget
      );
    }).toList();

    // Lasketaan kokonaisbudjetti ja toteutuneet summat
    final totalBudget = budgetCategories.fold<double>(
        0.0, (sum, category) => sum + budget.expenses[category]!.values.fold(0.0, (s, v) => s + v));
    final totalSpent = budgetCategories.fold<double>(
        0.0, (sum, category) => sum + (categoryTotals[category] ?? 0.0));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _isExpanded,
          onExpansionChanged: (bool expanded) {
            if (mounted) {
              setState(() {
                _isExpanded = expanded;
              });
            }
          },
          tilePadding: EdgeInsets.zero,
          leading: const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.assignment_outlined, color: Colors.blueGrey),
          ),
          title: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Budjettiseuranta',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (budgetCategories.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${budgetCategories.length} kategoria${budgetCategories.length == 1 ? '' : 'a'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                    ),
                  ),
              ],
            ),
          ),
          trailing: const Padding(
            padding: EdgeInsets.only(right: 10),
            child: Icon(Icons.expand_more),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...categoryWidgets,
                  if (budgetCategories.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Yhteensä: ${totalSpent.toStringAsFixed(2)} / ${totalBudget.toStringAsFixed(2)} €',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: totalSpent > totalBudget ? Colors.red : Colors.black87,
                            ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}