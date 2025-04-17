import 'package:budu/features/budget/models/expense_event.dart';
import 'package:budu/features/history/event_filter_section.dart';
import 'package:budu/features/history/event_list_item.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String? _selectedCategory;
  String? _selectedType;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final events = expenseProvider.expenses;

    // Suodatetaan tapahtumat
    final filteredEvents = events.where((event) {
      final matchesCategory = _selectedCategory == null || _selectedCategory == 'Kaikki kategoriat' || event.category == _selectedCategory;
      final matchesType = _selectedType == null || _selectedType == 'Kaikki' || (_selectedType == 'Tulot' && event.type == EventType.income) || (_selectedType == 'Menot' && event.type == EventType.expense);
      final matchesQuery = _searchQuery.isEmpty || (event.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      return matchesCategory && matchesType && matchesQuery;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historia'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          EventFilterSection(
            onCategoryChanged: (category) {
              setState(() {
                _selectedCategory = category;
              });
            },
            onTypeChanged: (type) {
              setState(() {
                _selectedType = type;
              });
            },
            onSearchQueryChanged: (query) {
              setState(() {
                _searchQuery = query;
              });
            },
          ),
          Expanded(
            child: filteredEvents.isEmpty
                ? const Center(child: Text('Ei tapahtumia'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredEvents.length,
                    itemBuilder: (context, index) {
                      return EventListItem(event: filteredEvents[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}