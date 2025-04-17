import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';

class EventFilterSection extends StatefulWidget {
  final Function(String?) onCategoryChanged;
  final Function(String?) onTypeChanged;
  final Function(String) onSearchQueryChanged;

  const EventFilterSection({
    super.key,
    required this.onCategoryChanged,
    required this.onTypeChanged,
    required this.onSearchQueryChanged,
  });

  @override
  State<EventFilterSection> createState() => _EventFilterSectionState();
}

class _EventFilterSectionState extends State<EventFilterSection> {
  String? _selectedCategory = 'Kaikki kategoriat';
  String? _selectedType = 'Kaikki';
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kategoria-suodatin
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Kategoria',
                  border: OutlineInputBorder(),
                ),
                items: categories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                    widget.onCategoryChanged(value);
                  });
                },
              ),
              const SizedBox(height: 16),
              // Tyyppi-suodatin
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ChoiceChip(
                    label: const Text('Kaikki'),
                    selected: _selectedType == 'Kaikki',
                    onSelected: (selected) {
                      setState(() {
                        _selectedType = 'Kaikki';
                        widget.onTypeChanged('Kaikki');
                      });
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Tulot'),
                    selected: _selectedType == 'Tulot',
                    onSelected: (selected) {
                      setState(() {
                        _selectedType = 'Tulot';
                        widget.onTypeChanged('Tulot');
                      });
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Menot'),
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
                decoration: const InputDecoration(
                  labelText: 'Hae kuvauksesta',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
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