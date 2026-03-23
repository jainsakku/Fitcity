import 'dart:ui';

import 'package:flutter/material.dart';

import 'colors.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: FitCityColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FitCityColors.border),
          ),
          child: child,
        ),
      ),
    );
  }
}
