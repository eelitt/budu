import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Widget, joka näyttää budjetin tulot ja budjetoidut menot.
/// Mahdollistaa tulojen muokkaamisen ja näyttää reaaliajassa päivittyvän budjetoitujen menojen summan.
class IncomeSection extends StatefulWidget {
  const IncomeSection({super.key});

  @override
  State<IncomeSection> createState() => _IncomeSectionState();
}

/// IncomeSectionin tilallinen tila, joka hallinnoi tulojen muokkaustilaa ja virheviestejä.
class _IncomeSectionState extends State<IncomeSection> {
  bool _isEditing = false; // Seuraa, onko muokkaustila aktiivinen
  final TextEditingController _amountController = TextEditingController(); // Tekstikentän ohjain tulojen summan muokkaamiseen
  String? _errorMessage; // Virheviesti, joka näytetään, jos syöte ei ole kelvollinen

  @override
  void initState() {
    super.initState();
    // Haetaan BudgetProvider ja asetetaan alustava tulojen summa tekstikenttään
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    _amountController.text = budgetProvider.budget?.income.toStringAsFixed(2) ?? '0.00';
  }

  @override
  void dispose() {
    // Vapautetaan tekstikentän ohjaimen resurssit
    _amountController.dispose();
    super.dispose();
  }

  /// Aloittaa tulojen muokkaustilan.
  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
  }

  /// Peruuttaa muokkaustilan ja palauttaa alkuperäisen tulojen summan.
  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
      _amountController.text = budgetProvider.budget?.income.toStringAsFixed(2) ?? '0.00';
      _errorMessage = null; // Nollataan virheviesti
    });
  }

  /// Tallentaa muokatun tulojen summan Firestoreen ja validoi syötteen.
  void _saveChanges() {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    // Validoinnit euromäärälle
    if (amount == null || amount < 0) {
      setState(() {
        _errorMessage = 'Syötä positiivinen numero';
      });
      return;
    }

    if (amount > 1000000) {
      setState(() {
        _errorMessage = 'Euromäärä voi olla enintään 1 000 000 €';
      });
      return;
    }

    final decimalPlaces = amountText.contains('.') ? amountText.split('.')[1].length : 0;
    if (decimalPlaces > 2) {
      setState(() {
        _errorMessage = 'Euromäärä voi sisältää enintään 2 desimaalia';
      });
      return;
    }

    // Päivitetään tulot Firestoreen, jos käyttäjä on autentikoitu
    if (authProvider.user != null) {
      budgetProvider.updateIncome(
        userId: authProvider.user!.uid,
        year: DateTime.now().year,
        month: DateTime.now().month,
        income: amount,
      );
      setState(() {
        _isEditing = false; // Poistutaan muokkaustilasta
        _errorMessage = null; // Nollataan virheviesti
      });
    }
  }

  /// Laskee budjetoitujen menojen kokonaissumman BudgetProviderin expenses-datasta.
  double _calculateTotalExpenses(Map<String, Map<String, double>> expenses) {
    double total = 0.0;
    expenses.forEach((category, subcategories) {
      subcategories.forEach((subcategory, amount) {
        total += amount;
      });
    });
    return total;
  }

  @override
  Widget build(BuildContext context) {
    // Kuunnellaan BudgetProvider-tilaa tulojen ja menojen päivittämiseksi reaaliajassa
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final income = budgetProvider.budget?.income ?? 0.0;
    final totalExpenses = _calculateTotalExpenses(budgetProvider.budget?.expenses ?? {});

    return Container(
      margin: const EdgeInsets.only(bottom: 16), // Välistys alareunaan
      decoration: BoxDecoration(
        color: Colors.white, // Taustaväri
        borderRadius: BorderRadius.circular(12), // Pyöristetyt kulmat
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15), // Varjon väri
            blurRadius: 8, // Varjon pehmennys
            offset: const Offset(0, 4), // Varjon siirtymä
          ),
        ],
      ),
      padding: const EdgeInsets.all(16), // Sisäinen välistys
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tulot-otsikko ja summa/muokkauslomake
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Tulot-otsikko ja ikoni
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.arrow_upward,
                    color: Colors.green,
                    size: 24,
                  ),
                  const SizedBox(width: 8), // Väli ikonin ja tekstin välillä
                  const Text(
                    'Tulot',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              // Näyttää tulojen summan tai muokkauslomakkeen
              _isEditing
                  ? Row(
                      children: [
                        // Tekstikenttä tulojen summan muokkaamiseen
                        SizedBox(
                          width: 100, // Kiinteä leveys tekstikentälle
                          child: TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true), // Numeronäppäimistö desimaaleilla
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(), // Reunan tyyli
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0), // Sisäinen välistys
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')), // Sallitaan vain numerot ja pisteet
                            ],
                          ),
                        ),
                        // Vahvistuspainike (vihreä ruksi), joka tallentaa muutokset
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: _saveChanges,
                        ),
                        // Peruutuspainike (punainen ruksi), joka peruuttaa muokkaukset
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: _cancelEditing,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        // Näyttää tulojen summan, jos ei olla muokkaustilassa
                        Text(
                          '${income.toStringAsFixed(2)} €', // Näyttää summan kahden desimaalin tarkkuudella
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.black54),                         
                        ),
                        // Muokkauspainike, joka aloittaa muokkaustilan
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: _startEditing,
                        ),
                      ],
                    ),
            ],
          ),
          // Budjetoidut menot -otsikko ja reaaliaikainen summa
          Row(
            spacing: 10,
            children: [
              // Budjetoidut menot -otsikko ja ikoni
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.arrow_downward,
                    color: Colors.red,
                    size: 24,
                  ),
                  const SizedBox(width: 8), // Väli ikonin ja tekstin välillä
                  const Text(
                    'Budjetoidut menot',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              // Näyttää budjetoitujen menojen summan reaaliajassa
              Text(
                '${totalExpenses.toStringAsFixed(2)} €', // Näyttää summan kahden desimaalin tarkkuudella
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.black54),
              ),
            ],
          ),
          // Näyttää virheviestin, jos sellainen on olemassa
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