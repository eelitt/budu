import 'package:budu/features/auth/providers/auth_provider.dart';
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
  String? _selectedMonth; // Uusi suodatin kuukausille
  String _searchQuery = '';
  Future<void>? _loadEventsFuture;

  @override
  void initState() {
    super.initState();
    _selectedMonth = 'Kaikki kuukaudet';
    _loadEventsFuture = _loadAllEvents();
  }

  Future<void> _loadAllEvents() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    if (authProvider.user != null) {
      await expenseProvider.loadAllExpenses(authProvider.user!.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final events = expenseProvider.expenses;

    // Haetaan saatavilla olevat kuukaudet tapahtumista
    final availableMonths = events
        .map((event) => '${event.year}_${event.month}')
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a)); // Järjestä uusin ensin
    final monthOptions = ['Kaikki kuukaudet', ...availableMonths.map((month) {
      final parts = month.split('_');
      return '${int.parse(parts[1])}/${parts[0]}';
    })];

    // Suodatetaan tapahtumat
    final filteredEvents = events.where((event) {
      final matchesCategory = _selectedCategory == null || _selectedCategory == 'Kaikki kategoriat' || event.category == _selectedCategory;
      final matchesType = _selectedType == null || _selectedType == 'Kaikki' || (_selectedType == 'Tulot' && event.type == EventType.income) || (_selectedType == 'Menot' && event.type == EventType.expense);
      final matchesQuery = _searchQuery.isEmpty || (event.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      final matchesMonth = _selectedMonth == null || _selectedMonth == 'Kaikki kuukaudet' || '${event.month}/${event.year}' == _selectedMonth;
      return matchesCategory && matchesType && matchesQuery && matchesMonth;
    }).toList();

    return FutureBuilder(
      future: _loadEventsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Virhe latauksessa: ${snapshot.error}'));
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Historia'),
            automaticallyImplyLeading: false,
          ),
          body: Column(
            children: [
              EventFilterSection(
                availableMonths: monthOptions,
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
                onMonthChanged: (month) {
                  setState(() {
                    _selectedMonth = month;
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
      },
    );
  }
}