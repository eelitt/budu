import 'package:budu/features/budget/screens/create_budget/managers/category_manager.dart';
import 'package:budu/features/budget/screens/create_budget/managers/subcategory_manager.dart';
import 'package:flutter/material.dart';


class ExpensesSection extends StatelessWidget {
  final Map<String, Map<String, TextEditingController>> expenseControllers;
  final VoidCallback onUpdate;

  const ExpensesSection({
    super.key,
    required this.expenseControllers,
    required this.onUpdate,
  });

  String? _validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Salli tyhjä kenttä
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

  @override
  Widget build(BuildContext context) {
    final categoryManager = CategoryManager(
      expenseControllers: expenseControllers,
      onUpdate: onUpdate,
    );
    final subcategoryManager = SubcategoryManager(
      expenseControllers: expenseControllers,
      onUpdate: onUpdate,
    );

    // Järjestä yläkategoriat aakkosjärjestykseen
    final sortedCategories = expenseControllers.keys.toList()..sort();
    final canAddCategory = categoryManager.canAddCategory;

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
            'Kategorioita: ${sortedCategories.length} \n(ilmaisversiossa max 11)',
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ElevatedButton(
                            onPressed: canAddCategory ? () => categoryManager.addCategory(context) : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).elevatedButtonTheme.style?.backgroundColor?.resolve({}),
                              foregroundColor: Theme.of(context).elevatedButtonTheme.style?.foregroundColor?.resolve({}),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  canAddCategory ? Icons.add : Icons.info,
                                  size: 16,
                                  color: Theme.of(context).elevatedButtonTheme.style?.foregroundColor?.resolve({}),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  canAddCategory ? 'Lisää kategoria' : 'Ei lisättäviä kategorioita',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: Theme.of(context).elevatedButtonTheme.style?.foregroundColor?.resolve({}),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...sortedCategories.map((category) {
                    final sortedSubcategories = expenseControllers[category]!.keys.toList()..sort();
                    final canAddSubcategory = subcategoryManager.canAddSubcategory(category);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                        ),
                        child: ExpansionTile(
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(category),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => categoryManager.removeCategory(category),
                                tooltip: 'Poista kategoria',
                              ),
                            ],
                          ),
                          children: [
                            ...sortedSubcategories.map((subcategory) {
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 8.0),
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(subcategory)),
                                    SizedBox(
                                      width: 100,
                                      child: TextField(
                                        controller: expenseControllers[category]![subcategory],
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: 'Summa (€)',
                                          border: const OutlineInputBorder(),
                                          errorText: _validateAmount(expenseControllers[category]![subcategory]!.text),
                                        ),
                                        onChanged: (value) {
                                          onUpdate();
                                        },
                                        onEditingComplete: () {
                                          _formatAmount(expenseControllers[category]![subcategory]!);
                                          onUpdate();
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => subcategoryManager.removeSubcategory(category, subcategory),
                                      tooltip: 'Poista alakategoria',
                                    ),
                                  ],
                                ),
                              );
                            }),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Tooltip(
                                    message: canAddSubcategory
                                        ? 'Lisää uusi alakategoria'
                                        : 'Maksimi alakategorioiden määrä (6) saavutettu',
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.add),
                                      label: Text(
                                        'Lisää alakategoria',
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                              color: Theme.of(context).elevatedButtonTheme.style?.foregroundColor?.resolve({}),
                                            ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(context).elevatedButtonTheme.style?.backgroundColor?.resolve({}),
                                        foregroundColor: Theme.of(context).elevatedButtonTheme.style?.foregroundColor?.resolve({}),
                                      ),
                                      onPressed: canAddSubcategory
                                          ? () => subcategoryManager.addSubcategory(context, category)
                                          : null,
                                    ),
                                  ),
                                  if (!canAddSubcategory) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Maksimi alakategorioiden määrä (6) saavutettu',
                                      style: TextStyle(
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