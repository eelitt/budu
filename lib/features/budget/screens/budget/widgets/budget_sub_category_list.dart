import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/screens/budget/controllers/budget_category_controller.dart';
import 'package:budu/features/budget/screens/budget/widgets/budget_sub_category_dialogs.dart';
import 'package:budu/features/budget/screens/budget/widgets/edit_subcategory_form.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Widget, joka näyttää budjettikategorian alakategoriat listana.
/// Mahdollistaa alakategorioiden muokkaamisen ja poistamisen, ja korostaa juuri lisätyt alakategoriat.
class BudgetSubCategoryList extends StatelessWidget {
  final String categoryName; // Yläkategorian nimi, johon alakategoriat liittyvät
  final Map<String, double> displayedExpenses; // Alakategoriat ja niiden summat näyttömuodossa
  final bool isEditing; // Onko muokkaustila aktiivinen (muokataan yhtä alakategoriaa)
  final bool isSaving; // Onko tallennus käynnissä (esim. muokkauksen tai lisäyksen aikana)
  final String? editingSubcategory; // Muokattavan alakategorian nimi, jos muokkaustila on aktiivinen
  final String? newlyAddedSubcategory; // Viimeksi lisätyn alakategorian nimi (korostetaan visuaalisesti)
  final Map<String, TextEditingController> nameControllers; // Tekstikenttien ohjaimet alakategorioiden nimille
  final Map<String, TextEditingController> amountControllers; // Tekstikenttien ohjaimet alakategorioiden summille
  final String? errorMessage; // Virheviesti, joka näytetään, jos muokkaus/lisäys epäonnistuu
  final BudgetCategoryController service; // Kontrolleri alakategorioiden hallintaan
  final VoidCallback onCancelEditing; // Callback-funktio, jota kutsutaan, kun muokkaus peruutetaan
  final Function(String, BuildContext) onStartEditing; // Callback-funktio, jota kutsutaan, kun muokkaus aloitetaan
  final Function(String) onUpdateSubcategory; // Callback-funktio, jota kutsutaan, kun alakategoria päivitetään

  const BudgetSubCategoryList({
    super.key,
    required this.categoryName,
    required this.displayedExpenses,
    required this.isEditing,
    required this.isSaving,
    required this.editingSubcategory,
    required this.newlyAddedSubcategory,
    required this.nameControllers,
    required this.amountControllers,
    required this.errorMessage,
    required this.service,
    required this.onCancelEditing,
    required this.onStartEditing,
    required this.onUpdateSubcategory,
  });

  /// Muotoilee alakategorian nimen lisäämällä katkaisumerkin, jos nimi on pidempi kuin 13 merkkiä.
  /// [subcategory] on muotoiltava alakategorian nimi.
  /// Palauttaa muotoillun nimen, jossa on katkaisumerkki ("-") 14 merkin jälkeen, jos nimi on liian pitkä.
  String _formatSubcategoryName(String subcategory) {
    const int maxLengthBeforeHyphen = 14; // Maksimipituus ennen katkaisumerkkiä
    if (subcategory.length <= maxLengthBeforeHyphen) {
      return subcategory; // Palautetaan nimi sellaisenaan, jos se on tarpeeksi lyhyt
    }
    // Lisätään "-" 14 merkin jälkeen ja jätetään loput seuraavalle riville
    return '${subcategory.substring(0, maxLengthBeforeHyphen)}-${subcategory.substring(maxLengthBeforeHyphen)}';
  }

  @override
  Widget build(BuildContext context) {
    // Järjestetään alakategoriat aakkosjärjestykseen
    final entries = displayedExpenses.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    // Luodaan lista widgeteistä jokaiselle alakategorialle
    final List<Widget> subcategoryWidgets = entries.map((entry) {
      final subcategory = entry.key; // Alakategorian nimi
      final amount = entry.value; // Alakategorian summa
      final isNewlyAdded = subcategory == newlyAddedSubcategory; // Onko alakategoria juuri lisätty
      // Onko tallennus käynnissä tälle alakategorialle (lisäys tai muokkaus)
      final isCurrentlySaving = isSaving && (subcategory == newlyAddedSubcategory || subcategory == editingSubcategory);

      return AnimatedContainer(
        duration: const Duration(seconds: 2), // Animaation kesto korostukselle
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0), // Välistys alakategorioiden välillä
        padding: const EdgeInsets.all(2.0), // Sisäinen välistys
        decoration: BoxDecoration(
          color: isNewlyAdded ? Colors.blueGrey[50] : Colors.white, // Korostetaan juuri lisätty alakategoria
          borderRadius: BorderRadius.circular(8), // Pyöristetyt kulmat
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15), // Varjon väri
              blurRadius: 4, // Varjon pehmennys
              offset: const Offset(0, 2), // Varjon siirtymä
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Alakategorian nimi tai muokkauslomake
            Expanded(
              child: isEditing && editingSubcategory == subcategory
                  ? EditSubcategoryForm(
                      nameController: nameControllers[subcategory]!, // Nimen ohjain muokkauslomakkeelle
                      amountController: amountControllers[subcategory]!, // Summan ohjain muokkauslomakkeelle
                      onSave: () => onUpdateSubcategory(subcategory), // Päivitetään alakategoria
                      onCancel: onCancelEditing, // Peruutetaan muokkaus
                    )
                  : Padding(
                      padding: const EdgeInsets.only(left: 8.0, right: 4.0),
                      child: Text(
                        _formatSubcategoryName(subcategory), // Näyttää muotoillun alakategorian nimen
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                        softWrap: true, // Sallii tekstin rivittämisen
                      ),
                    ),
            ),
            // Summa ja toimintopainikkeet (muokkaa, poista)
            Row(
              children: [
                if (!(isEditing && editingSubcategory == subcategory)) ...[
                  if (isCurrentlySaving)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2), // Latausindikaattori tallennuksen aikana
                      ),
                    )
                  else
                    Text(
                      '${amount.toStringAsFixed(2)} €', // Näyttää alakategorian summan kahden desimaalin tarkkuudella
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  // Muokkauspainike
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => onStartEditing(subcategory, context), // Aloittaa alakategorian muokkauksen
                  ),
                  // Poistopainike
                  IconButton(
                    icon: const Icon(
                      Icons.delete,
                      size: 20,
                      color: Colors.red,
                    ),
                    onPressed: () async {
                      // Näytetään vahvistusdialogi poistolle
                      final deleteEvents = await confirmDeleteSubcategory(
                        context: context,
                        subcategory: subcategory,
                        categoryName: categoryName,
                      );
                      if (!deleteEvents) return;

                      // Poistetaan alakategoria Firestoresta, jos käyttäjä vahvistaa
                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      if (authProvider.user != null) {
                        final now = DateTime.now();
                        await service.deleteSubcategory(
                          context: context,
                          userId: authProvider.user!.uid,
                          year: now.year,
                          month: now.month,
                          categoryName: categoryName,
                          subcategory: subcategory,
                          deleteEvents: deleteEvents,
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    }).toList();

    return Column(
      children: [
        // Näytetään kaikki alakategoriat listana
        ...subcategoryWidgets,
        // Näytetään virheviesti, jos sellainen on olemassa
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              errorMessage!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}