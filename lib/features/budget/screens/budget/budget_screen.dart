import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/screens/budget/controllers/budget_screen_controller.dart';
import 'package:budu/features/budget/screens/budget/income_section.dart';
import 'package:budu/features/budget/screens/budget/widgets/add_category.dart';
import 'package:budu/features/budget/screens/budget/widgets/budget_month_selector.dart';
import 'package:budu/features/budget/screens/budget/widgets/category_list_wrapper.dart';
import 'package:budu/features/budget/screens/budget/widgets/budget_confirmation_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Budjettinäkymä, joka näyttää budjetin tiedot, tulot ja kategoriat.
/// Delegoi budjetin tilan hallinnan BudgetScreenController:ille ja keskittyy käyttöliittymän renderöintiin.
class BudgetScreen extends StatefulWidget {
  final VoidCallback? onBudgetDeleted; // Callback budjetin poiston jälkeen
  const BudgetScreen({super.key, this.onBudgetDeleted});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  late BudgetScreenController _controller; // Budjetin hallintaan käytettävä kontrolleri
BudgetModel? _lastBudget; // Seurataan budjetin tilaa

  @override
  void initState() {
    super.initState();
    _controller = BudgetScreenController(
      context: context,
      onStateChanged: () {
        // Varmistetaan, että widget on vielä kiinnitetty ennen tilan päivitystä
        if (mounted) {
          setState(() {});
        }
      },
      onBudgetDeleted: widget.onBudgetDeleted, // Välitetään callback kontrollerille
    );
  }

  @override
  void dispose() {
    // Vapautetaan kontrollerin resurssit ja perutaan asynkroniset operaatiot
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Odota, että BudgetScreenController on alustettu ennen FutureBuilderin suorittamista
    if (!_controller.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<void>(
      future: null, // loadAvailableMonths suoritetaan jo _initializeBudget-metodissa
      builder: (context, snapshot) {
        if (_controller.isLoadingBudget) {
          return const Center(child: CircularProgressIndicator());
        }

        return Consumer<BudgetProvider>(
          builder: (context, budgetProvider, child) {
            // Päivitetään _lastBudget budjetin tilan seurantaan
            if (_lastBudget != budgetProvider.budget) {
              _lastBudget = budgetProvider.budget;
              // Ei suoriteta budjetin latausta täällä, koska BudgetScreenController hoitaa sen
            }
            final budget = budgetProvider.budget;

            if (budget == null) {
              if (_controller.availableMonths.isEmpty) {
                return const Center(child: Text('Luo budjetti ensin!'));
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            }

            return SingleChildScrollView(
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
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
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.edit_document,
                                  color: Colors.blueGrey,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Muokkaa budjettia',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black87,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            BudgetMonthSelector(
                              availableMonths: _controller.availableMonths,
                              selectedMonth: _controller.selectedMonth.value,
                              onMonthSelected: (value) async {
                                if (value != null) {
                                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                  await _controller.loadBudget(
                                    userId: authProvider.user!.uid,
                                    year: value['year']!,
                                    month: value['month']!,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: () async {
                                  final confirmed = await showResetConfirmationDialog(context);
                                  if (confirmed) {
                                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                    await _controller.resetBudgetExpenses(
                                      userId: authProvider.user!.uid,
                                      year: _controller.currentYear.value,
                                      month: _controller.currentMonth.value,
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueGrey[700],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.refresh, size: 16),
                                    SizedBox(width: 4),
                                    Text('Nollaa'),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  final confirmed = await showDeleteConfirmationDialog(
                                    context: context,
                                    isLastBudget: _controller.availableMonths.length == 1,
                                    customMessage: _controller.availableMonths.length == 1
                                        ? 'Haluatko varmasti poistaa budjetin?\nKaikki siihen liittyvät tapahtumat poistetaan.\nKoska tämä on ainoa budjettisi, sinut ohjataan luomaan uusi.'
                                        : 'Haluatko varmasti poistaa tämän budjetin? Budjetin tulo- ja menotapahtumat poistetaan samalla.',
                                  );
                                  if (confirmed) {
                                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                    await _controller.deleteBudget(
                                      userId: authProvider.user!.uid,
                                      year: _controller.currentYear.value,
                                      month: _controller.currentMonth.value,
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueGrey[900],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.delete, size: 16),
                                    SizedBox(width: 4),
                                    Text('Poista'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const IncomeSection(),
                      const SizedBox(height: 16),
                      Container(
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
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Kategoriat',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                ),
                                const AddCategory(),
                              ],
                            ),
                            const SizedBox(height: 8),
                            CategoryListWrapper(budget: budget),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}