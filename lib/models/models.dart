// lib/models/models.dart
// Tous les modèles de données — aucune dépendance externe

enum Faction { hunter, shadow, neutral }
enum CardType { utilisation, equipement }
enum DeckType { lumiere, tenebres, vision }
enum AiDifficulty { easy, normal, hard }

enum GamePhase {
  lobby,
  roleReveal,
  ability,
  move,
  zoneEffect,
  cardChoice,
  cardDrawn,
  chooseTarget,
  attack,
  gameOver,
}

// ─────────────────────────────────────────────
// PERSONNAGE
// ─────────────────────────────────────────────
class CharacterCard {
  final String id, name, icon, ability, abilityEffect, winCondition, winEffect;
  final bool abilityRepeatable; // true = chaque tour, false = une seule fois
  final Faction faction;
  final int hp;

  const CharacterCard({
    required this.id,
    required this.name,
    required this.faction,
    required this.hp,
    required this.icon,
    required this.ability,
    required this.abilityEffect,
    this.abilityRepeatable = false,
    required this.winCondition,
    required this.winEffect,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'faction': faction.name, 'hp': hp,
    'icon': icon, 'ability': ability, 'abilityEffect': abilityEffect,
    'abilityRepeatable': abilityRepeatable,
    'winCondition': winCondition, 'winEffect': winEffect,
  };

  factory CharacterCard.fromJson(Map<String, dynamic> j) => CharacterCard(
    id: j['id'] as String,
    name: j['name'] as String,
    faction: Faction.values.byName(j['faction'] as String),
    hp: j['hp'] as int,
    icon: j['icon'] as String,
    ability: j['ability'] as String,
    abilityEffect: j['abilityEffect'] as String,
    abilityRepeatable: (j['abilityRepeatable'] as bool?) ?? false,
    winCondition: j['winCondition'] as String,
    winEffect: j['winEffect'] as String,
  );
}

// ─────────────────────────────────────────────
// CARTE DE JEU
// ─────────────────────────────────────────────
class GameCard {
  final String id, name, text, effect;
  final DeckType deck;
  final CardType type;

  const GameCard({
    required this.id,
    required this.name,
    required this.deck,
    required this.type,
    required this.text,
    required this.effect,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'deck': deck.name,
    'type': type.name, 'text': text, 'effect': effect,
  };

  factory GameCard.fromJson(Map<String, dynamic> j) => GameCard(
    id: j['id'] as String,
    name: j['name'] as String,
    deck: DeckType.values.byName(j['deck'] as String),
    type: CardType.values.byName(j['type'] as String),
    text: j['text'] as String,
    effect: j['effect'] as String,
  );
}

// ─────────────────────────────────────────────
// TERRAIN
// ─────────────────────────────────────────────
class Terrain {
  final String num, name, effect, desc, icon;
  final int id;

  const Terrain({
    required this.num,
    required this.id,
    required this.name,
    required this.effect,
    required this.desc,
    required this.icon,
  });

  Map<String, dynamic> toJson() => {
    'num': num, 'id': id, 'name': name,
    'effect': effect, 'desc': desc, 'icon': icon,
  };

  factory Terrain.fromJson(Map<String, dynamic> j) => Terrain(
    num: j['num'] as String,
    id: j['id'] as int,
    name: j['name'] as String,
    effect: j['effect'] as String,
    desc: j['desc'] as String,
    icon: j['icon'] as String,
  );

  /// Mot-clé court et lisible pour l'effet de ce terrain, à afficher à la
  /// place de la description complète (ex: sur le plateau, où l'espace est
  /// très limité et où une phrase entière devient illisible).
  String get keyword => switch (effect) {
    'vision'   => 'Vision',
    'choice'   => 'Choix',
    'lumiere'  => 'Lumière',
    'tenebres' => 'Ténèbre',
    'damage9'  => 'Blessure',
    'steal'    => 'Vol',
    _ => desc,
  };
}

// ─────────────────────────────────────────────
// JOUEUR
// ─────────────────────────────────────────────
class Player {
  final String uid;
  String name;
  String token;
  CharacterCard? character;
  int wounds;
  int zoneIndex;
  bool alive;
  bool revealed;
  bool abilityUsed;
  bool isReady;
  bool shield;
  int shieldCharges;
  bool newTurn;
  bool terrainImmune;
  bool terrainDmgImmune; // Broche de Chance: immunisé aux DÉGÂTS du terrain 9 (le soin reste possible)
  bool sainteTunique;
  bool crucifixArgent; // Crucifix d'Argent : récupère TOUT l'équipement d'un joueur éliminé
  bool tendebresImmune;
  bool lance;
  bool lanceLonginus; // +2 dmg si Hunter révélé uniquement (sinon aucun bonus)
  bool bazooka;
  bool hache;
  bool sniper;
  bool dague;
  bool epeeNinja; // +2 blessures supplémentaires si l'attaque inflige des dégâts
  // New ability fields
  int bonusMaxHp;      // Felipe Pompims: bonus PV temporaires
  bool poisoned;        // Ingénieur: subit 1 blessure/tour
  bool frozen;          // 80ans/Léa: ne peut pas se déplacer
  bool cannotHeal;      // Rémi Canada: ne peut pas se soigner
  bool abilityBlocked;  // Peio Mongolie: ne peut pas utiliser sa capacité
  bool revived;         // Jesus: a déjà ressuscité
  int attackCount;      // Mathieu: compte les attaques
  int startZone;        // Chaise Merguez: zone de départ
  bool invulnerable;    // Rémi Hunter: invulnérable si allié révélé présent
  bool mustReveal;      // Théo Homard: doit être révélé
  bool infiniteRange;   // Pirate: portée infinie
  bool autoCounter;     // Scott: contre-attaque auto
  bool mirrorDamage;    // Raphaël Shadow: miroir dégâts
  String? deathBombTargetUid; // Enceinte: cible de la bombe à la mort
  int deathBombDmg;           // Enceinte: dégâts de la bombe
  bool fifiAutomneShield;
  String? killedByUid;  // uid du joueur qui a tué ce personnage     // Fifi Automne: annule prochaine attaque
  String? copiedEffect; // Baptiste/Oscar: effet copié
  String? poisonSourceUid; // qui a empoisonné
  int poisonTurnsRemaining; // Damien : tours restants de poison (3 dégâts/tour)
  String? lucFireSourceUid; // qui a mis le feu
  int lucFireTurnsRemaining; // Luc : tours restants en feu (2 dégâts/tour, +1 dégât aux attaques)
  int drunkTurnsRemaining = 0; // Maxence : tours restants ivre (vision brouillée, sur SON écran uniquement)
  int drunkSeed = 0;           // Maxence : graine fixe pour que le brouillage reste cohérent pendant les 2 tours
  int tomBonusDmg = 0; // Tom : dégâts bonus PERMANENTS cumulés, +2 à chaque Shadow qu'il élimine
  String? disguiseIconOverride;
  String? disguiseNameOverride;
  String? disguiseFactionOverride;
  String? disguiseCharIdOverride; // ID du perso imité — pour afficher sa carte complète
  bool disguiseJustLost = false; // Jason : vient de perdre son déguisement (5+ dégâts/tour) — déclenche sa vraie révélation
  bool fannyJustRevealed = false; // Fanny : vient de voler une identité en éliminant un joueur sans être révélée — déclenche sa révélation automatique
  bool felipeJustRevealed = false; // Felipe : vient de survivre à un coup mortel sans être révélé — déclenche sa révélation automatique
  bool jasonWeaponVoicePlayed = false; // Jason : voice line arme spéciale déjà jouée cette partie (une seule fois)
  int storedDamage = 0;      // Nils : blessures stockées en attendant d'être déchargées
  int oscarXp = 0;           // Oscar : XP cumulée (1 par blessure infligée en attaque), condition de victoire à 13
  bool oscarFireBonus = false; // Oscar : "Feu" activé — +2 dégâts à sa prochaine attaque ce tour
  bool fannyHasStolen = false; // Fanny : est-ce qu'elle a déjà volé une carte (une seule fois)
  bool deathPassiveProcessed = false; // Marqueur dédié "passifs de mort déjà traités pour ce joueur" — séparé de abilityUsed pour ne pas entrer en conflit avec les personnages dont la capacité unique avait déjà été utilisée AVANT leur mort
  Map<String, int> charmLevels; // Victor : uid → % de charme (0-100), stocké UNIQUEMENT sur Victor — lui seul peut voir cette donnée
  bool maximeUsedFirstBonus = false; // Maxime : sa première attaque après révélation (dégâts doublés) a-t-elle déjà eu lieu
  String? maximeFirstAttackerUid; // Maxime : uid du premier joueur à lui avoir infligé des blessures cette partie (condition de victoire)
  bool nilsStoring = false;  // Nils : mode "stockage" actif (ses attaques stockent au lieu de blesser)
  bool emilienRerolledThisTurn = false; // Emilien : relance du D6 déjà utilisée ce tour (une seule fois)
  int maxHpModifier = 0; // Agathe : PV max volés/perdus, définitivement (+ pour elle, − pour la victime, plafonné à ±5)
  bool felipeOnBorrowedTime = false; // Felipe : a survécu à des dégâts létaux, en sursis jusqu'à la fin de son prochain tour
  bool attackedLastOwnTurn = true; // Fifi Été / Theo : a attaqué lors de SON PROPRE tour précédent (true par défaut — pas de malus au tout premier tour)
  List<String> remiEquipmentChoices; // Rémi : les 2 effets choisis pour son équipement personnalisé
  bool forcedToAttackNextTurn = false; // Rémi (effet "oblige à attaquer") : doit attaquer quelqu'un à son prochain tour
  List<String> privatelyKnownBy; // uids des joueurs qui connaissent secrètement l'identité de CE joueur (Vision Suprême) — reveal permanent, mais visible seulement d'eux
  bool marinDagueVoicePlayed = false; // Marin : voice line dague déjà jouée cette partie (une seule fois)
  String? abilityLockedByUid; // Inès : uid de l'Inès qui a verrouillé la capacité de ce joueur, null si non verrouillé
  String? megForm; // Meg : 'offense' (+1 infligé) ou 'defense' (-1 reçu), null si pas encore choisie
  int damageTakenThisTurn; // remis à 0 au début de CHAQUE tour (Jason: perd son déguisement à 5+)
  List<GameCard> equipment;

  Player({
    required this.uid,
    required this.name,
    required this.token,
    this.character,
    this.wounds = 0,
    this.zoneIndex = 0,
    this.alive = true,
    this.revealed = false,
    this.abilityUsed = false,
    this.isReady = false,
    this.shield = false,
    this.shieldCharges = 0,
    this.newTurn = false,
    this.terrainImmune = false,
    this.terrainDmgImmune = false,
    this.sainteTunique = false,
    this.crucifixArgent = false,
    this.tendebresImmune = false,
    this.lance = false,
    this.lanceLonginus = false,
    this.bazooka = false,
    this.hache = false,
    this.sniper = false,
    this.dague = false,
    this.epeeNinja = false,
    this.bonusMaxHp = 0,
    this.poisoned = false,
    this.frozen = false,
    this.cannotHeal = false,
    this.abilityBlocked = false,
    this.revived = false,
    this.attackCount = 0,
    this.startZone = 0,
    this.invulnerable = false,
    this.mustReveal = false,
    this.infiniteRange = false,
    this.autoCounter = false,
    this.mirrorDamage = false,
    this.deathBombTargetUid,
    this.deathBombDmg = 0,
    this.fifiAutomneShield = false,
    this.killedByUid,
    this.copiedEffect,
    this.poisonSourceUid,
    this.poisonTurnsRemaining = 0,
    this.lucFireSourceUid,
    this.lucFireTurnsRemaining = 0,
    this.drunkTurnsRemaining = 0,
    this.drunkSeed = 0,
    this.tomBonusDmg = 0,
    this.disguiseIconOverride,
    this.disguiseNameOverride,
    this.disguiseFactionOverride,
    this.disguiseCharIdOverride,
    this.damageTakenThisTurn = 0,
    this.disguiseJustLost = false,
    this.fannyJustRevealed = false,
    this.felipeJustRevealed = false,
    this.jasonWeaponVoicePlayed = false,
    this.storedDamage = 0,
    this.oscarXp = 0,
    this.oscarFireBonus = false,
    this.fannyHasStolen = false,
    this.deathPassiveProcessed = false,
    Map<String, int>? charmLevels,
    this.maximeUsedFirstBonus = false,
    this.maximeFirstAttackerUid,
    this.nilsStoring = false,
    this.emilienRerolledThisTurn = false,
    this.maxHpModifier = 0,
    this.felipeOnBorrowedTime = false,
    this.attackedLastOwnTurn = true,
    List<String>? remiEquipmentChoices,
    List<String>? privatelyKnownBy,
    this.marinDagueVoicePlayed = false,
    this.forcedToAttackNextTurn = false,
    this.abilityLockedByUid,
    this.megForm,
    List<GameCard>? equipment,
  }) : equipment = equipment ?? [],
       remiEquipmentChoices = remiEquipmentChoices ?? [],
       privatelyKnownBy = privatelyKnownBy ?? [],
       charmLevels = charmLevels ?? {};

  bool get isBot => uid.startsWith('bot_');

  Map<String, dynamic> toJson() => {
    'uid': uid, 'name': name, 'token': token,
    'character': character?.toJson(),
    'wounds': wounds, 'zoneIndex': zoneIndex,
    'alive': alive, 'revealed': revealed,
    'abilityUsed': abilityUsed, 'isReady': isReady,
    'shield': shield, 'shieldCharges': shieldCharges,
    'newTurn': newTurn, 'terrainImmune': terrainImmune,
    'terrainDmgImmune': terrainDmgImmune,
    'sainteTunique': sainteTunique, 'crucifixArgent': crucifixArgent, 'tendebresImmune': tendebresImmune,
    'lance': lance, 'lanceLonginus': lanceLonginus, 'bazooka': bazooka, 'hache': hache,
    'sniper': sniper, 'dague': dague, 'epeeNinja': epeeNinja,
    'bonusMaxHp': bonusMaxHp, 'poisoned': poisoned, 'frozen': frozen,
    'cannotHeal': cannotHeal, 'abilityBlocked': abilityBlocked,
    'revived': revived, 'attackCount': attackCount, 'startZone': startZone,
    'invulnerable': invulnerable, 'mustReveal': mustReveal,
    'infiniteRange': infiniteRange, 'autoCounter': autoCounter,
    'mirrorDamage': mirrorDamage, 'deathBombTargetUid': deathBombTargetUid,
    'deathBombDmg': deathBombDmg, 'fifiAutomneShield': fifiAutomneShield,
    'killedByUid': killedByUid, 'copiedEffect': copiedEffect,
    'poisonSourceUid': poisonSourceUid,
    'poisonTurnsRemaining': poisonTurnsRemaining,
    'lucFireSourceUid': lucFireSourceUid,
    'lucFireTurnsRemaining': lucFireTurnsRemaining,
    'drunkTurnsRemaining': drunkTurnsRemaining,
    'drunkSeed': drunkSeed,
    'tomBonusDmg': tomBonusDmg,
    'disguiseIconOverride': disguiseIconOverride,
    'disguiseNameOverride': disguiseNameOverride,
    'disguiseFactionOverride': disguiseFactionOverride,
    'disguiseCharIdOverride': disguiseCharIdOverride,
    'disguiseFactionOverride': disguiseFactionOverride,
    'damageTakenThisTurn': damageTakenThisTurn,
    'disguiseJustLost': disguiseJustLost,
    'fannyJustRevealed': fannyJustRevealed,
    'felipeJustRevealed': felipeJustRevealed,
    'jasonWeaponVoicePlayed': jasonWeaponVoicePlayed,
    'storedDamage': storedDamage,
    'oscarXp': oscarXp,
    'oscarFireBonus': oscarFireBonus,
    'fannyHasStolen': fannyHasStolen,
    'deathPassiveProcessed': deathPassiveProcessed,
    'charmLevels': charmLevels,
    'maximeUsedFirstBonus': maximeUsedFirstBonus,
    'maximeFirstAttackerUid': maximeFirstAttackerUid,
    'nilsStoring': nilsStoring,
    'emilienRerolledThisTurn': emilienRerolledThisTurn,
    'maxHpModifier': maxHpModifier,
    'felipeOnBorrowedTime': felipeOnBorrowedTime,
    'attackedLastOwnTurn': attackedLastOwnTurn,
    'remiEquipmentChoices': remiEquipmentChoices,
    'privatelyKnownBy': privatelyKnownBy,
    'forcedToAttackNextTurn': forcedToAttackNextTurn,
    'marinDagueVoicePlayed': marinDagueVoicePlayed,
    'abilityLockedByUid': abilityLockedByUid,
    'megForm': megForm,
    'equipment': equipment.map((e) => e.toJson()).toList(),
  };

  factory Player.fromJson(Map<String, dynamic> j) => Player(
    uid: j['uid'] as String,
    name: j['name'] as String,
    token: (j['token'] as String?) ?? '🔵',
    character: j['character'] != null
        ? CharacterCard.fromJson(Map<String, dynamic>.from(j['character'] as Map))
        : null,
    wounds: (j['wounds'] as int?) ?? 0,
    zoneIndex: (j['zoneIndex'] as int?) ?? 0,
    alive: (j['alive'] as bool?) ?? true,
    revealed: (j['revealed'] as bool?) ?? false,
    abilityUsed: (j['abilityUsed'] as bool?) ?? false,
    isReady: (j['isReady'] as bool?) ?? false,
    shield: (j['shield'] as bool?) ?? false,
    shieldCharges: (j['shieldCharges'] as int?) ?? 0,
    newTurn: (j['newTurn'] as bool?) ?? false,
    terrainImmune: (j['terrainImmune'] as bool?) ?? false,
    terrainDmgImmune: (j['terrainDmgImmune'] as bool?) ?? false,
    sainteTunique: (j['sainteTunique'] as bool?) ?? false,
    crucifixArgent: (j['crucifixArgent'] as bool?) ?? false,
    tendebresImmune: (j['tendebresImmune'] as bool?) ?? false,
    lance: (j['lance'] as bool?) ?? false,
    lanceLonginus: (j['lanceLonginus'] as bool?) ?? false,
    bazooka: (j['bazooka'] as bool?) ?? false,
    hache: (j['hache'] as bool?) ?? false,
    sniper: (j['sniper'] as bool?) ?? false,
    dague: (j['dague'] as bool?) ?? false,
    epeeNinja: (j['epeeNinja'] as bool?) ?? false,
    bonusMaxHp: (j['bonusMaxHp'] as int?) ?? 0,
    poisoned: (j['poisoned'] as bool?) ?? false,
    frozen: (j['frozen'] as bool?) ?? false,
    cannotHeal: (j['cannotHeal'] as bool?) ?? false,
    abilityBlocked: (j['abilityBlocked'] as bool?) ?? false,
    revived: (j['revived'] as bool?) ?? false,
    attackCount: (j['attackCount'] as int?) ?? 0,
    startZone: (j['startZone'] as int?) ?? 0,
    invulnerable: (j['invulnerable'] as bool?) ?? false,
    mustReveal: (j['mustReveal'] as bool?) ?? false,
    infiniteRange: (j['infiniteRange'] as bool?) ?? false,
    autoCounter: (j['autoCounter'] as bool?) ?? false,
    mirrorDamage: (j['mirrorDamage'] as bool?) ?? false,
    deathBombTargetUid: j['deathBombTargetUid'] as String?,
    deathBombDmg: (j['deathBombDmg'] as int?) ?? 0,
    fifiAutomneShield: (j['fifiAutomneShield'] as bool?) ?? false,
    killedByUid: j['killedByUid'] as String?,
    copiedEffect: j['copiedEffect'] as String?,
    poisonSourceUid: j['poisonSourceUid'] as String?,
    poisonTurnsRemaining: (j['poisonTurnsRemaining'] as int?) ?? 0,
    lucFireSourceUid: j['lucFireSourceUid'] as String?,
    lucFireTurnsRemaining: (j['lucFireTurnsRemaining'] as int?) ?? 0,
    drunkTurnsRemaining: (j['drunkTurnsRemaining'] as int?) ?? 0,
    drunkSeed: (j['drunkSeed'] as int?) ?? 0,
    tomBonusDmg: (j['tomBonusDmg'] as int?) ?? 0,
    disguiseIconOverride: j['disguiseIconOverride'] as String?,
    disguiseNameOverride: j['disguiseNameOverride'] as String?,
    disguiseFactionOverride: j['disguiseFactionOverride'] as String?,
    disguiseCharIdOverride: j['disguiseCharIdOverride'] as String?,
    damageTakenThisTurn: (j['damageTakenThisTurn'] as int?) ?? 0,
    disguiseJustLost: (j['disguiseJustLost'] as bool?) ?? false,
    fannyJustRevealed: (j['fannyJustRevealed'] as bool?) ?? false,
    felipeJustRevealed: (j['felipeJustRevealed'] as bool?) ?? false,
    jasonWeaponVoicePlayed: (j['jasonWeaponVoicePlayed'] as bool?) ?? false,
    storedDamage: (j['storedDamage'] as num?)?.toInt() ?? 0,
    oscarXp: (j['oscarXp'] as num?)?.toInt() ?? 0,
    oscarFireBonus: j['oscarFireBonus'] as bool? ?? false,
    fannyHasStolen: j['fannyHasStolen'] as bool? ?? false,
    deathPassiveProcessed: j['deathPassiveProcessed'] as bool? ?? false,
    charmLevels: j['charmLevels'] != null
        ? Map<String, int>.from((j['charmLevels'] as Map).map((k, v) => MapEntry(k as String, v as int)))
        : null,
    maximeUsedFirstBonus: j['maximeUsedFirstBonus'] as bool? ?? false,
    maximeFirstAttackerUid: j['maximeFirstAttackerUid'] as String?,
    nilsStoring: (j['nilsStoring'] as bool?) ?? false,
    emilienRerolledThisTurn: (j['emilienRerolledThisTurn'] as bool?) ?? false,
    maxHpModifier: (j['maxHpModifier'] as num?)?.toInt() ?? 0,
    felipeOnBorrowedTime: (j['felipeOnBorrowedTime'] as bool?) ?? false,
    attackedLastOwnTurn: (j['attackedLastOwnTurn'] as bool?) ?? true,
    remiEquipmentChoices: (j['remiEquipmentChoices'] as List?)?.map((e) => e as String).toList() ?? [],
    privatelyKnownBy: (j['privatelyKnownBy'] as List?)?.map((e) => e as String).toList() ?? [],
    forcedToAttackNextTurn: (j['forcedToAttackNextTurn'] as bool?) ?? false,
    marinDagueVoicePlayed: (j['marinDagueVoicePlayed'] as bool?) ?? false,
    abilityLockedByUid: j['abilityLockedByUid'] as String?,
    megForm: j['megForm'] as String?,
    equipment: ((j['equipment'] as List?) ?? [])
        .map((e) => GameCard.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );

  Player copy() => Player.fromJson(toJson());
}

// ─────────────────────────────────────────────
// GAMESTATE (Firebase)
// ─────────────────────────────────────────────
class GameState {
  final String roomId;
  final String hostId;
  final String currentPlayerId;
  final GamePhase phase;
  final List<String> playerOrder;
  final List<Terrain> terrainLayout;
  final String? pendingAction;
  final String? pendingTargetAction;
  final String? attackTargetId;
  final int? pendingDamage;
  final bool hasAttacked;
  final String? abilityOverlay;
  final Map<String, int>? abilityDiceResult;
  final Map<String, int>? scottCounterDice; // dés de la contre-attaque de Scott, pour affichage
  final Map<String, int>? lastDiceResult; // dernier jet de dés (attaque/déplacement/carte) — visible de tous
  final String? lastDrawnCardId; // dernière carte piochée (non-Vision) — visible de tous, sur le même
  final int? lastDrawnCardTimestamp; // principe que lastDiceResult, indépendant de la phase de jeu
  final String? lastDiceLabel;            // libellé du jet ('Déplacement', 'Attaque', etc.)
  final int? lastDiceTimestamp;           // ms depuis epoch au moment du jet
  final int? turnStartedAt;               // ms epoch — début du tour courant (timer AFK)
  final String? pendingPunishActorUid;  // Divination X ou Y : qui a joué la carte
  final String? pendingPunishTargetUid; // Divination X ou Y : qui doit répondre
  final String? privateRevealTargetUid; // Vision Suprême : uid dont la carte est montrée
  final String? privateRevealForUid;    // Vision Suprême : à QUI montrer (uid du lanceur)
  final String? forcedAttackerUid;      // Corne des Woods : qui doit attaquer (étape 2 en attente)
  final bool peioReturnToMove;           // Peio : retourner en phase Déplacement après le terrain réactivé
  // Clémence builder power
  final int builderStep;                 // 0=off 1=1er choix 2=2ème choix 3=choisir cible
  final String? builderEffect1;
  final String? builderEffect2;
  final List<String> builderOffered;     // 3 effets proposés au tour courant
  final List<String> haileyOffered;      // Hailey : 3 Hunters non joués proposés au tour courant
  // Jeanne (Prophétesse)
  final String? markedPlayerUid;  // uid du joueur marqué (visible de tous)
  final String? tristanTargetUid; // Tristan : joueur choisi à l'étape 1
  final int? tristanGiveIdx;      // Tristan : index de SON équipement choisi à l'étape 2
  final String? jeanneReward;     // récompense secrète (visible seulement de Jeanne)
  final String? jeanneUid;        // uid de Jeanne
  // Richard II — échange de zones
  final int? swapZone1;           // 1ère zone choisie
  final int? swapZone2;           // 2ème zone choisie
  // Ninja — tours bonus
  final int bonusTurnsRemaining;
  final bool fifiGoldenTurn;
  final int fifiMoveResult;   // Fifi : valeur de déplacement choisie
  final int fifiAtkResult;    // Fifi : valeur d'attaque choisie
  // Jeanne prophétesse
  final int jeanneStep;                  // 0=off, 1=choisir cible, 2=choisir récompense
  // Elaia — pouvoir de prescience
  final int elaiaStep;                   // 0=off, 1=choisir la pile, 2=choisir l'ordre
  final String? elaiaDeck;               // 'tenebres'|'lumiere'|'vision' — pile choisie
  final String? elaiaCard1Id;            // 1ère carte regardée
  final String? elaiaCard2Id;            // 2ème carte regardée
  final String? damienTargetUid;         // Damien : cible choisie, en attente du choix alcool/poison
  final String? lootKillerUid;    // qui vient d'éliminer quelqu'un avec équipement
  final List<String> lootDeadQueue; // file d'attente des morts avec butin à choisir (kills simultanés)
  final int? richardActivateZone; // Richard II : zone dont l'effet doit être activé (pas forcément sa position)
  final String? publicRevealUid;      // qui vient de se révéler (visible/audible de tous)
  final String? jeanneRewardBanner;      // texte à afficher en grand quand la récompense de Jeanne se déclenche
  final int? jeanneRewardBannerTimestamp; // pour l'auto-expiration côté clients
  final int? publicRevealTimestamp;   // pour l'auto-expiration côté clients
  final Map<String, List<String>> forcedDeckQueue; // cartes forcées par pile (Elaia)
  // Pile réelle par deck : liste mélangée des IDs restant à piocher. Se
  // remplit et se mélange automatiquement dès qu'elle est vide.
  final Map<String, List<String>> deckPiles;
  // Baptiste : mémorise la cible (un joueur mort) choisie entre l'étape
  // "cible" et l'étape "montant à sacrifier" — nécessaire en multijoueur
  // pour que le montant se résolve correctement chez le bon client.
  final String? baptisteTargetUid;

  const GameState({
    required this.roomId,
    required this.hostId,
    required this.phase,
    required this.currentPlayerId,
    required this.playerOrder,
    required this.terrainLayout,
    this.pendingAction,
    this.pendingTargetAction,
    this.attackTargetId,
    this.pendingDamage,
    this.hasAttacked = false,
    this.abilityOverlay,
    this.abilityDiceResult,
    this.scottCounterDice,
    this.lastDiceResult,
    this.lastDrawnCardId,
    this.lastDrawnCardTimestamp,
    this.lastDiceLabel,
    this.lastDiceTimestamp,
    this.turnStartedAt,
    this.pendingPunishActorUid,
    this.pendingPunishTargetUid,
    this.privateRevealTargetUid,
    this.privateRevealForUid,
    this.forcedAttackerUid,
    this.peioReturnToMove = false,
    this.builderStep = 0,
    this.builderEffect1,
    this.builderEffect2,
    this.builderOffered = const [],
    this.haileyOffered = const [],
    this.markedPlayerUid,
    this.tristanTargetUid,
    this.tristanGiveIdx,
    this.jeanneReward,
    this.jeanneUid,
    this.swapZone1,
    this.swapZone2,
    this.bonusTurnsRemaining = 0,
    this.fifiGoldenTurn = false,
    this.fifiMoveResult = 7,
    this.fifiAtkResult = 5,
    this.jeanneStep = 0,
    this.elaiaStep = 0,
    this.elaiaDeck,
    this.elaiaCard1Id,
    this.elaiaCard2Id,
    this.damienTargetUid,
    this.lootKillerUid,
    this.lootDeadQueue = const [],
    this.richardActivateZone,
    this.publicRevealUid,
    this.jeanneRewardBanner,
    this.jeanneRewardBannerTimestamp,
    this.publicRevealTimestamp,
    this.forcedDeckQueue = const {},
    this.deckPiles = const {},
    this.baptisteTargetUid,
  });

  Map<String, dynamic> toJson() => {
    'roomId': roomId, 'hostId': hostId,
    'phase': phase.name, 'currentPlayerId': currentPlayerId,
    'playerOrder': playerOrder,
    'terrainLayout': terrainLayout.map((t) => t.toJson()).toList(),
    'pendingAction': pendingAction,
    'pendingTargetAction': pendingTargetAction,
    'attackTargetId': attackTargetId,
    'pendingDamage': pendingDamage,
    'hasAttacked': hasAttacked,
    'abilityOverlay': abilityOverlay,
    'abilityDiceResult': abilityDiceResult,
    'scottCounterDice': scottCounterDice,
    'lastDiceResult': lastDiceResult,
    'lastDrawnCardId': lastDrawnCardId,
    'lastDrawnCardTimestamp': lastDrawnCardTimestamp,
    'lastDiceLabel': lastDiceLabel,
    'lastDiceTimestamp': lastDiceTimestamp,
    'turnStartedAt': turnStartedAt,
    'pendingPunishActorUid': pendingPunishActorUid,
    'pendingPunishTargetUid': pendingPunishTargetUid,
    'privateRevealTargetUid': privateRevealTargetUid,
    'privateRevealForUid': privateRevealForUid,
    'forcedAttackerUid': forcedAttackerUid,
    'peioReturnToMove': peioReturnToMove,
    'builderStep': builderStep,
    'builderEffect1': builderEffect1,
    'builderEffect2': builderEffect2,
    'builderOffered': builderOffered,
    'haileyOffered': haileyOffered,
    'markedPlayerUid': markedPlayerUid,
    'tristanTargetUid': tristanTargetUid,
    'tristanGiveIdx': tristanGiveIdx,
    'jeanneReward': jeanneReward,
    'jeanneUid': jeanneUid,
    'swapZone1': swapZone1,
    'swapZone2': swapZone2,
    'bonusTurnsRemaining': bonusTurnsRemaining,
    'fifiGoldenTurn': fifiGoldenTurn,
    'fifiMoveResult': fifiMoveResult,
    'fifiAtkResult': fifiAtkResult,
    'jeanneStep': jeanneStep,
    'elaiaStep': elaiaStep,
    'elaiaDeck': elaiaDeck,
    'elaiaCard1Id': elaiaCard1Id,
    'elaiaCard2Id': elaiaCard2Id,
    'damienTargetUid': damienTargetUid,
    'lootKillerUid': lootKillerUid,
    'lootDeadQueue': lootDeadQueue,
    'richardActivateZone': richardActivateZone,
    'publicRevealUid': publicRevealUid,
    'jeanneRewardBanner': jeanneRewardBanner,
    'jeanneRewardBannerTimestamp': jeanneRewardBannerTimestamp,
    'publicRevealTimestamp': publicRevealTimestamp,
    'forcedDeckQueue': forcedDeckQueue,
    'deckPiles': deckPiles,
    'baptisteTargetUid': baptisteTargetUid,
  };

  factory GameState.fromJson(Map<String, dynamic> j) => GameState(
    roomId: (j['roomId'] as String?) ?? '',
    hostId: (j['hostId'] as String?) ?? '',
    phase: GamePhase.values.byName((j['phase'] as String?) ?? 'lobby'),
    currentPlayerId: (j['currentPlayerId'] as String?) ?? '',
    playerOrder: List<String>.from((j['playerOrder'] as List?) ?? []),
    terrainLayout: ((j['terrainLayout'] as List?) ?? [])
        .map((t) => Terrain.fromJson(Map<String, dynamic>.from(t as Map)))
        .toList(),
    pendingAction: j['pendingAction'] as String?,
    pendingTargetAction: j['pendingTargetAction'] as String?,
    attackTargetId: j['attackTargetId'] as String?,
    pendingDamage: j['pendingDamage'] as int?,
    hasAttacked: (j['hasAttacked'] as bool?) ?? false,
    abilityOverlay: j['abilityOverlay'] as String?,
    abilityDiceResult: j['abilityDiceResult'] != null
        ? Map<String, int>.from((j['abilityDiceResult'] as Map)
            .map((k, v) => MapEntry(k as String, (v as num).toInt())))
        : null,
    scottCounterDice: j['scottCounterDice'] != null
        ? Map<String, int>.from((j['scottCounterDice'] as Map)
            .map((k, v) => MapEntry(k as String, (v as num).toInt())))
        : null,
    lastDiceResult: j['lastDiceResult'] != null
        ? Map<String, int>.from((j['lastDiceResult'] as Map)
            .map((k, v) => MapEntry(k as String, (v as num).toInt())))
        : null,
    lastDiceLabel: j['lastDiceLabel'] as String?,
    lastDiceTimestamp: j['lastDiceTimestamp'] as int?,
    lastDrawnCardId: j['lastDrawnCardId'] as String?,
    lastDrawnCardTimestamp: j['lastDrawnCardTimestamp'] as int?,
    turnStartedAt: j['turnStartedAt'] as int?,
    pendingPunishActorUid: j['pendingPunishActorUid'] as String?,
    pendingPunishTargetUid: j['pendingPunishTargetUid'] as String?,
    privateRevealTargetUid: j['privateRevealTargetUid'] as String?,
    privateRevealForUid: j['privateRevealForUid'] as String?,
    forcedAttackerUid: j['forcedAttackerUid'] as String?,
    peioReturnToMove: (j['peioReturnToMove'] as bool?) ?? false,
    builderStep: (j['builderStep'] as int?) ?? 0,
    builderEffect1: j['builderEffect1'] as String?,
    builderEffect2: j['builderEffect2'] as String?,
    builderOffered: List<String>.from((j['builderOffered'] as List?) ?? []),
    haileyOffered: List<String>.from((j['haileyOffered'] as List?) ?? []),
    markedPlayerUid: j['markedPlayerUid'] as String?,
    tristanTargetUid: j['tristanTargetUid'] as String?,
    tristanGiveIdx: j['tristanGiveIdx'] as int?,
    jeanneReward: j['jeanneReward'] as String?,
    jeanneStep: (j['jeanneStep'] as int?) ?? 0,
    jeanneUid: j['jeanneUid'] as String?,
    swapZone1: j['swapZone1'] as int?,
    swapZone2: j['swapZone2'] as int?,
    bonusTurnsRemaining: (j['bonusTurnsRemaining'] as int?) ?? 0,
    fifiGoldenTurn: (j['fifiGoldenTurn'] as bool?) ?? false,
    fifiMoveResult: (j['fifiMoveResult'] as int?) ?? 7,
    fifiAtkResult: (j['fifiAtkResult'] as int?) ?? 5,
    elaiaStep: (j['elaiaStep'] as int?) ?? 0,
    elaiaDeck: j['elaiaDeck'] as String?,
    elaiaCard1Id: j['elaiaCard1Id'] as String?,
    elaiaCard2Id: j['elaiaCard2Id'] as String?,
    damienTargetUid: j['damienTargetUid'] as String?,
    lootKillerUid: j['lootKillerUid'] as String?,
    lootDeadQueue: j['lootDeadQueue'] != null ? List<String>.from(j['lootDeadQueue'] as List) : const [],
    richardActivateZone: j['richardActivateZone'] as int?,
    publicRevealUid: j['publicRevealUid'] as String?,
    jeanneRewardBanner: j['jeanneRewardBanner'] as String?,
    jeanneRewardBannerTimestamp: j['jeanneRewardBannerTimestamp'] as int?,
    publicRevealTimestamp: j['publicRevealTimestamp'] as int?,
    forcedDeckQueue: j['forcedDeckQueue'] != null
        ? Map<String, List<String>>.from((j['forcedDeckQueue'] as Map).map(
            (k, v) => MapEntry(k as String, List<String>.from(v as List))))
        : const {},
    deckPiles: j['deckPiles'] != null
        ? Map<String, List<String>>.from((j['deckPiles'] as Map).map(
            (k, v) => MapEntry(k as String, List<String>.from(v as List))))
        : const {},
    baptisteTargetUid: j['baptisteTargetUid'] as String?,
  );
}

// ─────────────────────────────────────────────
// LOG ENTRY (solo)
// ─────────────────────────────────────────────
class LogEntry {
  final String message;
  final String cls; // '', 'important', 'death', 'bot', 'player'
  LogEntry(this.message, {this.cls = ''});
}
