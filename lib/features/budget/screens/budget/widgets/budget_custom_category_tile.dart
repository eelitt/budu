import 'package:flutter/material.dart';

class CustomExpansionTile extends StatefulWidget {
  final Widget title;
  final List<Widget> children;
  final ValueNotifier<bool> isExpanded;
  final void Function(bool) onExpansionChanged;

  const CustomExpansionTile({
    super.key,
    required this.title,
    required this.children,
    required this.isExpanded,
    required this.onExpansionChanged,
  });

  @override
  State<CustomExpansionTile> createState() => _CustomExpansionTileState();
}

class _CustomExpansionTileState extends State<CustomExpansionTile> {
  void _toggleExpanded() {
    widget.onExpansionChanged(!widget.isExpanded.value);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.isExpanded,
      builder: (context, isExpanded, child) {
        return Column(
          children: [
            GestureDetector(
              onTap: _toggleExpanded,
              behavior: HitTestBehavior.opaque,
              child: widget.title,
            ),
            AnimatedCrossFade(
              firstChild: Container(),
              secondChild: Column(
                children: widget.children,
              ),
              crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        );
      },
    );
  }
}