import 'package:flutter/material.dart';

class TeleportBackground extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool useSafeArea;

  const TeleportBackground({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    this.useSafeArea = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget content = Padding(padding: padding, child: child);
    if (useSafeArea) {
      content = SafeArea(child: content);
    }

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.surface,
                scheme.surface,
                scheme.surfaceContainerHighest,
              ],
            ),
          ),
        ),
        content,
      ],
    );
  }
}
