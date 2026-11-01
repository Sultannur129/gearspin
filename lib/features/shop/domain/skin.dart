import 'dart:ui' show Color;

const String kDefaultSkinId = 'default';

/// A projectile look. Purely visual: the engine never reads it, the painter
/// does (so physics stays identical for every skin).
class Skin {
  const Skin({
    required this.id,
    required this.name,
    required this.core,
    required this.glow,
    required this.trail,
    this.coinPrice,
    this.iapProductId,
    this.trailLength = 22,
  });

  final String id;
  final String name;
  final Color core;
  final Color glow;
  final Color trail;

  /// Coins needed to unlock. 0 = free (owned from the start), null = cannot
  /// be bought with coins.
  final int? coinPrice;

  /// Store product id when the skin is sold for real money.
  final String? iapProductId;

  /// Length of the comet tail in world units.
  final double trailLength;

  bool get isFree => coinPrice == 0;
  bool get isPremium => iapProductId != null;
}

const Skin kDefaultSkin = Skin(
  id: kDefaultSkinId,
  name: 'Classic',
  core: Color(0xFFFFFFFF),
  glow: Color(0xFFFFFFFF),
  trail: Color(0xFFFFFFFF),
  coinPrice: 0,
);

const List<Skin> kSkins = [
  kDefaultSkin,
  Skin(
    id: 'comet',
    name: 'Comet',
    core: Color(0xFFFFFFFF),
    glow: Color(0xFF4FD8FF),
    trail: Color(0xFF4FD8FF),
    coinPrice: 200,
  ),
  Skin(
    id: 'nebula',
    name: 'Nebula',
    core: Color(0xFFFFE6FF),
    glow: Color(0xFFE24DFF),
    trail: Color(0xFFE24DFF),
    coinPrice: 200,
    trailLength: 28,
  ),
  Skin(
    id: 'ion',
    name: 'Ion',
    core: Color(0xFFE6E2FF),
    glow: Color(0xFF7C6CFF),
    trail: Color(0xFF7C6CFF),
    coinPrice: 200,
  ),
  Skin(
    id: 'aurora',
    name: 'Aurora',
    core: Color(0xFFE0FFF8),
    glow: Color(0xFF2EE6C5),
    trail: Color(0xFF2EE6C5),
    coinPrice: 200,
    trailLength: 30,
  ),
  Skin(
    id: 'inferno',
    name: 'Inferno',
    core: Color(0xFFFFF3D6),
    glow: Color(0xFFFFA23A),
    trail: Color(0xFFFF6A1F),
    coinPrice: 200,
    trailLength: 32,
  ),
  Skin(
    id: 'sakura',
    name: 'Sakura',
    core: Color(0xFFFFEAF6),
    glow: Color(0xFFFF7AC8),
    trail: Color(0xFFFF7AC8),
    coinPrice: 200,
  ),
  Skin(
    id: 'golden_nova',
    name: 'Golden Nova',
    core: Color(0xFFFFFBE0),
    glow: Color(0xFFFFC83D),
    trail: Color(0xFFFFB300),
    iapProductId: 'skin_golden_nova',
    trailLength: 36,
  ),
];

/// Unknown ids (e.g. from a newer app version via cloud sync) fall back to
/// the default look instead of crashing.
Skin skinById(String id) =>
    kSkins.firstWhere((s) => s.id == id, orElse: () => kDefaultSkin);

bool isKnownSkin(String id) => kSkins.any((s) => s.id == id);
