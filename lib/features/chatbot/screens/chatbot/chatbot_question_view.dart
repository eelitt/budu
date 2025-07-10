import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:budu/core/app_router/app_router.dart';
import 'package:budu/features/chatbot/providers/chatbot_provider.dart';
import 'package:budu/features/chatbot/screens/chatbot/multiple_choice_buttons.dart';
import 'package:budu/features/chatbot/screens/chatbot/text_field_with_number_keyboard.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class ChatbotQuestionView extends StatefulWidget {
  final ChatbotProvider chatbotProvider;

  const ChatbotQuestionView({
    super.key,
    required this.chatbotProvider,
  });

  @override
  State<ChatbotQuestionView> createState() => _ChatbotQuestionViewState();
}

class _ChatbotQuestionViewState extends State<ChatbotQuestionView> with TickerProviderStateMixin {
  late AnimationController _bottomWidgetFadeController;
  late Animation<double> _bottomWidgetFadeAnimation;
  late Animation<Offset> _bottomWidgetSlideAnimation;
  final Map<int, AnimationController> _messageControllers = {};

  @override
  void initState() {
    super.initState();
    // Syöttökentän/monivalintapainikkeiden animaatio
    _bottomWidgetFadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _bottomWidgetFadeAnimation = CurvedAnimation(
      parent: _bottomWidgetFadeController,
      curve: Curves.easeIn,
    );
    _bottomWidgetSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _bottomWidgetFadeController,
      curve: Curves.easeOut,
    ));

    // Alustetaan animaatiokontrollerit viesteille
    _initializeControllers(widget.chatbotProvider.messages.length);

    // Käynnistetään syöttökentän ja ohituspainikkeen animaatio viiveellä
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _bottomWidgetFadeController.forward();
      }
    });
  }

  void _initializeControllers(int messageCount) {
    for (int i = 0; i < messageCount; i++) {
      if (!_messageControllers.containsKey(i)) {
        _messageControllers[i] = AnimationController(
          duration: const Duration(milliseconds: 500),
          vsync: this,
        )..forward();
      }
    }
  }

  @override
  void didUpdateWidget(ChatbotQuestionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Alustetaan animaatiokontrollerit uusille viesteille
    final oldLength = oldWidget.chatbotProvider.messages.length;
    final newLength = widget.chatbotProvider.messages.length;
    if (newLength > oldLength) {
      _initializeControllers(newLength);
    }

    // Resetoi ja viivytä syöttökentän/monivalintapainikkeiden animaatio aina, kun viestejä lisätään tai isMultipleChoice muuttuu
    if (newLength > oldLength || oldWidget.chatbotProvider.isMultipleChoice != widget.chatbotProvider.isMultipleChoice) {
      _bottomWidgetFadeController.reset();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _bottomWidgetFadeController.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _bottomWidgetFadeController.dispose();
    _messageControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  void _skipToManualBudget() {
    print('ChatbotQuestionView: Ohitetaan chatbot, navigoidaan budjetin luontisivulle');
    FirebaseCrashlytics.instance.log('ChatbotQuestionView: Ohitetaan chatbot, navigoidaan budjetin luontisivulle');
    Navigator.pushReplacementNamed(context, AppRouter.createBudgetRoute);
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
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true, // Uusin viesti alimpana
              itemCount: widget.chatbotProvider.messages.length,
              itemBuilder: (context, index) {
                final message = widget.chatbotProvider.messages[widget.chatbotProvider.messages.length - 1 - index];
                AnimationController? controller = _messageControllers[widget.chatbotProvider.messages.length - 1 - index];
                if (controller == null) {
                  controller = AnimationController(
                    duration: const Duration(milliseconds: 500),
                    vsync: this,
                  )..forward();
                  _messageControllers[widget.chatbotProvider.messages.length - 1 - index] = controller;
                }
                return FadeTransition(
                  opacity: CurvedAnimation(
                    parent: controller,
                    curve: Curves.easeIn,
                  ),
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.5),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: controller,
                      curve: Curves.easeOut,
                    )),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                      child: Align(
                        alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          decoration: BoxDecoration(
                            color: message.isUser ? Colors.blueGrey[800] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            message.text,
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                              color: message.isUser ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          FadeTransition(
            opacity: _bottomWidgetFadeAnimation,
            child: SlideTransition(
              position: _bottomWidgetSlideAnimation,
              child: Column(
                children: [
                  widget.chatbotProvider.isMultipleChoice
                      ? MultipleChoiceButtons(
                          chatbotProvider: widget.chatbotProvider,
                          onOptionSelected: (option) {
                            print('ChatbotQuestionView: Käyttäjä valitsi: $option');
                            widget.chatbotProvider.handleUserResponse(option, context);
                          },
                        )
                      : TextFieldWithNumberKeyboard(
                          key: ValueKey(widget.chatbotProvider.step),
                          onSubmitted: (value) {
                            if (value.isNotEmpty) {
                              print('ChatbotQuestionView: Käyttäjä vastasi: $value');
                              widget.chatbotProvider.handleUserResponse(value, context);
                            }
                          },
                        ),
                  const SizedBox(height: 8), // Väli syöttökentän ja ohituspainikkeen välillä
                  FadeTransition(
                    opacity: _bottomWidgetFadeAnimation,
                    child: SlideTransition(
                      position: _bottomWidgetSlideAnimation,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: OutlinedButton.icon(
                          onPressed: _skipToManualBudget,
                          icon: Icon(
                            Icons.arrow_forward,
                            size: 20,
                            color: Colors.blueGrey[800],
                          ),
                          label: Text(
                            "Ohita ja luo budjetti",
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              color: Colors.blueGrey[800],
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.blueGrey[800]!),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}