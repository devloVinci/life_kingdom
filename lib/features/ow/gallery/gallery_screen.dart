import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../game/atlas/sprite_atlas.dart';
import '../ow_style.dart';

/// Browse every imported atlas and its animations, to name directions and
/// pick frames for `catalog.dart`.
class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  String _id = Atlases.all.first;

  @override
  Widget build(BuildContext context) {
    final atlas = ref.watch(atlasProvider(_id));
    return Scaffold(
      backgroundColor: Ow.bg,
      appBar: AppBar(
        backgroundColor: Ow.panel,
        title: Text('معرض الأست', style: Ow.title(18)),
      ),
      body: Column(children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            children: [
              for (final id in Atlases.all)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ChoiceChip(
                    label: Text(id, style: Ow.body(11)),
                    selected: id == _id,
                    onSelected: (_) => setState(() => _id = id),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: atlas.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (a) {
              if (a == null) {
                return Center(
                    child: Text('هذا الأطلس غير مستورد', style: Ow.body(14)));
              }
              final anims = a.data.animations.keys.toList();
              return ListView.builder(
                itemCount: anims.length,
                itemBuilder: (_, i) {
                  final name = anims[i];
                  final frames = a.anim(name);
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(name,
                            textDirection: TextDirection.ltr,
                            style: Ow.body(12, color: Ow.gold)),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 84,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (var f = 0; f < frames.length; f++)
                                Container(
                                  width: 84,
                                  margin: const EdgeInsets.only(left: 4),
                                  color: Ow.panel,
                                  child: Stack(children: [
                                    Positioned.fill(
                                        child: FrameView(a, frames[f])),
                                    Positioned(
                                      left: 2,
                                      top: 0,
                                      child: Text('$f',
                                          style: Ow.body(10, color: Ow.muted)),
                                    ),
                                  ]),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

/// One atlas frame scaled to fit its box.
class FrameView extends StatelessWidget {
  const FrameView(this.atlas, this.frame, {super.key});
  final SpriteAtlas atlas;
  final String frame;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _FramePainter(atlas, frame));
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.a, this.frame);
  final SpriteAtlas a;
  final String frame;

  @override
  void paint(Canvas canvas, Size size) {
    final f = a.frame(frame);
    if (f == null) return;
    final s = (size.width / f.sourceSize.width)
        .clamp(0.0, size.height / f.sourceSize.height);
    final at = Offset(
        size.width / 2 + (f.pivot.dx - 0.5) * f.sourceSize.width * s,
        size.height / 2 + (f.pivot.dy - 0.5) * f.sourceSize.height * s);
    a.draw(canvas, frame, at, scale: s);
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.frame != frame || old.a != a;
}
