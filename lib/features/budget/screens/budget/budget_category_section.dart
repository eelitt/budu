import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/screens/budget/controllers/budget_category_controller.dart';
import 'package:budu/features/budget/screens/budget/controllers/shared_budget_screen_controller.dart';
import 'package:budu/features/budget/screens/budget/utils/category_icon_utils.dart';
import 'package:budu/features/budget/screens/budget/utils/delete_dialog_state_manager.dart';
import 'package:budu/features/budget/screens/budget/utils/expansion_state_manager.dart';
import 'package:budu/features/budget/screens/budget/widgets/add_subcategory_form.dart';
import 'package:budu/features/budget/screens/budget/widgets/budget_custom_category_tile.dart';
import 'package:budu/features/budget/screens/budget/widgets/budget_confirmation_dialogs.dart';
import 'package:budu/features/budget/screens/budget/widgets/budget_sub_category_list.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Widget, joka näyttää budjettikategorian ja sen alakategoriat laajennettavassa muodossa.
/// Mahdollistaa kategorian ja alakategorioiden hallinnan, kuten lisäämisen, muokkaamisen ja poistamisen.
/// Tukee sekä henkilökohtaisia (BudgetProvider) että yhteistalousbudjetteja (SharedBudget).
class BudgetCategorySection extends StatefulWidget {
  final String categoryName; // Kategorian nimi, joka näytetään ja jota hallitaan
  final bool isSharedBudget; // Määrittää, onko budjetti yhteistalousbudjetti
  final BudgetModel budget; // Budjetti (henkilökohtainen tai yhteistalous)
  final BudgetModel sharedBudget; // Yhteistalousbudjetti, jos valittuna
  final SharedBudgetScreenController sharedController; // Kontrolleri yhteistalousbudjetin tilan hallintaan

  const BudgetCategorySection({
    super.key,
    required this.categoryName,
    required this.isSharedBudget,
    required this.budget,
    required this.sharedBudget,
    required this.sharedController,
  });

  @override
  State<BudgetCategorySection> createState() => _BudgetCategorySectionState();
}

/// Budjettikategorian tilallinen tila, joka hallinnoi laajennettavaa näkymää ja alakategorioiden tilaa.
class _BudgetCategorySectionState extends State<BudgetCategorySection> {
  late BudgetCategoryController _controller; // Kontrolleri kategorian ja alakategorioiden hallintaan
  late ExpansionStateManager _expansionStateManager; // Hallinnoi kategorian laajennettua/supistettua tilaa
  late DeleteDialogStateManager _deleteDialogStateManager; // Hallinnoi poiston vahvistusdialogin tilaa
  final ValueNotifier<bool> _isExpanded = ValueNotifier<bool>(false); // Seuraa, onko kategoria laajennettu
  final GlobalKey _expansionTileKey = GlobalKey(); // Avain laajennettavan elementin tilan hallintaan

  @override
  void initState() {
    super.initState();
    // Alustetaan kontrolleri kategorian ja alakategorioiden hallintaa varten
    _controller = BudgetCategoryController();
    // Alustetaan ExpansionStateManager kategorian laajennustilan hallintaan
    _expansionStateManager = ExpansionStateManager(
      categoryName: widget.categoryName,
      isExpanded: _isExpanded,
    );
    // Alustetaan DeleteDialogStateManager poiston vahvistusdialogin tilan hallintaan
    _deleteDialogStateManager = DeleteDialogStateManager();
    // Ladataan tallennettu laajennustila (laajennettu/supistettu)
    _expansionStateManager.loadExpansionState();
  }

  @override
  void dispose() {
    // Vapautetaan resurssit, kun widget poistetaan
    _controller.dispose();
    _isExpanded.dispose();
    super.dispose();
  }

  /// Aloittaa uuden alakategorian lisäämisen ja laajentaa kategorian ohjelmallisesti
  void _handleStartAdding() {
    _controller.startAdding(context, widget.categoryName, widget.isSharedBudget, widget.sharedBudget);
    _expansionStateManager.expandProgrammatically();
  }

  /// Aloittaa olemassa olevan alakategorian muokkauksen ja laajentaa kategorian ohjelmallisesti
  void _handleStartEditing(String subcategory, BuildContext context) {
    _controller.startEditing(subcategory, context, widget.isSharedBudget, widget.sharedBudget);
    _expansionStateManager.expandProgrammatically();
  }

  @override
  Widget build(BuildContext context) {
    // Tarjoaa BudgetCategoryController:in jälkeläisille ja kuuntelee BudgetProvider:in muutoksia
    return ListenableProvider<BudgetCategoryController>.value(
      value: _controller,
      child: Consumer2<BudgetCategoryController, BudgetProvider>(
        builder: (context, controller, budgetProvider, child) {
          // Haetaan kategorian menot budjettityypin perusteella
          final expenses = widget.budget?.expenses[widget.categoryName] ?? {};
          final Map<String, double> displayedExpenses = {};
          // Muunnetaan menot näyttömuotoon: 'default'-alakategoria korvataan kategorian nimellä
          expenses.forEach((subcategory, value) {
            final displaySubcategory = subcategory == 'default' ? widget.categoryName : subcategory;
            displayedExpenses[displaySubcategory] = value;
          });

          final subcategoryCount = displayedExpenses.length; // Lasketaan alakategorioiden määrä

          return Container(
            decoration: BoxDecoration(
              color: Colors.white, // Kategorian taustaväri
              borderRadius: BorderRadius.circular(12), // Pyöristetyt kulmat
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15), // Varjon väri
                  blurRadius: 8, // Varjon pehmennys
                  offset: const Offset(0, 4), // Varjon siirtymä
                ),
              ],
            ),
            child: CustomExpansionTile(
              key: _expansionTileKey, // Avain laajennettavan elementin tilan hallintaan
              isExpanded: _isExpanded, // Laajennustilan seurantamuuttuja
              onExpansionChanged: (expanded) {
                // Päivitetään laajennustila ja tallennetaan se
                _isExpanded.value = expanded;
                _expansionStateManager.saveExpansionState(expanded, isManual: true);
              },
              title: Stack(
                children: [
                  // Kategorian ikoni vasemmassa yläkulmassa
                  Positioned(
                    left: 12,
                    top: 4,
                    child: Icon(
                      getCategoryIcon(widget.categoryName), // Haetaan ikoni kategorian nimen perusteella
                      color: Colors.blueGrey,
                      size: 24,
                    ),
                  ),
                  // Ala-kategorioiden määrä kategorian ikonin oikealla puolella
                  Positioned(
                    left: 40, // Sijoitetaan ikonin (24 px leveä + 4 px väli) oikealle puolelle
                    top: 4,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _isExpanded,
                      builder: (context, isExpanded, child) {
                        if (isExpanded) return const SizedBox.shrink(); // Ei näytetä, kun kategoria on laajennettu
                        return Text(
                          'Ala-kategorioita: $subcategoryCount', // Näyttää alakategorioiden lukumäärän
                          style: const TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        );
                      },
                    ),
                  ),
                  // Laajennus/supistus-ikoni oikeassa yläkulmassa
                  Positioned(
                    right: 4,
                    top: 4,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _isExpanded,
                      builder: (context, isExpanded, child) {
                        return AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0, // 0.5 = 180 astetta, kun laajennettu
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.linear,
                          child: Icon(
                            Icons.expand_more,
                            color: Colors.blueGrey,
                            size: 24,
                          ),
                        );
                      },
                    ),
                  ),
                  // Kategorian nimi ja toimintopainikkeet ikonin alapuolella
                  Padding(
                    padding: const EdgeInsets.only(top: 34, left: 16, right: 2, bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            widget.categoryName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Painike uuden alakategorian lisäämiseen
                            IconButton(
                              icon: const Icon(Icons.add, size: 20),
                              onPressed: _handleStartAdding,
                              padding: const EdgeInsets.only(right: 4),
                              constraints: const BoxConstraints(),
                              visualDensity: VisualDensity.compact,
                            ),
                            // Painike kategorian poistamiseen
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                              onPressed: () async {
                                // Tarkistetaan, näytetäänkö poiston vahvistusdialogi
                                final shouldShowDialog = await _deleteDialogStateManager.shouldShowDeleteDialog();
                                if (!shouldShowDialog) {
                                  // Poistetaan kategoria suoraan, jos dialogia ei näytetä
                                  await controller.deleteCategory(
                                    context,
                                    widget.categoryName,
                                    widget.isSharedBudget,
                                    widget.sharedBudget,
                                    widget.sharedController,
                                  );
                                  return;
                                }

                                // Näytetään vahvistusdialogi poistolle
                                final result = await showDeleteConfirmationDialog(
                                  context: context,
                                  isLastBudget: false,
                                  customMessage: 'Haluatko varmasti poistaa kategorian "${widget.categoryName}" ja kaikki sen alakategoriat? Kategoria poistetaan budjetistasi, mutta voit lisätä sen takaisin myöhemmin.',
                                  onDontShowAgainChanged: (dontShowAgain) async {
                                    await _deleteDialogStateManager.setShowDeleteDialog(!dontShowAgain);
                                  },
                                );

                                if (result == true) {
                                  // Poistetaan kategoria, jos käyttäjä vahvistaa
                                  await controller.deleteCategory(
                                    context,
                                    widget.categoryName,
                                    widget.isSharedBudget,
                                    widget.sharedBudget,
                                    widget.sharedController,
                                  );                                
                                }
                              },
                              tooltip: 'Poista kategoria',
                              padding: const EdgeInsets.only(left: 4),
                              constraints: const BoxConstraints(),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              children: [
                // Näytetään lomake uuden alakategorian lisäämiseen, jos lisäystila on aktiivinen
                if (controller.isAdding)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 16, right: 16), // Lisätty top padding
                    child: AddSubcategoryForm(
                      controller: controller.subcategoryController,
                      errorMessage: controller.errorMessage,
                      onAdd: () => controller.addSubcategory(
                        context,
                        widget.categoryName,
                        widget.isSharedBudget,
                        widget.sharedBudget,
                        sharedController: widget.sharedController,
                      ),
                      onCancel: controller.cancelAdding,
                      isSharedBudget: widget.isSharedBudget,
                      sharedBudget: widget.sharedBudget,
                      categoryName: widget.categoryName,
                    ),
                  ),
                // Näytetään alakategorioiden lista ja muokkausmahdollisuudet
                BudgetSubCategoryList(
                  categoryName: widget.categoryName,
                  displayedExpenses: displayedExpenses,
                  isEditing: controller.isEditing,
                  isSaving: controller.isSaving,
                  editingSubcategory: controller.editingSubcategory,
                  newlyAddedSubcategory: controller.newlyAddedSubcategory,
                  nameControllers: controller.nameControllers,
                  amountControllers: controller.amountControllers,
                  errorMessage: controller.errorMessage,
                  service: controller,
                  onCancelEditing: controller.cancelEditing,
                  onStartEditing: _handleStartEditing,
                  onUpdateSubcategory: (oldSubcategory) => controller.updateSubcategory(
                    context,
                    widget.categoryName,
                    oldSubcategory,
                    widget.isSharedBudget,
                    widget.sharedBudget,
                    sharedController: widget.sharedController,
                  ),
                  isSharedBudget: widget.isSharedBudget,
                  sharedBudget: widget.sharedBudget,
                  budget: widget.budget,
                  sharedController: widget.sharedController,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}