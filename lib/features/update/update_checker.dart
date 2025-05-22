import 'package:budu/features/update/update_manager.dart';
import 'package:flutter/material.dart';

/// Widget, joka suorittaa päivitystarkistuksen sovelluksen käynnistyksessä.
/// Käyttää BuildContext:ia, joka on MultiProvider:in jälkeläinen.
class UpdateChecker extends StatefulWidget {
  final Widget child; // Lisätään child-widget, jotta UpdateChecker voi kääriä MaterialApp:in

  const UpdateChecker({
    super.key,
    required this.child,
  });

  @override
  UpdateCheckerState createState() => UpdateCheckerState();
}

class UpdateCheckerState extends State<UpdateChecker> {
  @override
  void initState() {
    super.initState();
    // Suorita päivitystarkistus sovelluksen käynnistyksessä
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('UpdateChecker: initState - Aloitetaan päivitystarkistus');
      final updateManager = UpdateManager();
      updateManager.checkAndHandleUpdate(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child; // Palautetaan lapsi-widget (MaterialApp)
  }
}