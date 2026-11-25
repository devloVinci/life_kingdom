/// A minimal reader for maps made in the free Tiled editor (.tmx + .tsx).
///
/// Supports what the EPIC RPG World pack uses: orthogonal maps, one external
/// tileset, and tile layers stored as CSV. Flip flags in gids are cleared.
class TileMapData {
  const TileMapData({
    required this.width,
    required this.height,
    required this.tileWidth,
    required this.tileHeight,
    required this.columns,
    required this.firstGid,
    required this.imageSource,
    required this.layers,
  });

  /// Map size in tiles.
  final int width;
  final int height;

  /// Tile size in pixels.
  final int tileWidth;
  final int tileHeight;

  /// Number of tile columns in the tileset image.
  final int columns;
  final int firstGid;

  /// Tileset image file name, relative to the .tsx file.
  final String imageSource;

  /// Tile layers bottom to top. Each has width*height gids (0 = empty).
  final List<TileLayer> layers;

  double get pixelWidth => (width * tileWidth).toDouble();
  double get pixelHeight => (height * tileHeight).toDouble();

  /// Gid flip bits used by Tiled.
  static const int _flipMask = 0x1FFFFFFF;

  static TileMapData parse(String tmx, String tsx) {
    final map = _attrs(RegExp(r'<map\b[^>]*>').firstMatch(tmx)!.group(0)!);
    if ((map['orientation'] ?? 'orthogonal') != 'orthogonal') {
      throw const FormatException('Only orthogonal Tiled maps are supported');
    }
    final tsRef =
        _attrs(RegExp(r'<tileset\b[^>]*>').firstMatch(tmx)!.group(0)!);
    final tileset =
        _attrs(RegExp(r'<tileset\b[^>]*>').firstMatch(tsx)!.group(0)!);
    final image = _attrs(RegExp(r'<image\b[^>]*>').firstMatch(tsx)!.group(0)!);

    final w = int.parse(map['width']!);
    final h = int.parse(map['height']!);
    final layers = <TileLayer>[];
    final layerRe = RegExp(
        r'<layer\b([^>]*)>\s*<data encoding="csv">(.*?)</data>',
        dotAll: true);
    for (final m in layerRe.allMatches(tmx)) {
      final a = _attrs('<layer ${m.group(1)}>');
      final gids = m
          .group(2)!
          .split(',')
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty)
          .map((v) => int.parse(v) & _flipMask)
          .toList(growable: false);
      if (gids.length != w * h) {
        throw FormatException('Layer ${a['name']} has ${gids.length} tiles');
      }
      layers.add(TileLayer(
        name: a['name'] ?? 'layer',
        visible: a['visible'] != '0',
        gids: gids,
      ));
    }

    return TileMapData(
      width: w,
      height: h,
      tileWidth: int.parse(map['tilewidth']!),
      tileHeight: int.parse(map['tileheight']!),
      columns: int.parse(tileset['columns']!),
      firstGid: int.parse(tsRef['firstgid'] ?? '1'),
      imageSource: image['source']!,
      layers: layers,
    );
  }

  static Map<String, String> _attrs(String tag) => {
        for (final m in RegExp(r'([\w-]+)="([^"]*)"').allMatches(tag))
          m.group(1)!: m.group(2)!,
      };
}

class TileLayer {
  const TileLayer({required this.name, required this.visible, required this.gids});

  final String name;
  final bool visible;
  final List<int> gids;
}
