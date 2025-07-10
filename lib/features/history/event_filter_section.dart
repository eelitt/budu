import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Widget, joka tarjoaa suodattimet tapahtumahistorian tapahtumille: kategoria, tyyppi, budjetti ja hakukysely.
class EventFilterSection extends StatefulWidget {
  final List<String> availableBudgets; // Lista budjettien aikaväleistä
  final Function(String?) onCategoryChanged; // Callback kategorian muutokselle
  final Function(String?) onTypeChanged; // Callback tyypin muutokselle
  final Function(String?) onBudgetChanged; // Callback budjetin muutokselle
  final Function(String) onSearchQueryChanged; // Callback hakukyselyn muutokselle

  const EventFilterSection({
    super.key,
    required this.availableBudgets,
    required this.onCategoryChanged,
    required this.onTypeChanged,
    required this.onBudgetChanged,
    required this.onSearchQueryChanged,
  });

  @override
  State<EventFilterSection> createState() => _EventFilterSectionState();
}

class _EventFilterSectionState extends State<EventFilterSection> {
  String? _selectedCategory = 'Kaikki kategoriat';
  String? _selectedType = 'Kaikki';
  String? _selectedBudget = 'Kaikki budjetit';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Käytetään kaikkia mahdollisia kategorioita ExpenseProvider:sta, jos budjetti ei ole valittuna
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final categories = [
      'Kaikki kategoriat',
      ...expenseProvider.expenses.map((e) => e.category).toSet().toList()..sort(),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // "Historia"-otsikko
              Text(
                'Historia',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
              ),
              const SizedBox(height: 16),
              // Kategoria-suodatin
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Kategoria',
                  labelStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: PopupMenuButton<String>(
                  onSelected: (value) {
                    setState(() {
                      _selectedCategory = value;
                      widget.onCategoryChanged(value);
                    });
                  },
                  itemBuilder: (BuildContext context) {
                    return categories.map((category) {
                      return PopupMenuItem<String>(
                        value: category,
                        child: Text(
                          category,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      );
                    }).toList();
                  },
                  color: Colors.white,
                  position: PopupMenuPosition.under,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _selectedCategory ?? 'Kaikki kategoriat',
                          style: Theme.of(context).textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
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
              // Budjetti-suodatin
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Budjetti',
                  labelStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: PopupMenuButton<String>(
                  onSelected: (value) {
                    setState(() {
                      _selectedBudget = value;
                      widget.onBudgetChanged(value);
                    });
                  },
                  itemBuilder: (BuildContext context) {
                    return widget.availableBudgets.map((budget) {
                      return PopupMenuItem<String>(
                        value: budget,
                        child: Text(
                          budget,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      );
                    }).toList();
                  },
                  color: Colors.white,
                  position: PopupMenuPosition.under,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _selectedBudget ?? 'Kaikki budjetit',
                          style: Theme.of(context).textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
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
              // Tyyppi-suodatin
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ChoiceChip(
                    label: Text(
                      'Kaikki',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    selected: _selectedType == 'Kaikki',
                    onSelected: (selected) {
                      setState(() {
                        _selectedType = 'Kaikki';
                        widget.onTypeChanged('Kaikki');
                      });
                    },
                  ),
                  ChoiceChip(
                    label: Text(
                      'Tulot',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    selected: _selectedType == 'Tulot',
                    onSelected: (selected) {
                      setState(() {
                        _selectedType = 'Tulot';
                        widget.onTypeChanged('Tulot');
                      });
                    },
                    selectedColor: Colors.green,
                  ),
                  ChoiceChip(
                    label: Text(
                      'Menot',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    selected: _selectedType == 'Menot',
                    onSelected: (selected) {
                      setState(() {
                        _selectedType = 'Menot';
                        widget.onTypeChanged('Menot');
                      });
                    },
                    selectedColor: Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Hakukenttä
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Hae kuvauksesta',
                  labelStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (value) {
                  widget.onSearchQueryChanged(value);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}