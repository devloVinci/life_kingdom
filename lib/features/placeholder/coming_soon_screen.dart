import 'package:flutter/material.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/game_background.dart';

class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return GameBackground(
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: AppText.heading(32)),
          const SizedBox(height: 8),
          Text('Coming soon', style: AppText.body(16, color: Colors.white)),
        ]),
      ),
    );
  }
}
