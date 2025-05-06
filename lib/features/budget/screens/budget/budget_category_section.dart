import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class BudgetCategorySection extends StatefulWidget {
  final String categoryName;

  const BudgetCategorySection({super.key, required this.categoryName});

  @override
  State<BudgetCategorySection> createState() => _BudgetCategorySectionState();
}

class _BudgetCategorySectionState extends State<BudgetCategorySection> {
  bool _isAdding = false;
  bool _isEditing = false;
  String? _editingSubcategory;
  final TextEditingController _subcategoryController = TextEditingController();
  final Map<String, TextEditingController> _nameControllers = {};
  final Map<String, TextEditingController> _amountControllers = {};
  String? _errorMessage;
  final ExpansionTileController _expansionController = ExpansionTileController();
  final GlobalKey _expansionTileKey = GlobalKey();

  @override
  void dispose() {
    _subcategoryController.dispose();
    _nameControllers.values.forEach((controller) => controller.dispose());
    _amountControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  void _startAdding() {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final expenses = budgetProvider.budget?.expenses[widget.categoryName] ?? {};
    final subcategoryCount = expenses.length;

    if (subcategoryCount >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ilmaisversiossa voit lisätä enintään 6 alakategoriaa per yläkategoria.'),
        ),
      );
      return;
    }

    setState(() {
      _isAdding = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _expansionController.expand();
      }
    });
  }

  void _cancelAdding() {
    setState(() {
      _isAdding = false;
      _errorMessage = null;
      _subcategoryController.clear();
    });
  }

  void _startEditing(String subcategory, double currentAmount) {
    setState(() {
      _isEditing = true;
      _editingSubcategory = subcategory;
      _nameControllers[subcategory] = TextEditingController(text: subcategory);
      _amountControllers[subcategory] = TextEditingController(text: currentAmount.toStringAsFixed(2));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _expansionController.expand();
      }
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _editingSubcategory = null;
      _errorMessage = null;
      _nameControllers.remove(_editingSubcategory);
      _amountControllers.remove(_editingSubcategory);
    });
  }

  Future<void> _addSubcategory() async {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final subcategory = _subcategoryController.text.trim();
    if (subcategory.isEmpty) {
      setState(() {
        _errorMessage = 'Syötä alakategorian nimi';
      });
      return;
    }

    if (subcategory.length > 30) {
      setState(() {
        _errorMessage = 'Nimi voi olla enintään 30 merkkiä pitkä';
      });
      return;
    }

    final expenses = budgetProvider.budget?.expenses[widget.categoryName] ?? {};
    if (expenses.containsKey(subcategory)) {
      setState(() {
        _errorMessage = 'Tämä alakategorian nimi on jo käytössä';
      });
      return;
    }

    if (authProvider.user != null) {
      final now = DateTime.now();
      await budgetProvider.addSubcategory(
        authProvider.user!.uid,
        now.year,
        now.month,
        widget.categoryName,
        subcategory,
        0.0,
      );
      setState(() {
        _isAdding = false;
        _errorMessage = null;
        _subcategoryController.clear();
      });
    }
  }

  Future<void> _updateSubcategory(String oldSubcategory) async {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final newSubcategory = _nameControllers[oldSubcategory]!.text.trim();
    final amountText = _amountControllers[oldSubcategory]!.text.trim();
    final amount = double.tryParse(amountText);

    if (newSubcategory.isEmpty) {
      setState(() {
        _errorMessage = 'Syötä kelvollinen nimi';
      });
      return;
    }

    if (newSubcategory.length > 30) {
      setState(() {
        _errorMessage = 'Nimi voi olla enintään 30 merkkiä pitkä';
      });
      return;
    }

    final expenses = budgetProvider.budget?.expenses[widget.categoryName] ?? {};
    if (newSubcategory != oldSubcategory && expenses.containsKey(newSubcategory)) {
      setState(() {
        _errorMessage = 'Tämä alakategorian nimi on jo käytössä';
      });
      return;
    }

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

    if (authProvider.user != null) {
      final now = DateTime.now();
      await budgetProvider.removeSubcategory(
        authProvider.user!.uid,
        now.year,
        now.month,
        widget.categoryName,
        oldSubcategory,
      );
      await budgetProvider.addSubcategory(
        authProvider.user!.uid,
        now.year,
        now.month,
        widget.categoryName,
        newSubcategory,
        amount,
      );
      setState(() {
        _isEditing = false;
        _editingSubcategory = null;
        _errorMessage = null;
        _nameControllers.remove(oldSubcategory);
        _amountControllers.remove(oldSubcategory);
      });
    }
  }

  Future<bool> _confirmDeleteSubcategory(String subcategory) async {
    // Ensin varmistetaan poisto
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Poista alakategoria'),
        content: Text('Haluatko poistaa alakategorian "$subcategory"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Peruuta'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Poista'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return false; // Peruutettu, ei jatketa
    }

    // Tarkistetaan, onko alakategorialla meno-tapahtumia
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    if (authProvider.user == null) {
      return false;
    }

    final now = DateTime.now();
    final hasEvents = await expenseProvider.hasSubcategoryEvents(
      userId: authProvider.user!.uid,
      year: now.year,
      month: now.month,
      category: widget.categoryName,
      subcategory: subcategory,
    );

    if (hasEvents) {
      // Jos meno-tapahtumia on, näytetään toinen dialogi
      final deleteEvents = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Meno-tapahtumat löydetty'),
          content: Text(
              'Alakategoriassa "$subcategory" on meno-tapahtumia. Poistetaanko myös tapahtumat?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Peruuta'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Poista kaikki'),
            ),
          ],
        ),
      );
      return deleteEvents ?? false;
    }

    // Jos meno-tapahtumia ei ole, jatketaan poistoa
    return true;
  }

  IconData getCategoryIcon(String categoryName) {
    switch (categoryName) {
      case "Asuminen":
        return Icons.home;
      case "Liikkuminen":
        return Icons.directions_car;
      case "Kodin kulut":
        return Icons.power;
      case "Viihde":
        return Icons.movie;
      case "Harrastukset":
        return Icons.sports;
      case "Ruoka":
        return Icons.fastfood;
      case "Terveys":
        return Icons.local_hospital;
      case "Hygienia":
        return Icons.cleaning_services;
      case "Lemmikit":
        return Icons.pets;
      case "Sijoittaminen":
        return Icons.savings;
      case "Velat":
        return Icons.money_off;
      case "Muut":
        return Icons.category;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final budget = budgetProvider.budget;

    final expenses = budget?.expenses[widget.categoryName] ?? {};
    final Map<String, double> displayedExpenses = {};
    expenses.forEach((subcategory, value) {
      final displaySubcategory = subcategory == 'default' ? widget.categoryName : subcategory;
      displayedExpenses[displaySubcategory] = value;
    });

    final entries = displayedExpenses.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final List<Widget> subcategoryWidgets = entries.map((entry) {
      final subcategory = entry.key;
      final amount = entry.value;
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _isEditing && _editingSubcategory == subcategory
                  ? TextField(
                      controller: _nameControllers[subcategory],
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black87),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      maxLength: 30,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    )
                  : Text(
                      '  - $subcategory',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                    ),
            ),
            Row(
              children: [
                _isEditing && _editingSubcategory == subcategory
                    ? Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: TextField(
                              controller: _amountControllers[subcategory],
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black87),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green, size: 20),
                            onPressed: () => _updateSubcategory(subcategory),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red, size: 20),
                            onPressed: _cancelEditing,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Text(
                            '${amount.toStringAsFixed(2)} €',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _startEditing(subcategory, amount),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                            onPressed: () async {
                              final deleteEvents = await _confirmDeleteSubcategory(subcategory);
                              if (!deleteEvents) {
                                return; // Peruutettu, ei tehdä mitään
                              }

                              final authProvider = Provider.of<AuthProvider>(context, listen: false);
                              final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
                              final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
                              if (authProvider.user != null) {
                                final now = DateTime.now();
                                // Poistetaan meno-tapahtumat, jos käyttäjä valitsi "Poista kaikki"
                                if (deleteEvents) {
                                  await expenseProvider.deleteSubcategoryEvents(
                                    userId: authProvider.user!.uid,
                                    year: now.year,
                                    month: now.month,
                                    category: widget.categoryName,
                                    subcategory: subcategory,
                                  );
                                }
                                // Poistetaan alakategoria budjetista
                                await budgetProvider.removeSubcategory(
                                  authProvider.user!.uid,
                                  now.year,
                                  now.month,
                                  widget.categoryName,
                                  subcategory,
                                );
                                // Päivitetään tapahtumat yhteenvetosivulle
                                await expenseProvider.loadExpenses(
                                  authProvider.user!.uid,
                                  now.year,
                                  now.month,
                                );
                              }
                            },
                          ),
                        ],
                      ),
              ],
            ),
          ],
        ),
      );
    }).toList();

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
      child: Theme(
        data: Theme.of(context).copyWith(

        ),
        child: ExpansionTile(
          key: _expansionTileKey,
          controller: _expansionController,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Icon(
            getCategoryIcon(widget.categoryName),
            color: Colors.blueGrey,
            size: 24,
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.categoryName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                onPressed: _startAdding,
              ),
            ],
          ),
          children: [
            if (_isAdding)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _subcategoryController,
                      decoration: InputDecoration(
                        labelText: 'Uusi alakategoria',
                        border: const OutlineInputBorder(),
                        errorText: _errorMessage,
                      ),
                      maxLength: 30,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: _addSubcategory,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: _cancelAdding,
                  ),
                ],
              ),
            ...subcategoryWidgets,
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}