// lib/data/cosmetics_data.dart
// Catalogue des cosmétiques de la boutique — illustrations alternatives
// pour personnages, jetons et terrains. Chaque item pointe vers un fichier
// à fournir séparément (même convention que les illustrations de base).

enum CosmeticCategory { character, token, terrain }

class CosmeticItem {
  final String id;          // identifiant unique du cosmétique
  final String name;        // nom affiché en boutique
  final CosmeticCategory category;
  final String targetId;    // id du personnage / du jeton / num du terrain visé
  final int cost;           // prix en or
  final String imagePath;   // chemin de l'illustration alternative
  const CosmeticItem({
    required this.id, required this.name, required this.category,
    required this.targetId, required this.cost, required this.imagePath,
  });

  /// Clé utilisée pour le stockage "quel cosmétique est équipé pour X" —
  /// ex: 'character:albane', 'token:remi', 'terrain:0'.
  String get slotKey => '${category.name}:$targetId';
}

/// Catalogue de départ — à enrichir librement en ajoutant des entrées ici
/// au fur et à mesure que de nouvelles illustrations sont prêtes. Chaque
/// `imagePath` doit correspondre à un fichier que tu fournis toi-même,
/// exactement comme pour les illustrations de personnages actuelles.
const List<CosmeticItem> kCosmeticsCatalog = [
  // ── Personnages ──────────────────────────────────────────────────────
  CosmeticItem(id: 'albane_gold', name: 'Albane — Tenue Dorée',
    category: CosmeticCategory.character, targetId: 'albane', cost: 150,
    imagePath: 'assets/images/characters_skins/albane_gold.png'),
  CosmeticItem(id: 'christine_winter', name: 'Christine — Édition Hiver',
    category: CosmeticCategory.character, targetId: 'christine', cost: 150,
    imagePath: 'assets/images/characters_skins/christine_winter.png'),
  CosmeticItem(id: 'agathe_royal', name: 'Agathe — Vampire Royale',
    category: CosmeticCategory.character, targetId: 'agathe', cost: 200,
    imagePath: 'assets/images/characters_skins/agathe_royal.png'),
  CosmeticItem(id: 'remi_master', name: 'Rémi — Maître Artisan',
    category: CosmeticCategory.character, targetId: 'remi', cost: 150,
    imagePath: 'assets/images/characters_skins/remi_master.png'),
  CosmeticItem(id: 'felipe_survivor', name: 'Felipe — Survivant',
    category: CosmeticCategory.character, targetId: 'felipe', cost: 150,
    imagePath: 'assets/images/characters_skins/felipe_survivor.png'),

  // ── Jetons ───────────────────────────────────────────────────────────
  CosmeticItem(id: 'albane_token_gold', name: 'Jeton Doré — Albane',
    category: CosmeticCategory.token, targetId: 'albane', cost: 80,
    imagePath: 'assets/images/tokens_skins/albane_gold.png'),
  CosmeticItem(id: 'remi_token_neon', name: 'Jeton Néon — Rémi',
    category: CosmeticCategory.token, targetId: 'remi', cost: 80,
    imagePath: 'assets/images/tokens_skins/remi_neon.png'),
  CosmeticItem(id: 'agathe_token_blood', name: 'Jeton Sang — Agathe',
    category: CosmeticCategory.token, targetId: 'agathe', cost: 80,
    imagePath: 'assets/images/tokens_skins/agathe_blood.png'),

  // ── Terrains (targetId = effect du terrain, même convention que
  // terrainImagePath() déjà utilisée dans le jeu : 'vision', 'lumiere',
  // 'tenebres', 'choice', 'damage9', 'steal') ──────────────────────────
  CosmeticItem(id: 'terrain_vision_grotte', name: 'Grotte',
    category: CosmeticCategory.terrain, targetId: 'vision', cost: 250,
    imagePath: 'assets/images/terrains_skins/grotte23.png'),
  CosmeticItem(id: 'terrain_lumiere_eglise', name: 'Chapelle',
    category: CosmeticCategory.terrain, targetId: 'lumiere', cost: 250,
    imagePath: 'assets/images/terrains_skins/chapelle6.png'),
  CosmeticItem(id: 'terrain_steal_armurerie', name: 'Armurerie',
    category: CosmeticCategory.terrain, targetId: 'steal', cost: 250,
    imagePath: 'assets/images/terrains_skins/armurerie10.png'),
     CosmeticItem(id: 'terrain_5_marche', name: 'Marché',
    category: CosmeticCategory.terrain, targetId: 'choice', cost: 250,
    imagePath: 'assets/images/terrains_skins/marche45.png'),
  CosmeticItem(id: 'terrain_tenebre_enfer', name: 'Enfer',
    category: CosmeticCategory.terrain, targetId: 'tenebre', cost: 250,
    imagePath: 'assets/images/terrains_skins/enfer8.png'),
  CosmeticItem(id: 'terrain_9_apothicaire', name: 'Apothicaire',
    category: CosmeticCategory.terrain, targetId: 'damage9', cost: 250,
    imagePath: 'assets/images/terrains_skins/apothicaire9.png'),
];

List<CosmeticItem> cosmeticsFor(CosmeticCategory cat, String targetId) =>
    kCosmeticsCatalog.where((c) => c.category == cat && c.targetId == targetId).toList();
