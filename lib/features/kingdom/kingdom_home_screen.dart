import 'package:flutter/material.dart';

import 'village/village_hud.dart';
import 'village/village_map.dart';

/// Home: the living village with the heads-up display on top.
class KingdomHomeScreen extends StatelessWidget {
  const KingdomHomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const Stack(children: [
        Positioned.fill(child: VillageMap()),
        Positioned(left: 0, right: 0, top: 0, child: VillageHud()),
      ]);
}
