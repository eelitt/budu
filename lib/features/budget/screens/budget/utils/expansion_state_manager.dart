import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExpansionStateManager {
  final String categoryName;
  final ValueNotifier<bool> isExpanded;


  ExpansionStateManager({
    required this.categoryName,
    required this.isExpanded,

  });

  Future<void> loadExpansionState() async {
    final prefs = await SharedPreferences.getInstance();
    final isExpanded = prefs.getBool('expansion_$categoryName') ?? false;

    this.isExpanded.value = isExpanded;
 
  }

  Future<void> saveExpansionState(bool expanded, {bool isManual = true}) async {
    if (isManual) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('expansion_$categoryName', expanded);
    }
    isExpanded.value = expanded;
  }

  void expandProgrammatically() {
    isExpanded.value = true;
  }
}