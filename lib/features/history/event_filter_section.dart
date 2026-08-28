import 'package:budu/features/history/domain/history_filters.dart';
import 'package:flutter/material.dart';

/// Controlled filters for History: category, budget, type chips, description search.
class EventFilterSection extends StatefulWidget {
  final List<String> categories;
  final List<String> availableBudgetLabels;
  final String selectedCategory;
  final String selectedType;
  final String selectedBudgetLabel;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onBudgetLabelChanged;
  final ValueChanged<String> onSearchQueryChanged;

  const EventFilterSection({
    super.key,
    required this.categories,
    required this.availableBudgetLabels,
    required this.selectedCategory,
    required this.selectedType,
    required this.selectedBudgetLabel,
    required this.onCategoryChanged,
    required this.onTypeChanged,
    required this.onBudgetLabelChanged,
    required this.onSearchQueryChanged,
  });

  @override
  State<EventFilterSection> createState() => _EventFilterSectionState();
}

class _EventFilterSectionState extends State<EventFilterSection> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = [
      historyAllCategoriesLabel,
      ...widget.categories,
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
              Text(
                'Historia',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Kategoria',
                  labelStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: PopupMenuButton<String>(
                  onSelected: widget.onCategoryChanged,
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
                          widget.selectedCategory,
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
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Budjetti',
                  labelStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: PopupMenuButton<String>(
                  onSelected: widget.onBudgetLabelChanged,
                  itemBuilder: (BuildContext context) {
                    return widget.availableBudgetLabels.map((budget) {
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
                          widget.selectedBudgetLabel,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ChoiceChip(
                    label: Text(
                      historyAllTypesLabel,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    selected: widget.selectedType == historyAllTypesLabel,
                    onSelected: (_) =>
                        widget.onTypeChanged(historyAllTypesLabel),
                  ),
                  ChoiceChip(
                    label: Text(
                      historyIncomeTypeLabel,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    selected: widget.selectedType == historyIncomeTypeLabel,
                    onSelected: (_) =>
                        widget.onTypeChanged(historyIncomeTypeLabel),
                    selectedColor: Colors.green,
                  ),
                  ChoiceChip(
                    label: Text(
                      historyExpenseTypeLabel,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    selected: widget.selectedType == historyExpenseTypeLabel,
                    onSelected: (_) =>
                        widget.onTypeChanged(historyExpenseTypeLabel),
                    selectedColor: Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                onChanged: widget.onSearchQueryChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
