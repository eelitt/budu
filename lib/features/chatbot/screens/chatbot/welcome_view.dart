import 'package:flutter/material.dart';

class WelcomeView extends StatefulWidget {
  final VoidCallback onProceed;
  final VoidCallback onSkip;
  final Animation<Offset> slideAnimation;

  const WelcomeView({
    super.key,
    required this.onProceed,
    required this.onSkip,
    required this.slideAnimation,
  });

  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<WelcomeView> with TickerProviderStateMixin {
  late AnimationController _textFadeController;
  late AnimationController _buttonFadeController;
  Animation<double>? _textFadeAnimation;
  Animation<double>? _buttonFadeAnimation;
  bool _hasStartedButtonAnimation = false; // Seurataan, onko painikkeiden animaatio jo käynnistetty

  @override
  void initState() {
    super.initState();
    // Fade-animaatio tervetulotekstille ja vinkeille
    _textFadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _textFadeAnimation = CurvedAnimation(
      parent: _textFadeController,
      curve: Curves.easeIn,
    );

    // Fade-animaatio painikkeille
    _buttonFadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _buttonFadeAnimation = CurvedAnimation(
      parent: _buttonFadeController,
      curve: Curves.easeIn,
    );

    // Käynnistetään tervetulotekstin ja vinkkien animaatio välittömästi
    _textFadeController.forward();
  }

  @override
  void dispose() {
    _textFadeController.dispose();
    _buttonFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Color.fromARGB(255, 253, 228, 190),
            Color(0xFFFFFCF5),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tervetuloteksti animaatiolla
            SlideTransition(
              position: widget.slideAnimation,
              child: FadeTransition(
                opacity: _textFadeAnimation!,
                child: Text(
                  'Tervetuloa tavoittelemaan stressittömämpää elämää!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.black87,
                        fontSize: 28,
                      ),
                  textAlign: TextAlign.left,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Vinkit animaatiolla
            SlideTransition(
              position: widget.slideAnimation,
              child: FadeTransition(
                opacity: _textFadeAnimation!,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vinkkejä budjetin muodostamiseen:',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _buildTip(context, 'Voit luoda budjettipohjan kysymysten pohjalta tai luoda itse budjetin.'),
                    const SizedBox(height: 8),
                    _buildTip(context, 'Pyri arvioimaan menosi realistisesti, mieluummin hiukan ylä- kuin alakanttiin.'),
                    const SizedBox(height: 8),
                    _buildTip(context, 'Käytä hetki aikaa vastaamiseen, jotta saat tarkemman kuvan taloudestasi.'),
                    const SizedBox(height: 8),
                    _buildTip(context, 'Voit aina muokata budjettia myöhemmin, mikäli se on tarpeen.'),
                  ],
                ),
              ),
            ),
            const Spacer(),
            // Painikkeet viiveellä
            FutureBuilder(
              future: Future.delayed(const Duration(milliseconds: 2000)),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  // Käynnistetään painikkeiden fade-animaatio vain kerran, kun FutureBuilder on valmis
                  if (!_hasStartedButtonAnimation) {
                    _buttonFadeController.forward();
                    _hasStartedButtonAnimation = true;
                  }
                  return FadeTransition(
                    opacity: _buttonFadeAnimation!,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: widget.onProceed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey[800],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            'Siirry kysymyksiin',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        OutlinedButton(
                          onPressed: widget.onSkip,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.blueGrey[800]!),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            'Luo budjetti itse',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.blueGrey[800],
                                  fontSize: 11,
                                ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTip(BuildContext context, String tip) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.lightbulb_outline,
          size: 20,
          color: Colors.blueGrey[800],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            tip,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                ),
          ),
        ),
      ],
    );
  }
}