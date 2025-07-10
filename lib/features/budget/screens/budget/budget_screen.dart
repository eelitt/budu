import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:budu/features/budget/screens/budget/controllers/budget_screen_controller.dart';
import 'package:budu/features/budget/screens/budget/controllers/shared_budget_screen_controller.dart';
import 'package:budu/features/budget/screens/budget/income_section.dart';
import 'package:budu/features/budget/screens/budget/widgets/add_category.dart';
import 'package:budu/features/budget/screens/budget/widgets/budget_month_selector.dart';
import 'package:budu/features/budget/screens/budget/widgets/budget_confirmation_dialogs.dart';
import 'package:budu/features/budget/screens/budget/widgets/category_list_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Budjettinäkymä, joka näyttää budjetin tiedot, tulot ja kategoriat.
/// Delegoi budjetin tilan hallinnan BudgetScreenController:ille ja SharedBudgetScreenController:ille.
/// Näyttää toggle-painikkeen vain, jos yhteistalousbudjetteja on saatavilla.
/// Tallentaa toggle-painikkeen valinnan (isSharedBudget) SharedPreferences:iin.
/// Näyttää BudgetMonthSelector:n sekä henkilökohtaisille että yhteistalousbudjeteille.
class BudgetScreen extends StatefulWidget {
  final VoidCallback? onBudgetDeleted;
  const BudgetScreen({super.key, this.onBudgetDeleted});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  late BudgetScreenController _personalController;
  late SharedBudgetScreenController _sharedController;
  bool _isSharedBudget = false;
  BudgetModel? _selectedSharedBudget;
  bool _isLoadingBudgets = true;
  bool _hasSharedBudgets = false;
  bool _isLoadingSharedBudget = false; // Seuraa yhteistalousbudjetin lataustilaa

  @override
  void initState() {
    super.initState();
    // Alustetaan kontrollerit henkilökohtaisille ja yhteistalousbudjeteille
    _personalController = BudgetScreenController(
      context: context,
      onStateChanged: () {
        if (mounted) setState(() {});
      },
      onBudgetDeleted: widget.onBudgetDeleted,
    );
    _sharedController = SharedBudgetScreenController(
      context: context,
      onStateChanged: () {
        if (mounted) setState(() {});
      },
      onBudgetDeleted: widget.onBudgetDeleted,
    );
    // Ladataan budjetit ja toggle-painikkeen valinta build-vaiheen jälkeen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPreferencesAndBudgets();
    });
  }

  /// Lataa SharedPreferences:stä toggle-painikkeen valinnan ja budjetit
  Future<void> _loadPreferencesAndBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final sharedBudgetProvider = Provider.of<SharedBudgetProvider>(context, listen: false);

    try {
      // Lue isSharedBudget SharedPreferences:stä, oletusarvo false
      final savedIsSharedBudget = prefs.getBool('isSharedBudget') ?? false;

      // Lataa budjetit
      await sharedBudgetProvider.fetchSharedBudgets(authProvider.user!.uid);
      if (mounted) {
        setState(() {
          _isLoadingBudgets = false;
          _hasSharedBudgets = sharedBudgetProvider.sharedBudgets.isNotEmpty;
          // Aseta _isSharedBudget vain, jos yhteistalousbudjetteja on
          _isSharedBudget = _hasSharedBudgets && savedIsSharedBudget;
          if (_hasSharedBudgets) {
            _selectedSharedBudget = sharedBudgetProvider.sharedBudgets.first;
            // Ladataan yhteistalousbudjetti, jos valittuna
            if (_isSharedBudget && _selectedSharedBudget != null) {
              _isLoadingSharedBudget = true;
              _sharedController.loadBudget(
                userId: authProvider.user!.uid,
                sharedBudgetId: _selectedSharedBudget!.id.toString(),
              ).then((_) {
                if (mounted) {
                  setState(() {
                    _isLoadingSharedBudget = false;
                  });
                }
              });
            }
          }
        });
      }
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to load shared budgets or preferences',
      );
      if (mounted) {
        setState(() {
          _isLoadingBudgets = false;
        });
      }
    }
  }

  /// Tallentaa toggle-painikkeen valinnan SharedPreferences:iin
  Future<void> _saveBudgetPreference(bool isSharedBudget) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isSharedBudget', isSharedBudget);
  }

  @override
  void dispose() {
    _personalController.dispose();
    _sharedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingBudgets || !_personalController.isInitialized || _isLoadingSharedBudget || _sharedController.isLoadingBudget) {
      return const Center(child: CircularProgressIndicator());
    }

    return Consumer2<BudgetProvider, SharedBudgetProvider>(
      builder: (context, budgetProvider, sharedBudgetProvider, child) {
        // Päivitä _selectedSharedBudget uusimmalla versiolla _sharedBudgets-listasta
        if (_isSharedBudget && _selectedSharedBudget != null) {
          final newSelectedBudget = sharedBudgetProvider.sharedBudgets.firstWhere(
            (budget) => budget.id == _selectedSharedBudget!.id,
            orElse: () => _selectedSharedBudget!,
          );
          // Aina päivitä, jos objekti on eri (uusi instanssi expenses-muutoksella)
          if (newSelectedBudget != _selectedSharedBudget) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _selectedSharedBudget = newSelectedBudget;
              });
            });
          }
        }

        return StreamBuilder<BudgetModel?>(
          stream: _sharedController.selectedBudget,
          builder: (context, snapshot) {
            final budget = _isSharedBudget ? snapshot.data : budgetProvider.budget;

            if (budget == null) {
              if (_personalController.availableBudgets.isEmpty && !_hasSharedBudgets) {
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
                      // Näytä toggle-painike vain, jos yhteistalousbudjetteja on
                      if (_hasSharedBudgets) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Henkilökohtainen',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontSize: 16,
                                    fontWeight: _isSharedBudget ? FontWeight.normal : FontWeight.bold,
                                  ),
                            ),
                            Switch(
                              value: _isSharedBudget,
                              onChanged: (value) async {
                                WidgetsBinding.instance.addPostFrameCallback((_) async {
                                  setState(() {
                                    _isSharedBudget = value;
                                    if (value && _selectedSharedBudget != null) {
                                      _isLoadingSharedBudget = true;
                                    }
                                  });
                                  // Tallenna toggle-painikkeen valinta
                                  await _saveBudgetPreference(value);
                                  // Ladataan yhteistalousbudjetti, jos valittu
                                  if (value && _selectedSharedBudget != null) {
                                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                    await _sharedController.loadBudget(
                                      userId: authProvider.user!.uid,
                                      sharedBudgetId: _selectedSharedBudget!.id.toString(),
                                    );
                                    if (mounted) {
                                      setState(() {
                                        _isLoadingSharedBudget = false;
                                      });
                                    }
                                  }
                                });
                              },
                              activeColor: Colors.blueGrey[700],
                              inactiveThumbColor: Colors.blueGrey[300],
                            ),
                            Text(
                              'Yhteistalous',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontSize: 16,
                                    fontWeight: _isSharedBudget ? FontWeight.bold : FontWeight.normal,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
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
                                  _isSharedBudget ? 'Muokkaa yhteistalousbudjettia' : 'Muokkaa budjettia',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        fontSize: _isSharedBudget ? 15 : 18,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black87,
                                      ),
                                      maxLines: _isSharedBudget ? 2 : 1,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            BudgetMonthSelector(
                              isSharedBudget: _isSharedBudget,
                              availableBudgets: _personalController.availableBudgets,
                              availableSharedBudgets: sharedBudgetProvider.sharedBudgets,
                              selectedBudget: budgetProvider.budget,
                              selectedSharedBudget: _selectedSharedBudget ?? sharedBudgetProvider.sharedBudgets.firstOrNull, // Null-tarkistus: Käytä ensimmäistä saatavilla olevaa, jos null
                              onBudgetSelected: (value) async {
                                if (value != null) {
                                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                  if (_isSharedBudget && value is BudgetModel) {
                                    setState(() {
                                      _isLoadingSharedBudget = true;
                                      _selectedSharedBudget = value;
                                    });
                                    await _sharedController.loadBudget(
                                      userId: authProvider.user!.uid,
                                      sharedBudgetId: value.id.toString(),
                                    );
                                    if (mounted) {
                                      setState(() {
                                        _isLoadingSharedBudget = false;
                                      });
                                    }
                                  } else if (!_isSharedBudget && value is BudgetModel) {
                                    await _personalController.loadBudget(
                                      userId: authProvider.user!.uid,
                                      budgetId: value.id!,
                                    );
                                  }
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
                                    if (_isSharedBudget) {
                                      await _sharedController.resetBudgetExpenses(
                                        userId: authProvider.user!.uid,
                                        sharedBudgetId: _selectedSharedBudget?.id.toString() ?? '', // Null-tarkistus: Tyhjä string, jos null (virheenkäsittely)
                                      );
                                    } else {
                                      await _personalController.resetBudgetExpenses(
                                        userId: authProvider.user!.uid,
                                        budgetId: budget.id!,
                                      );
                                    }
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
                                    isLastBudget: _isSharedBudget
                                        ? _hasSharedBudgets && sharedBudgetProvider.sharedBudgets.length == 1
                                        : _personalController.availableBudgets.length == 1,
                                    customMessage: _isSharedBudget
                                        ? 'Haluatko varmasti poistaa yhteistalousbudjetin? Kaikki siihen liittyvät tapahtumat poistetaan.'
                                        : 'Haluatko varmasti poistaa tämän budjetin? Budjetin tulo- ja menotapahtumat poistetaan samalla.',
                                  );
                                  if (confirmed) {
                                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                    if (_isSharedBudget) {
                                      await _sharedController.deleteBudget(
                                        userId: authProvider.user!.uid,
                                        sharedBudgetId: _selectedSharedBudget?.id.toString() ?? '', // Null-tarkistus: Tyhjä string, jos null (virheenkäsittely)
                                      );
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        setState(() {
                                          _hasSharedBudgets = sharedBudgetProvider.sharedBudgets.isNotEmpty;
                                          if (!_hasSharedBudgets) {
                                            _isSharedBudget = false;
                                            _selectedSharedBudget = null;
                                            // Nollataan isSharedBudget SharedPreferences:ssä
                                            _saveBudgetPreference(false);
                                          } else {
                                            // Valitse ensimmäinen jäljellä oleva yhteistalousbudjetti
                                            _selectedSharedBudget = sharedBudgetProvider.sharedBudgets.first;
                                            _sharedController.loadBudget(
                                              userId: authProvider.user!.uid,
                                              sharedBudgetId: _selectedSharedBudget!.id.toString(),
                                            );
                                          }
                                        });
                                      });
                                    } else {
                                      await _personalController.deleteBudget(
                                        userId: authProvider.user!.uid,
                                        budgetId: budget.id!,
                                      );
                                    }
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
                      IncomeSection(
                        isSharedBudget: _isSharedBudget,
                        selectedSharedBudget: _selectedSharedBudget,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
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
                                AddCategory(
                                  isSharedBudget: _isSharedBudget,
                                  selectedSharedBudget: _selectedSharedBudget,
                                  sharedController: _sharedController,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            CategoryListWrapper(
                              isSharedBudget: _isSharedBudget,
                              budget: budget,
                              sharedBudget: _selectedSharedBudget ?? BudgetModel( // Null-tarkistus: Luo tyhjä oletus-BudgetModel, jos null (virheenkäsittely)
                                income: 0.0,
                                expenses: {},
                                createdAt: DateTime.now(),
                                startDate: DateTime.now(),
                                endDate: DateTime.now(),
                                type: 'custom',
                                isPlaceholder: true,
                              ),
                              sharedController: _sharedController,
                            ),
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