import 'package:budu/core/utils.dart';
import 'package:budu/features/budget/event_dialog/add_event_dialog.dart';
import 'package:budu/features/budget/models/expense_event.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:budu/features/budget/screens/summary/budget_tracking/sub_category_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CategoryExpansionTile extends StatefulWidget {
  final String categoryName;
  final double categoryBudget;
  final double categorySpent;
  final List<MapEntry<String, double>>? categoryExpenses;
  final List<MapEntry<String, double>>? unmappedExpenses;
  final bool isUnmappedCategory;
  final String budgetId; // Budjetin tunniste SummaryScreen:ltä
  final bool isSharedBudget; // Lisätty: Onko yhteistalousbudjetti

  const CategoryExpansionTile({
    super.key,
    required this.categoryName,
    required this.categoryBudget,
    required this.categorySpent,
    this.categoryExpenses,
    this.unmappedExpenses,
    this.isUnmappedCategory = false,
    required this.budgetId,
    required this.isSharedBudget,
  });

  @override
  State<CategoryExpansionTile> createState() => _CategoryExpansionTileState();
}

class _CategoryExpansionTileState extends State<CategoryExpansionTile> {
  bool _isExpanded = false;

  @override
  void didUpdateWidget(CategoryExpansionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Tarkistetaan, onko categorySpent-arvo muuttunut
    if (oldWidget.categorySpent != widget.categorySpent) {
      setState(() {
        // Päivitetään progress barin tila
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.categoryBudget > 0 ? widget.categorySpent / widget.categoryBudget : 0.0;
    final remainingPercentage = widget.categoryBudget > 0
        ? ((widget.categoryBudget - widget.categorySpent) / widget.categoryBudget * 100).clamp(0, 100)
        : 100.0;
    final isOverBudget = progress > 1;

    // Lasketaan alakategorioiden lukumäärä
    final subCategoryCount = widget.isUnmappedCategory
        ? (widget.unmappedExpenses?.length ?? 0)
        : (widget.categoryExpenses?.length ?? 0);

    final categoryIcon = widget.isUnmappedCategory
        ? Icons.category
        : widget.categoryName == "Asuminen"
            ? Icons.home
            : widget.categoryName == "Liikkuminen"
                ? Icons.directions_car
                : widget.categoryName == "Laskut ja palvelut"
                    ? Icons.receipt_long
                    : widget.categoryName == "Viihde"
                        ? Icons.movie
                        : widget.categoryName == "Harrastukset"
                            ? Icons.sports
                            : widget.categoryName == "Ruoka"
                                ? Icons.fastfood
                                : widget.categoryName == "Terveys"
                                    ? Icons.local_hospital
                                    : widget.categoryName == "Hygienia"
                                        ? Icons.cleaning_services
                                        : widget.categoryName == "Lemmikit"
                                            ? Icons.pets
                                            : widget.categoryName == "Sijoittaminen ja säästäminen"
                                                ? Icons.savings
                                                : widget.categoryName == "Vakuutukset"
                                                    ? Icons.description
                                                    : widget.categoryName == "Velat"
                                                        ? Icons.money_off
                                                        : Icons.category;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 255, 255),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _isExpanded,
          onExpansionChanged: (bool expanded) {
            setState(() {
              _isExpanded = expanded;
            });
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 5),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 0),
          leading: null,
          trailing: const SizedBox.shrink(),
          title: Stack(
            children: [
              // Kategorian ikoni vasemmassa yläkulmassa
              Positioned(
                left: 12,
                top: 4,
                child: Icon(
                  categoryIcon,
                  color: Colors.blueGrey,
                  size: 22,
                ),
              ),
              // Alakategorioiden lukumäärä ikonista vasemmalle
              Positioned(
                right: 30,
                top: 4,
                child: Text(
                  '$subCategoryCount alakategoria${subCategoryCount == 1 ? '' : 'a'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                      ),
                ),
              ),
              // Laajennus/supistus-ikoni oikeassa yläkulmassa
              Positioned(
                right: 0,
                top: 4,
                child: AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more,
                    color: Colors.blueGrey,
                    size: 22,
                  ),
                ),
              ),
              // Kortin sisältö (kategorian nimi, budjetti, edistymispalkki, jne.)
              Padding(
                padding: const EdgeInsets.only(top: 28, left: 16, right: 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.categoryName,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isOverBudget)
                                const Icon(
                                  Icons.warning,
                                  color: Colors.red,
                                  size: 16,
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '${formatCurrency(widget.categorySpent)} / ${formatCurrency(widget.categoryBudget)}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress > 1 ? 1 : progress,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(isOverBudget ? Colors.red : Colors.green),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Text(
                          '${remainingPercentage.toStringAsFixed(0)}% jäljellä',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                        ),
                        if (isOverBudget)
                          Text(
                            'Budjetti ylittynyt!',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          children: [
            ...widget.isUnmappedCategory
                ? widget.unmappedExpenses!.map((entry) {
                    final subCategory = entry.key;
                    final budgetAmount = entry.value;
                    final spentAmount = Provider.of<ExpenseProvider>(context, listen: false)
                        .expenses
                        .where((expense) =>
                            expense.type == EventType.expense &&
                            expense.budgetId == widget.budgetId &&
                            expense.subcategory == subCategory)
                        .fold<double>(0.0, (sum, expense) => sum + expense.amount);
                    return SubCategoryTile(
                      subCategory: subCategory,
                      subCategoryBudget: budgetAmount,
                      spentAmount: spentAmount,
                      categoryName: widget.categoryName,
                    );
                  }).toList()
                : widget.categoryExpenses!.map((entry) {
                    final subCategory = entry.key;
                    final subCategoryBudget = entry.value;
                    final spentAmount = Provider.of<ExpenseProvider>(context, listen: false)
                        .expenses
                        .where((expense) =>
                            expense.type == EventType.expense &&
                            expense.budgetId == widget.budgetId &&
                            expense.category == widget.categoryName &&
                            expense.subcategory == subCategory)
                        .fold<double>(0.0, (sum, expense) => sum + expense.amount);
                    return SubCategoryTile(
                      subCategory: subCategory,
                      subCategoryBudget: subCategoryBudget,
                      spentAmount: spentAmount,
                      categoryName: widget.categoryName,
                    );
                  }).toList(),
            // Lisää painike vain, kun kategoria on laajennettu
            if (_isExpanded && subCategoryCount > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: ElevatedButton(
                  onPressed: () {
                    // Avaa AddEventDialog esivalitulla kategorialla ja budjetilla
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (dialogContext) => AddEventDialog(
                        initialCategory: widget.categoryName,
                        initialBudgetId: widget.budgetId, // Välitetään budjetin ID
                        isSharedBudget: widget.isSharedBudget, // Välitetään budjettityyppi
                      ),
                    );
                  },
                  child: Text(
                    'Lisää meno',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}