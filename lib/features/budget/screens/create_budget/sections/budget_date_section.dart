import 'package:budu/features/budget/domain/periods.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Controlled type + start/end pickers for create-budget.
/// Parent owns period state; this widget only displays and emits changes.
class BudgetDateSection extends StatefulWidget {
  final String type;
  final DateTime startDate;
  final DateTime endDate;
  final void Function({
    required String type,
    required DateTime start,
    required DateTime end,
  }) onPeriodChanged;

  const BudgetDateSection({
    super.key,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.onPeriodChanged,
  });

  @override
  State<BudgetDateSection> createState() => _BudgetDateSectionState();
}

class _BudgetDateSectionState extends State<BudgetDateSection> {
  late TextEditingController _startDateController;
  late TextEditingController _endDateController;

  static final _budgetTypes = {
    'monthly': 'Kuukausittainen',
    'biweekly': '2 viikkoa',
    'custom': 'Mukautettu',
  };

  static final _dateFormat = DateFormat('d.M.yyyy');

  @override
  void initState() {
    super.initState();
    _startDateController = TextEditingController(
      text: _dateFormat.format(widget.startDate),
    );
    _endDateController = TextEditingController(
      text: _dateFormat.format(widget.endDate),
    );
  }

  @override
  void didUpdateWidget(BudgetDateSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startDate != widget.startDate) {
      _startDateController.text = _dateFormat.format(widget.startDate);
    }
    if (oldWidget.endDate != widget.endDate) {
      _endDateController.text = _dateFormat.format(widget.endDate);
    }
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<DateTime?> _selectDate(DateTime initialDate) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
  }

  void _emit(({DateTime start, DateTime end, String type}) period) {
    widget.onPeriodChanged(
      type: period.type,
      start: period.start,
      end: period.end,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PopupMenuButton<String>(
            onSelected: (value) {
              _emit(
                applyBudgetPeriodType(
                  type: value,
                  start: widget.startDate,
                  end: widget.endDate,
                ),
              );
            },
            itemBuilder: (context) {
              return _budgetTypes.entries.map((entry) {
                return PopupMenuItem<String>(
                  value: entry.key,
                  child: Text(
                    entry.value,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.black87,
                          fontSize: 15,
                        ),
                  ),
                );
              }).toList();
            },
            color: Colors.white,
            position: PopupMenuPosition.under,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _budgetTypes[widget.type] ?? 'Valitse budjetin tyyppi',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.black87,
                            fontSize: 16,
                          ),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.black87),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _startDateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Alkamispäivä',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: () async {
                    final selected =
                        await _selectDate(widget.startDate);
                    if (selected == null || !mounted) return;
                    _emit(
                      adjustCreateBudgetStart(
                        type: widget.type,
                        newStart: selected,
                        currentEnd: widget.endDate,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _endDateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Päättymispäivä',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: () async {
                    final selected = await _selectDate(widget.endDate);
                    if (selected == null || !mounted) return;
                    _emit(
                      adjustCreateBudgetEnd(
                        type: widget.type,
                        currentStart: widget.startDate,
                        newEnd: selected,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
