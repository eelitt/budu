import 'package:budu/core/constants.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CreateBudgetScreen extends StatefulWidget {
  final BudgetModel sourceBudget;
  final int newYear;
  final int newMonth;

  const CreateBudgetScreen({
    super.key,
    required this.sourceBudget,
    required this.newYear,
    required this.newMonth,
  });

  @override
  State<CreateBudgetScreen> createState() => _CreateBudgetScreenState();
}

class _CreateBudgetScreenState extends State<CreateBudgetScreen> {
  late TextEditingController _incomeController;
  final Map<String, Map<String, TextEditingController>> _expenseControllers = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Pyöristetään tulot kahden desimaalin tarkkuudella
    final roundedIncome = (widget.sourceBudget.income * 100).roundToDouble() / 100;
    _incomeController = TextEditingController(
      text: roundedIncome.toStringAsFixed(2),
    );

    // Kopioidaan ylä- ja alakategoriat viimeisimmästä budjetista
    for (var category in widget.sourceBudget.expenses.keys) {
      final subcategories = widget.sourceBudget.expenses[category]!;
      _expenseControllers[category] = {};
      for (var subcategory in subcategories.keys) {
        // Pyöristetään arvo kahden desimaalin tarkkuudella
        final roundedValue = (subcategories[subcategory]! * 100).roundToDouble() / 100;
        _expenseControllers[category]![subcategory] = TextEditingController(
          text: roundedValue.toStringAsFixed(2),
        );
      }
    }

    // Varmistetaan, että kaikki yläkategoriat ovat mukana, vaikka niillä ei olisi arvoja
    for (var category in categoryMapping.keys) {
      if (!_expenseControllers.containsKey(category)) {
        _expenseControllers[category] = {};
        // Lisätään yläkategoria oletusarvolla 0.00
        _expenseControllers[category]![category] = TextEditingController(text: '0.00');
      }
    }

    // Kuunnellaan muutoksia tulojen ja menojen arvoissa yhteenvetoa varten
    _incomeController.addListener(_updateSummary);
    _expenseControllers.forEach((category, subcategoryMap) {
      subcategoryMap.forEach((subcategory, controller) {
        controller.addListener(_updateSummary);
      });
    });
  }

  @override
  void dispose() {
    _incomeController.removeListener(_updateSummary);
    _incomeController.dispose();
    _expenseControllers.forEach((category, subcategoryMap) {
      subcategoryMap.forEach((subcategory, controller) {
        controller.removeListener(_updateSummary);
        controller.dispose();
      });
    });
    super.dispose();
  }

  // Metodi yhteenvetoarvojen laskemiseen
  void _updateSummary() {
    setState(() {});
  }

  double get _totalIncome {
    return double.tryParse(_incomeController.text) ?? 0.0;
  }

  double get _totalExpenses {
    double total = 0.0;
    _expenseControllers.forEach((category, subcategoryMap) {
      subcategoryMap.forEach((subcategory, controller) {
        total += double.tryParse(controller.text) ?? 0.0;
      });
    });
    return total;
  }

  Future<void> _createBudget() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);

    if (authProvider.user == null) return;

    final double income = double.tryParse(_incomeController.text) ?? 0.0;
    final Map<String, Map<String, double>> expenses = {};

    // Tallennetaan ylä- ja alakategoriat
    for (var category in _expenseControllers.keys) {
      final subcategoryMap = _expenseControllers[category]!;
      expenses[category] = {};
      for (var subcategory in subcategoryMap.keys) {
        final amount = double.tryParse(subcategoryMap[subcategory]!.text) ?? 0.0;
        // Pyöristetään arvo kahden desimaalin tarkkuudella tallennuksessa
        final roundedAmount = (amount * 100).roundToDouble() / 100;
        if (roundedAmount > 0) {
          expenses[category]![subcategory] = roundedAmount;
        }
      }
      // Poistetaan tyhjät yläkategoriat
      if (expenses[category]!.isEmpty) {
        expenses.remove(category);
      }
    }

    // Validointi: Varoita, jos menot ovat suuremmat kuin tulot
    if (_totalExpenses > _totalIncome) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Varoitus'),
          content: const Text('Menot ovat suuremmat kuin tulot. Haluatko jatkaa?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Peruuta'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Jatka'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    final newBudget = BudgetModel(
      income: income,
      expenses: expenses,
      createdAt: DateTime.now(),
      year: widget.newYear,
      month: widget.newMonth,
    );

    try {
      await budgetProvider.saveBudget(authProvider.user!.uid, newBudget);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error creating budget: $e');
      setState(() {
        _errorMessage = 'Virhe budjetin tallentamisessa: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Järjestä yläkategoriat aakkosjärjestykseen
    final sortedCategories = _expenseControllers.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text('Luo budjetti (${widget.newMonth}/${widget.newYear})'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tulot',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _incomeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tulot (€)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Menot kategorioittain',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...sortedCategories.map((category) {
              // Järjestä alakategoriat aakkosjärjestykseen
              final sortedSubcategories = _expenseControllers[category]!.keys.toList()..sort();
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ExpansionTile(
                  title: Text(category),
                  children: sortedSubcategories.map((subcategory) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                      child: Row(
                        children: [
                          Expanded(child: Text(subcategory)),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: _expenseControllers[category]![subcategory],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Summa (€)',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                // Varmistetaan, että arvo näytetään kahden desimaalin tarkkuudella
                                final parsed = double.tryParse(value);
                                if (parsed != null) {
                                  final roundedValue = (parsed * 100).roundToDouble() / 100;
                                  _expenseControllers[category]![subcategory]!.value = TextEditingValue(
                                    text: roundedValue.toStringAsFixed(2),
                                    selection: TextSelection.collapsed(offset: roundedValue.toStringAsFixed(2).length),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            }),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ],
            const SizedBox(height: 24),
            // Yhteenveto: Tulot ja menot
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Yhteenveto',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tulot:'),
                      Text(
                        '${_totalIncome.toStringAsFixed(2)} €',
                        style: const TextStyle(color: Colors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Menot:'),
                      Text(
                        '${_totalExpenses.toStringAsFixed(2)} €',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Jäljellä:'),
                      Text(
                        '${(_totalIncome - _totalExpenses).toStringAsFixed(2)} €',
                        style: TextStyle(
                          color: (_totalIncome - _totalExpenses) >= 0 ? Colors.black : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: _createBudget,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Tallenna budjetti'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}