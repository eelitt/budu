import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EventFilterSection extends StatefulWidget {
  final List<String> availableMonths;
  final Function(String?) onCategoryChanged;
  final Function(String?) onTypeChanged;
  final Function(String?) onMonthChanged;
  final Function(String) onSearchQueryChanged;

  const EventFilterSection({
    super.key,
    required this.availableMonths,
    required this.onCategoryChanged,
    required this.onTypeChanged,
    required this.onMonthChanged,
    required this.onSearchQueryChanged,
  });

  @override
  State<EventFilterSection> createState() => _EventFilterSectionState();
}

class _EventFilterSectionState extends State<EventFilterSection> {
  String? _selectedCategory = 'Kaikki kategoriat';
  String? _selectedType = 'Kaikki';
  String? _selectedMonth = 'Kaikki kuukaudet';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final categories = ['Kaikki kategoriat', 'Tulo', ...(budgetProvider.budget?.expenses.keys.toList() ?? [])];

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
                  color: Colors.white, // Teeman mukainen taustaväri
                  position: PopupMenuPosition.under, // Valikko avautuu alas
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
              // Kuukausi-suodatin
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Kuukausi',
                  labelStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: PopupMenuButton<String>(
                  onSelected: (value) {
                    setState(() {
                      _selectedMonth = value;
                      widget.onMonthChanged(value);
                    });
                  },
                  itemBuilder: (BuildContext context) {
                    return widget.availableMonths.map((month) {
                      return PopupMenuItem<String>(
                        value: month,
                        child: Text(
                          month,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      );
                    }).toList();
                  },
                  color: Colors.white, // Teeman mukainen taustaväri
                  position: PopupMenuPosition.under, // Valikko avautuu alas
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _selectedMonth ?? 'Kaikki kuukaudet',
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