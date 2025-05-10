import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExpansionStateManager {
  final String categoryName;
  final ValueNotifier<bool> isExpanded;
  final ExpansionTileController expansionController;
  bool _isManuallyExpanded = false;

  ExpansionStateManager({
    required this.categoryName,
    required this.isExpanded,
    required this.expansionController,
  });

  Future<void> loadExpansionState() async {
    final prefs = await SharedPreferences.getInstance();
    final isExpanded = prefs.getBool('expansion_$categoryName') ?? false;
    _isManuallyExpanded = isExpanded;
    this.isExpanded.value = isExpanded;
    if (isExpanded) {
      expansionController.expand();
    }
  }

  Future<void> saveExpansionState(bool expanded, {bool isManual = true}) async {
    if (isManual) {
      _isManuallyExpanded = expanded;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('expansion_$categoryName', expanded);
    }
    isExpanded.value = expanded;
  }

  void expandProgrammatically() {
    isExpanded.value = true;
    expansionController.expand();
  }
}