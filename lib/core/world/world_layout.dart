import 'dart:math' as math;
import 'dart:ui';

/// Static layout of the kingdom world, in world units (1 unit = 1 logical
/// pixel at zoom 1). Everything placeable lives here so the map widgets stay
/// generic: move a building or add a region by editing this file only.
class WorldLayout {
  WorldLayout._();

  static const size = Size(1100, 1500);
  static const plaza = Offset(550, 760);
  static const plazaRadius = 74.0;

  static const buildings = <String, BuildingSpot>{
    'keep': BuildingSpot('keep', "Keep", Offset(550, 640), Size(200, 210), Offset(100, 200), 1.15),
    'laboratory': BuildingSpot('laboratory', 'Laboratory', Offset(330, 575), Size(120, 170), Offset(60, 162)),
    'treasury': BuildingSpot('treasury', 'Treasury', Offset(785, 585), Size(150, 140), Offset(72, 132)),
    'builders_hut': BuildingSpot('builders_hut', "Builder's Hut", Offset(320, 820), Size(140, 130), Offset(66, 122)),
    'army_camp': BuildingSpot('army_camp', 'Army Camp', Offset(790, 840), Size(160, 120), Offset(80, 110)),
    'shop': BuildingSpot('shop', 'Shop', Offset(385, 1010), Size(150, 130), Offset(70, 122)),
    'magic_items': BuildingSpot('magic_items', 'Magic Items', Offset(720, 1020), Size(120, 150), Offset(60, 142)),
    'clan_castle': BuildingSpot('clan_castle', 'Clan Castle', Offset(550, 1165), Size(160, 150), Offset(78, 142)),
  };

  /// Regions that open up as the player levels up. The heartland (everything
  /// not covered by a region) is always open.
  static const regions = <WorldRegion>[
    WorldRegion('whisperwood', 'Whisperwood', 5, Rect.fromLTWH(0, 190, 175, 1150), Offset(88, 760)),
    WorldRegion('crystal_lake', 'Crystal Lake', 10, Rect.fromLTWH(925, 190, 175, 1150), Offset(1012, 760)),
    WorldRegion('highlands', 'The Highlands', 15, Rect.fromLTWH(0, 0, 1100, 330), Offset(550, 170)),
    WorldRegion('dragons_rest', "Dragon's Rest", 25, Rect.fromLTWH(0, 1300, 1100, 200), Offset(550, 1410)),
  ];

  /// Roads leaving the heartland toward each region.
  static const regionRoads = <String, List<Offset>>{
    'highlands': [Offset(550, 450), Offset(560, 330), Offset(540, 200)],
    'whisperwood': [Offset(250, 760), Offset(175, 750), Offset(90, 770)],
    'crystal_lake': [Offset(860, 760), Offset(925, 770), Offset(990, 750)],
    'dragons_rest': [Offset(550, 1180), Offset(560, 1300), Offset(545, 1400)],
  };

  /// Pond inside the heartland.
  static const pond = Rect.fromLTWH(150, 1110, 150, 82);

  /// The big lake in the Crystal Lake region.
  static const lake = Rect.fromLTWH(945, 380, 150, 560);

  /// Door point of a building (where paths end and the hero stops).
  static Offset door(String id) => buildings[id]!.anchor + const Offset(0, 14);

  /// Sampled road from the plaza edge to a building door.
  static List<Offset> roadTo(String id) {
    final d = door(id);
    final dir = d - plaza;
    final start = plaza + dir / dir.distance * (plazaRadius - 6);
    return curve(start, d, bend: id.length.isEven ? 18 : -18);
  }

  /// All roads (for drawing and for keeping trees off them).
  static List<List<Offset>> get roads => [
        for (final id in buildings.keys) roadTo(id),
        for (final r in regionRoads.values) _poly(r),
      ];

  /// Quadratic curve from [a] to [b] bent sideways by [bend], as points.
  static List<Offset> curve(Offset a, Offset b, {double bend = 0, int n = 16}) {
    final mid = (a + b) / 2;
    final d = b - a;
    final len = d.distance == 0 ? 1.0 : d.distance;
    final c = mid + Offset(-d.dy / len, d.dx / len) * bend;
    final out = <Offset>[];
    for (var i = 0; i <= n; i++) {
      final t = i / n;
      final u = 1 - t;
      out.add(a * (u * u) + c * (2 * u * t) + b * (t * t));
    }
    return out;
  }

  static List<Offset> _poly(List<Offset> pts) {
    final out = <Offset>[];
    for (var i = 0; i < pts.length - 1; i++) {
      final seg = curve(pts[i], pts[i + 1], bend: i.isEven ? 12 : -12, n: 10);
      out.addAll(i == 0 ? seg : seg.skip(1));
    }
    return out;
  }

  /// Trees, rocks and flowers, scattered once and deterministically.
  static final List<Decor> decor = _scatter();

  static List<Decor> _scatter() {
    final rnd = math.Random(7);
    final roads = WorldLayout.roads;
    final out = <Decor>[];

    bool blocked(Offset p, double r) {
      if ((p - plaza).distance < plazaRadius + r + 26) return true;
      for (final b in buildings.values) {
        final box = Rect.fromLTRB(
            b.anchor.dx - b.size.width * 0.55 * b.scale - r,
            b.anchor.dy - b.size.height * 0.75 * b.scale - r,
            b.anchor.dx + b.size.width * 0.55 * b.scale + r,
            b.anchor.dy + 34 + r);
        if (box.contains(p)) return true;
      }
      for (final road in roads) {
        for (final q in road) {
          if ((p - q).distance < 26 + r) return true;
        }
      }
      if (pond.inflate(18 + r).contains(p)) return true;
      if (lake.inflate(14 + r).contains(p)) return true;
      if (p.dy > 40 && p.dy < 250 && p.dx > 60 && p.dx < 1040) {
        return true; // mountain range
      }
      for (final d in out) {
        if ((d.pos - p).distance < (d.radius + r) * 0.8) return true;
      }
      return false;
    }

    // Dense forest in Whisperwood, lighter woods elsewhere.
    void place(DecorKind kind, int tries, Rect area, double rMin, double rMax) {
      for (var i = 0; i < tries; i++) {
        final p = Offset(area.left + rnd.nextDouble() * area.width,
            area.top + rnd.nextDouble() * area.height);
        final r = rMin + rnd.nextDouble() * (rMax - rMin);
        if (blocked(p, r)) continue;
        out.add(Decor(kind, p, r, rnd.nextInt(1 << 20)));
      }
    }

    place(DecorKind.tree, 260, const Rect.fromLTWH(0, 260, 175, 1080), 20, 30);
    place(DecorKind.tree, 90, const Rect.fromLTWH(175, 330, 750, 960), 18, 26);
    place(DecorKind.tree, 70, const Rect.fromLTWH(925, 260, 175, 1080), 18, 26);
    place(DecorKind.tree, 60, const Rect.fromLTWH(0, 1290, 1100, 210), 18, 28);
    place(DecorKind.tree, 30, const Rect.fromLTWH(0, 250, 1100, 90), 18, 24);
    place(DecorKind.rock, 50, const Rect.fromLTWH(60, 300, 980, 1150), 6, 12);
    place(DecorKind.bush, 70, const Rect.fromLTWH(160, 330, 780, 980), 8, 13);
    out.sort((a, b) => a.pos.dy.compareTo(b.pos.dy));
    return out;
  }

  /// Flower patches (flat, painted with the ground).
  static final List<Offset> flowers = () {
    final rnd = math.Random(11);
    return [
      for (var i = 0; i < 220; i++)
        Offset(60 + rnd.nextDouble() * 980, 300 + rnd.nextDouble() * 1150),
    ];
  }();

  /// Spots the dragon likes to visit, per region ('' = heartland).
  static const dragonSpots = <(String, Offset)>[
    ('', Offset(470, 900)),
    ('', Offset(660, 700)),
    ('', Offset(640, 940)),
    ('', Offset(450, 690)),
    ('', Offset(250, 690)),
    ('', Offset(860, 990)),
    ('', Offset(560, 860)),
    ('whisperwood', Offset(110, 600)),
    ('crystal_lake', Offset(1000, 1020)),
    ('highlands', Offset(400, 300)),
    ('dragons_rest', Offset(700, 1380)),
  ];
}

class BuildingSpot {
  const BuildingSpot(this.id, this.name, this.anchor, this.size, this.pivot,
      [this.scale = 1]);

  final String id;
  final String name;

  /// World position of the building's ground point (bottom centre).
  final Offset anchor;

  /// Art size and the ground point inside the art.
  final Size size;
  final Offset pivot;
  final double scale;
}

class WorldRegion {
  const WorldRegion(this.id, this.name, this.unlockLevel, this.bounds, this.label);

  final String id;
  final String name;
  final int unlockLevel;
  final Rect bounds;

  /// Where the lock sign stands.
  final Offset label;
}

enum DecorKind { tree, rock, bush }

class Decor {
  const Decor(this.kind, this.pos, this.radius, this.seed);
  final DecorKind kind;

  /// Ground point (bottom centre).
  final Offset pos;
  final double radius;
  final int seed;
}
