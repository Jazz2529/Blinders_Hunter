// lib/data/cosmetics_data.dart
// Catalogue des cosmétiques de la boutique — illustrations alternatives
// pour personnages, jetons et terrains. Chaque item pointe vers un fichier
// à fournir séparément (même convention que les illustrations de base).

enum CosmeticCategory { character, token, terrain }

class CosmeticItem {
  final String id;          // identifiant unique du cosmétique
  final String name;        // nom affiché en boutique (et dans le sélecteur pour les jetons)
  final CosmeticCategory category;
  final String targetId;    // id du personnage visé (character) / num du terrain (terrain)
                             // — ignoré pour les jetons, qui sont des choix autonomes
  final int cost;           // prix en or
  final String imagePath;   // chemin de l'illustration alternative
  final String fallbackEmoji; // utilisé uniquement pour les jetons (repli si l'image manque)
  const CosmeticItem({
    required this.id, required this.name, required this.category,
    this.targetId = '', required this.cost, required this.imagePath,
    this.fallbackEmoji = '⚪',
  });

  /// Clé utilisée pour le stockage "quel cosmétique est équipé pour X" —
  /// ex: 'character:albane', 'terrain:vision'. Non utilisée pour les
  /// jetons (qui n'ont pas de "cible" à remplacer, voir plus bas).
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

  // ── Jetons — ce sont des jetons AUTONOMES, ajoutés à la liste des choix
  // disponibles dans le sélecteur (pas liés à un personnage précis, donc
  // pas de targetId) ────────────────────────────────────────────────────
  CosmeticItem(id: 'token_Loot', name: 'Loot',
    category: CosmeticCategory.token, cost: 80, fallbackEmoji: '🟡',
    imagePath: 'assets/images/tokens/loot.png'),
  CosmeticItem(id: 'token_cypher', name: 'Cypher',
    category: CosmeticCategory.token, cost: 80, fallbackEmoji: '🟢',
    imagePath: 'assets/images/tokens/cypher.png'),
  CosmeticItem(id: 'token_Manabu', name: 'Manabu',
    category: CosmeticCategory.token, cost: 80, fallbackEmoji: '🔴',
    imagePath: 'assets/images/tokens/manabu.png'),
    CosmeticItem(id: 'token_toph', name: 'Toph',
    category: CosmeticCategory.token, cost: 60, fallbackEmoji: '🦀',
    imagePath: 'assets/images/tokens/jeton19.png'),
  CosmeticItem(id: 'token_bingbong', name: 'Bingbong',
    category: CosmeticCategory.token, cost: 80, fallbackEmoji: '⚪',
    imagePath: 'assets/images/tokens/jeton17.png'),
  CosmeticItem(id: 'token_conan', name: 'Conan',
    category: CosmeticCategory.token, cost: 80, fallbackEmoji: '🔍',
    imagePath: 'assets/images/tokens/jeton18.png'),
  CosmeticItem(id: 'token_flott', name: 'Flott',
    category: CosmeticCategory.token, cost: 80, fallbackEmoji: '🏄',
    imagePath: 'assets/images/tokens/jeton20.png'),

  // ── Terrains (targetId = effect du terrain, même convention que
  // terrainImagePath() déjà utilisée dans le jeu : 'vision', 'lumiere',
  // 'tenebres', 'choice', 'damage9', 'steal') ──────────────────────────
  CosmeticItem(id: 'terrain_vision_grotte', name: 'Grotte',
    category: CosmeticCategory.terrain, targetId: 'vision', cost: 250,
    imagePath: 'assets/images/terrains/grotte23.png'),
  CosmeticItem(id: 'terrain_lumiere_eglise', name: 'Chapelle',
    category: CosmeticCategory.terrain, targetId: 'lumiere', cost: 250,
    imagePath: 'assets/images/terrains/chapelle6.png'),
  CosmeticItem(id: 'terrain_steal_armurerie', name: 'Armurerie',
    category: CosmeticCategory.terrain, targetId: 'steal', cost: 250,
    imagePath: 'assets/images/terrains/armurerie10.png'),
     CosmeticItem(id: 'terrain_5_marche', name: 'Marché',
    category: CosmeticCategory.terrain, targetId: 'choice', cost: 250,
    imagePath: 'assets/images/terrains/marche45.png'),
  CosmeticItem(id: 'terrain_tenebre_enfer', name: 'Enfer',
    category: CosmeticCategory.terrain, targetId: 'tenebre', cost: 250,
    imagePath: 'assets/images/terrains/enfer8.png'),
  CosmeticItem(id: 'terrain_9_apothicaire', name: 'Apothicaire',
    category: CosmeticCategory.terrain, targetId: 'damage9', cost: 250,
    imagePath: 'assets/images/terrains/apothicaire9.png'),
];

List<CosmeticItem> cosmeticsFor(CosmeticCategory cat, String targetId) =>
    kCosmeticsCatalog.where((c) => c.category == cat && c.targetId == targetId).toList();
