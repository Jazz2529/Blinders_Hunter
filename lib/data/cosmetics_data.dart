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
 
  CosmeticItem(id: 'agathe-animal', name: 'Agathe - Blomburrow',
    category: CosmeticCategory.character, targetId: 'agathe', cost: 150,
    imagePath: 'assets/images/characters/agathe-animal.png'),

  CosmeticItem(id: 'albane-animal', name: 'Albane - Blomburrow',
    category: CosmeticCategory.character, targetId: 'albane', cost: 150,
    imagePath: 'assets/images/characters/albane-animal.png'),

  CosmeticItem(id: 'amelia-animal', name: 'Amelia - Blomburrow',
    category: CosmeticCategory.character, targetId: 'amelia', cost: 150,
    imagePath: 'assets/images/characters/amelia-animal.png'), 

  CosmeticItem(id: 'art_cade-enf', name: 'Artcade - Baby',
    category: CosmeticCategory.character, targetId: 'art_cade', cost: 150,
    imagePath: 'assets/images/characters/art-enf.png'),

  CosmeticItem(id: 'augustin-enf', name: 'Augustin - Baby',
    category: CosmeticCategory.character, targetId: 'augustin', cost: 150,
    imagePath: 'assets/images/characters/augustin-enf.png'),  

  CosmeticItem(id: 'baleine-tarot', name: 'Baleine - XVII.The Star',
    category: CosmeticCategory.character, targetId: 'baleine', cost: 150,
    imagePath: 'assets/images/characters/baleine-tarot.png'), 

  CosmeticItem(id: 'baptiste-enf', name: 'Baptiste - Baby',
    category: CosmeticCategory.character, targetId: 'baptiste', cost: 150,
    imagePath: 'assets/images/characters/baptiste-enf.png'), 

  CosmeticItem(id: 'beeble', name: 'Beeble',
    category: CosmeticCategory.character, targetId: 'bibble', cost: 150,
    imagePath: 'assets/images/characters/beeble.png'),

  CosmeticItem(id: 'bob-sh', name: 'Bob - Theatre',
    category: CosmeticCategory.character, targetId: 'bob', cost: 150,
    imagePath: 'assets/images/characters/bob-sh.png'), 

  CosmeticItem(id: 'cambou-enf', name: 'Cambou - Baby',
    category: CosmeticCategory.character, targetId: 'cambou', cost: 150,
    imagePath: 'assets/images/characters/cambou-enf.png'),

  CosmeticItem(id: 'carapatte-sh', name: 'Carapatte - Theatre',
    category: CosmeticCategory.character, targetId: 'carapatte', cost: 150,
    imagePath: 'assets/images/characters/carapatte-sh.png'),  

  CosmeticItem(id: 'carla-sh', name: 'Carla - Theatre',
    category: CosmeticCategory.character, targetId: 'carla', cost: 150,
    imagePath: 'assets/images/characters/carla-sh.png'),

  CosmeticItem(id: 'christine-sh', name: 'Christine - Theatre',
    category: CosmeticCategory.character, targetId: 'christine', cost: 150,
    imagePath: 'assets/images/characters/christine-sh.png'),

  CosmeticItem(id: 'clemence-tarot', name: 'Clemence - II.The High Priestess',
    category: CosmeticCategory.character, targetId: 'carla', cost: 150,
    imagePath: 'assets/images/characters/clemence-sh.png'),

  CosmeticItem(id: 'damien-sh', name: 'Damien - XIV.Temperance',
    category: CosmeticCategory.character, targetId: 'damien', cost: 150,
    imagePath: 'assets/images/characters/damien-sh.png'), 

  CosmeticItem(id: 'elaia-enf', name: 'Elaia - Baby',
    category: CosmeticCategory.character, targetId: 'elaia', cost: 150,
    imagePath: 'assets/images/characters/elaia-enf.png'),

  CosmeticItem(id: 'elise-tarot', name: 'Elise - III.The Empress',
    category: CosmeticCategory.character, targetId: 'elise', cost: 150,
    imagePath: 'assets/images/characters/elise-tarot.png'),  

  CosmeticItem(id: 'emilien-animal', name: 'Emilien - Baby',
    category: CosmeticCategory.character, targetId: 'emilien', cost: 150,
    imagePath: 'assets/images/characters/emilien-animal.png'), 

  CosmeticItem(id: 'fanny-sh', name: 'Fanny - Theatre',
    category: CosmeticCategory.character, targetId: 'fanny', cost: 150,
    imagePath: 'assets/images/characters/fanny-sh.png'),
  
  CosmeticItem(id: 'felipe-tarot', name: 'Felipe - XII.The Hanged Man',
    category: CosmeticCategory.character, targetId: 'felipe', cost: 150,
    imagePath: 'assets/images/characters/felipe-tarot.png'), 

  CosmeticItem(id: 'fifi-sh', name: 'Fifi - Theatre',
    category: CosmeticCategory.character, targetId: 'fifi', cost: 150,
    imagePath: 'assets/images/characters/fifi-sh.png'),

  CosmeticItem(id: 'fijacked-enf', name: 'Fijacked - Baby',
    category: CosmeticCategory.character, targetId: 'fijacked', cost: 150,
    imagePath: 'assets/images/characters/fijacked-enf.png'), 

  CosmeticItem(id: 'gege-tarot', name: 'Gege - XVIII.The Moon',
    category: CosmeticCategory.character, targetId: 'gege_le_fantome', cost: 150,
    imagePath: 'assets/images/characters/gege-tarot.png'),   
    
  CosmeticItem(id: 'hailey-sh', name: 'Hailey - Theatre',
    category: CosmeticCategory.character, targetId: 'hailey', cost: 150,
    imagePath: 'assets/images/characters/hailey-sh.png'),   

  CosmeticItem(id: 'hong-animal', name: 'Hong Yi - Baby',
    category: CosmeticCategory.character, targetId: 'hong_yi', cost: 150,
    imagePath: 'assets/images/characters/hong-animal.png'),

  CosmeticItem(id: 'ines-enf', name: 'Ines - Baby',
    category: CosmeticCategory.character, targetId: 'ines', cost: 150,
    imagePath: 'assets/images/characters/ines-enf.png'),

  CosmeticItem(id: 'jason-tarot', name: 'Jason - 0.The Fool',
    category: CosmeticCategory.character, targetId: 'jason', cost: 150,
    imagePath: 'assets/images/characters/jason-tarot.png'), 

  CosmeticItem(id: 'jeanne-animal', name: 'Jeanne - Blomburrow',
    category: CosmeticCategory.character, targetId: 'jeanne', cost: 150,
    imagePath: 'assets/images/characters/jeanne-animal.png'), 

  CosmeticItem(id: 'julien-tarot', name: 'Julien - IV.The Emperor',
    category: CosmeticCategory.character, targetId: 'julien', cost: 150,
    imagePath: 'assets/images/characters/julien-tarot.png'),  

  CosmeticItem(id: 'leo-tarot', name: 'Léo - XIII.Death',
    category: CosmeticCategory.character, targetId: 'leo', cost: 150,
    imagePath: 'assets/images/characters/leo-tarot.png'), 

  CosmeticItem(id: 'louise-animal', name: 'Louise - Blomburrow',
    category: CosmeticCategory.character, targetId: 'louise', cost: 150,
    imagePath: 'assets/images/characters/louise-animal.png'),

  CosmeticItem(id: 'louna-sh', name: 'Louna - Theatre',
    category: CosmeticCategory.character, targetId: 'louna', cost: 150,
    imagePath: 'assets/images/characters/louna-sh.png'),  

  CosmeticItem(id: 'luc-tarot', name: 'Luc - XIX.The Sun',
    category: CosmeticCategory.character, targetId: 'luc', cost: 150,
    imagePath: 'assets/images/characters/luc-tarot.png'),  

  CosmeticItem(id: 'mango-animal', name: 'Mango Loco - Blomburrow',
    category: CosmeticCategory.character, targetId: 'mango', cost: 150,
    imagePath: 'assets/images/characters/mango-animal.png'),

  CosmeticItem(id: 'marin-sh', name: 'Marin - Theatre',
    category: CosmeticCategory.character, targetId: 'marin', cost: 150,
    imagePath: 'assets/images/characters/marin-sh.png'), 

  CosmeticItem(id: 'marion-sh', name: 'Marion - Theatre',
    category: CosmeticCategory.character, targetId: 'Marion', cost: 150,
    imagePath: 'assets/images/characters/marion-sh.png'),  

  CosmeticItem(id: 'mathieu-animal', name: 'Mathieu - Baby',
    category: CosmeticCategory.character, targetId: 'mathieu', cost: 150,
    imagePath: 'assets/images/characters/mathieu-animal.png'),

  CosmeticItem(id: 'maxence-sh', name: 'Maxence - Theatre',
    category: CosmeticCategory.character, targetId: 'maxence', cost: 150,
    imagePath: 'assets/images/characters/maxence-sh.png'),   

  CosmeticItem(id: 'maxime-enf', name: 'Maxime - Baby',
    category: CosmeticCategory.character, targetId: 'maxime', cost: 150,
    imagePath: 'assets/images/characters/maxime-enf.png'), 

  CosmeticItem(id: 'meg-tarot', name: 'Meg - XVI.The Tower',
    category: CosmeticCategory.character, targetId: 'meg', cost: 150,
    imagePath: 'assets/images/characters/meg-tarot.png'),  

  CosmeticItem(id: 'monkey-animal', name: 'Monkey - Baby',
    category: CosmeticCategory.character, targetId: 'monkey', cost: 150,
    imagePath: 'assets/images/characters/monkey-animal.png'),

  CosmeticItem(id: 'casino-tarot', name: 'Mr. Casino - X.The Wheel',
    category: CosmeticCategory.character, targetId: 'mr_casino', cost: 150,
    imagePath: 'assets/images/characters/casino-tarot.png'),    

  CosmeticItem(id: 'nils-tarot', name: 'Nils - XI.Justice',
    category: CosmeticCategory.character, targetId: 'nils', cost: 150,
    imagePath: 'assets/images/characters/nils-tarot.png'),  

  CosmeticItem(id: 'ninja-animal', name: 'Ninja - Baby',
    category: CosmeticCategory.character, targetId: 'ninja', cost: 150,
    imagePath: 'assets/images/characters/ninja-animal.png'),   

  CosmeticItem(id: 'oceane-animal', name: 'Oceane - Bloomburrow',
    category: CosmeticCategory.character, targetId: 'oceane', cost: 150,
    imagePath: 'assets/images/characters/oceane-animal.png'),   

  CosmeticItem(id: 'oscar-animal', name: 'Oscar - Bloomburrow',
    category: CosmeticCategory.character, targetId: 'oscar', cost: 150,
    imagePath: 'assets/images/characters/oscar-animal.png'),   

  CosmeticItem(id: 'peio-animal', name: 'Peio - Blomburrow',
    category: CosmeticCategory.character, targetId: 'peio', cost: 150,
    imagePath: 'assets/images/characters/peio-animal.png'),  

  CosmeticItem(id: 'pirate-animal', name: 'Pirate - Baby',
    category: CosmeticCategory.character, targetId: 'pirate', cost: 150,
    imagePath: 'assets/images/characters/pirate-animal.png'),  

  CosmeticItem(id: 'raph-tarot', name: 'Raph - IX.The Hermit',
    category: CosmeticCategory.character, targetId: 'raph_du_soleil_levant', cost: 150,
    imagePath: 'assets/images/characters/raph-tarot.png'),  

  CosmeticItem(id: 'rat-tarot', name: 'Rat - XV.The Devil',
    category: CosmeticCategory.character, targetId: 'rat', cost: 150,
    imagePath: 'assets/images/characters/rat-tarot.png'),  

  CosmeticItem(id: 'remi-sh', name: 'Remi - Theatre',
    category: CosmeticCategory.character, targetId: 'remi', cost: 150,
    imagePath: 'assets/images/characters/remi-sh.png'),

  CosmeticItem(id: 'richard-tarot', name: 'Richard II - I.The Magician',
    category: CosmeticCategory.character, targetId: 'richard_ii', cost: 150,
    imagePath: 'assets/images/characters/richard-tarot.png'), 

  CosmeticItem(id: 'scott-sh', name: 'Scott - Theatre',
    category: CosmeticCategory.character, targetId: 'scott', cost: 150,
    imagePath: 'assets/images/characters/scott-sh.png'),

  CosmeticItem(id: 'theo-tarot', name: 'Theo - VII.The Chariot',
    category: CosmeticCategory.character, targetId: 'theo', cost: 150,
    imagePath: 'assets/images/characters/theo-tarot.png'),

  CosmeticItem(id: 'tom-tarot', name: 'Tom - VIII.Strength',
    category: CosmeticCategory.character, targetId: 'Tom', cost: 150,
    imagePath: 'assets/images/characters/tom-tarot.png'),

  CosmeticItem(id: 'tommy-tarot', name: 'Tommy - XX.Judgement',
    category: CosmeticCategory.character, targetId: 'tommy', cost: 150,
    imagePath: 'assets/images/characters/tommy-tarot.png'),    

  CosmeticItem(id: 'travert-sh', name: 'Travert - Theatre',
    category: CosmeticCategory.character, targetId: 'travert', cost: 150,
    imagePath: 'assets/images/characters/travert-sh.png'), 

  CosmeticItem(id: 'tristan-tarot', name: 'Tristan - V.The Hierophant',
    category: CosmeticCategory.character, targetId: 'tristan', cost: 150,
    imagePath: 'assets/images/characters/tristan-tarot.png'), 

  CosmeticItem(id: 'victor-tarot', name: 'Victor - VI.The Lovers',
    category: CosmeticCategory.character, targetId: 'victor', cost: 150,
    imagePath: 'assets/images/characters/victor-tarot.png'),            
  
  CosmeticItem(id: 'vlad-animal', name: 'Vlad - Blomburrow',
    category: CosmeticCategory.character, targetId: 'vlad', cost: 150,
    imagePath: 'assets/images/characters/vlad-animal.png'),
   


  // ── Jetons — ce sont des jetons AUTONOMES, ajoutés à la liste des choix
  // disponibles dans le sélecteur (pas liés à un personnage précis, donc
  // pas de targetId) ────────────────────────────────────────────────────
  CosmeticItem(id: 'token_bloom', name: 'Bloom',
    category: CosmeticCategory.token, cost: 70, fallbackEmoji: '🟡',
    imagePath: 'assets/images/tokens/bloom.png'),
  CosmeticItem(id: 'token_flora', name: 'Flora',
    category: CosmeticCategory.token, cost: 70, fallbackEmoji: '🟢',
    imagePath: 'assets/images/tokens/flora.png'),
  CosmeticItem(id: 'token_layla', name: 'Layla',
    category: CosmeticCategory.token, cost: 70, fallbackEmoji: '🟡',
    imagePath: 'assets/images/tokens/layla.png'),
  CosmeticItem(id: 'token_musa', name: 'Musa',
    category: CosmeticCategory.token, cost: 70, fallbackEmoji: '🟢',
    imagePath: 'assets/images/tokens/musa.png'),  
  CosmeticItem(id: 'token_stella', name: 'Stella',
    category: CosmeticCategory.token, cost: 70, fallbackEmoji: '🟡',
    imagePath: 'assets/images/tokens/stella.png'),
  CosmeticItem(id: 'token_tecna', name: 'Tecna',
    category: CosmeticCategory.token, cost: 70, fallbackEmoji: '🟢',
    imagePath: 'assets/images/tokens/tecna.png'),   
  CosmeticItem(id: 'token_Manabu', name: 'Manabu',
    category: CosmeticCategory.token, cost: 70, fallbackEmoji: '🔴',
    imagePath: 'assets/images/tokens/manabu.png'),
  CosmeticItem(id: 'token_toph', name: 'Toph',
    category: CosmeticCategory.token, cost: 70, fallbackEmoji: '🦀',
    imagePath: 'assets/images/tokens/jeton19.png'),
  CosmeticItem(id: 'token_Katara', name: 'Katara',
    category: CosmeticCategory.token, cost: 70, fallbackEmoji: '🦀',
    imagePath: 'assets/images/tokens/katara.png'),
    CosmeticItem(id: 'token_zuko', name: 'Zuko',
    category: CosmeticCategory.token, cost: 70, fallbackEmoji: '🦀',
    imagePath: 'assets/images/tokens/zuko.png'),
  CosmeticItem(id: 'token_aang', name: 'Aang',
    category: CosmeticCategory.token, cost: 70, fallbackEmoji: '🦀',
    imagePath: 'assets/images/tokens/aang.png'),  
  CosmeticItem(id: 'token_bingbong', name: 'Bingbong',
    category: CosmeticCategory.token, cost: 70, fallbackEmoji: '⚪',
    imagePath: 'assets/images/tokens/jeton17.png'),
  CosmeticItem(id: 'token_conan', name: 'Conan',
    category: CosmeticCategory.token, cost: 70, fallbackEmoji: '🔍',
    imagePath: 'assets/images/tokens/jeton18.png'),
  CosmeticItem(id: 'token_flott', name: 'Flott',
    category: CosmeticCategory.token, cost: 70, fallbackEmoji: '🏄',
    imagePath: 'assets/images/tokens/jeton20.png'),
  CosmeticItem(id: 'token_centrale', name: 'Centrale Lille',
    category: CosmeticCategory.token, cost: 70, fallbackEmoji: '🟢',
    imagePath: 'assets/images/tokens/centrale.png'),
  CosmeticItem(id: 'token_homer', name: 'Homer',
    category: CosmeticCategory.token, cost: 70, fallbackEmoji: '🔴',
    imagePath: 'assets/images/tokens/homer.png'),
    CosmeticItem(id: 'token_Krusty', name: 'Krusty',
    category: CosmeticCategory.token, cost: 70, fallbackEmoji: '🦀',
    imagePath: 'assets/images/tokens/krusty.png'),
  CosmeticItem(id: 'token_singe', name: 'Ourang-Outan',
    category: CosmeticCategory.token, cost: 70, fallbackEmoji: '⚪',
    imagePath: 'assets/images/tokens/singe.png'),
  CosmeticItem(id: 'token_Bersek', name: 'Berserk',
    category: CosmeticCategory.token, cost: 70, fallbackEmoji: '🔍',
    imagePath: 'assets/images/tokens/berserk.png'),
  CosmeticItem(id: 'token_jace', name: 'Jace',
    category: CosmeticCategory.token, cost: 70, fallbackEmoji: '🟡',
    imagePath: 'assets/images/tokens/jace.png'),
 
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
  CosmeticItem(id: 'terrain_vision_zoo', name: 'Zoo',
    category: CosmeticCategory.terrain, targetId: 'vision', cost: 250,
    imagePath: 'assets/images/terrains/zoo23.png'),
  CosmeticItem(id: 'terrain_lumiere_paradis', name: 'Paradis',
    category: CosmeticCategory.terrain, targetId: 'lumiere', cost: 250,
    imagePath: 'assets/images/terrains/paradis6.png'),
  CosmeticItem(id: 'terrain_steal_bandit', name: 'Bandit',
    category: CosmeticCategory.terrain, targetId: 'steal', cost: 250,
    imagePath: 'assets/images/terrains/bandit10.png'),
     CosmeticItem(id: 'terrain_5_candyland', name: 'CandyLand',
    category: CosmeticCategory.terrain, targetId: 'choice', cost: 250,
    imagePath: 'assets/images/terrains/candyland45.png'),
  CosmeticItem(id: 'terrain_tenebre_volcan', name: 'Volcan',
    category: CosmeticCategory.terrain, targetId: 'tenebre', cost: 250,
    imagePath: 'assets/images/terrains/volcan8.png'),
  CosmeticItem(id: 'terrain_9_laboratoire', name: 'Laboratoire',
    category: CosmeticCategory.terrain, targetId: 'damage9', cost: 250,
    imagePath: 'assets/images/terrains/laboratoire9.png'),
];

List<CosmeticItem> cosmeticsFor(CosmeticCategory cat, String targetId) =>
    kCosmeticsCatalog.where((c) => c.category == cat && c.targetId == targetId).toList();
