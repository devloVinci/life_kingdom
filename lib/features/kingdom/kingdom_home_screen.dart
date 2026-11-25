import 'package:flutter/material.dart';

import 'tile_world/land_journal.dart';
import 'tile_world/tile_world_view.dart';
import 'village/village_hud.dart';

/// Home: the pixel-art tile world that grows with real progress, with the
/// heads-up display on top and the next-land card above the bottom bar.
class KingdomHomeScreen extends StatelessWidget {
  const KingdomHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Stack(children: [
      const Positioned.fill(child: TileWorldView()),
      const Positioned(left: 0, right: 0, top: 0, child: VillageHud()),
      Positioned(
        left: 12,
        right: 12,
        bottom: bottom + 10,
        child: const NextLandCard(),
      ),
    ]);
  }
}
