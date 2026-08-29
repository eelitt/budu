import 'package:budu/features/budget/domain/save_decisions.dart';
import 'package:flutter/material.dart';

class IncomeSection extends StatefulWidget {
  final TextEditingController incomeController;

  const IncomeSection({
    super.key,
    required this.incomeController,
  });

  @override
  State<IncomeSection> createState() => _IncomeSectionState();
}

class _IncomeSectionState extends State<IncomeSection> {
  late FocusNode _focusNode;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _validateAndFormat(widget.incomeController);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _validateAndFormat(TextEditingController controller) {
    final error = validateIncomeText(
      controller.text.isEmpty ? null : controller.text,
    );
    setState(() {
      _errorText = error;
    });
    if (error == null) {
      _formatAmount(controller);
    }
  }

  void _formatAmount(TextEditingController controller) {
    final value = controller.text;
    if (value.isEmpty) {
      controller.text = '0.00';
    } else {
      final parsed = double.tryParse(value);
      if (parsed != null) {
        final roundedValue = (parsed * 100).roundToDouble() / 100;
        controller.text = roundedValue.toStringAsFixed(2);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tulot',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8.0),
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
          child: TextField(
            controller: widget.incomeController,
            focusNode: _focusNode,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Tulot (€)',
              border: const OutlineInputBorder(),
              errorText: _errorText,
            ),
            onChanged: (value) {
              setState(() {
                _errorText = validateIncomeText(
                  value.isEmpty ? null : value,
                );
              });
            },
            onEditingComplete: () {
              _validateAndFormat(widget.incomeController);
              FocusScope.of(context).unfocus();
            },
          ),
        ),
      ],
    );
  }
}
