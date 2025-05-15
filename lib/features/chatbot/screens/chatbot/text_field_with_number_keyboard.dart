import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Tarvitaan inputFormatters-ominaisuutta varten
import 'package:google_fonts/google_fonts.dart';

class TextFieldWithNumberKeyboard extends StatefulWidget {
  final Function(String) onSubmitted;

  const TextFieldWithNumberKeyboard({
    super.key,
    required this.onSubmitted,
  });

  @override
  State<TextFieldWithNumberKeyboard> createState() => _TextFieldWithNumberKeyboardState();
}

class _TextFieldWithNumberKeyboardState extends State<TextFieldWithNumberKeyboard> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          hintText: 'Syötä summa...',
          hintStyle: GoogleFonts.montserrat(
            fontSize: 14,
            color: Colors.grey[500],
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[400]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.blueGrey[800]!, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        style: GoogleFonts.montserrat(
          fontSize: 14,
          color: Colors.black87,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9]')), // Sallitaan vain numerot
          LengthLimitingTextInputFormatter(6), // Rajoitetaan syöte 6 merkkiin (100 000 €)
        ],
        onSubmitted: (value) {
          widget.onSubmitted(value);
          _controller.clear();
        },
      ),
    );
  }
}