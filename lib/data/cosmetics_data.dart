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
 
  CosmeticItem(id: 'agathe-tarot', name: 'Agathe - Reine Baton',
    category: CosmeticCategory.character, targetId: 'agathe', cost: 150,
    imagePath: 'assets/images/characters/agathe-tarot.png'),

  CosmeticItem(id: 'albane-tarot', name: 'Albane - 7',
    category: CosmeticCategory.character, targetId: 'albane', cost: 150,
    imagePath: 'assets/images/characters/albane-tarot.png'),

  CosmeticItem(id: 'amelia-tarot', name: 'Amelia - Reine Denier',
    category: CosmeticCategory.character, targetId: 'amelia', cost: 150,
    imagePath: 'assets/images/characters/amelia-tarot.png'), 

  CosmeticItem(id: 'art_cade-tarot', name: 'Artcade - 9',
    category: CosmeticCategory.character, targetId: 'artcade', cost: 150,
    imagePath: 'assets/images/characters/art-tarot.png'),

  CosmeticItem(id: 'augustin-tarot', name: 'Augustin - Cavalier Baton',
    category: CosmeticCategory.character, targetId: 'augustin', cost: 150,
    imagePath: 'assets/images/characters/augustin-tarot.png'),  

  CosmeticItem(id: 'baleine-tarot', name: 'Baleine - XVII.The Star',
    category: CosmeticCategory.character, targetId: 'baleine', cost: 150,
    imagePath: 'assets/images/characters/baleine-tarot.png'), 

  CosmeticItem(id: 'baptiste-tarot', name: 'Baptiste - Cavalier Coupe',
    category: CosmeticCategory.character, targetId: 'baptiste', cost: 150,
    imagePath: 'assets/images/characters/baptiste-tarot.png'), 

  CosmeticItem(id: 'beeble', name: 'Beeble',
    category: CosmeticCategory.character, targetId: 'bibble', cost: 150,
    imagePath: 'assets/images/characters/beeble.png'),

  CosmeticItem(id: 'bob-tarot', name: 'Bob - 10',
    category: CosmeticCategory.character, targetId: 'bob', cost: 150,
    imagePath: 'assets/images/characters/bob-tarot.png'), 

  CosmeticItem(id: 'cambou-tarot', name: 'Cambou - As Baton',
    category: CosmeticCategory.character, targetId: 'cambou', cost: 150,
    imagePath: 'assets/images/characters/cambou-tarot.png'),

  CosmeticItem(id: 'carapatte-tarot', name: 'Carapatte - As Coupe',
    category: CosmeticCategory.character, targetId: 'carapatte', cost: 150,
    imagePath: 'assets/images/characters/carapatte-tarot.png'),  

  CosmeticItem(id: 'carla-tarot', name: 'Carla - 9',
    category: CosmeticCategory.character, targetId: 'carla', cost: 150,
    imagePath: 'assets/images/characters/carla-tarot.png'),

  CosmeticItem(id: 'christine-tarot', name: 'Christine - 9',
    category: CosmeticCategory.character, targetId: 'christine', cost: 150,
    imagePath: 'assets/images/characters/christine-tarot.png'),

  CosmeticItem(id: 'clemence-tarot', name: 'Clemence - II.The High Priestess',
    category: CosmeticCategory.character, targetId: 'clemence', cost: 150,
    imagePath: 'assets/images/characters/clemence-tarot.png'),

  CosmeticItem(id: 'damien-sh', name: 'Damien - XIV.Temperance',
    category: CosmeticCategory.character, targetId: 'damien', cost: 150,
    imagePath: 'assets/images/characters/damien-tarot.png'), 

  CosmeticItem(id: 'elaia-tarot', name: 'Elaia - 9',
    category: CosmeticCategory.character, targetId: 'elaia', cost: 150,
    imagePath: 'assets/images/characters/elaia-tarot.png'),

  CosmeticItem(id: 'elise-tarot', name: 'Elise - III.The Empress',
    category: CosmeticCategory.character, targetId: 'elise', cost: 150,
    imagePath: 'assets/images/characters/elise-tarot.png'),  

  CosmeticItem(id: 'emilien-tarot', name: 'Emilien - 8',
    category: CosmeticCategory.character, targetId: 'emilien', cost: 150,
    imagePath: 'assets/images/characters/emilien-tarot.png'), 

  CosmeticItem(id: 'fanny-tarot', name: 'Fanny - As Epée',
    category: CosmeticCategory.character, targetId: 'fanny', cost: 150,
    imagePath: 'assets/images/characters/fanny-tarot.png'),
  
  CosmeticItem(id: 'felipe-tarot', name: 'Felipe - XII.The Hanged Man',
    category: CosmeticCategory.character, targetId: 'felipe', cost: 150,
    imagePath: 'assets/images/characters/felipe-tarot.png'), 

  CosmeticItem(id: 'fifi-tarot', name: 'Fifi - Valet Coupe',
    category: CosmeticCategory.character, targetId: 'fifi_shadow', cost: 150,
    imagePath: 'assets/images/characters/fifi-tarot.png'),

  CosmeticItem(id: 'fijacked-tarot', name: 'Fijacked - Roi Coupe',
    category: CosmeticCategory.character, targetId: 'fijacked', cost: 150,
    imagePath: 'assets/images/characters/fijacked-tarot.png'), 

  CosmeticItem(id: 'gege-tarot', name: 'Gege - XVIII.The Moon',
    category: CosmeticCategory.character, targetId: 'gege', cost: 150,
    imagePath: 'assets/images/characters/gege-tarot.png'),   
    
  CosmeticItem(id: 'hailey-tarot', name: 'Hailey - 7',
    category: CosmeticCategory.character, targetId: 'hailey', cost: 150,
    imagePath: 'assets/images/characters/hailey-tarot.png'),   

  CosmeticItem(id: 'hong-tarot', name: 'Hong Yi - Valet Epée',
    category: CosmeticCategory.character, targetId: 'hong_yi', cost: 150,
    imagePath: 'assets/images/characters/hong-tarot.png'),

  CosmeticItem(id: 'ines-tarot', name: 'Ines - Cavalier Denier',
    category: CosmeticCategory.character, targetId: 'ines', cost: 150,
    imagePath: 'assets/images/characters/ines-tarot.png'),

  CosmeticItem(id: 'jason-tarot', name: 'Jason - 0.The Fool',
    category: CosmeticCategory.character, targetId: 'jason', cost: 150,
    imagePath: 'assets/images/characters/jason-tarot.png'), 

  CosmeticItem(id: 'jeanne-tarot', name: 'Jeanne - 10',
    category: CosmeticCategory.character, targetId: 'jeanne', cost: 150,
    imagePath: 'assets/images/characters/jeanne-tarot.png'), 

  CosmeticItem(id: 'julien-tarot', name: 'Julien - IV.The Emperor',
    category: CosmeticCategory.character, targetId: 'julien', cost: 150,
    imagePath: 'assets/images/characters/julien-tarot.png'),  

  CosmeticItem(id: 'leo-tarot', name: 'Léo - XIII.Death',
    category: CosmeticCategory.character, targetId: 'leo', cost: 150,
    imagePath: 'assets/images/characters/leo-tarot.png'), 

  CosmeticItem(id: 'louise-tarot', name: 'Louise - 8',
    category: CosmeticCategory.character, targetId: 'louise', cost: 150,
    imagePath: 'assets/images/characters/louise-tarot.png'),

  CosmeticItem(id: 'louna-tarot', name: 'Louna - Reine Epée',
    category: CosmeticCategory.character, targetId: 'louna', cost: 150,
    imagePath: 'assets/images/characters/louna-tarot.png'),  

  CosmeticItem(id: 'luc-tarot', name: 'Luc - XIX.The Sun',
    category: CosmeticCategory.character, targetId: 'luc', cost: 150,
    imagePath: 'assets/images/characters/luc-tarot.png'),  

  CosmeticItem(id: 'mango-tarot', name: 'Mango Loco - XXI.The World',
    category: CosmeticCategory.character, targetId: 'mango', cost: 150,
    imagePath: 'assets/images/characters/mango-tarot.png'),

  CosmeticItem(id: 'marin-tarot', name: 'Marin - Roi Denier',
    category: CosmeticCategory.character, targetId: 'marin', cost: 150,
    imagePath: 'assets/images/characters/marin-tarot.png'), 

  CosmeticItem(id: 'marion-tarot', name: 'Marion - Reine Coupe',
    category: CosmeticCategory.character, targetId: 'marion', cost: 150,
    imagePath: 'assets/images/characters/marion-tarot.png'),  

  CosmeticItem(id: 'mathieu-tarot', name: 'Mathieu - 10',
    category: CosmeticCategory.character, targetId: 'mathieu', cost: 150,
    imagePath: 'assets/images/characters/mathieu-tarot.png'),

  CosmeticItem(id: 'maxence-tarot', name: 'Maxence - 7',
    category: CosmeticCategory.character, targetId: 'maxence', cost: 150,
    imagePath: 'assets/images/characters/maxence-tarot.png'),   

  CosmeticItem(id: 'maxime-tarot', name: 'Maxime - IDK',
    category: CosmeticCategory.character, targetId: 'maxime', cost: 150,
    imagePath: 'assets/images/characters/maxime-tarot.png'), 

  CosmeticItem(id: 'meg-tarot', name: 'Meg - XVI.The Tower',
    category: CosmeticCategory.character, targetId: 'meg', cost: 150,
    imagePath: 'assets/images/characters/meg-tarot.png'),  

  CosmeticItem(id: 'monkey-tarot', name: 'Monkey - Cavalier Epée',
    category: CosmeticCategory.character, targetId: 'monkey', cost: 150,
    imagePath: 'assets/images/characters/monkey-tarot.png'),

  CosmeticItem(id: 'casino-tarot', name: 'Mr. Casino - X.The Wheel',
    category: CosmeticCategory.character, targetId: 'mr_casino', cost: 150,
    imagePath: 'assets/images/characters/casino-tarot.png'),    

  CosmeticItem(id: 'nils-tarot', name: 'Nils - XI.Justice',
    category: CosmeticCategory.character, targetId: 'nils', cost: 150,
    imagePath: 'assets/images/characters/nils-tarot.png'),  

  CosmeticItem(id: 'ninja-tarot', name: 'Ninja - 10',
    category: CosmeticCategory.character, targetId: 'ninja', cost: 150,
    imagePath: 'assets/images/characters/ninja-tarot.png'),   

  CosmeticItem(id: 'oceane-tarot', name: 'Oceane - 7',
    category: CosmeticCategory.character, targetId: 'oceane', cost: 150,
    imagePath: 'assets/images/characters/oceane-tarot.png'),   

  CosmeticItem(id: 'oscar-tarot', name: 'Oscar - As Baton',
    category: CosmeticCategory.character, targetId: 'oscar', cost: 150,
    imagePath: 'assets/images/characters/oscar-tarot.png'),   

  CosmeticItem(id: 'peio-tarot', name: 'Peio - Roi Baton',
    category: CosmeticCategory.character, targetId: 'peio', cost: 150,
    imagePath: 'assets/images/characters/peio-tarot.png'),  

  CosmeticItem(id: 'pirate-tarot', name: 'Pirate - 8',
    category: CosmeticCategory.character, targetId: 'pirate', cost: 150,
    imagePath: 'assets/images/characters/pirate-tarot.png'),  

  CosmeticItem(id: 'raph-tarot', name: 'Raph - IX.The Hermit',
    category: CosmeticCategory.character, targetId: 'raph_soleil', cost: 150,
    imagePath: 'assets/images/characters/raph-tarot.png'),  

  CosmeticItem(id: 'rat-tarot', name: 'Rat - XV.The Devil',
    category: CosmeticCategory.character, targetId: 'rat_rouen', cost: 150,
    imagePath: 'assets/images/characters/rat-tarot.png'),  

  CosmeticItem(id: 'remi-tarot', name: 'Remi - Valet Baton',
    category: CosmeticCategory.character, targetId: 'remi', cost: 150,
    imagePath: 'assets/images/characters/remi-tarot.png'),

  CosmeticItem(id: 'richard-tarot', name: 'Richard II - I.The Magician',
    category: CosmeticCategory.character, targetId: 'richard2', cost: 150,
    imagePath: 'assets/images/characters/richard-tarot.png'), 

  CosmeticItem(id: 'scott-tarot', name: 'Scott - Roi Epée',
    category: CosmeticCategory.character, targetId: 'scott', cost: 150,
    imagePath: 'assets/images/characters/scott-tarot.png'),

  CosmeticItem(id: 'theo-tarot', name: 'Theo - VII.The Chariot',
    category: CosmeticCategory.character, targetId: 'theo', cost: 150,
    imagePath: 'assets/images/characters/theo-tarot.png'),

  CosmeticItem(id: 'tom-tarot', name: 'Tom - VIII.Strength',
    category: CosmeticCategory.character, targetId: 'tom', cost: 150,
    imagePath: 'assets/images/characters/tom-tarot.png'),

  CosmeticItem(id: 'tommy-tarot', name: 'Tommy - XX.Judgement',
    category: CosmeticCategory.character, targetId: 'tommy', cost: 150,
    imagePath: 'assets/images/characters/tommy-tarot.png'),    

  CosmeticItem(id: 'travert-tarot', name: 'Travert - 8',
    category: CosmeticCategory.character, targetId: 'travert', cost: 150,
    imagePath: 'assets/images/characters/travert-tarot.png'), 

  CosmeticItem(id: 'tristan-tarot', name: 'Tristan - V.The Hierophant',
    category: CosmeticCategory.character, targetId: 'tristan', cost: 150,
    imagePath: 'assets/images/characters/tristan-tarot.png'), 

  CosmeticItem(id: 'victor-tarot', name: 'Victor - VI.The Lovers',
    category: CosmeticCategory.character, targetId: 'victor', cost: 150,
    imagePath: 'assets/images/characters/victor-tarot.png'),            
  
  CosmeticItem(id: 'vlad-tarot', name: 'Vlad - Valet Denier',
    category: CosmeticCategory.character, targetId: 'vlad', cost: 150,
    imagePath: 'assets/images/characters/vlad-tarot.png'),
   


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
