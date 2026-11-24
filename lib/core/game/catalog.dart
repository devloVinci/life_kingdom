enum ItemType { character, title, background }

enum ItemRarity { common, rare, epic, legendary }

class ShopItem {
  const ShopItem({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.rarity,
    this.goldPrice,
    this.gemPrice,
    this.gradient,
  });

  final String id;
  final ItemType type;
  final String name;
  final String description;
  final ItemRarity rarity;

  /// Null price means "not available in that currency".
  final int? goldPrice;
  final int? gemPrice;

  /// Background items: [top, bottom] ARGB colors.
  final List<int>? gradient;

  bool get forSale => goldPrice != null || gemPrice != null;

  /// Equip slot name stored in GameState.equipped.
  String get slot => type.name;
}

class BuildingDef {
  const BuildingDef(this.id, this.name, this.description, this.effectPerLevel);

  final String id;
  final String name;
  final String description;

  /// Short effect text, e.g. "+2% gold per level".
  final String effectPerLevel;
}

class ChestDef {
  const ChestDef({
    required this.goldMin,
    required this.goldMax,
    required this.gemsMin,
    required this.gemsMax,
    required this.drops,
  });

  final int goldMin, goldMax, gemsMin, gemsMax;

  /// Character drop chances in percent, checked in order (best first).
  final List<(ItemRarity, int)> drops;
}

class Catalog {
  Catalog._();

  static const items = <ShopItem>[
    // Characters (Common 200 gold, Rare 600, Epic 1500 gold or 30 gems,
    // Legendary 150 gems).
    ShopItem(id: 'char_raider', type: ItemType.character, name: 'Raider', rarity: ItemRarity.common, description: 'A fearless barbarian with a golden mane and a big sword.'),
    ShopItem(id: 'char_archer', type: ItemType.character, name: 'Archer', rarity: ItemRarity.common, goldPrice: 200, description: 'A quick hooded markswoman who never misses a goal.'),
    ShopItem(id: 'char_gremlin', type: ItemType.character, name: 'Gremlin', rarity: ItemRarity.common, goldPrice: 200, description: 'A mischievous green troublemaker with pointy ears.'),
    ShopItem(id: 'char_brute', type: ItemType.character, name: 'Brute', rarity: ItemRarity.rare, goldPrice: 600, description: 'A giant with a big head and bigger muscles.'),
    ShopItem(id: 'char_sorcerer', type: ItemType.character, name: 'Sorcerer', rarity: ItemRarity.rare, goldPrice: 600, description: 'A bearded mage with sparks dancing in his hands.'),
    ShopItem(id: 'char_boar_rider', type: ItemType.character, name: 'Boar Rider', rarity: ItemRarity.rare, goldPrice: 600, description: 'Charges into every day on a hammer-wielding boar.'),
    ShopItem(id: 'char_iron_colossus', type: ItemType.character, name: 'Iron Colossus', rarity: ItemRarity.epic, goldPrice: 1500, gemPrice: 30, description: 'A towering armored machine with glowing eyes.'),
    ShopItem(id: 'char_crimson_maiden', type: ItemType.character, name: 'Crimson Maiden', rarity: ItemRarity.epic, goldPrice: 1500, gemPrice: 30, description: 'A red-haired warrior swinging a mighty double axe.'),
    ShopItem(id: 'char_seraph', type: ItemType.character, name: 'Seraph', rarity: ItemRarity.epic, goldPrice: 1500, gemPrice: 30, description: 'A winged healer in white and gold.'),
    ShopItem(id: 'char_drake', type: ItemType.character, name: 'Drake', rarity: ItemRarity.epic, goldPrice: 1500, gemPrice: 30, description: 'A small dragon with big wings and bigger ambitions.'),
    ShopItem(id: 'char_warlord', type: ItemType.character, name: 'Warlord', rarity: ItemRarity.legendary, gemPrice: 150, description: 'The king of the battlefield.'),
    ShopItem(id: 'char_huntress_queen', type: ItemType.character, name: 'Huntress Queen', rarity: ItemRarity.legendary, gemPrice: 150, description: 'A royal archer who rules the shadows.'),
    ShopItem(id: 'char_oracle', type: ItemType.character, name: 'Oracle', rarity: ItemRarity.legendary, gemPrice: 150, description: 'A wise guardian who sees the road ahead.'),
    ShopItem(id: 'char_lancer_champion', type: ItemType.character, name: 'Lancer Champion', rarity: ItemRarity.legendary, gemPrice: 150, description: 'A champion with a lance and an unbreakable will.'),
    // The Builder is a companion, not for sale.
    ShopItem(id: 'char_builder', type: ItemType.character, name: 'Builder', rarity: ItemRarity.rare, description: 'Your loyal Builder. He hammers whenever you do real work.'),

    // Titles
    ShopItem(id: 'title_early_bird', type: ItemType.title, name: 'Early Bird', rarity: ItemRarity.common, goldPrice: 150, description: 'For those who start the day first.'),
    ShopItem(id: 'title_focused', type: ItemType.title, name: 'Focused', rarity: ItemRarity.rare, goldPrice: 500, description: 'Nothing distracts you.'),
    ShopItem(id: 'title_unstoppable', type: ItemType.title, name: 'Unstoppable', rarity: ItemRarity.epic, goldPrice: 1200, gemPrice: 25, description: 'Momentum is your middle name.'),
    ShopItem(id: 'title_rising_star', type: ItemType.title, name: 'Rising Star', rarity: ItemRarity.rare, description: 'Awarded for reaching rank C.'),
    ShopItem(id: 'title_steadfast', type: ItemType.title, name: 'Steadfast', rarity: ItemRarity.epic, description: 'Awarded for a 30-day streak.'),
    ShopItem(id: 'title_unbreakable', type: ItemType.title, name: 'Unbreakable', rarity: ItemRarity.legendary, description: 'Awarded for a 100-day streak.'),
    ShopItem(id: 'title_national', type: ItemType.title, name: 'National Level', rarity: ItemRarity.legendary, description: 'Awarded for reaching National Level.'),

    // Backgrounds ([top, bottom] ARGB)
    ShopItem(id: 'bg_meadow', type: ItemType.background, name: 'Meadow Sky', rarity: ItemRarity.common, goldPrice: 100, gradient: [0xFF5BC0F8, 0xFFB8E8FF], description: 'Bright morning over the kingdom.'),
    ShopItem(id: 'bg_sunset', type: ItemType.background, name: 'Sunset', rarity: ItemRarity.rare, goldPrice: 400, gradient: [0xFFFF8A4C, 0xFFFFD58A], description: 'Golden hour.'),
    ShopItem(id: 'bg_night', type: ItemType.background, name: 'Starry Night', rarity: ItemRarity.epic, goldPrice: 900, gemPrice: 20, gradient: [0xFF12306A, 0xFF4B63C7], description: 'A calm night sky.'),
    ShopItem(id: 'bg_royal', type: ItemType.background, name: 'Royal Purple', rarity: ItemRarity.legendary, gemPrice: 80, gradient: [0xFF6B2FB3, 0xFFE0A8FF], description: 'Fit for a king.'),
  ];

  static final Map<String, ShopItem> byId = {for (final i in items) i.id: i};

  static const buildings = <BuildingDef>[
    BuildingDef('keep', 'Keep', 'The heart of your kingdom. Unlocks higher levels for every building.', 'Raises the building level cap'),
    BuildingDef('laboratory', 'Laboratory', 'Where magic items are researched.', 'Unlocks magic items'),
    BuildingDef('army_camp', 'Army Camp', 'Your companions gather here.', 'More active companions'),
    BuildingDef('builders_hut', "Builder's Hut", 'Home of your Builder. Higher levels allow parallel upgrades.', 'Parallel upgrades at level 5 and 10'),
    BuildingDef('clan_castle', 'Clan Castle', 'A place for your favourite hero.', 'Hero slot'),
    BuildingDef('treasury', 'Treasury', 'Stores and grows your gold.', '+2% gold per level above 1'),
    BuildingDef('shop', 'Shop', 'Better stock as it levels up.', 'Unlocks rarer stock'),
    BuildingDef('magic_items', 'Magic Items', 'Consumables that help your habits.', 'Unlocks consumables'),
  ];

  static final Map<String, BuildingDef> buildingById = {
    for (final b in buildings) b.id: b
  };

  static const chests = <String, ChestDef>{
    'wooden': ChestDef(goldMin: 50, goldMax: 100, gemsMin: 0, gemsMax: 1, drops: [(ItemRarity.common, 5)]),
    'silver': ChestDef(goldMin: 150, goldMax: 300, gemsMin: 1, gemsMax: 3, drops: [(ItemRarity.rare, 10), (ItemRarity.common, 25)]),
    'golden': ChestDef(goldMin: 400, goldMax: 800, gemsMin: 3, gemsMax: 8, drops: [(ItemRarity.epic, 15), (ItemRarity.rare, 30)]),
    'legendary': ChestDef(goldMin: 1000, goldMax: 2000, gemsMin: 10, gemsMax: 25, drops: [(ItemRarity.legendary, 25), (ItemRarity.epic, 40)]),
  };
}
