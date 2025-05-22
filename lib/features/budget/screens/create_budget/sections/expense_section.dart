import 'package:budu/core/constants.dart';
import 'package:budu/features/budget/screens/create_budget/managers/category_manager.dart';
import 'package:budu/features/budget/screens/create_budget/managers/subcategory_manager.dart';
import 'package:flutter/material.dart';

/// Widget, joka näyttää budjetin menot kategorioittain ja niiden alakategorioiden avulla.
/// Mahdollistaa kategorioiden ja alakategorioiden lisäämisen, poistamisen ja muokkaamisen.
class ExpensesSection extends StatefulWidget {
  final Map<String, Map<String, TextEditingController>> expenseControllers; // Kategorioiden ja alakategorioiden ohjaimet
  final VoidCallback onUpdate; // Callback-funktio, jota kutsutaan, kun kategoriat tai alakategoriat päivittyvät

  const ExpensesSection({
    super.key,
    required this.expenseControllers,
    required this.onUpdate,
  });

  @override
  State<ExpensesSection> createState() => _ExpensesSectionState();
}

/// ExpensesSectionin tilallinen tila, joka hallinnoi fokusnodeja ja käyttöliittymän tilaa.
class _ExpensesSectionState extends State<ExpensesSection> {
  Map<String, Map<String, FocusNode>> focusNodes = {}; // Fokusnodet tekstikenttien hallintaan

  @override
  void initState() {
    super.initState();
    // Alustetaan fokusnodet kategorioille ja alakategorioille
    _updateFocusNodes();
  }

  @override
  void didUpdateWidget(ExpensesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Päivitetään fokusnodet, kun widget päivittyy (esim. kategoria lisätään tai poistetaan)
    _updateFocusNodes();
  }

  /// Päivittää fokusnodet kategorioiden ja alakategorioiden perusteella.
  /// Varmistaa, että fokusnodet vastaavat nykyisiä kategorioita ja alakategorioita.
  void _updateFocusNodes() {
    final currentCategories = widget.expenseControllers.keys.toSet();
    // Poistetaan vanhat fokusnodet, jotka eivät ole enää käytössä
    focusNodes.removeWhere((category, _) => !currentCategories.contains(category));

    for (var category in widget.expenseControllers.keys) {
      focusNodes[category] ??= {};
      final currentSubcategories = widget.expenseControllers[category]!.keys.toSet();
      // Poistetaan vanhat fokusnodet alakategorioista, jotka eivät ole enää käytössä
      focusNodes[category]!.removeWhere((subcategory, _) => !currentSubcategories.contains(subcategory));

      for (var subcategory in widget.expenseControllers[category]!.keys) {
        // Luodaan uusi fokusnode, jos sellaista ei ole
        focusNodes[category]![subcategory] ??= FocusNode();
      }
    }
  }

  @override
  void dispose() {
    // Vapautetaan fokusnodet ja niiden resurssit
    focusNodes.forEach((_, subFocusNodes) {
      subFocusNodes.forEach((_, focusNode) => focusNode.dispose());
    });
    super.dispose();
  }

  /// Validoi budjetin menoarvon.
  /// [value] on tarkistettava arvo.
  /// Palauttaa virheviestin, jos arvo on virheellinen, muuten null.
  String? _validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Salli tyhjä arvo
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

  /// Muotoilee menoarvon kahden desimaalin tarkkuudella.
  /// [controller] on muotoiltava tekstikentän ohjain.
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
    // Alustetaan CategoryManager kategorioiden hallintaa varten
    final categoryManager = CategoryManager(
      expenseControllers: widget.expenseControllers,
      onUpdate: widget.onUpdate,
    );
    // Alustetaan SubcategoryManager alakategorioiden hallintaa varten
    final subcategoryManager = SubcategoryManager(
      expenseControllers: widget.expenseControllers,
      onUpdate: ({required String category, required String subcategory}) {
        widget.onUpdate();
        _updateFocusNodes(); // Varmistetaan, että fokusnodet on päivitetty
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (focusNodes[category] != null && focusNodes[category]![subcategory] != null) {
            // Siirretään fokus uuteen alakategoriaan
            focusNodes[category]![subcategory]!.requestFocus();
          }
        });
      },
    );

    // Järjestetään kategoriat aakkosjärjestykseen
    final sortedCategories = widget.expenseControllers.keys.toList()..sort();
    final canAddCategory = categoryManager.canAddCategory;

    return Container(
      margin: const EdgeInsets.only(bottom: 16), // Välistys alareunaan
      decoration: BoxDecoration(
        color: Colors.white, // Taustaväri
        borderRadius: BorderRadius.circular(12), // Pyöristetyt kulmat
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15), // Varjon väri
            blurRadius: 8, // Varjon pehmennys
            offset: const Offset(0, 4), // Varjon siirtymä
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent, // Poistetaan oletusjakajat
        ),
        child: ExpansionTile(
          initiallyExpanded: true, // Alkuasetus laajennustilalle
          title: Row(
            children: [
              const Icon(Icons.account_balance_wallet, size: 24), // Ikoni osion alussa
              const SizedBox(width: 8), // Väli ikonin ja tekstin välillä
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
              padding: const EdgeInsets.all(16.0), // Sisäinen välistys
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
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Sisäinen välistys
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  canAddCategory ? Icons.add : Icons.info,
                                  size: 16,
                                  color: Theme.of(context).elevatedButtonTheme.style?.foregroundColor?.resolve({}),
                                ),
                                const SizedBox(width: 4), // Väli ikonin ja tekstin välillä
                                Text(
                                  canAddCategory ? 'Lisää kategoria' : 'Kategorioiden maksimimäärä (${Constants.maxCategories}) saavutettu',
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
                  const SizedBox(height: 16), // Väli painikkeen ja kategorioiden välillä
                  // Näytetään jokainen kategoria laajennettavassa muodossa
                  ...sortedCategories.map((category) {
                    // Järjestetään alakategoriat aakkosjärjestykseen
                    final sortedSubcategories = widget.expenseControllers[category]!.keys.toList()..sort();
                    final canAddSubcategory = subcategoryManager.canAddSubcategory(category);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8), // Välistys kategorioiden välillä
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Sisäinen välistys
                      decoration: BoxDecoration(
                        color: Colors.white, // Taustaväri
                        borderRadius: BorderRadius.circular(8), // Pyöristetyt kulmat
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15), // Varjon väri
                            blurRadius: 6, // Varjon pehmennys
                            offset: const Offset(0, 2), // Varjon siirtymä
                          ),
                        ],
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent, // Poistetaan oletusjakajat
                        ),
                        child: ExpansionTile(
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  category,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  // Poistetaan kategoria ja sen alakategoriat
                                  categoryManager.removeCategory(category);
                                },
                                tooltip: 'Poista kategoria',
                              ),
                            ],
                          ),
                          children: [
                            // Näytetään jokainen alakategoria
                            ...sortedSubcategories.map((subcategory) {
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 8.0), // Välistys alakategorioiden välillä
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), // Sisäinen välistys
                                decoration: BoxDecoration(
                                  color: Colors.white, // Taustaväri
                                  border: Border.all(color: Colors.grey[300]!), // Reunan väri
                                  borderRadius: BorderRadius.circular(8), // Pyöristetyt kulmat
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15), // Varjon väri
                                      blurRadius: 6, // Varjon pehmennys
                                      offset: const Offset(0, 2), // Varjon siirtymä
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // Alakategorian nimi
                                    Expanded(child: Text(subcategory)),
                                    // Tekstikenttä alakategorian summan syöttämiseen
                                    SizedBox(
                                      width: 100,
                                      child: TextField(
                                        controller: widget.expenseControllers[category]![subcategory],
                                        focusNode: focusNodes[category]![subcategory],
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: 'Summa (€)',
                                          border: const OutlineInputBorder(),
                                          errorText: _validateAmount(widget.expenseControllers[category]![subcategory]!.text),
                                        ),
                                        onChanged: (value) {
                                          widget.onUpdate();
                                        },
                                        onEditingComplete: () {
                                          _formatAmount(widget.expenseControllers[category]![subcategory]!);
                                          widget.onUpdate();
                                          FocusScope.of(context).unfocus();
                                        },
                                      ),
                                    ),
                                    // Poistopainike alakategorialle
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => subcategoryManager.removeSubcategory(category, subcategory),
                                      tooltip: 'Poista alakategoria',
                                    ),
                                  ],
                                ),
                              );
                            }),
                            // Alakategorioiden lisäyspainike ja rajoitusviesti
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                                  // Näytetään viesti, jos alakategorioiden maksimimäärä on saavutettu
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