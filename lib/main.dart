import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/kingdom/kingdom_home_screen.dart';

void main() => runApp(const LifeKingdomApp());

class LifeKingdomApp extends StatelessWidget {
  const LifeKingdomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Life Kingdom',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const KingdomHomeScreen(),
    );
  }
}
