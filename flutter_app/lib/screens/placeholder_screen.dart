import 'package:flutter/material.dart';

import '../theme/glass_card.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: GlassCard(
          child: Text('$title screen scaffolded for Phase 1'),
        ),
      ),
    );
  }
}
