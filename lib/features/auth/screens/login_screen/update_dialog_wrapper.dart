import 'package:budu/features/update/providers/update_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'update_handler.dart';

class UpdateDialogWrapper extends StatelessWidget {
  final UpdateHandler updateHandler;
  final String currentVersion;

  const UpdateDialogWrapper({
    super.key,
    required this.updateHandler,
    required this.currentVersion,
  });

  @override
  Widget build(BuildContext context) {
    return Container();
  }

  void show(BuildContext context) {
    if (updateHandler.isUpdateRequired) {
      updateHandler.checkForAppUpdate(context, Provider.of<UpdateProvider>(context, listen: false));
    }
  }
}