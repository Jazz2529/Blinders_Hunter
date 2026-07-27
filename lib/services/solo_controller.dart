// lib/services/solo_controller.dart
// Contrôleur solo complet — état local + IA

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../data/game_data.dart';
import '../services/audio_service.dart';
import 'engine.dart';

// ─────────────────────────────────────────────
// ÉTAT SOLO
// ─────────────────────────────────────────────
class SoloState {
  List<Player> players;
  List<Terrain> terrainLayout;
  int currentIdx;
  GamePhase phase;
  List<LogEntry> log;
  GameCard? pendingCard;
  bool pendingCardIsSecret; // true = carte Vision, secrète pour les autres
  String? pendingTargetAction;
  String? attackTargetId;
  List<String> winnerIds;
  String? winnerMessage;
  bool botThinking;
  bool hasAttackedThisTurn;
  bool hasDoubleMove;
  bool didNotAttackLastTurn; // Fifi été
  bool skipMovement;         // Demi-sel: peut ne pas se déplacer
  bool peioReturnToMove = false; // Peio: après avoir réactivé le terrain, revenir en phase Déplacement
  String? linkedUid1;        // Cupidon: uid1 lié
  String? linkedUid2;        // Cupidon: uid2 lié
  int linkedTurnsLeft;       // Cupidon: tours restants
  String? shieldTargetUid;   // Vlad Princesse: uid protégé (-1 dmg)
  String? intercept;         // Vlad Princesse intercept
  GameCard? lastLumiereCard; // Elise/Mère Christine: dernière carte Lumière
  String? lucPassive;        // Luc: passive choisie
  String? peintrPassive;     // Peintre: passive choisie
  bool inessPassiveActive;   // Inès: insensible si 7
  String? woundFlashUid;
  String? pendingRevealAnimation;
  String? abilityOverlay; // 'artcade_flames' | null
  String? privateRevealTargetUid; // Vision Suprême : uid du joueur dont la carte doit être montrée
  String? forcedAttackerUid; // Corne des Woods
  String? equipChoiceMode;    // 'steal' | 'give'
  String? equipChoiceActorUid;
  String? equipChoiceTargetUid;
  // Richard II — échange de zones
  int? swapZone1;              // 1ère zone choisie (index 0-5)
  int? swapZone2;              // 2ème zone choisie — null = pas encore choisie
  // Ninja — tours bonus
  int bonusTurnsRemaining = 0;
  // Clémence builder power state
  int builderStep = 0;           // 0=off, 1=1er choix, 2=2ème choix, 3=choisir cible
  String? builderEffect1;        // 1er effet choisi
  String? builderEffect2;        // 2ème effet choisi
  List<String> builderOffered = []; // les 3 effets proposés au tour courant
  // Jeanne (Prophétesse) state
  String? markedPlayerUid;   // uid du joueur marqué (visible de tous)
  String? jeanneReward;      // récompense secrète (visible seulement de Jeanne)
  String? jeanneUid;         // uid de Jeanne (pour lui soigner 3 à la mort de la cible)
  int jeanneStep = 0;        // 0=off, 1=choisir cible, 2=choisir récompense
  Map<String,int>? abilityDiceResult; // {d:4, result:3, dmg:3, name:'Vlad'} // uid du joueur dont la carte s'affiche
  // Shadow specials
  String? controlledUid;     // Zombie Raph: uid du joueur contrôlé
  bool fifiGoldenTurn;
  int fifiMoveResult; // Fifi: résultat déplacement choisi
  int fifiAtkResult;  // Fifi: résultat attaque choisi
  int fifiMoveD4; int fifiMoveD6;
  int fifiAtkD4;  int fifiAtkD6;
  bool jasonDoubleVision; // Jason Espion: dégâts Vision doublés       // Fifi shadow: tour parfait (7 move, 5 dmg)
  int ninjaExtraTurns;       // Ninja: tours bonus restants
  bool ninaTurnUsed;
  bool ninaTurnPending; // Nina: rejouer 1 tour complet après ce tour         // Nina: tour bonus utilisé ce tour
  Map<int,String> trappedZones; // Damien/Emilien/Peio: zones piégées {zoneIdx: trapType}
  String? maximeBlockerUid;  // Maxime: uid de l'assaillant à contrer
  int maximeAssailantRoll;   // Maxime: résultat de l'assaillant
  bool raphShadowMultiAtk;   // Raphaël Shadow: attaques multiples actives
  int raphShadowTotalDmg;    // Raphaël Shadow: total dégâts infligés (= dégâts subis)
  String? raphShadowTargetUid; // Raphaël: cible désignée
  bool gladsCombining;
  int killsThisTurn;     // Couronne: tués ce tour       // Glads: en train de combiner
  List<GameCard> gladsBackup;// Glads: sauvegarde équipements
  // Elaia — pouvoir de prescience
  int elaiaStep = 0;          // 0=off, 1=choisir la pile, 2=choisir l'ordre
  String? elaiaDeck;          // 'tenebres'|'lumiere'|'vision'
  String? elaiaCard1Id;
  String? elaiaCard2Id;
  String? damienTargetUid; // Damien : cible choisie, en attente du choix alcool/poison
  String? lootKillerUid;   // qui vient d'éliminer quelqu'un avec équipement
  List<String> lootDeadQueue = []; // file d'attente des morts avec butin (kills simultanés, ex: bazooka)
  Map<String, List<String>> forcedDeckQueue = {}; // cartes forcées par pile

  SoloState({
    required this.players,
    required this.terrainLayout,
    this.currentIdx = 0,
    this.phase = GamePhase.ability,
    List<LogEntry>? log,
    this.pendingCard,
    this.pendingCardIsSecret = false,
    this.pendingTargetAction,
    this.attackTargetId,
    List<String>? winnerIds,
    this.winnerMessage,
    this.botThinking = false,
    this.hasAttackedThisTurn = false,
    this.hasDoubleMove = false,
    this.didNotAttackLastTurn = false,
    this.skipMovement = false,
    this.linkedUid1,
    this.linkedUid2,
    this.linkedTurnsLeft = 0,
    this.shieldTargetUid,
    this.intercept,
    this.lastLumiereCard,
    this.lucPassive,
    this.peintrPassive,
    this.inessPassiveActive = false,
    this.woundFlashUid,
    this.pendingRevealAnimation,
    this.controlledUid,
    this.fifiGoldenTurn = false,
    this.fifiMoveResult = 7,
    this.fifiAtkResult = 5,
    this.fifiMoveD4 = 4, this.fifiMoveD6 = 3,
    this.fifiAtkD4 = 4, this.fifiAtkD6 = 1,
    this.jasonDoubleVision = false,
    this.ninjaExtraTurns = 0,
    this.ninaTurnUsed = false,
    this.ninaTurnPending = false,
    Map<int,String>? trappedZones,
    this.maximeBlockerUid,
    this.maximeAssailantRoll = 0,
    this.raphShadowMultiAtk = false,
    this.raphShadowTotalDmg = 0,
    this.raphShadowTargetUid,
    this.gladsCombining = false,
    this.killsThisTurn = 0,
    List<GameCard>? gladsBackup,
  })  : trappedZones = trappedZones ?? {},
        gladsBackup = gladsBackup ?? [],
        log = log ?? [],
        winnerIds = winnerIds ?? [];

  Player get current => players[currentIdx];
  bool get isHuman => !current.isBot;
  bool get isOver  => phase == GamePhase.gameOver;
}

// ─────────────────────────────────────────────
// CERVEAU IA
// ─────────────────────────────────────────────
class _AiBrain {
  final Random _rng = Random();
  final GameEngine _eg = GameEngine.instance;
  final Map<String, Faction> _memory = {};

  void remember(List<Player> players) {
    for (final p in players) {
      if (p.revealed && p.character != null) _memory[p.uid] = p.character!.faction;
    }
  }

  double _probAttack(AiDifficulty d)  => switch(d){AiDifficulty.easy=>0.5,AiDifficulty.normal=>0.70,AiDifficulty.hard=>0.90};
  double _probAbility(AiDifficulty d) => switch(d){AiDifficulty.easy=>0.4,AiDifficulty.normal=>0.75,AiDifficulty.hard=>0.95};
  bool _roll(double p) => _rng.nextDouble() < p;

  // Décide si le bot joue sa capacité
  bool shouldUseAbility(Player bot, List<Player> all, List<Terrain> layout, AiDifficulty d) {
    if (!bot.revealed) {
      if (d == AiDifficulty.hard) return _isAbilityUseful(bot, all, layout);
      return _roll(0.5);
    }
    return !bot.abilityUsed && _roll(_probAbility(d));
  }

  bool _isAbilityUseful(Player bot, List<Player> all, List<Terrain> layout) {
    switch (bot.character!.abilityEffect) {
      case 'full_heal': return bot.wounds > 0;
      case 'shield3':   return bot.wounds > 0;
      case 'd4_all':    return true;
      case 'draw_dark': return true;
      default: return all.any((p) => p.alive && p.uid != bot.uid);
    }
  }

  // Choisit la meilleure zone
  int bestZone(Player bot, List<Player> all, List<Terrain> layout, AiDifficulty d) {
    if (d == AiDifficulty.easy) {
      final opts = List.generate(6, (i)=>i).where((i)=>i!=bot.zoneIndex).toList();
      return opts[_rng.nextInt(opts.length)];
    }
    final isLow = bot.wounds >= (bot.character!.hp * 0.55).floor();
    final scored = List.generate(6, (i) {
      if (i == bot.zoneIndex) return (i: i, s: -100.0);
      final t = layout[i]; double s = 0;
      if (isLow && t.effect == 'lumiere') s += 25;
      if (isLow && t.effect == 'choice')  s += 15;
      if (bot.character!.faction == Faction.shadow && t.effect == 'tenebres') s += 20;
      if (bot.character!.faction == Faction.hunter && t.effect == 'vision')   s += 15;
      if (bot.character!.winEffect == 'die_first') {
        s += all.where((p)=>p.alive&&p.uid!=bot.uid&&p.zoneIndex==i).length * 15.0;
      }
      return (i: i, s: s);
    });
    scored.sort((a,b)=>b.s.compareTo(a.s));
    return scored.first.i;
  }

  // Choisit le deck
  DeckType bestDeck(Player bot, AiDifficulty d) {
    if (d == AiDifficulty.easy) return DeckType.values[_rng.nextInt(3)];
    final isLow = bot.wounds >= (bot.character!.hp * 0.55).floor();
    if (bot.character!.faction == Faction.shadow) return DeckType.tenebres;
    return isLow ? DeckType.lumiere : DeckType.vision;
  }

  // Choisit la meilleure cible
  Player? bestTarget(Player bot, List<Player> all, AiDifficulty d, {String context = ''}) {
    final cands = all.where((p) => p.alive && p.uid != bot.uid).toList();
    if (cands.isEmpty) return null;
    if (d == AiDifficulty.easy) return cands[_rng.nextInt(cands.length)];
    if (context.contains('steal') || context.contains('pince')) {
      final withEquip = cands.where((p) => p.equipment.isNotEmpty).toList();
      if (withEquip.isEmpty) return null;
      return withEquip[_rng.nextInt(withEquip.length)];
    }
    if (context.contains('heal') || context.contains('soin')) {
      final allies = cands.where((p) => _isAlly(bot, p)).toList();
      if (allies.isEmpty) return cands.reduce((a,b)=>a.wounds>b.wounds?a:b);
      return allies.reduce((a,b)=>a.wounds>b.wounds?a:b);
    }
    final scored = cands.map((t) {
      double s = 0;
      final knownFaction = _memory[t.uid] ?? (t.revealed ? t.character!.faction : null);
      if (knownFaction != null && _isEnemy(bot, knownFaction)) s += 30;
      if (knownFaction != null && bot.character!.faction == knownFaction) s -= 50;
      final hpLeft = t.character!.hp - t.wounds;
      if (hpLeft <= 3) s += 40; else if (hpLeft <= 6) s += 15;
      if (d == AiDifficulty.hard) s += t.equipment.length * 5.0;
      if (bot.character!.winEffect == 'die_first') s = _rng.nextDouble() * 20;
      return (p: t, s: s);
    }).toList();
    scored.sort((a,b)=>b.s.compareTo(a.s));
    return scored.first.p;
  }

  bool _isEnemy(Player me, Faction f) =>
    (me.character!.faction == Faction.hunter && f == Faction.shadow) ||
    (me.character!.faction == Faction.shadow  && f == Faction.hunter);

  bool _isAlly(Player me, Player other) =>
    me.character!.faction != Faction.neutral && me.character!.faction == other.character!.faction;

  bool shouldAttack(Player bot, List<Player> all, List<Terrain> layout, AiDifficulty d) {
    return _eg.attackTargets(bot, all, layout).isNotEmpty && _roll(_probAttack(d));
  }

  bool shouldApplyCard(GameCard card, Player bot, AiDifficulty d) {
    // Une carte piochée est OBLIGATOIRE (même règle que pour un joueur
    // humain — impossible de l'ignorer). L'ancien 25% de chance de "skip"
    // en difficulté Facile faisait disparaître des cartes sans effet,
    // y compris des cartes purement bénéfiques comme l'Éclair Purificateur.
    return true;
  }
}

// ─────────────────────────────────────────────
// CONTRÔLEUR
// ─────────────────────────────────────────────
class SoloController extends ChangeNotifier {
  final GameEngine _eg = GameEngine.instance;
  final _AiBrain   _ai = _AiBrain();
  final Random     _rng = Random();
  Map<String, Map<String, dynamic>> _currentSnapshot = {};

  SoloState? state;
  AiDifficulty difficulty;
  String humanName;
  String humanToken;
  String? forcedCharacterId;          // null = aléatoire, sinon id du personnage choisi
  List<String>? characterPool;        // null = tous, sinon liste d'ids autorisés

  SoloController({
    this.difficulty = AiDifficulty.normal,
    this.humanName  = 'Joueur',
    this.humanToken = 'vlad',
    this.forcedCharacterId,
    this.characterPool,
  });

  // Retourne le nom lisible d'un token
  static String _nameForToken(String id) {
    const names = {
      'vlad':'Vlad','jason':'Jason','marin':'Marin','felipe':'Felipe',
      'julien':'Julien','cambou':'Cambou','raph':'Raph','marion':'Marion',
      'albane':'Albane','emilien':'Emilien','damien':'Damien','clemence':'Clemence',
      'remi':'Remi','peio':'Peio','toph':'Toph','bingbong':'Bingbong',
      'conan':'Conan','elise':'Elise','flott':'Flott',
    };
    return names[id] ?? id;
  }

  // ─── Setup ──────────────────────────────
  void startGame() {
    // 5 joueurs : humain + 4 bots
    // Tous les tokens disponibles — nom bot = nom du token
    const allTokenIds = [
      'vlad','jason','marin','felipe','julien','cambou','raph','marion',
      'albane','emilien','damien','clemence','remi','peio',
      'toph','bingbong','conan','elise','flott',
    ];
    final available = allTokenIds.where((t) => t != humanToken).toList()..shuffle(_rng);
    final players = [
      Player(uid: 'human', name: humanName, token: humanToken),
      Player(uid: 'bot_0', name: _nameForToken(available[0]), token: available[0]),
      Player(uid: 'bot_1', name: _nameForToken(available[1]), token: available[1]),
      Player(uid: 'bot_2', name: _nameForToken(available[2]), token: available[2]),
      Player(uid: 'bot_3', name: _nameForToken(available[3]), token: available[3]),
    ];
    // Assigner les rôles (avec pool filtrée si définie)
    _eg.assignRolesWithPool(players,
      pool: characterPool,
      forcedCharId: forcedCharacterId);
    // Théo Homard commence révélé
    for (final p in players) {
      if (p.character?.abilityEffect == 'revealed_plus1_dmg') p.revealed = true;
    } // 2 Hunters + 2 Shadows + 1 Neutre
    final layout = [...kAllTerrains]..shuffle(_rng);
    // Répartir les joueurs sur les 6 zones
    for (int i = 0; i < players.length; i++) { players[i].zoneIndex = i % 6; }
    state = SoloState(
      players: players, terrainLayout: layout,
      log: [LogEntry('⚔️ La partie commence !', cls: 'important')],
      phase: GamePhase.roleReveal, // Afficher la carte du joueur d'abord
    );
    notifyListeners();
  }

  // ─── Tour suivant ────────────────────────
  Future<void> nextTurn() async {
    if (state == null || state!.isOver) return;
    // 🍀 Fifi — le "tour parfait" ne dure qu'UN tour : on le consomme ici,
    // avant de passer au joueur suivant, pour revenir à l'aléatoire ensuite.
    if (state!.fifiGoldenTurn) {
      state!.fifiGoldenTurn = false;
    }
    int next = (state!.currentIdx + 1) % state!.players.length;
    while (!state!.players[next].alive) { next = (next + 1) % state!.players.length; }
    final p = state!.players[next];
    // Reset ability only if it's repeatable (usable every turn)
    if (p.character?.abilityRepeatable == true) p.abilityUsed = false;
    if (p.shield && p.shieldCharges == 99) { p.shield = false; p.shieldCharges = 0; }
    p.damageTakenThisTurn = 0; // remise à zéro pour le tracking de Jason
    state!.currentIdx = next;
    state!.phase = GamePhase.ability;
    state!.pendingCard = null;
    state!.pendingCardIsSecret = false;
    state!.pendingTargetAction = null;
    state!.hasAttackedThisTurn = false;
    // Passifs début de tour
    final passiveLogs = _eg.applyStartOfTurnPassives(p, state!.players, state!.terrainLayout,
        lastLumiereCard: state!.lastLumiereCard);
    // Pirate passif permanent — portée infinie
    final pEff = p.copiedEffect ?? p.character?.abilityEffect ?? '';
    if (pEff == 'infinite_range') p.infiniteRange = true;
    // Fifi Été: marquer le buff si pas attaqué le tour précédent
    if (pEff == 'no_attack_buff' && p.revealed && state!.didNotAttackLastTurn) {
      p.bonusMaxHp = 1; // flag "buff actif"
      _log('🌻 Fifi Été — +2 dégâts ce tour (pas attaqué hier)', cls: 'player');
    } else if (pEff == 'no_attack_buff') {
      p.bonusMaxHp = 0;
    }
    for (final l in passiveLogs) _log(l);
    // Un passif de début de tour (poison de Damien, etc.) peut tuer un
    // joueur — sans ce check, ni la victoire ni la récompense de Jeanne ne
    // se déclenchaient jamais pour une mort survenue de cette façon.
    if (!p.alive) { _checkWin(justDiedId: p.uid); }
    // Zazou snapshot
    _currentSnapshot = {
      for (final pl in state!.players) pl.uid: {'wounds': pl.wounds, 'equip': List.from(pl.equipment), 'alive': pl.alive}
    };
    _log('─── Tour de ${p.name} ${p.isBot ? "(Bot)" : "(Vous)"} ───', cls: p.isBot ? 'bot' : 'player');
    // Sauvegarder la zone de départ du tour (pour Chaise Merguez)
    p.startZone = p.zoneIndex;
    // Monkey Raph — pioche ténèbres au début du tour si révélé
    if (pEff == 'draw_dark' && p.revealed) {
      humanDrawCard(DeckType.tenebres);
      _log('🐒 Monkey Raph pioche une carte Ténèbres (visible de tous)', cls: 'player');
    }
    // Artcade — actif répétable (géré dans humanUseAbility)
    notifyListeners();
    if (p.isBot) await _playBot(p);
  }


  /// Appelé quand le joueur appuie sur "J'ai compris" après la révélation de son rôle
  Future<void> confirmRoleReveal() async {
    if (state == null) return;
    state!.phase = GamePhase.ability;
    notifyListeners();
    if (state!.players[state!.currentIdx].isBot) await _playBot(state!.current);
  }

  // ─── Bot ────────────────────────────────
  Future<void> _playBot(Player bot) async {
    state!.botThinking = true; notifyListeners();
    const d = Duration(milliseconds: 850);

    _ai.remember(state!.players);

    // Capacité
    await Future.delayed(d);
    if (_ai.shouldUseAbility(bot, state!.players, state!.terrainLayout, difficulty) &&
        !(bot.character!.abilityEffect == 'copy_ability' &&
          !state!.players.any((x) => x.uid != bot.uid && x.alive && x.revealed &&
              x.character != null &&
              !GameEngine.uncopyableAbilities.contains(x.character!.abilityEffect)))) {
      if (!bot.revealed) {
        bot.revealed = true;
        state!.pendingRevealAnimation = bot.uid;
        audio.playReveal();
        _log('🃏 ${bot.name} révèle sa carte');
      }
      final needsTarget = _abilityNeedsTarget(bot.character!.abilityEffect);
      Player? target;
      if (bot.character!.abilityEffect == 'copy_ability') {
        // Tommy (bot) : choisit un joueur révélé au pouvoir copiable, au hasard.
        final candidates = state!.players.where((x) =>
          x.uid != bot.uid && x.alive && x.revealed && x.character != null &&
          !GameEngine.uncopyableAbilities.contains(x.character!.abilityEffect)).toList();
        if (candidates.isNotEmpty) target = candidates[_rng.nextInt(candidates.length)];
      } else if (needsTarget) {
        target = _ai.bestTarget(bot, state!.players, difficulty);
      }
      final log = _eg.applyAbility(bot, state!.players, state!.terrainLayout, target: target);
      if (log == 'draw_dark' || log == 'draw_light') {
        // Monkey Raph / Élise : piocher ET résoudre immédiatement pour le bot
        // (humanDrawCard() laisse la partie en attente d'un clic "Appliquer"
        // qui ne viendra jamais pour un bot — ça figeait le jeu).
        final deck = log == 'draw_dark' ? DeckType.tenebres : DeckType.lumiere;
        state!.peioReturnToMove = true;
        if (log == 'draw_dark') state!.abilityOverlay = 'monkey_demon_eyes';
        final card = _eg.drawCard(deck, forcedQueue: state!.forcedDeckQueue);
        _log(log == 'draw_dark'
            ? '🐒 ${bot.name} pioche une carte Ténèbres : ${card.name}'
            : '⛪ ${bot.name} pioche une carte Lumière : ${card.name}', cls: 'player');
        if (_ai.shouldApplyCard(card, bot, difficulty)) {
          Player? cardTarget;
          if (_cardNeedsTarget(card.effect)) {
            cardTarget = _ai.bestTarget(bot, state!.players, difficulty, context: card.effect);
          }
          if (cardTarget != null || !_cardNeedsTarget(card.effect)) {
            final res = _eg.resolveCard(card, bot, state!.players, state!.terrainLayout, target: cardTarget);
            if (res['needsTarget'] != true) {
              _log(res['log'] as String);
              final justDied = state!.players.where((x) => !x.alive).toList();
              if (justDied.isEmpty) { _checkWin(); }
              else { for (final d in justDied) { _checkWin(justDiedId: d.uid); } }
            }
          }
        }
        notifyListeners();
        if (state!.isOver) { state!.botThinking = false; notifyListeners(); return; }
        // IMPORTANT : consommer le flag ici, sinon il reste bloqué à true et
        // pollue le tour de N'IMPORTE QUEL joueur suivant (même sans rapport
        // avec Monkey Raph/Élise) — ça faisait relancer les dés et se
        // redéplacer une 2e fois après avoir simplement pioché une carte
        // normale sur un terrain.
        state!.peioReturnToMove = false;
        // Le tour continue normalement (déplacement) — pas de return ici.
      } else if (log == 'damien_target_chosen' && target != null) {
        // Damien (bot) : choisit algorithmiquement — alcool si ça peut tuer,
        // sinon poison (dégâts totaux plus élevés sur la durée).
        final remainingHp = (target.character?.hp ?? 12) - target.wounds;
        final String resolveLog;
        if (remainingHp <= 4) {
          resolveLog = _eg.damienServeAlcohol(bot, target);
        } else {
          resolveLog = _eg.damienServePoison(bot, target);
        }
        _log(resolveLog);
      } else if (log.startsWith('tommy_copied:')) {
        // Tommy (bot) : le pouvoir copié se déclenche immédiatement si besoin
        final parts = log.split(':');
        _log('🎭 ${bot.name} copie le pouvoir de ${parts.length > 1 ? parts[1] : "?"}');
        if (bot.copiedEffect == 'builder_power') {
          state!.builderStep = 1;
          state!.builderEffect1 = null;
          state!.builderEffect2 = null;
          state!.builderOffered = _eg.builderDraw3();
          // Choix simple pour le bot : garde le 1er effet proposé aux 2 étapes
          final firstOffer = List<String>.from(state!.builderOffered);
          if (firstOffer.isNotEmpty) {
            clemenceChooseEffect(firstOffer.first);
            if (state!.builderStep == 2 && state!.builderOffered.isNotEmpty) {
              clemenceChooseEffect(state!.builderOffered.first);
            }
            if (state!.builderStep == 3 && state!.pendingTargetAction == 'clemence_target') {
              final t = _ai.bestTarget(bot, state!.players, difficulty);
              if (t != null) clemenceApplyToTarget(t);
            }
          }
        } else if (bot.copiedEffect == 'prophete_mark') {
          // Le bot marque directement le meilleur adversaire trouvé
          final markTarget = _ai.bestTarget(bot, state!.players, difficulty);
          if (markTarget != null) {
            jeanneChooseTarget(markTarget.uid);
            final rewards = List<String>.from(state!.builderOffered);
            if (rewards.isNotEmpty) jeanneChooseReward(rewards.first);
          }
        }
      } else if (log != 'cible_requise') {
        _log(log);
      }
      _checkWin();
    }
    notifyListeners();
    if (state!.isOver) { state!.botThinking = false; notifyListeners(); return; }

    // Déplacement
    await Future.delayed(d);
    final roll = _eg.rollMove();
    final sum = roll['sum']!;
    int zoneIdx;
    if (sum == 7) {
      zoneIdx = _ai.bestZone(bot, state!.players, state!.terrainLayout, difficulty);
    } else {
      final tid = _eg.sumToTerrainId(sum);
      zoneIdx = tid != null ? _eg.terrainLayoutIdx(state!.terrainLayout, tid) : (bot.zoneIndex + 1) % 6;
      if (zoneIdx == -1 || zoneIdx == bot.zoneIndex) zoneIdx = (bot.zoneIndex + 1) % 6;
    }
    bot.zoneIndex = zoneIdx;
    _log('🚶 ${bot.name} → ${state!.terrainLayout[zoneIdx].name}');
    notifyListeners();

    // Effet terrain
    await Future.delayed(d);
    final terrain = state!.terrainLayout[bot.zoneIndex];
    if (terrain.effect == 'choice') {
      final deck = _ai.bestDeck(bot, difficulty);
      state!.pendingCard = _eg.drawCard(deck, forcedQueue: state!.forcedDeckQueue);
      state!.pendingCardIsSecret = (deck == DeckType.vision);
    } else if (terrain.effect == 'vision')   {
      state!.pendingCard = _eg.drawCard(DeckType.vision, forcedQueue: state!.forcedDeckQueue);
      state!.pendingCardIsSecret = true;
    } else if (terrain.effect == 'lumiere')  {
      state!.pendingCard = _eg.drawCard(DeckType.lumiere, forcedQueue: state!.forcedDeckQueue);
      state!.pendingCardIsSecret = false;
    } else if (terrain.effect == 'tenebres') {
      state!.pendingCard = _eg.drawCard(DeckType.tenebres, forcedQueue: state!.forcedDeckQueue);
      state!.pendingCardIsSecret = false;
    }
    else if (terrain.effect == 'damage9')    {
      final t = _ai.bestTarget(bot, state!.players, difficulty);
      if (t != null) { _eg.applyDamage(t, 2, isTerrain9Dmg: true); _log('🏹 ${bot.name} inflige 2 à ${t.name}'); _checkWin(justDiedId: t.alive?null:t.uid); }
    }
    else if (terrain.effect == 'steal') {
      final t = _ai.bestTarget(bot, state!.players, difficulty, context: 'steal');
      if (t != null && t.equipment.isNotEmpty) {
        final e = t.equipment.removeAt(_rng.nextInt(t.equipment.length));
        bot.equipment.add(e); _log('🗼 ${bot.name} vole "${e.name}" à ${t.name}');
      }
    }
    if (state!.pendingCard != null) {
      // Vision card details are secret — only log damage results after apply
    }
    notifyListeners();
    if (state!.isOver) { state!.botThinking = false; notifyListeners(); return; }

    // Carte
    if (state!.pendingCard != null) {
      await Future.delayed(d);
      final card = state!.pendingCard!;
      if (_ai.shouldApplyCard(card, bot, difficulty)) {
        Player? target;
        if (_cardNeedsTarget(card.effect)) {
          target = _ai.bestTarget(bot, state!.players, difficulty, context: card.effect);
        }
        if (target != null || !_cardNeedsTarget(card.effect)) {
          final res = _eg.resolveCard(card, bot, state!.players, state!.terrainLayout, target: target);
          if (res['needsTarget'] != true) {
            final vlog = res['log'] as String;
            // Pour les cartes vision, ne loguer que le résultat (pas le contenu)
            _log(vlog);
            _checkWin();
          }
        }
      }
      state!.pendingCard = null;
      notifyListeners();
      if (state!.isOver) { state!.botThinking = false; notifyListeners(); return; }
    }

    // Attaque
    await Future.delayed(d);
    if (_ai.shouldAttack(bot, state!.players, state!.terrainLayout, difficulty)) {
      final targets = _eg.attackTargets(bot, state!.players, state!.terrainLayout);
      final target = _ai.bestTarget(bot, targets, difficulty, context: 'attack');
      if (target != null) {
        final eff = bot.copiedEffect ?? bot.character?.abilityEffect;
        int dmg;
        if (eff == 'double_attack_if_tanky' && target.revealed && target.character!.hp >= 13) {
          // 🥭 Mango Loco : cible costaude → double lancer, dégâts additionnés
          final rA = _eg.rollAttack(); final rB = _eg.rollAttack();
          dmg = rA['damage']! + rB['damage']!;
        } else {
          final roll2 = _eg.rollAttack();
          dmg = roll2['damage']!;
        }
        // Ne PAS ajouter lance/lanceLonginus/dague ici : resolveAttack() les
        // applique déjà en interne. Les ajouter aussi ici les comptait EN
        // DOUBLE pour Lance de Lumière et la Dague, et la Lance de Longinus
        // manquait carrément de ce calcul manuel (elle restait correcte,
        // mais seule, ce qui semblait "trop faible" comparée aux autres).
        bot.attackCount++; // sinon le bonus de Mathieu ne se déclenche jamais pour un bot
        final attackRes = _eg.resolveAttack(bot, target, dmg);
        final log = attackRes['log'] as String;
        _log(log);
        if (attackRes['scottCountered'] == true) state!.abilityOverlay = 'scott_counter';
        if (!target.alive) { _log('💀 ${target.name} est éliminé !', cls: 'death'); }
        state!.woundFlashUid = target.uid;
        Future.delayed(const Duration(milliseconds: 800), () {
          if (state != null) { state!.woundFlashUid = null; }
        });
        _checkWin(justDiedId: target.alive ? null : target.uid);
      }
    }
    notifyListeners();
    if (state!.isOver) { state!.botThinking = false; notifyListeners(); return; }

    // Tour supp
    if (bot.newTurn) {
      bot.newTurn = false; _log('⏰ ${bot.name} rejoue !');
      notifyListeners();
      final r2 = _eg.rollMove(); final s2 = r2['sum']!;
      final tid2 = _eg.sumToTerrainId(s2);
      int z2 = tid2 != null ? _eg.terrainLayoutIdx(state!.terrainLayout, tid2) : (bot.zoneIndex+1)%6;
      if (z2 == -1 || z2 == bot.zoneIndex) z2 = (bot.zoneIndex+1)%6;
      bot.zoneIndex = z2; _log('🚶 ${bot.name} → ${state!.terrainLayout[z2].name}');
    }

    _log('⏩ ${bot.name} termine son tour', cls: 'bot');
    state!.botThinking = false; notifyListeners();
    await Future.delayed(const Duration(milliseconds: 400));
    await nextTurn();
  }

  // ─── Actions humain ──────────────────────
  // Wrapper applyDamage avec son
  int _applyDmgAudio(Player p, int n, {bool isTenebresCard = false}) {
    final dealt = _eg.applyDamage(p, n, isTenebresCard: isTenebresCard);
    if (dealt > 0) audio.playDamage();
    return dealt;
  }

  void humanReveal() {
    final p = state!.current; p.revealed = true;
    state!.pendingRevealAnimation = p.uid;
    audio.playReveal();
    _log('🃏 ${p.name} révèle : ${p.character!.name}', cls: 'player');
    // Clémence : démarrer le pouvoir constructeur juste après la révélation
    if (p.character?.abilityEffect == 'builder_power') {
      state!.builderStep = 1;
      state!.builderEffect1 = null;
      state!.builderEffect2 = null;
      state!.builderOffered = _eg.builderDraw3();
    }
    // Jeanne : démarrer le marquage juste après la révélation
    if (p.character?.abilityEffect == 'prophete_mark') {
      state!.jeanneStep = 1;
      state!.jeanneUid = p.uid;
      state!.pendingTargetAction = 'jeanne_mark_target';
      state!.phase = GamePhase.chooseTarget;
    }
    notifyListeners();
  }

  /// Jason (Caméléon) : se révèle en affichant le nom/icône d'un personnage
  /// (Hunter ou Shadow) actuellement en jeu, au lieu de sa vraie identité.
  /// Clémence : choix d'un effet au tour 1 ou 2.
  /// Jeanne étape 1 : choisit le joueur à marquer.
  /// Jeanne étape 1 : choisit le joueur à marquer.
  void jeanneChooseTarget(String targetUid) {
    final s = state!;
    s.markedPlayerUid = targetUid;
    // Préparer 3 récompenses pour l'étape 2 (affichées dans le widget)
    s.builderOffered = _eg.jeanneDraw3(); // réutilise builderOffered comme liste temporaire
    s.jeanneStep = 2;
    s.pendingTargetAction = null;
    s.phase = GamePhase.ability; // retour phase capacité pour afficher le widget récompense
    notifyListeners();
  }

  /// Jeanne étape 2 : choisit secrètement la récompense.
  void jeanneChooseReward(String reward) {
    final s = state!;
    final jeanne = s.current;
    s.jeanneReward = reward;
    s.jeanneUid = jeanne.uid; // IMPORTANT : mémoriser l'uid de Jeanne pour le soin de 3
    jeanne.abilityUsed = true;
    s.jeanneStep = 0;
    s.builderOffered = [];
    s.phase = GamePhase.move;
    _log('🔮 ${jeanne.name} marque un joueur — récompense secrète posée !', cls: 'player');
    notifyListeners();
  }

  /// Appelé après checkWin/applyDeathPassives : vérifie si un mort était
  /// marqué par Jeanne et distribue la récompense au tueur.
  void _checkJeanneMark(Player dead) {
    final reward = state!.jeanneReward;
    final jeanneUid = state!.jeanneUid;
    final markedUid = state!.markedPlayerUid;
    if (reward == null || markedUid == null || dead.uid != markedUid) return;
    // killedByUid peut être null si la mort vient d'une carte/effet indirect
    // — on attribue la récompense au joueur dont c'est le tour
    final killerUid = dead.killedByUid ?? state!.current.uid;
    final killer = state!.players.firstWhere(
        (p) => p.uid == killerUid, orElse: () => state!.current);
    final (log, needsCard) = _eg.applyJeanneReward(
        reward, killer, dead, state!.players);
    // Jeanne se soigne de 3 si encore vivante
    if (jeanneUid != null) {
      final jeanne = state!.players.firstWhere(
          (p) => p.uid == jeanneUid, orElse: () => state!.players.first);
      if (jeanne.alive) _eg.applyHeal(jeanne, 3);
    }
    if (log.isNotEmpty) _log(log, cls: 'important');
    // Cas spéciaux nécessitant une pioche de carte
    if (needsCard && reward == 'heal3_lumiere') {
      state!.pendingCard = _eg.drawCard(DeckType.lumiere, forcedQueue: state!.forcedDeckQueue);
      state!.phase = GamePhase.cardDrawn;
    }
    if (needsCard && reward == 'draw_vision') {
      state!.pendingCard = _eg.drawCard(DeckType.vision, forcedQueue: state!.forcedDeckQueue);
      state!.phase = GamePhase.cardDrawn;
    }
    // Effacer le marquage
    state!.markedPlayerUid = null;
    state!.jeanneReward = null;
  }

  /// Résout le choix d'équipement (vol ou don) après une carte peau_banane/pince_attrape.
  /// Richard II : sélection d'une zone (étape 1 ou 2).
  void humanChooseSwapZone(int zoneIdx) {
    final s = state!;
    if (s.swapZone1 == null) {
      // Étape 1 — première zone choisie
      s.swapZone1 = zoneIdx;
      s.pendingTargetAction = 'swap_zone_pick2';
      _log('👑 Zone ${zoneIdx + 1} sélectionnée — choisissez la 2ème zone', cls: 'player');
      notifyListeners();
    } else {
      // Étape 2 — deuxième zone choisie, on applique l'échange
      final z1 = s.swapZone1!;
      final z2 = zoneIdx;
      if (z1 == z2) {
        _log('👑 Choisissez une zone différente !', cls: 'player');
        notifyListeners(); return;
      }
      final (log, richardActivatesZone) = _eg.swapTerrainZones(z1, z2, s.players, s.terrainLayout, s.current);
      _log(log, cls: 'player');
      s.swapZone1 = null; s.swapZone2 = null;
      s.pendingTargetAction = null;
      // Richard II active l'effet du terrain qui vient d'arriver sur SA
      // case de départ (celui avec lequel il a échangé), pas celui qu'il a
      // emporté avec lui en se déplaçant.
      s.abilityOverlay = 'richard2_swap';
      humanApplyTerrainEffect(nextPhaseIfDefault: GamePhase.attack, zoneOverride: richardActivatesZone);
      notifyListeners();
    }
  }

  /// humanEndTurn avec gestion des tours bonus du Ninja.
  Future<void> humanEndTurn() async {
    final s = state!;
    if (s.bonusTurnsRemaining > 0) {
      s.bonusTurnsRemaining--;
      _log('🥷 Ninja rejoue ! (${s.bonusTurnsRemaining} tour(s) restant(s))', cls: 'player');
      s.phase = GamePhase.move;
      s.hasAttackedThisTurn = false;
      notifyListeners(); return;
    }
    await _humanEndTurnInternal();
  }


  void humanResolveEquipChoice(int equipIdx) {
    final mode = state!.equipChoiceMode ?? 'steal';
    final actorUid = state!.equipChoiceActorUid;
    final targetUid = state!.equipChoiceTargetUid;
    if (actorUid == null || targetUid == null) return;
    final actor = state!.players.firstWhere((p) => p.uid == actorUid);
    final target = state!.players.firstWhere((p) => p.uid == targetUid);
    final log = _eg.resolveEquipChoice(mode, actor, target, equipIdx);
    _log(log, cls: 'player');
    state!.equipChoiceMode = null;
    state!.equipChoiceActorUid = null;
    state!.equipChoiceTargetUid = null;
    state!.pendingTargetAction = null;
    state!.pendingCard = null;
    state!.phase = _postCardPhase();
    _checkWin(); notifyListeners();
  }

  void clemenceChooseEffect(String eff) {
    final s = state!;
    if (s.builderStep == 1) {
      s.builderEffect1 = eff;
      s.builderStep = 2;
      s.builderOffered = _eg.builderDraw3(exclude: eff);
    } else if (s.builderStep == 2) {
      s.builderEffect2 = eff;
      final e1 = s.builderEffect1!;
      // Vérifier si une cible est nécessaire
      if (_eg.builderCombinedNeedsTarget(e1, eff)) {
        s.builderStep = 3;
        s.builderOffered = [];
        s.pendingTargetAction = 'clemence_target';
        s.phase = GamePhase.chooseTarget;
      } else {
        // Tout est AoE : appliquer directement
        _applyBuilderCombo(null);
      }
    }
    notifyListeners();
  }

  /// Clémence : résolution après sélection de cible (builderStep==3).
  void clemenceApplyToTarget(Player target) {
    _applyBuilderCombo(target);
  }

  void _applyBuilderCombo(Player? target) {
    final s = state!;
    final p = s.current;
    final e1 = s.builderEffect1!;
    final e2 = s.builderEffect2!;
    // Effet 1
    final log1 = _eg.applyBuilderEffect(e1, p, target, s.players, s.terrainLayout);
    // Effet 2 — si la cible du premier est morte et que le 2ème la cible, on passe null
    final t2 = (target != null && !target.alive && _eg.builderNeedsTarget(e2)) ? null : target;
    final log2 = _eg.applyBuilderEffect(e2, p, t2, s.players, s.terrainLayout);
    if (log1.isNotEmpty) _log(log1, cls: 'player');
    if (log2.isNotEmpty) _log(log2, cls: 'player');
    _eg.applyDeathPassives(s.players);
    // Réinitialiser le builder
    s.builderStep = 0; s.builderEffect1 = null; s.builderEffect2 = null;
    s.builderOffered = []; s.pendingTargetAction = null;
    s.phase = GamePhase.move;
    p.abilityUsed = true;
    _checkWin(justDiedId: target != null && !target.alive ? target.uid : null);
    notifyListeners();
  }

  void humanRevealAsDisguise(CharacterCard disguise) {
    final p = state!.current; p.revealed = true;
    p.disguiseNameOverride = disguise.name;
    p.disguiseIconOverride = disguise.icon;
    p.disguiseFactionOverride = disguise.faction.name;
    p.disguiseCharIdOverride = disguise.id; // pour afficher la carte complète
    state!.pendingRevealAnimation = p.uid;
    audio.playReveal();
    _log('🃏 ${p.name} révèle : ${disguise.name}', cls: 'player'); notifyListeners();
  }

  void humanUseAbility({Player? target, String? passive}) {
    final p = state!.current;
    final s = state!;
    final eff = p.copiedEffect ?? p.character?.abilityEffect ?? '';

    switch (eff) {
      // ── Albane: double dés géré dans la phase move ──
      case 'double_move_dice':
        s.abilityOverlay = 'albane_clock';
        s.hasDoubleMove = true;
        p.abilityUsed = true;
        _log('⏳ Albane — double lancé de dés activé', cls: 'player');
        s.phase = GamePhase.move; notifyListeners(); return;

      // ── Amélia : 2 dmg tous Shadows révélés + 2 soins tous Hunters révélés ──
      case 'ally_sacrifice_heal':
        s.abilityOverlay = 'amelia_light';
        int shadowsHit = 0; int huntersHealed = 0;
        for (final x in s.players) {
          if (!x.alive || !x.revealed) continue;
          if (x.character?.faction == Faction.shadow) { _eg.applyDamage(x, 2); shadowsHit++; }
          else if (x.character?.faction == Faction.hunter) { _eg.applyHeal(x, 2); huntersHealed++; }
        }
        p.abilityUsed = true;
        _log('🌸 Amélia — $shadowsHit Shadow(s) subissent 2, $huntersHealed Hunter(s) soignés de 2', cls: 'player');

      // ── Artcade: 2 dégâts zone 6 — actif répétable ──
      case 'aoe_zone6':
        final idx6 = _eg.terrainLayoutIdx(s.terrainLayout, 2);
        int hit6 = 0;
        for (final x in s.players) {
          if (x.alive && x.uid != p.uid && x.zoneIndex == idx6) {
            _eg.applyDamage(x, 2); hit6++;
          }
        }
        s.abilityOverlay = 'artcade_flames';
        p.abilityUsed = false; // répétable chaque tour
        s.pendingTargetAction = null;
        _log('🐉 Art\'Cade enflamme la zone 6 — $hit6 joueur(s) subissent 2 blessures !', cls: 'player');
        _checkWin();
        s.phase = GamePhase.move; notifyListeners(); return;

      // ── Captain Ricard: s'inflige des blessures pour soigner un mort/vivant ──
      case 'sacrifice_heal_dead':
        if (target == null) { s.pendingTargetAction = 'ability_captain_ricard'; s.phase = GamePhase.chooseTarget; notifyListeners(); return; }
        final cost = 3;
        _eg.applyDamage(p, cost);
        _eg.applyHeal(target, cost);
        if (!target.alive) { target.alive = true; target.wounds = target.character!.hp - cost; _log('🍾 Captain Ricard ressuscite ${target.name}!', cls: 'player'); }
        else { _log('🍾 Captain Ricard subit $cost pour soigner ${target.name} de $cost', cls: 'player'); }
        p.abilityUsed = true;

      // ── Elaia: force révélation + 1 blessure ──
      case 'force_reveal_damage1':
        if (target == null) { s.pendingTargetAction = 'ability_elaia'; s.phase = GamePhase.chooseTarget; notifyListeners(); return; }
        target.revealed = true; _eg.applyDamage(target, 1);
        p.abilityUsed = true;
        _log('🔮 Elaia révèle ${target.name} et lui inflige 1', cls: 'player');

      // ── Luc & Peintre: choisir une capacité passive ──
      case 'choose_passive':
      case 'pay2_give_passive':
        if (passive != null) {
          if (eff == 'pay2_give_passive') _eg.applyDamage(p, 2);
          s.lucPassive = passive;
          p.abilityUsed = true;
          _log('🎭 ${p.name} choisit : $passive', cls: 'player');
        }

      // ── Océane: D4 soigne tout le monde SAUF 1 joueur au choix ──
      case 'd4_heal_neighbors':
        if (target == null) { s.pendingTargetAction = 'ability_oceane'; s.phase = GamePhase.chooseTarget; notifyListeners(); return; }
        final d = _eg.rollD4();
        int healedCount = 0;
        for (final pl in s.players) {
          if (pl.alive && pl.uid != target.uid) { _eg.applyHeal(pl, d); healedCount++; }
        }
        p.abilityUsed = true;
        s.pendingTargetAction = null;
        s.abilityOverlay = 'oceane_notes';
        s.abilityDiceResult = {'d': 4, 'result': d, 'dmg': -d};
        _log('🌊 Océane lance D4($d) — soigne $healedCount joueur(s) (sauf ${target.name})', cls: 'player');

      // ── Marion: place un joueur à 5 blessures (dans les deux sens) ──
      // ── Damien : sert un verre — nécessite une cible puis un choix ──
      case 'damien_serve':
        if (target == null) { s.pendingTargetAction = 'ability_damien'; s.phase = GamePhase.chooseTarget; notifyListeners(); return; }
        p.abilityUsed = true;
        s.pendingTargetAction = null;
        s.damienTargetUid = target.uid;
        s.phase = GamePhase.ability;
        _log('🍸 ${p.name} prépare un verre pour ${target.name}…', cls: 'player');
        notifyListeners(); return;

      // ── Tommy : copie le pouvoir d'un joueur révélé ──
      case 'copy_ability':
        if (target == null) { s.pendingTargetAction = 'ability_tommy'; s.phase = GamePhase.chooseTarget; notifyListeners(); return; }
        p.copiedEffect = target.character!.abilityEffect;
        p.abilityUsed = !target.character!.abilityRepeatable;
        s.pendingTargetAction = null;
        _log('🎭 ${p.name} copie le pouvoir de ${target.name} : ${target.character!.ability}', cls: 'player');
        // Certains pouvoirs se déclenchent normalement à la révélation — pour
        // Tommy (déjà révélé), on les déclenche immédiatement après la copie.
        if (p.copiedEffect == 'builder_power') {
          s.builderStep = 1;
          s.builderEffect1 = null;
          s.builderEffect2 = null;
          s.builderOffered = _eg.builderDraw3();
          s.phase = GamePhase.ability; notifyListeners(); return;
        }
        if (p.copiedEffect == 'prophete_mark') {
          s.jeanneStep = 1;
          s.jeanneUid = p.uid;
          s.pendingTargetAction = 'jeanne_mark_target';
          s.phase = GamePhase.chooseTarget; notifyListeners(); return;
        }
        s.phase = GamePhase.move; notifyListeners(); return;

      case 'set_wounds5':
        if (target == null) { s.pendingTargetAction = 'ability_set5'; s.phase = GamePhase.chooseTarget; notifyListeners(); return; }
        final before = target.wounds;
        target.wounds = 5;
        if (target.wounds >= target.character!.hp) target.alive = false;
        p.abilityUsed = true;
        s.pendingTargetAction = null;
        s.abilityOverlay = 'marion_plants';
        final diff = 5 - before;
        if (diff > 0) {
          _log('📍 Marion place ${target.name} à 5 blessures (subit $diff)', cls: 'player');
        } else if (diff < 0) {
          _log('📍 Marion place ${target.name} à 5 blessures (soigné de ${-diff})', cls: 'player');
        } else {
          _log('📍 Marion place ${target.name} à 5 blessures (déjà à 5)', cls: 'player');
        }
        _checkWin(justDiedId: target.alive ? null : target.uid);
        s.phase = GamePhase.move; notifyListeners(); return;

      // ── Cupidon: lie 2 joueurs ──
      case 'link_two_players':
        if (target == null) { s.pendingTargetAction = 'ability_cupidon'; s.phase = GamePhase.chooseTarget; notifyListeners(); return; }
        s.linkedUid1 = p.uid; s.linkedUid2 = target.uid; s.linkedTurnsLeft = 2;
        p.abilityUsed = true;
        _log('💘 Cupidon lie ${p.name} et ${target.name} pour 1 tour !', cls: 'player');

      // ── Raph du soleil levant ──
      case 'damage2_then_heal3':
        if (target == null) { s.pendingTargetAction = 'ability_raph_heal'; s.phase = GamePhase.chooseTarget; notifyListeners(); return; }
        _eg.applyDamage(p, 2); _eg.applyHeal(target, 3);
        p.abilityUsed = true;
        s.pendingTargetAction = null;
        s.abilityOverlay = 'raph_petals';
        _log('🥷 Raph subit 2 et soigne ${target.name} de 3', cls: 'player');
        _checkWin(justDiedId: p.alive ? null : p.uid);
        // Si Raph est mort en utilisant sa capacité, on passe au tour suivant
        if (!p.alive) { humanEndTurn(); return; }
        s.phase = GamePhase.move; notifyListeners(); return;

      // ── Mère Christine: copie Lumière sur allié ──
      case 'lumiere_copy':
        // Passif géré dans humanApplyCard
        p.abilityUsed = false; // passif permanent
        _log('✨ Mère Christine — copie active sur prochain Lumière', cls: 'player');

      // ── Commandante Marion ──
      case 'move_player_or_cancel_equip':
        if (target == null) { s.pendingTargetAction = 'ability_cmd_marion'; s.phase = GamePhase.chooseTarget; notifyListeners(); return; }
        final adj = kAdjacences[target.zoneIndex];
        if (adj.isNotEmpty) target.zoneIndex = adj[_rng.nextInt(adj.length)];
        p.abilityUsed = true;
        _log('🎯 Commandante Marion déplace ${target.name}', cls: 'player');

      // ── Vlad Princesse: protège un joueur ──
      case 'intercept_attack':
        if (target == null) { s.pendingTargetAction = 'ability_vlad_pr'; s.phase = GamePhase.chooseTarget; notifyListeners(); return; }
        s.shieldTargetUid = target.uid;
        _log('👸 Vlad Princesse protège ${target.name} (−1 dégât)', cls: 'player');

      // ── Jason Espion: pioche Vision à dégâts doublés ──
      case 'double_vision_damage':
        s.phase = GamePhase.chooseTarget; s.pendingTargetAction = 'ability_jason_espion';
        notifyListeners(); return;

      // ── Prêtresse Raph: pioche Lumière de son choix ──
      case 'fetch_lumiere':
        p.abilityUsed = true;
        s.phase = GamePhase.cardDrawn;
        s.pendingCard = _eg.drawCard(DeckType.lumiere, forcedQueue: s.forcedDeckQueue);
        _log('🙏 Prêtresse Raph choisit une carte Lumière', cls: 'player');
        notifyListeners(); return;

      // ── Voiture de Clem: échange de place ──
      case 'swap_position':
        if (target == null) { s.pendingTargetAction = 'ability_voiture'; s.phase = GamePhase.chooseTarget; notifyListeners(); return; }
        final tmp = p.zoneIndex; p.zoneIndex = target.zoneIndex; target.zoneIndex = tmp;
        p.abilityUsed = true;
        _log('🚗 Voiture de Clem échange avec ${target.name}', cls: 'player');
        s.skipMovement = true; // a déjà bougé
        s.phase = GamePhase.zoneEffect; notifyListeners(); return;

      // ── Soubrette Marin: défausse tous les équipements ──
      case 'discard_all_equip':
        for (final x in s.players) x.equipment.clear();
        p.abilityUsed = true;
        _log('🧹 Soubrette Marin — tous les équipements défaussés !', cls: 'player');

      // ── Baleine: passif mort → géré dans _checkWin ──
      case 'death_heal_allies':
        // Unique actif: soigne tous les Hunters révélés de 2
        final alliesRevealed = s.players.where((x) =>
          x.alive && x.revealed && x.character!.faction == Faction.hunter).toList();
        for (final h in alliesRevealed) _eg.applyHeal(h, 2);
        p.abilityUsed = true; // unique = une seule fois
        _log('🐋 Baleine — ${alliesRevealed.length} Hunter(s) révélé(s) soignés de 2 !', cls: 'player');
        s.phase = GamePhase.move; notifyListeners(); return;

      // ── Fifi Hiver: gèle un joueur ──
      case 'force_d4_move':
        if (target == null) { s.pendingTargetAction = 'ability_fifi_hiver'; s.phase = GamePhase.chooseTarget; notifyListeners(); return; }
        target.frozen = true;
        p.abilityUsed = true;
        _log('❄️ Fifi Hiver gèle ${target.name} pour 1 tour !', cls: 'player');

      // ── Richard II: échange de terrains ──
      case 'swap_terrains':
        if (target == null) { s.pendingTargetAction = 'ability_richard2'; s.phase = GamePhase.chooseTarget; notifyListeners(); return; }
        final myZone = p.zoneIndex; final theirZone = target.zoneIndex;
        // Échange les terrains (pas les joueurs)
        final tmpT = s.terrainLayout[myZone];
        s.terrainLayout[myZone] = s.terrainLayout[theirZone];
        s.terrainLayout[theirZone] = tmpT;
        p.abilityUsed = true;
        _log('🔀 Richard II échange les terrains ${tmpT.num} et ${s.terrainLayout[myZone].num}', cls: 'player');
        // Active l'effet du terrain échangé
        humanApplyTerrainEffect(); return;

      // ── Demi-sel: reste sur place → réactive terrain ──
      case 'stay_retrigger_terrain':
        s.skipMovement = true;
        _log('🧂 Demi-sel reste sur place', cls: 'player');
        humanApplyTerrainEffect(); return;

      // ── Peio Shadow: subit 1 → réactive terrain (équipement inclus) ──
      case 'self1_trigger_terrain':
        _eg.applyDamage(p, 1);
        _log('🧌 Peio subit 1 → réactive l\'effet du terrain', cls: 'player');
        state!.peioReturnToMove = true;
        humanApplyTerrainEffect(nextPhaseIfDefault: GamePhase.move); return;

      // ── Mango Loco: pioche sur hit → passif, dual target à l'attaque ──
      case 'draw_on_hit_dual_target':
        p.abilityUsed = false; // passif
        _log('🥭 Mango Loco — peut cibler 2 personnages', cls: 'player');

      // ── Baptiste: reçoit un pouvoir aléatoire Hunter non joué ──
      case 'copy_hunter_ability':
        final unused = kAllCharacters.where((c) =>
          c.faction == Faction.hunter &&
          !s.players.any((x) => x.character?.id == c.id)).toList();
        if (unused.isNotEmpty) {
          final chosen = unused[_rng.nextInt(unused.length)];
          p.copiedEffect = chosen.abilityEffect;
          p.abilityUsed = true;
          _log('📖 Baptiste copie le pouvoir de ${chosen.name} : ${chosen.ability}', cls: 'player');
        }

      // ── Louna: insensible ce tour ──
      case 'shield3':
        p.shield = true; p.shieldCharges = 99; p.abilityUsed = true;
        s.abilityOverlay = 'louna_shield';
        _log('🐱 Louna est insensible ce tour !', cls: 'player');

      // ── Gège: passif combiné ──
      case 'team_attack':
        p.abilityUsed = false; // passif
        _log('👻 Gège — attaque double quand un allié attaque', cls: 'player');

      // ── Vladimir (Vlad Shadow): D4 AVANT de se déplacer, peut encore attaquer ──
      case 'd4_bonus_attack':
        if (target == null) {
          // Vérifier s'il y a des cibles adjacentes
          final vladTargets = _eg.attackTargets(p, s.players, s.terrainLayout);
          if (vladTargets.isEmpty) {
            _log('💨 Vlad — aucun joueur adjacent à portée.', cls: 'player');
            s.phase = GamePhase.move; notifyListeners(); return;
          }
          s.pendingTargetAction = 'ability_vladimir';
          s.phase = GamePhase.chooseTarget;
          notifyListeners(); return;
        }
        final dv = _eg.rollD4();
        final dealtVlad = _eg.applyDamage(target, dv);
        p.abilityUsed = false; // répétable chaque tour
        s.pendingTargetAction = null;
        s.abilityOverlay = 'vlad_mountain';
        s.abilityDiceResult = {'d': 4, 'result': dv, 'dmg': dealtVlad};
        _log('💨 Vlad lance D4($dv) → inflige $dealtVlad blessures à ${target.name} !', cls: 'player');
        _checkWin(justDiedId: target.alive ? null : target.uid);
        s.phase = GamePhase.move;
        notifyListeners(); return;

      // ── Elaia : prescience — choisir la pile à regarder ──
      case 'peek_reorder_deck':
        // Ne PAS forcer abilityUsed=false : ça permettait de relancer le
        // choix de pile en boucle dans le même tour. On verrouille jusqu'au
        // tour suivant (capacité répétable, réactivée automatiquement).
        p.abilityUsed = true;
        s.elaiaStep = 1;
        _log('🔮 ${p.name} active son pouvoir de prescience…', cls: 'player');
        notifyListeners(); return;

      // ── Monkey Raph: pioche ténèbres visible ──
      case 'draw_dark':
        humanDrawCard(DeckType.tenebres);
        p.abilityUsed = false; // répétable
        s.abilityOverlay = 'monkey_demon_eyes';
        s.peioReturnToMove = true; // retourner en déplacement après la carte
        _log('🐒 Monkey Raph pioche une carte Ténèbres', cls: 'player');
        notifyListeners(); return;

      // ── Richard II : échange de zones (répétable) ──
      case 'swap_zones':
        // Richard II échange sa propre zone avec une zone choisie
        s.swapZone1 = p.zoneIndex; // sa zone actuelle est automatiquement zone 1
        s.swapZone2 = null;
        s.phase = GamePhase.chooseTarget;
        s.pendingTargetAction = 'swap_zone_pick2'; // directement à l'étape 2
        _log('👑 Richard II choisit une zone avec laquelle échanger…', cls: 'player');
        notifyListeners(); return;

      // ── Ninja : tours bonus ──
      case 'bonus_turns':
        final deadCount = state!.players.where((pl) => !pl.alive).length;
        p.abilityUsed = true; // toujours consommer l'usage unique
        if (deadCount == 0) {
          _log('🥷 Ninja : aucun joueur mort, pouvoir sans effet.', cls: 'player');
          s.phase = GamePhase.move; notifyListeners(); return;
        }
        s.bonusTurnsRemaining = deadCount;
        _log('🥷 Ninja active son pouvoir — $deadCount tour(s) bonus !', cls: 'player');
        s.phase = GamePhase.move; notifyListeners(); return;

      // ── Julien: inflige 2 à une cible ──
      case 'damage2_or_heal1':
        if (target == null) { s.pendingTargetAction = 'ability_julien'; s.phase = GamePhase.chooseTarget; notifyListeners(); return; }
        _eg.applyDamage(target, 2);
        _log('🍳 Julien inflige 2 à ${target.name}', cls: 'player');
        _checkWin(justDiedId: target.alive ? null : target.uid);
        s.phase = GamePhase.move; notifyListeners(); return;

      // ── Marin Shadow: donne item → inflige 2 ──
      case 'trade_item_damage3':
        if (target == null) { s.pendingTargetAction = 'ability_marin_shadow'; s.phase = GamePhase.chooseTarget; notifyListeners(); return; }
        if (p.equipment.isEmpty) { _log('Marin — pas d\'équipement à donner', cls: 'player'); break; }
        final item = p.equipment.removeAt(0); target.equipment.add(item);
        _eg.equipPassivePublic(target, item);
        _eg.applyDamage(target, 2);
        _log('💰 Marin donne "${item.name}" à ${target.name} et inflige 2', cls: 'player');
        _checkWin(justDiedId: target.alive ? null : target.uid);
        s.phase = GamePhase.move; notifyListeners(); return;

      // ── Travert: D6 sur cible choisie ──
      case 'd6_global_attack':
        if (target == null) {
          s.pendingTargetAction = 'ability_travert';
          s.phase = GamePhase.chooseTarget; notifyListeners(); return;
        }
        final dt = _eg.rollD6();
        final dealtTr = _applyDmgAudio(target, dt);
        p.abilityUsed = true; // unique
        s.pendingTargetAction = null; // effacer avant dice pour éviter boucle
        s.abilityDiceResult = {'d': 6, 'result': dt, 'dmg': dealtTr};
        s.abilityOverlay = 'travert_shockwave';
        _log('🎲 Travert lance D6($dt) → inflige $dealtTr blessures à ${target.name} !', cls: 'player');
        _checkWin(justDiedId: target.alive ? null : target.uid);
        s.phase = GamePhase.move; notifyListeners(); return;

      // ── Raphaël Shadow: attaque répétée, miroir ──
      case 'mirror_damage':
        if (target == null) { s.pendingTargetAction = 'ability_raph_shadow'; s.phase = GamePhase.chooseTarget; notifyListeners(); return; }
        s.raphShadowMultiAtk = true; s.raphShadowTargetUid = target.uid; s.raphShadowTotalDmg = 0;
        p.abilityUsed = true;
        _log('⚔️ Raphaël Shadow cible ${target.name} — attaques libres (miroir)', cls: 'player');
        s.phase = GamePhase.attack; notifyListeners(); return;

      // ── Jazzon: inflige 1 ou vole un équipement ──
      case 'trade_banana_for_equip':
        if (target == null) { s.pendingTargetAction = 'ability_jazzon'; s.phase = GamePhase.chooseTarget; notifyListeners(); return; }
        _eg.applyDamage(target, 1);
        if (target.equipment.isNotEmpty) {
          final ej = target.equipment.removeAt(_rng.nextInt(target.equipment.length));
          p.equipment.add(ej); _eg.equipPassivePublic(p, ej); _eg.recalcPassives(target);
          _log('🎵 Jazzon inflige 1 à ${target.name} et vole "${ej.name}"', cls: 'player');
        } else {
          _log('🎵 Jazzon inflige 1 à ${target.name} (pas d\'équipement)', cls: 'player');
        }
        _checkWin(justDiedId: target.alive ? null : target.uid);
        s.phase = GamePhase.move; notifyListeners(); return;

      // ── Glads: récupère TOUS les équipements ──
      case 'gather_attack_redistribute':
        final allEquip = <GameCard>[];
        for (final x in s.players) { allEquip.addAll(x.equipment); x.equipment.clear(); }
        p.equipment.addAll(allEquip);
        for (final e in allEquip) _eg.equipPassivePublic(p, e);
        p.abilityUsed = true;
        _log('💥 Glads récupère ${allEquip.length} équipements de la partie !', cls: 'player');
        s.phase = GamePhase.move; notifyListeners(); return;

      // ── Hong Yi: choisit un joueur, inflige 8 ET subit 8 ──
      case 'terrain_max_aoe':
        if (target == null) {
          s.pendingTargetAction = 'ability_hong_yi';
          s.phase = GamePhase.chooseTarget; notifyListeners(); return;
        }
        _applyDmgAudio(target, 8);
        // Hong Yi meurt TOUJOURS après avoir utilisé son pouvoir
        p.wounds = p.character!.hp; p.alive = false;
        p.abilityUsed = true; // unique
        s.pendingTargetAction = null;
        s.abilityOverlay = 'hongyi_dumbbell';
        s.abilityDiceResult = {'d': 8, 'result': 8, 'dmg': 8};
        _log('⚡ Hong Yi inflige 8 à ${target.name} — et meurt de sa propre puissance !', cls: 'player');
        _checkWin(justDiedId: target.alive ? null : target.uid);
        _checkWin(justDiedId: p.uid); // Hong Yi est mort
        if (!s.isOver) { s.phase = GamePhase.move; }
        notifyListeners();
        return;

      // ── Ingénieur: empoisonne un joueur (−1 PV/tour) ──
      case 'poison_player':
        if (target == null) { s.pendingTargetAction = 'ability_ingenieur'; s.phase = GamePhase.chooseTarget; notifyListeners(); return; }
        target.poisoned = true;
        p.abilityUsed = true;
        _log('🔧 Ingénieur empoisonne ${target.name} (−1 PV/tour)', cls: 'player');
        s.phase = GamePhase.move; notifyListeners(); return;

      // ── Enceinte: inflige 3 à un joueur à la révélation ──
      case 'death_bomb_4dmg':
        if (target == null) { s.pendingTargetAction = 'ability_enceinte'; s.phase = GamePhase.chooseTarget; notifyListeners(); return; }
        _eg.applyDamage(target, 3);
        p.abilityUsed = true;
        _log('🔊 Enceinte révèle et inflige 3 à ${target.name} !', cls: 'player');
        _checkWin(justDiedId: target.alive ? null : target.uid);
        s.phase = GamePhase.move; notifyListeners(); return;

      // ── Jésus: ressuscite à 0 blessure (passif mort) ──
      case 'resurrect_once':
        if (!p.revived && !p.alive) {
          p.wounds = 0; p.alive = true; p.revived = true;
          _log('✝️ Jésus ressuscite à 0 blessures !', cls: 'player');
          s.phase = GamePhase.ability; notifyListeners(); return;
        }

      // ── Ninja: rejoue N tours (1 par mort) ──
      case 'extra_turn_per_death':
        final deaths = s.players.where((x) => !x.alive).length;
        if (deaths > 0) {
          s.ninjaExtraTurns = deaths;
          p.abilityUsed = true;
          _log('🥷 Ninja rejoue $deaths tour(s) !', cls: 'player');
          s.phase = GamePhase.move; notifyListeners(); return;
        }
        _log('Ninja — aucun mort pour le moment', cls: 'player');

      // ── Vache: passif révélé ──
      case 'reduce_all_by1':
        p.abilityUsed = false; // passif permanent
        _log('🐄 Vache révèle — −1 dégât reçu et infligé', cls: 'player');

      // ── Théo Homard: révélé dès la création, géré dans nextTurn ──
      case 'revealed_plus1_dmg':
        p.revealed = true; p.abilityUsed = false;
        _log('🦐 Théo Homard est révélé (+1 dégât)', cls: 'player');

      // ── Nina: rejoue un tour complet à la fin de ce tour ──
      case 'move_between_players':
        s.ninaTurnPending = true;
        p.abilityUsed = true;
        _log('😤 Nina va rejouer un tour complet après ce tour !', cls: 'player');
        s.phase = GamePhase.move; notifyListeners(); return;


      case 'heal_on_same_terrain':
        p.abilityUsed = false;
        s.abilityOverlay = 'augustin_wheat';
        _log('🌾 Augustin — passif: 7 aux dés = soigné de 2', cls: 'player');
        s.phase = GamePhase.move; notifyListeners(); return;

      case 'heal_per_equip_eot':
        p.abilityUsed = false;
        s.abilityOverlay = 'fijacked_city';
        _log('🏺 Fijacked — passif: soigné 1/équipement au début du tour', cls: 'player');
        s.phase = GamePhase.move; notifyListeners(); return;

      case 'heal2_same_hunter':
        p.abilityUsed = false;
        _log('🏡 Hailey — passif: +2 soins si Hunter voisin révélé', cls: 'player');
        s.phase = GamePhase.move; notifyListeners(); return;

      case 'tenebres_heal_instead':
        p.abilityUsed = false;
        _log('🧚 Bibble — passif: les Ténèbres vous soignent', cls: 'player');
        s.phase = GamePhase.move; notifyListeners(); return;

      case 'zero_wound_power':
        p.abilityUsed = false;
        _log('💢 Louise — passif: 0 dmg → 4, sinon +1', cls: 'player');
        s.phase = GamePhase.move; notifyListeners(); return;

      case 'third_attack_bonus':
        p.abilityUsed = false;
        _log('📊 Mathieu — passif: à partir de la 3ème attaque, +2 dégâts permanent', cls: 'player');
        s.phase = GamePhase.move; notifyListeners(); return;

      case 'casino_bet':
        s.pendingTargetAction = 'casino_bet';
        s.phase = GamePhase.chooseTarget;
        p.abilityUsed = false; // répétable
        notifyListeners(); return;

      case 'infinite_range':
        p.infiniteRange = true; p.abilityUsed = false;
        _log('🏴‍☠️ Pirate — portée infinie activée', cls: 'player');
        s.phase = GamePhase.move; notifyListeners(); return;

      case 'create_minion':
        _eg.applyDamage(p, 4); p.abilityUsed = true;
        _log('🌅 Vlad du Soleil Levant subit 4 — mini créé !', cls: 'player');
        s.phase = GamePhase.move; notifyListeners(); return;

      case 'choose_all_dice':
        s.fifiGoldenTurn = true; p.abilityUsed = true;
        _log('🍀 Fifi — tour parfait ! Choisissez vos valeurs de dés', cls: 'player');
        s.pendingTargetAction = 'fifi_dice_picker';
        s.phase = GamePhase.chooseTarget; notifyListeners(); return;

      case 'full_heal_shield_turn':
        p.wounds = 0; p.shield = true; p.shieldCharges = 99;
        s.abilityOverlay = 'cambou_sheep';
        _log('🌙 Cambou passe son tour — soigné et protégé !', cls: 'player');
        humanEndTurn(); return;

      // ── Léo: D4 infligé à TOUS les joueurs, lui inclus ──
      case 'd4_all':
        final dLeo = _eg.rollD4();
        final killedUids = <String>[];
        for (final x in s.players) {
          if (!x.alive) continue;
          final dealt = _applyDmgAudio(x, dLeo);
          if (!x.alive) killedUids.add(x.uid);
          if (dealt > 0 && x.uid != p.uid) {
            // rien de spécial, juste appliquer
          }
        }
        p.abilityUsed = true; // unique
        s.pendingTargetAction = null;
        s.abilityOverlay = 'leo_flames_all';
        s.abilityDiceResult = {'d': 4, 'result': dLeo, 'dmg': dLeo};
        _log('🔥 Léo lance D4($dLeo) — TOUS les joueurs (lui inclus) subissent $dLeo blessures !', cls: 'player');
        for (final uid in killedUids) _checkWin(justDiedId: uid);
        if (killedUids.isEmpty) _checkWin();
        s.phase = GamePhase.move; notifyListeners(); return;

      case 'heal1_on_own_attack':
        p.abilityUsed = false;
        _log("🐀 Rat d'Rouen — passif: +1 soin sur vos hits", cls: 'player');
        s.phase = GamePhase.move; notifyListeners(); return;

      case 'd6_lifesteal':
        if (target == null) {
          s.pendingTargetAction = 'ability_carapatte';
          s.phase = GamePhase.chooseTarget; notifyListeners(); return;
        }
        final dcL = _eg.rollD6();
        final dealtL = _applyDmgAudio(target, dcL);
        _eg.applyHeal(p, dealtL);
        p.abilityUsed = true; // UNIQUE
        s.pendingTargetAction = null; // effacer AVANT le dice result pour éviter la boucle
        s.abilityDiceResult = {'d': 6, 'result': dcL, 'dmg': dealtL};
        s.abilityOverlay = 'carapatte_food';
        _log('🐢 Carapatte lance D6($dcL) sur ${target.name} — inflige $dcL, se soigne de $dealtL', cls: 'player');
        _checkWin(justDiedId: target.alive ? null : target.uid);
        s.phase = GamePhase.move; notifyListeners(); return;

      // ── Tristan : échange un équipement avec un autre joueur ──
      case 'swap_equipment':
        if (target == null) {
          s.pendingTargetAction = 'ability_tristan';
          s.phase = GamePhase.chooseTarget; notifyListeners(); return;
        }
        final res = _eg.applyAbilityFull(p, s.players, s.terrainLayout, target: target);
        final logSwap = res['log'] as String? ?? '';
        if (logSwap.isNotEmpty) _log(logSwap, cls: 'player');
        s.pendingTargetAction = null;
        _checkWin();
        s.phase = GamePhase.move; notifyListeners(); return;

      // ── Marin : 3 dégâts + dague à la cible ──
      case 'damage3_give_dague':
        if (target == null) {
          s.pendingTargetAction = 'ability_marin';
          s.phase = GamePhase.chooseTarget; notifyListeners(); return;
        }
        final resMarin = _eg.applyAbilityFull(p, s.players, s.terrainLayout, target: target);
        final logMarin = resMarin['log'] as String? ?? '';
        if (logMarin.isNotEmpty) _log(logMarin, cls: 'player');
        s.pendingTargetAction = null;
        _checkWin();
        s.phase = GamePhase.move; notifyListeners(); return;

      // ── Default: délègue au moteur (toutes les capacités non listées ci-dessus) ──
      default:
        final res = _eg.applyAbilityFull(p, s.players, s.terrainLayout, target: target);
        final log = res['log'] as String? ?? '';
        final special = res['special'] as String?;
        // Spéciaux fréquents
        if (special == 'draw_dark')  { s.peioReturnToMove = true; humanDrawCard(DeckType.tenebres); return; }
        if (special == 'draw_light') { s.peioReturnToMove = true; humanDrawCard(DeckType.lumiere); return; }
        if (special == 'trigger_terrain') { humanApplyTerrainEffect(); return; }
        if (special == 'skip_move')       { s.skipMovement = true; s.phase = GamePhase.zoneEffect; notifyListeners(); return; }
        if (special == 'skip_turn')       { s.phase = GamePhase.attack; notifyListeners(); return; }
        if (res['needsTarget'] == true && target == null) {
          s.pendingTargetAction = 'ability_default_$eff';
          s.phase = GamePhase.chooseTarget; notifyListeners(); return;
        }
        if (log.isNotEmpty) _log(log, cls: 'player');
    }

    // Après toute capacité qui n'a pas explicitement changé la phase → déplacement
    if (state!.phase == GamePhase.ability) {
      state!.phase = GamePhase.move;
    }
    _checkWin(); notifyListeners();
  }

  /// Elaia étape 1 : choisit la pile à regarder (tenebres/lumiere/vision).
  void elaiaChooseDeck(String deckName) {
    final s = state!;
    final deck = DeckType.values.byName(deckName);
    final (c1, c2) = _eg.peekTwoCards(deck);
    s.elaiaStep = 2;
    s.elaiaDeck = deckName;
    s.elaiaCard1Id = c1.id;
    s.elaiaCard2Id = c2.id;
    notifyListeners();
  }

  /// Elaia étape 2 : confirme l'ordre de pioche des 2 cartes regardées.
  /// [firstId] sera piochée en premier, [secondId] juste après.
  void elaiaConfirmOrder(String firstId, String secondId) {
    final s = state!;
    final deckName = s.elaiaDeck; if (deckName == null) return;
    s.forcedDeckQueue[deckName] = [firstId, secondId];
    _log('🔮 ${s.current.name} a organisé la pile ${_deckLabel(deckName)}.', cls: 'player');
    s.elaiaStep = 0;
    s.elaiaDeck = null;
    s.elaiaCard1Id = null;
    s.elaiaCard2Id = null;
    notifyListeners();
  }

  String _deckLabel(String d) => switch (d) {
    'tenebres' => 'Ténèbres', 'lumiere' => 'Lumière', 'vision' => 'Vision',
    _ => d,
  };

  /// Damien : sert l'alcool fort — 4 dégâts instantanés.
  void damienServeAlcohol() {
    final s = state!;
    final targetUid = s.damienTargetUid; if (targetUid == null) return;
    final actor = s.current;
    final target = s.players.firstWhere((x) => x.uid == targetUid, orElse: () => actor);
    final log = _eg.damienServeAlcohol(actor, target);
    _log(log, cls: 'player');
    s.damienTargetUid = null;
    _checkWin(justDiedId: target.alive ? null : target.uid);
    s.phase = GamePhase.move; notifyListeners();
  }

  /// Damien : sert le poison — 3 dégâts/tour pendant 2 tours.
  void damienServePoison() {
    final s = state!;
    final targetUid = s.damienTargetUid; if (targetUid == null) return;
    final actor = s.current;
    final target = s.players.firstWhere((x) => x.uid == targetUid, orElse: () => actor);
    final log = _eg.damienServePoison(actor, target);
    _log(log, cls: 'player');
    s.damienTargetUid = null;
    s.phase = GamePhase.move; notifyListeners();
  }

  void humanSkipAbility() {
    state!.phase = GamePhase.move; notifyListeners();
  }

  /// Butin : récupère l'équipement choisi sur le cadavre (premier de la file).
  void lootChooseItem(int equipIndex) {
    final s = state!;
    final killerUid = s.lootKillerUid;
    if (killerUid == null || s.lootDeadQueue.isEmpty) return;
    final deadUid = s.lootDeadQueue.first;
    final killer = s.players.firstWhere((p) => p.uid == killerUid);
    final dead = s.players.firstWhere((p) => p.uid == deadUid);
    if (equipIndex >= 0 && equipIndex < dead.equipment.length) {
      final item = dead.equipment.removeAt(equipIndex);
      killer.equipment.add(item);
      _eg.equipPassivePublic(killer, item);
      _log('🎒 ${killer.name} récupère "${item.name}" sur ${dead.name}', cls: 'player');
    }
    s.lootDeadQueue.removeAt(0);
    if (s.lootDeadQueue.isEmpty) s.lootKillerUid = null;
    notifyListeners();
  }

  /// Butin : ignore ce mort, passe au suivant dans la file s'il y en a un.
  void lootSkip() {
    final s = state!;
    if (s.lootDeadQueue.isNotEmpty) s.lootDeadQueue.removeAt(0);
    if (s.lootDeadQueue.isEmpty) s.lootKillerUid = null;
    notifyListeners();
  }

  void humanMove(int zoneIdx) {
    final p = state!.current; p.zoneIndex = zoneIdx;
    _log('🚶 → ${state!.terrainLayout[zoneIdx].name}', cls: 'player');
    state!.phase = GamePhase.zoneEffect; notifyListeners();
  }

  void humanDrawCard(DeckType deck) {
    audio.playCard();
    final card = _eg.drawCard(deck, forcedQueue: state!.forcedDeckQueue); state!.pendingCard = card;
    state!.phase = GamePhase.cardDrawn;
    if (card.deck != DeckType.vision) {
      _log('🃏 Tu pioches : ${card.name}', cls: 'player');
    } else {
      _log('🔮 Tu pioches une carte Vision...', cls: 'player');
      // Jeanne Baba: peut infliger 4 à une cible en recevant une vision
      final p = state!.current;
      if ((p.copiedEffect ?? p.character?.abilityEffect ?? '') == 'vision_then_4dmg' && p.revealed) {
        state!.pendingTargetAction = 'jeanne_baba_4dmg';
      }
    }
    notifyListeners();
  }

  void humanApplyTerrainEffect({GamePhase nextPhaseIfDefault = GamePhase.attack, int? zoneOverride}) {
    final terrain = state!.terrainLayout[zoneOverride ?? state!.current.zoneIndex];
    switch (terrain.effect) {
      case 'vision':   humanDrawCard(DeckType.vision);
      case 'lumiere':  humanDrawCard(DeckType.lumiere);
      case 'tenebres': humanDrawCard(DeckType.tenebres);
      case 'choice':   state!.phase = GamePhase.cardChoice; notifyListeners();
      case 'damage9':  state!.phase = GamePhase.chooseTarget; state!.pendingTargetAction = 'terrain_damage9'; notifyListeners();
      case 'steal':    state!.phase = GamePhase.chooseTarget; state!.pendingTargetAction = 'terrain_steal'; notifyListeners();
      default: state!.phase = nextPhaseIfDefault; notifyListeners();
    }
  }

  void humanSkipTerrain() {
    state!.phase = _postCardPhase(); notifyListeners();
  }

  void humanApplyCard({Player? target}) {
    final card = state!.pendingCard; if (card == null) return;
    final p = state!.current;
    // BIBBLE: si carte Ténèbres → soigner au lieu de blesser
    final bEff = p.copiedEffect ?? p.character?.abilityEffect ?? '';
    if (bEff == 'tenebres_heal_instead' && p.revealed && card.deck == DeckType.tenebres) {
      // Les cartes qui infligent des blessures à Bibble le soignent à la place
      final healAmt = 2; // montant standard ténèbres
      _eg.applyHeal(p, healAmt);
      _log('🧚 Bibble : "${card.name}" le soigne de $healAmt au lieu de le blesser !', cls: 'player');
      state!.pendingCard = null; state!.phase = _postCardPhase();
      notifyListeners(); return;
    }
    final res = _eg.resolveCard(card, p, state!.players, state!.terrainLayout, target: target);
    if (res['needsTarget'] == true) {
      state!.phase = GamePhase.chooseTarget;
      state!.pendingTargetAction = res['action'] as String;
      notifyListeners(); return;
    }
    if (res['needsTargetChoice'] == true) {
      // Mode solo : la cible (bot) répond automatiquement via une heuristique.
      final punishActor = state!.players.firstWhere((x) => x.uid == res['punishActorUid']);
      final punishTarget = state!.players.firstWhere((x) => x.uid == res['punishTargetUid']);
      final giveEquip = _eg.botPunishChoice(punishTarget);
      final punishLog = _eg.resolvePunishChoice(punishActor, punishTarget, giveEquip);
      _log(punishLog, cls: 'player');
      state!.pendingCard = null; state!.phase = _postCardPhase();
      _checkWin(justDiedId: punishTarget.alive ? null : punishTarget.uid); notifyListeners(); return;
    }
    if (res['needsEquipChoice'] == true) {
      state!.equipChoiceMode = res['equipChoiceMode'] as String;
      state!.equipChoiceActorUid = res['equipChoiceActorUid'] as String;
      state!.equipChoiceTargetUid = res['equipChoiceTargetUid'] as String;
      state!.phase = GamePhase.chooseTarget;
      state!.pendingTargetAction = 'equip_choice';
      notifyListeners(); return;
    }
    if (res['needsSecondTarget'] == true) {
      // Corne des Woods — étape 2 : le joueur (humain) choisit la victime,
      // restreinte à la portée du joueur forcé d'attaquer.
      state!.forcedAttackerUid = res['forcedAttackerUid'] as String;
      state!.pendingTargetAction = 'corne_des_woods_victim';
      state!.phase = GamePhase.chooseTarget;
      notifyListeners(); return;
    }
    if (res['privateRevealUid'] != null) {
      // Vision Suprême : affiche la carte de la cible uniquement au joueur actif.
      state!.pendingCard = null; state!.phase = _postCardPhase();
      state!.privateRevealTargetUid = res['privateRevealUid'] as String;
      _log(res['log'] as String, cls: 'player');
      notifyListeners(); return;
    }
    // Bouteille de Ricard : se déplace et déclenche l'effet du terrain
    if (res['special'] == 'reroll_move') {
      _log(res['log'] as String, cls: 'player');
      if (res['diceResult'] != null) {
        final dr = res['diceResult'] as Map<String, dynamic>;
        state!.abilityDiceResult = {'d4': dr['d4'] as int? ?? 0, 'd6': dr['d6'] as int? ?? 0, 'sum': dr['sum'] as int? ?? 0};
      }
      state!.pendingCard = null;
      humanApplyTerrainEffect(nextPhaseIfDefault: GamePhase.attack);
      notifyListeners(); return;
    }
    final logMsg = res['log'] as String;
    _log(logMsg, cls: 'player');
    // Afficher un popup de dés si la carte en a produit un (Dynamite, Banane, etc.)
    if (res['diceResult'] != null) {
      final dr = res['diceResult'] as Map<String, dynamic>;
      final d4v = dr['d4'] as int? ?? 0;
      final d6v = dr['d6'] as int? ?? 0;
      final sumv = dr['sum'] as int? ?? 0;
      // Format attendu par _AbilityDiceRoll
      if (d4v > 0 && d6v > 0) {
        // Dynamite et similaires : D4 + D6
        state!.abilityDiceResult = {'d4val': d4v, 'd6val': d6v, 'sum': sumv, 'dmg': sumv};
      } else {
        // Banane Démoniaque : D6 seul
        state!.abilityDiceResult = {'d': 6, 'result': d6v, 'dmg': d6v};
      }
    }
    state!.pendingCard = null; state!.phase = _postCardPhase();
    // Une carte peut tuer un ou plusieurs joueurs (AoE) — vérifier la victoire
    // pour CHAQUE joueur mort suite à cette carte (sinon Tommy/Mango Loco ne
    // sont jamais reconnus vainqueurs quand le kill vient d'une carte).
    final justDied = state!.players.where((x) => !x.alive).toList();
    // Rattrapage : de nombreux effets de carte infligent des dégâts sans
    // attribuer explicitement killedByUid — sans ça, Tommy ne serait jamais
    // reconnu comme l'auteur du kill quand il joue une carte lui-même.
    for (final d in justDied) { d.killedByUid ??= p.uid; }
    if (justDied.isEmpty) {
      _checkWin();
    } else {
      for (final d in justDied) { _checkWin(justDiedId: d.uid); }
    }
    notifyListeners();
  }

  /// Détermine la phase à utiliser après résolution d'une carte/effet de
  /// terrain. Normalement `attack`, mais Peio retourne en `move` une fois
  /// (flag consommé) pour pouvoir se déplacer après avoir réactivé le terrain.
  GamePhase _postCardPhase() {
    if (state!.peioReturnToMove) {
      state!.peioReturnToMove = false;
      return GamePhase.move;
    }
    return GamePhase.attack;
  }

  void humanSkipCard() {
    state!.pendingCard = null; state!.phase = _postCardPhase(); notifyListeners();
  }

  void humanApplyTerrainTarget(String targetId) {
    final action = state!.pendingTargetAction ?? '';
    final target = state!.players.firstWhere((p) => p.uid == targetId);
    if (action == 'terrain_damage9') {
      final dmg9 = _eg.applyDamage(target, 2, isTerrain9Dmg: true);
      _log('🏹 Terrain 9 — tu infliges $dmg9 à ${target.name}', cls: 'player');
      _checkWin(justDiedId: target.alive ? null : target.uid);
    } else if (action == 'terrain_steal') {
      if (target.equipment.isNotEmpty) {
        final e = target.equipment.removeAt(_rng.nextInt(target.equipment.length));
        state!.current.equipment.add(e);
        _eg.equipPassivePublic(state!.current, e);
        // Retirer les passifs de la victime et les recalculer
        _eg.recalcPassives(target);
        _log('🗼 Tu voles "${e.name}" à ${target.name}', cls: 'player');
      } else {
        _log('🗼 ${target.name} ne possède aucun équipement', cls: 'player');
      }
    }
    state!.pendingTargetAction = null; state!.phase = _postCardPhase(); notifyListeners();
  }

  void humanChooseTarget(String targetId) {
    final target = state!.players.firstWhere((p) => p.uid == targetId);
    if (state!.pendingTargetAction == 'jeanne_mark_target') {
      jeanneChooseTarget(targetId);
      return;
    }
    if (state!.pendingTargetAction == 'clemence_target') {
      clemenceApplyToTarget(target);
      return;
    }
    if (state!.pendingTargetAction == 'equip_choice') {
      // L'équipement est sélectionné via un index passé en tant que uid fictif
      // Traité par humanResolveEquipChoice — ce cas ne devrait pas arriver ici
      return;
    }
    if (state!.pendingTargetAction == 'corne_des_woods_victim') {
      // Corne des Woods — étape 2 : la victime est enfin choisie.
      final attackerUid = state!.forcedAttackerUid;
      if (attackerUid != null) {
        final attacker = state!.players.firstWhere((p) => p.uid == attackerUid);
        final res = _eg.resolveCorneDesWoods(attacker, target);
        _log(res['log'] as String, cls: 'player');
        // Afficher le popup de dés
        final dr = res['diceResult'] as Map<String, dynamic>;
        state!.abilityDiceResult = {'d4val': dr['d4'] as int, 'd6val': dr['d6'] as int, 'sum': dr['sum'] as int, 'dmg': dr['sum'] as int};
        state!.forcedAttackerUid = null;
        state!.pendingTargetAction = null;
        state!.phase = GamePhase.attack;
        _checkWin(justDiedId: target.alive ? null : target.uid);
        notifyListeners();
      }
      return;
    }
    // Liste canonique des effets de CARTE (pas de capacité) qui nécessitent une
    // cible — doit rester synchronisée avec le switch de resolveCard().
    const cardTargetEffects = {
      'set_marker7_choice', 'heal_other_d6', 'heal_other_d4', 'banane_demonique',
      'vampirisation', 'blue_shell', 'veuve_noire', 'peau_banane', 'pince_attrape',
      'trebuchet', 'creation_marin', 'corne_des_woods',
      'vision_shadow_2', 'vision_shadow_1', 'vision_hunter_1', 'vision_hunter_2',
      'vision_shadow_heal_or_dmg', 'vision_hunter_heal_or_dmg', 'vision_neutral_heal_or_dmg',
      'vision_show_card', 'vision_punish_neutral_shadow', 'vision_punish_neutral_hunter',
      'vision_punish_shadow_hunter', 'vision_hp_12plus', 'vision_hp_11minus',
    };
    final isCardTarget = cardTargetEffects.contains(state!.pendingTargetAction);
    if (state!.pendingCard != null && isCardTarget) { humanApplyCard(target: target); return; }
    final action = state!.pendingTargetAction ?? '';
    if (action == 'terrain_damage9' || action == 'terrain_steal') {
      humanApplyTerrainTarget(targetId); return;
    }
    if (action == 'richard_terrain') {
      // Richard II active l'effet d'une zone de son choix sans se déplacer
      final savedZone = state!.current.zoneIndex;
      state!.current.zoneIndex = target.zoneIndex; // se placer temporairement
      humanApplyTerrainEffect(); // activer l'effet
      // ne revient pas — il reste là où il est pour l'effet
      state!.pendingTargetAction = null;
      _log("🔀 Richard II active l'effet du terrain ${target.zoneIndex}", cls: 'player');
      notifyListeners(); return;
    }
    // Capacité nécessitant une cible
    humanUseAbility(target: target);
    // NB: humanUseAbility gère elle-même la phase suivante pour les cas spéciaux
  }

  void humanAttack(String targetId, int dmg) {
    final attacker = state!.current;
    final target = state!.players.firstWhere((p) => p.uid == targetId);
    // Fifi Golden: force 5 dégâts
    final actualDmg = state!.fifiGoldenTurn ? 5 : dmg;
    // Mathieu: incrémenter compteur
    attacker.attackCount++;
    final isMathieuThird = (attacker.copiedEffect ?? attacker.character?.abilityEffect ?? '') == 'third_attack_bonus'
        && attacker.attackCount >= 3;
    final res = _eg.resolveAttackFull(attacker, target, actualDmg, state!.players, attackCount: attacker.attackCount - 1);
    _log(res['log'] as String, cls: 'player');
    if (!target.alive) { _log('💀 ${target.name} est éliminé !', cls: 'death'); }
    // Mathieu 3e attaque : animation
    if (isMathieuThird) state!.abilityOverlay = 'mathieu_bullet';
    // Scott contre-attaque : animation
    if (res['scottCountered'] == true) state!.abilityOverlay = 'scott_counter';
    // Gège le Fantôme : attaque automatiquement la même cible
    final (gegeLog, gegeTriggered) = _eg.applyGegePassiveEx(attacker, target, state!.players);
    if (gegeLog != null) {
      _log(gegeLog, cls: 'player');
      if (!target.alive) { _log('💀 ${target.name} est éliminé !', cls: 'death'); }
      if (gegeTriggered) state!.abilityOverlay = 'gege_ghost'; // animation fantôme
    }
    // Gège le Fantôme : la contre-attaque de Scott EST aussi une attaque d'un
    // Hunter révélé — sans ce check séparé, Gège ne se déclenchait jamais
    // sur les contre-attaques (rôles inversés : Scott devient l'attaquant).
    if (res['scottCountered'] == true && attacker.alive) {
      final (gegeLog2, gegeTriggered2) = _eg.applyGegePassiveEx(target, attacker, state!.players);
      if (gegeLog2 != null) {
        _log(gegeLog2, cls: 'player');
        if (!attacker.alive) { _log('💀 ${attacker.name} est éliminé !', cls: 'death'); }
        if (gegeTriggered2) state!.abilityOverlay = 'gege_ghost';
      }
    }
    _checkWin(justDiedId: target.alive ? null : target.uid);
    // Track Raphaël mirror damage
    if (state!.raphShadowMultiAtk) {
      state!.raphShadowTotalDmg += (res['actualDmg'] as int? ?? dmg);
    }
    state!.hasAttackedThisTurn = true;
    state!.woundFlashUid = targetId;
    state!.phase = GamePhase.attack; notifyListeners();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (state != null) { state!.woundFlashUid = null; notifyListeners(); }
    });
  }


  void humanBazookaAttack(int dmg) {
    if (state == null) return;
    final attacker = state!.current;
    final targets = _eg.attackTargets(attacker, state!.players, state!.terrainLayout);
    if (targets.isEmpty) { notifyListeners(); return; }

    final actualDmg = state!.fifiGoldenTurn ? state!.fifiAtkResult : dmg;
    final killed = <String>[];

    for (final target in targets) {
      attacker.attackCount++;
      final res = _eg.resolveAttackFull(attacker, target, actualDmg,
          state!.players, attackCount: attacker.attackCount - 1);
      _log(res['log'] as String, cls: 'player');
      if (!target.alive) {
        _log('💀 ${target.name} est éliminé !', cls: 'death');
        killed.add(target.uid);
      }
    }

    state!.hasAttackedThisTurn = true;
    state!.phase = GamePhase.attack;

    // Check wins after all attacks
    for (final uid in killed) _checkWin(justDiedId: uid);
    if (!state!.isOver) notifyListeners();
  }

  void humanGladsFinish() {
    // Redistribue les équipements après l'attaque de Glads
    if (!state!.gladsCombining) return;
    state!.current.equipment.clear();
    final backup = List<GameCard>.from(state!.gladsBackup)..shuffle(_rng);
    for (int i = 0; i < backup.length; i++) {
      final p = state!.players[i % state!.players.length];
      p.equipment.add(backup[i]);
    }
    state!.gladsBackup.clear();
    state!.gladsCombining = false;
    _log('💥 Glads redistribue les équipements', cls: 'important');
    notifyListeners();
  }

  void humanRaphShadowFinish() {
    // Fin de l'attaque multiple de Raphaël Shadow — subit autant qu'il a infligé
    if (!state!.raphShadowMultiAtk) return;
    final me = state!.current;
    if (state!.raphShadowTotalDmg > 0) {
      _eg.applyDamage(me, state!.raphShadowTotalDmg);
      _log('⚔️ Raphaël Shadow subit ${state!.raphShadowTotalDmg} (miroir)', cls: 'player');
    }
    state!.raphShadowMultiAtk = false;
    state!.raphShadowTotalDmg = 0;
    state!.raphShadowTargetUid = null;
    state!.hasAttackedThisTurn = true;
    notifyListeners();
  }

  void logAbility(String msg) => _log(msg, cls: 'player');

  /// Retire le premier équipement avec l'effet donné de l'inventaire du joueur courant.
  void consumeEquipment(String effect) {
    final p = state!.current;
    final idx = p.equipment.indexWhere((e) => e.effect == effect);
    if (idx >= 0) {
      p.equipment.removeAt(idx);
      _eg.recalcPassives(p);
      notifyListeners();
    }
  }



  void applyDamageToPlayer(String uid, int dmg) {
    if (state == null) return;
    final target = state!.players.firstWhere((p) => p.uid == uid, orElse: () => state!.players.first);
    _eg.applyDamage(target, dmg);
    _checkWin(justDiedId: target.alive ? null : target.uid);
    notifyListeners();
  }

  void healPlayer(String uid, int amount) {
    final p = state!.players.firstWhere((x) => x.uid == uid, orElse: () => state!.players.first);
    _eg.applyHeal(p, amount);
    audio.playHeal();
    notifyListeners();
  }

  void applyDamageToHuman(int dmg, {String reason = ''}) {
    final me = state!.players.firstWhere((p) => !p.isBot, orElse: () => state!.current);
    _eg.applyDamage(me, dmg);
    if (reason.isNotEmpty) _log(reason, cls: 'player');
    _checkWin(justDiedId: me.alive ? null : me.uid);
    state!.phase = GamePhase.attack;
    notifyListeners();
  }

  // Attaque avec la Hache du Berserker (d4 seulement)
  Map<String, int> rollHacheAttack() => _eg.rollHacheAttack();

  // Vérifie si le joueur DOIT attaquer ce tour (Hache)
  bool get humanMustAttack =>
    state?.current.hache == true && !state!.hasAttackedThisTurn;

  Future<void> _humanEndTurnInternal() async {
    final p = state!.current;
    if (p.newTurn) {
      p.newTurn = false; state!.phase = GamePhase.move;
      _log('⏰ Tu joues un tour supplémentaire !', cls: 'important'); notifyListeners(); return;
    }
    _log('⏩ Tu termines ton tour', cls: 'player');
    await nextTurn();
  }

  // ─── Helpers ────────────────────────────
  List<Player> get humanAttackTargets {
    if (state == null) return [];
    final targets = _eg.attackTargets(state!.current, state!.players, state!.terrainLayout);
    // Hache / Sabre : si aucune cible accessible, le joueur s'attaque lui-même
    final me = state!.current;
    if (targets.isEmpty && (me.hache || me.epeeNinja)) return [me];
    return targets;
  }

  Terrain? terrainOf(Player p) {
    if (state == null || p.zoneIndex >= state!.terrainLayout.length) return null;
    return state!.terrainLayout[p.zoneIndex];
  }

  void _log(String msg, {String cls = ''}) {
    state!.log.add(LogEntry(msg, cls: cls));
    if (state!.log.length > 80) state!.log.removeAt(0);
  }

  void _checkWin({String? justDiedId}) {
    if (state == null) return;
    // Baleine — soigne les Hunters révélés à sa mort (et tout autre passif de mort)
    _eg.applyDeathPassives(state!.players);
    // Jeanne — vérifie si le mort était la cible marquée et distribue la récompense
    if (justDiedId != null && state!.markedPlayerUid == justDiedId) {
      final dead = state!.players.firstWhere((p) => p.uid == justDiedId,
          orElse: () => state!.players.first);
      _checkJeanneMark(dead);
    }
    // Léo: vérifie si c'est le premier mort
    if (justDiedId != null) {
      final deadPlayer = state!.players.firstWhere((p) => p.uid == justDiedId, orElse: () => state!.players.first);
      final totalDeaths = state!.players.where((p) => !p.alive).length;
      if (deadPlayer.character?.winEffect == 'die_first_or_kill_hunters' && totalDeaths == 1) {
        // Léo est le PREMIER à mourir → il gagne !
        state!.phase = GamePhase.gameOver;
        state!.winnerIds = [deadPlayer.uid];
        state!.winnerMessage = '💀 Léo est éliminé en premier — Léo GAGNE !';
        _log('🏆 ${state!.winnerMessage}', cls: 'important');
        notifyListeners(); return;
      }
    }
    final res = _eg.checkWin(state!.players, justDiedId: justDiedId);
    if (res != null) {
      state!.phase = GamePhase.gameOver;
      state!.winnerIds = List<String>.from(res['winnerIds'] as List);
      state!.winnerMessage = res['reason'] as String;
      _log('🏆 ${state!.winnerMessage}', cls: 'important');
      return;
    }
    // Butin : le tueur peut choisir de récupérer un équipement de sa victime
    // (mis en FILE D'ATTENTE — plusieurs morts simultanées, ex: bazooka,
    // peuvent chacune offrir un butin sans s'écraser l'une l'autre).
    if (justDiedId != null) {
      final dead = state!.players.firstWhere((p) => p.uid == justDiedId, orElse: () => state!.players.first);
      final loot = _eg.checkLootOpportunity(dead, state!.players);
      if (loot != null) {
        final (killerUid, deadUid) = loot;
        final killer = state!.players.firstWhere((p) => p.uid == killerUid);
        if (killer.isBot) {
          // IA : prend l'objet le plus utile si possible, sinon ignore
          final items = dead.equipment;
          if (items.isNotEmpty) {
            final picked = items.first;
            dead.equipment.remove(picked);
            killer.equipment.add(picked);
            _eg.equipPassivePublic(killer, picked);
            _log('🎒 ${killer.name} récupère "${picked.name}" sur ${dead.name}', cls: 'player');
          }
        } else {
          state!.lootKillerUid = killerUid;
          if (!state!.lootDeadQueue.contains(deadUid)) state!.lootDeadQueue.add(deadUid);
        }
      }
    }
    // Jason : vient-il de perdre son déguisement (5+ dégâts en un tour) ?
    // Indépendant d'un kill éventuel — déclenche sa vraie révélation.
    final unmasked = _eg.checkDisguiseLost(state!.players);
    if (unmasked != null) {
      unmasked.disguiseJustLost = false;
      state!.pendingRevealAnimation = unmasked.uid;
      _log('🎭 ${unmasked.name} perd son déguisement — sa vraie identité est révélée !', cls: 'player');
    }
  }

  // Liste synchronisée avec les checks 'cible_requise' de engine.dart —
  // sans ça, un bot avec une de ces capacités la gâche silencieusement
  // (target reste null, l'effet ne s'applique jamais, le tour semble figé).
  bool _abilityNeedsTarget(String eff) => [
    'damage2_choice','damage2_then_heal3','set_wounds5','steal_equip_choice',
    'damage3_give_dague','d6_global_attack','terrain_max_aoe','d6_lifesteal',
    'swap_equipment','damien_serve','copy_ability','d4_heal_neighbors',
  ].contains(eff);

  // Liste synchronisée avec le switch needsTarget de resolveCard() —
  // sans ça, un bot qui pioche une de ces cartes (notamment les Visions,
  // très fréquentes) la jette sans effet au lieu de choisir une cible.
  bool _cardNeedsTarget(String eff) => [
    'heal_other_d6','heal_other_d4','set_marker7_choice','banane_demonique',
    'vampirisation','blue_shell','veuve_noire','peau_banane','pince_attrape',
    'trebuchet','vision_shadow_2','vision_shadow_1','vision_hunter_1','vision_hunter_2',
    'vision_shadow_heal_or_dmg','vision_hunter_heal_or_dmg','vision_neutral_heal_or_dmg',
    'vision_show_card','vision_punish_neutral_shadow','vision_punish_neutral_hunter',
    'vision_punish_shadow_hunter','vision_hp_12plus','vision_hp_11minus',
  ].contains(eff);

  void resetGame() { state = null; notifyListeners(); }
}
