import 'package:budu/features/update/providers/update_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/update_handler.dart';

class UpdateDialogWrapper {
  final UpdateHandler updateHandler;
  final String currentVersion;

  const UpdateDialogWrapper({
    required this.updateHandler,
    required this.currentVersion,
  });

  Future<bool> show(BuildContext context) async {
    final updateProvider = Provider.of<UpdateProvider>(context, listen: false);
    await updateHandler.checkForAppUpdate(context, updateProvider);
    return updateHandler.isUpdateRequired;
  }
}