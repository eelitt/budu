import 'package:flutter/material.dart';

/// Shared white card chrome for Summary expandable sections.
class SummarySectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SummarySectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(6),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      padding: padding,
      child: child,
    );
  }
}
