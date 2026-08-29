import 'package:budu/core/constants.dart';
import 'package:budu/features/budget/screens/create_budget/dialogs/add_category_dialog.dart';
import 'package:budu/features/budget/screens/create_budget/dialogs/add_subcategory_dialog.dart';
import 'package:flutter/material.dart';

/// Category tree UI for create-budget: add/remove mains and subs, amount fields.
class ExpensesSection extends StatefulWidget {
  final Map<String, Map<String, TextEditingController>> expenseControllers;
  final VoidCallback onUpdate;
  final void Function(TextEditingController controller) attachController;
  final void Function(TextEditingController controller) detachController;

  const ExpensesSection({
    super.key,
    required this.expenseControllers,
    required this.onUpdate,
    required this.attachController,
    required this.detachController,
  });

  @override
  State<ExpensesSection> createState() => _ExpensesSectionState();
}

class _ExpensesSectionState extends State<ExpensesSection> {
  Map<String, Map<String, FocusNode>> focusNodes = {};

  @override
  void initState() {
    super.initState();
    _updateFocusNodes();
  }

  @override
  void didUpdateWidget(ExpensesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateFocusNodes();
  }

  /// Keeps focus nodes aligned with controllers; disposes nodes that leave the tree.
  void _updateFocusNodes() {
    final currentCategories = widget.expenseControllers.keys.toSet();
    final removedCategories = focusNodes.keys
        .where((category) => !currentCategories.contains(category))
        .toList();
    for (final category in removedCategories) {
      final subs = focusNodes.remove(category)!;
      for (final node in subs.values) {
        node.dispose();
      }
    }

    for (final category in widget.expenseControllers.keys) {
      focusNodes[category] ??= {};
      final currentSubcategories =
          widget.expenseControllers[category]!.keys.toSet();
      final removedSubs = focusNodes[category]!
          .keys
          .where((subcategory) => !currentSubcategories.contains(subcategory))
          .toList();
      for (final subcategory in removedSubs) {
        focusNodes[category]!.remove(subcategory)!.dispose();
      }

      for (final subcategory in widget.expenseControllers[category]!.keys) {
        focusNodes[category]![subcategory] ??= FocusNode();
      }
    }
  }

  @override
  void dispose() {
    focusNodes.forEach((_, subFocusNodes) {
      subFocusNodes.forEach((_, focusNode) => focusNode.dispose());
    });
    super.dispose();
  }

  String? _validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final parsed = double.tryParse(value);
    if (parsed == null) {
      return 'Syötä kelvollinen numero';
    }
    if (parsed < 0) {
      return 'Summa ei voi olla negatiivinen';
    }
    if (parsed > 99999) {
      return 'Summa ei voi olla suurempi kuin 99999 €';
    }
    return null;
  }

  void _formatAmount(TextEditingController controller) {
    final value = controller.text;
    if (value.isEmpty) {
      controller.text = '0.00';
    } else {
      final parsed = double.tryParse(value);
      if (parsed != null) {
        final roundedValue = (parsed * 100).roundToDouble() / 100;
        controller.text = roundedValue.toStringAsFixed(2);
      }
    }
  }

  Future<void> _addCategory() async {
    final name = await showAddCategoryDialog(
      context: context,
      existingCategories: widget.expenseControllers.keys.toSet(),
    );
    if (name == null || !mounted) return;
    widget.expenseControllers[name] = {};
    widget.onUpdate();
  }

  void _removeCategory(String category) {
    final subs = widget.expenseControllers.remove(category);
    if (subs != null) {
      for (final controller in subs.values) {
        widget.detachController(controller);
      }
    }
    widget.onUpdate();
  }

  Future<void> _addSubcategory(String category) async {
    final name = await showAddSubcategoryDialog(
      context: context,
      category: category,
      existingSubcategories:
          widget.expenseControllers[category]?.keys.toSet() ?? {},
    );
    if (name == null || !mounted) return;

    final controller = TextEditingController(text: '0.00');
    widget.attachController(controller);
    widget.expenseControllers[category]![name] = controller;
    widget.onUpdate();
    _updateFocusNodes();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNodes[category]?[name]?.requestFocus();
    });
  }

  void _removeSubcategory(String category, String subcategory) {
    final controller =
        widget.expenseControllers[category]?.remove(subcategory);
    if (controller != null) {
      widget.detachController(controller);
    }
    widget.onUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final sortedCategories = widget.expenseControllers.keys.toList()..sort();
    final canAddCategory =
        widget.expenseControllers.length < Constants.maxCategories;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: true,
          title: Row(
            children: [
              const Icon(Icons.account_balance_wallet, size: 24),
              const SizedBox(width: 8),
              Text(
                'Menot kategorioittain',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          subtitle: Text(
            'Kategorioita: ${sortedCategories.length}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ElevatedButton(
                    onPressed: canAddCategory ? _addCategory : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context)
                          .elevatedButtonTheme
                          .style
                          ?.backgroundColor
                          ?.resolve({}),
                      foregroundColor: Theme.of(context)
                          .elevatedButtonTheme
                          .style
                          ?.foregroundColor
                          ?.resolve({}),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          canAddCategory ? Icons.add : Icons.info,
                          size: 16,
                          color: Theme.of(context)
                              .elevatedButtonTheme
                              .style
                              ?.foregroundColor
                              ?.resolve({}),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          canAddCategory
                              ? 'Lisää kategoria'
                              : 'Kategorioiden maksimimäärä (${Constants.maxCategories}) saavutettu',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context)
                                        .elevatedButtonTheme
                                        .style
                                        ?.foregroundColor
                                        ?.resolve({}),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...sortedCategories.map((category) {
                    final sortedSubcategories =
                        widget.expenseControllers[category]!.keys.toList()
                          ..sort();
                    final canAddSubcategory =
                        (widget.expenseControllers[category]?.length ?? 0) <
                            Constants.maxSubcategories;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                        ),
                        child: ExpansionTile(
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  category,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _removeCategory(category),
                                tooltip: 'Poista kategoria',
                              ),
                            ],
                          ),
                          children: [
                            ...sortedSubcategories.map((subcategory) {
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 8.0,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: Colors.grey[300]!,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(subcategory)),
                                    SizedBox(
                                      width: 100,
                                      child: TextField(
                                        controller: widget.expenseControllers[
                                            category]![subcategory],
                                        focusNode: focusNodes[category]![
                                            subcategory],
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: 'Summa (€)',
                                          border: const OutlineInputBorder(),
                                          errorText: _validateAmount(
                                            widget
                                                .expenseControllers[category]![
                                                    subcategory]!
                                                .text,
                                          ),
                                        ),
                                        onChanged: (_) => widget.onUpdate(),
                                        onEditingComplete: () {
                                          _formatAmount(
                                            widget.expenseControllers[
                                                category]![subcategory]!,
                                          );
                                          widget.onUpdate();
                                          FocusScope.of(context).unfocus();
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => _removeSubcategory(
                                        category,
                                        subcategory,
                                      ),
                                      tooltip: 'Poista alakategoria',
                                    ),
                                  ],
                                ),
                              );
                            }),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 8.0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Tooltip(
                                    message: canAddSubcategory
                                        ? 'Lisää uusi alakategoria'
                                        : 'Alakategorioiden maksimimäärä (${Constants.maxSubcategories}) saavutettu',
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.add),
                                      label: Text(
                                        'Lisää alakategoria',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .elevatedButtonTheme
                                                  .style
                                                  ?.foregroundColor
                                                  ?.resolve({}),
                                            ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(context)
                                            .elevatedButtonTheme
                                            .style
                                            ?.backgroundColor
                                            ?.resolve({}),
                                        foregroundColor: Theme.of(context)
                                            .elevatedButtonTheme
                                            .style
                                            ?.foregroundColor
                                            ?.resolve({}),
                                      ),
                                      onPressed: canAddSubcategory
                                          ? () => _addSubcategory(category)
                                          : null,
                                    ),
                                  ),
                                  if (!canAddSubcategory) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Alakategorioiden maksimimäärä (${Constants.maxSubcategories}) saavutettu',
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
