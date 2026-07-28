// lib/data/interactions_data.dart
// ─── Interactions vocales entre personnages ──────────────────────────────────
// Système de "voice lines" déclenchées quand certains personnages sont
// révélés/agissent en présence d'un autre. PLACEHOLDER : chaque interaction
// a un texte à personnaliser et attend un fichier audio
// `assets/audio/interact_<key>.mp3` (silencieusement ignoré si absent).

class CharInteraction {
  final String speakerId;      // qui parle
  final String? conditionId;   // l'autre personnage qui doit être révélé (null = inconditionnel)
  final String key;            // clé unique -> assets/audio/interact_<key>.mp3
  final String text;           // réplique (placeholder, à personnaliser)
  const CharInteraction({
    required this.speakerId,
    this.conditionId,
    required this.key,
    required this.text,
  });
}

/// Interactions déclenchées quand [speakerId] se révèle alors que
/// [conditionId] est déjà révélé.
const List<CharInteraction> kRevealInteractions = [
  CharInteraction(speakerId: 'louise', conditionId: 'albane', key: 'louise_albane',
      text: '[Louise à Albane, à personnaliser]'),
  CharInteraction(speakerId: 'fijacked', conditionId: 'amelia', key: 'fijacked_amelia',
      text: '[Fijacked à Amélia, à personnaliser]'),
  CharInteraction(speakerId: 'baleine', conditionId: 'artcade', key: 'baleine_artcade',
      text: '[Baleine à Art\'Cade, à personnaliser]'),
  CharInteraction(speakerId: 'elaia', conditionId: 'artcade', key: 'elaia_artcade',
      text: '[Elaia à Art\'Cade, à personnaliser]'),
  CharInteraction(speakerId: 'hong_yi', conditionId: 'baleine', key: 'hongyi_baleine',
      text: '[Hong Yi à Baleine, à personnaliser]'),
  CharInteraction(speakerId: 'julien', conditionId: 'carapatte', key: 'julien_carapatte',
      text: '[Julien à Carapatte, à personnaliser]'),
  CharInteraction(speakerId: 'louna', conditionId: 'damien', key: 'louna_damien',
      text: '[Louna à Damien, à personnaliser]'),
  CharInteraction(speakerId: 'jeanne', conditionId: 'elaia', key: 'jeanne_elaia',
      text: '[Jeanne à Elaia, à personnaliser]'),
  CharInteraction(speakerId: 'oceane', conditionId: 'elise', key: 'oceane_elise',
      text: '[Océane à Élise, à personnaliser]'),
  CharInteraction(speakerId: 'leo', conditionId: 'gege', key: 'leo_gege',
      text: '[Léo à Gège, à personnaliser]'),
  CharInteraction(speakerId: 'elaia', conditionId: 'jeanne', key: 'elaia_jeanne',
      text: '[Elaia à Jeanne, à personnaliser]'),
  CharInteraction(speakerId: 'ninja', conditionId: 'leo', key: 'ninja_leo',
      text: '[Ninja à Léo, à personnaliser]'),
  CharInteraction(speakerId: 'mango', conditionId: 'louise', key: 'mango_louise',
      text: '[Mango Loco à Louise, à personnaliser]'),
  CharInteraction(speakerId: 'marion', conditionId: 'louna', key: 'marion_louna',
      text: '[Marion à Louna, à personnaliser]'),
  CharInteraction(speakerId: 'richard2', conditionId: 'mango', key: 'richard2_mango',
      text: '[Richard II à Mango Loco, à personnaliser]'),
  CharInteraction(speakerId: 'julien', conditionId: 'marion', key: 'julien_marion',
      text: '[Julien à Marion, à personnaliser]'),
  CharInteraction(speakerId: 'mr_casino', conditionId: 'pirate', key: 'casino_pirate',
      text: '[Mr Casino à Pirate, à personnaliser]'),
  CharInteraction(speakerId: 'pirate', conditionId: 'mr_casino', key: 'pirate_casino',
      text: '[Pirate à Mr Casino, à personnaliser]'),
  CharInteraction(speakerId: 'rat_rouen', conditionId: 'oceane', key: 'rat_oceane',
      text: '[Rat d\'Rouen à Océane, à personnaliser]'),
  CharInteraction(speakerId: 'vlad', conditionId: 'tommy', key: 'vlad_tommy',
      text: '[Vlad à Tommy, à personnaliser]'),
  CharInteraction(speakerId: 'fifi_shadow', conditionId: 'tristan', key: 'fifi_tristan',
      text: '[Fifi à Tristan, à personnaliser]'),
  CharInteraction(speakerId: 'amelia', conditionId: 'ninja', key: 'amelia_ninja',
      text: '[Amélia à Ninja, à personnaliser]'),
  CharInteraction(speakerId: 'elise', conditionId: 'vlad', key: 'elise_vlad',
      text: '[Élise à Vlad, à personnaliser]'),
  CharInteraction(speakerId: 'fijacked', conditionId: 'hong_yi', key: 'fijacked_hongyi',
      text: '[Fijacked à Hong Yi, à personnaliser]'),
  CharInteraction(speakerId: 'albane', conditionId: 'peio', key: 'albane_peio',
      text: '[Albane à Peio, à personnaliser]'),
  CharInteraction(speakerId: 'raph_soleil', conditionId: 'monkey', key: 'raphsoleil_monkey',
      text: '[Raph du Soleil Levant à Monkey Raph, à personnaliser]'),
  CharInteraction(speakerId: 'clemence', conditionId: 'raph_soleil', key: 'clemence_raphsoleil',
      text: '[Clémence à Raph du Soleil Levant, à personnaliser]'),
  CharInteraction(speakerId: 'fifi_shadow', conditionId: 'rat_rouen', key: 'fifi_rat',
      text: '[Fifi à Rat d\'Rouen, à personnaliser]'),
  // Jason démasqué (perd son déguisement) alors que Bibble est révélé —
  // réutilise le même mécanisme de révélation (sa vraie identité 'jason'
  // redevient active dès que le déguisement tombe).
  CharInteraction(speakerId: 'jason', conditionId: 'bibble', key: 'jason_bibble_unmasked',
      text: '[Jason démasqué face à Bibble, à personnaliser]'),
];

/// Cherche une interaction de révélation pour [revealedId] sachant que
/// [otherRevealedIds] contient les IDs de tous les autres joueurs déjà
/// révélés. Retourne la première correspondance ou null.
CharInteraction? findRevealInteraction(String revealedId, Set<String> otherRevealedIds) {
  for (final it in kRevealInteractions) {
    if (it.speakerId == revealedId && otherRevealedIds.contains(it.conditionId)) {
      return it;
    }
  }
  return null;
}

/// Jason équipe une arme spéciale (Mitrailleuse/Révolver/Sniper) — une seule
/// fois par partie.
const CharInteraction kJasonWeaponInteraction = CharInteraction(
  speakerId: 'jason', conditionId: null, key: 'jason_weapon',
  text: '[Jason avec une arme spéciale, à personnaliser]');

/// Marin révélé reçoit une Dague du Voleur.
const CharInteraction kMarinDagueInteraction = CharInteraction(
  speakerId: 'marin', conditionId: null, key: 'marin_dague',
  text: '[Marin reçoit une dague, à personnaliser]');

/// Julien pioche la carte Lumière "Bucket de Poulet" (L16).
const CharInteraction kJulienBucketInteraction = CharInteraction(
  speakerId: 'julien', conditionId: null, key: 'julien_bucket',
  text: '[Julien pioche le Bucket de Poulet, à personnaliser]');

/// Travert utilise son pouvoir alors que Clémence est révélée.
const CharInteraction kTravertClemenceInteraction = CharInteraction(
  speakerId: 'travert', conditionId: 'clemence', key: 'travert_clemence',
  text: '[Travert à Clémence, à personnaliser]');

/// Travert utilise son pouvoir (cas général, sans Clémence révélée).
const CharInteraction kTravertGeneralInteraction = CharInteraction(
  speakerId: 'travert', conditionId: null, key: 'travert_power',
  text: '[Travert utilise son pouvoir, à personnaliser]');

/// Mathieu : son bonus permanent s'active (3ème attaque).
const CharInteraction kMathieuActivateInteraction = CharInteraction(
  speakerId: 'mathieu', conditionId: null, key: 'mathieu_activate',
  text: '[Mathieu, bonus activé, à personnaliser]');

/// Tommy utilise sa capacité (copie un pouvoir) alors que Richard II est révélé.
const CharInteraction kTommyRichardInteraction = CharInteraction(
  speakerId: 'tommy', conditionId: 'richard2', key: 'tommy_richard2',
  text: '[Tommy à Richard II, à personnaliser]');

/// Scott : quand le minuteur de tour atteint 30 secondes (si Scott est en jeu).
const CharInteraction kScottTimerInteraction = CharInteraction(
  speakerId: 'scott', conditionId: null, key: 'scott_timer30',
  text: '[Scott, minuteur bas, à personnaliser]');
