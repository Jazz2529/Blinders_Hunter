// lib/services/game_provider.dart
// Provider multijoueur — pont Firebase ↔ UI

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../data/game_data.dart';
import 'engine.dart';
import 'firebase_service.dart';
import 'persistence.dart';

class GameProvider extends ChangeNotifier {
  final FirebaseService _fb = FirebaseService.instance;
  FirebaseService get fb => _fb; // accès lecture (reconnexion, etc.)
  final GameEngine      _eg = GameEngine.instance;
  final bool firebaseEnabled;
  GameProvider({this.firebaseEnabled = false});

  String? roomId;
  String? myUid;
  String? hostId;
  GameState? gameState;
  Map<String, Player> players = {};
  String roomStatus = 'lobby';
  Map<String, dynamic>? gameResult;
  int roleConfirms = 0;
  List<String> log = [];
  List<String> privateLog = []; // logs visibles seulement par ce joueur

  StreamSubscription? _gsSub, _pSub, _stSub, _rSub, _rcSub, _logSub, _privLogSub;

  // ─── Getters ────────────────────────────
  Player? get me => myUid != null ? players[myUid] : null;
  bool get isMyTurn => gameState?.currentPlayerId == myUid;
  bool get isHost    => hostId == myUid;
  GamePhase get phase => gameState?.phase ?? GamePhase.lobby;
  Player? get currentPlayer => gameState != null ? players[gameState!.currentPlayerId] : null;

  List<Player> get playerList {
    if (gameState == null) return players.values.toList();
    return gameState!.playerOrder.where(players.containsKey).map((id) => players[id]!).toList();
  }

  List<Player> get attackTargets {
    final actor = me; if (actor == null || gameState == null) return [];
    final targets = _eg.attackTargets(actor, players.values.toList(), gameState!.terrainLayout);
    // Hache / Sabre : si aucune cible accessible, s'attaque soi-même
    if (targets.isEmpty && (actor.hache || actor.epeeNinja)) return [actor];
    return targets;
  }

  /// Cibles attaquables pour un joueur arbitraire (pas forcément `me`) —
  /// utilisé par Corne des Woods pour restreindre la victime à la portée
  /// du joueur forcé d'attaquer.
  List<Player> attackTargetsFor(Player p) {
    if (gameState == null) return [];
    return _eg.attackTargets(p, players.values.toList(), gameState!.terrainLayout);
  }

  Terrain? terrainOf(Player p) {
    if (gameState == null || p.zoneIndex >= gameState!.terrainLayout.length) return null;
    return gameState!.terrainLayout[p.zoneIndex];
  }

  // ─── Init ────────────────────────────────
  Future<void> init() async {
    if (!firebaseEnabled) {
      myUid = 'local_${DateTime.now().millisecondsSinceEpoch}';
      notifyListeners();
      return;
    }
    try {
      myUid = await _fb.signInAnonymously();
    } catch (e) {
      myUid = 'offline_${DateTime.now().millisecondsSinceEpoch}';
    }
    notifyListeners();
  }

  /// Génère une nouvelle identité locale — utile pour tester le multijoueur
  /// avec plusieurs fenêtres sur le même PC (chaque fenêtre = un joueur différent).
  Future<void> newIdentity() async {
    myUid = await _fb.newIdentity();
    notifyListeners();
  }

  Future<String> createRoom(String name, String token) async {
    roomId = await _fb.createRoom(name, token);
    myUid  = _fb.currentUid;
    hostId = myUid; // l'hôte est forcément moi quand je crée la salle
    Prefs.saveRoom(roomId!, myUid!);
    _subscribe(); notifyListeners();
    return roomId!;
  }

  Future<void> joinRoom(String code, String name, String token) async {
    await _fb.joinRoom(code.toUpperCase(), name, token);
    roomId = code.toUpperCase(); myUid = _fb.currentUid;
    hostId = await _fb.getHostId(roomId!);
    Prefs.saveRoom(roomId!, myUid!);
    _subscribe(); notifyListeners();
  }

  /// Reprend une partie en cours après fermeture de l'appli.
  /// Retourne false si la salle n'existe plus ou est terminée.
  Future<bool> resumeRoom(String rid, String uid) async {
    final status = await _fb.fetchRoomStatus(rid);
    if (status == null || status == 'finished') {
      Prefs.clearRoom();
      return false;
    }
    roomId = rid;
    myUid = uid;
    hostId = await _fb.getHostId(rid);
    _resultRecorded = false;
    _subscribe();
    notifyListeners();
    return true;
  }

  /// Rejouer avec les mêmes joueurs : retour au lobby (hôte uniquement).
  Future<void> restartGame() async {
    if (roomId == null) return;
    _resultRecorded = false;
    await _fb.restartRoom(roomId!);
  }

  bool _resultRecorded = false;
  bool _forcingTurn = false;

  void _recordMultiResult(Map<String, dynamic>? result) {
    if (result == null || _resultRecorded) return;
    final me = players[myUid];
    if (me == null) return;
    _resultRecorded = true;
    final winnerIds = List<String>.from(result['winnerIds'] as List? ?? []);
    Prefs.addGame(
      mode: 'multi',
      character: me.character?.name ?? '?',
      faction: me.character?.faction.name ?? '?',
      win: winnerIds.contains(myUid),
      reason: result['reason'] as String? ?? '',
    );
  }

  /// Timer AFK : si l'hôte constate que le tour dure > 120 s, il force
  /// le passage au joueur suivant.
  static const turnTimeoutMs = 120000;

  void _maybeForceTurn() {
    if (_forcingTurn) return;
    if (myUid == null || hostId != myUid) return;           // hôte seulement
    if (roomStatus != 'playing' || gameResult != null) return;
    final ts = gameState?.turnStartedAt;
    if (ts == null) return;
    if (DateTime.now().millisecondsSinceEpoch - ts < turnTimeoutMs) return;
    _forcingTurn = true;
    _forceAdvanceTurn().whenComplete(() => _forcingTurn = false);
  }

  Future<void> _forceAdvanceTurn() async {
    final gs = gameState;
    if (gs == null || roomId == null) return;
    final curId = gs.currentPlayerId;
    final cur = players[curId];
    await _fb.addLog(roomId!,
        '⏰ Temps écoulé — le tour de ${cur?.name ?? "?"} est passé automatiquement');
    final order = gs.playerOrder;
    int next = (order.indexOf(curId) + 1) % order.length;
    while (!(players[order[next]]?.alive ?? false)) {
      next = (next + 1) % order.length;
    }
    final all = _mutableAll();
    final nextPlayer = all.firstWhere((x) => x.uid == order[next]);
    if (nextPlayer.character?.abilityRepeatable == true) nextPlayer.abilityUsed = false;
    if (nextPlayer.shield && nextPlayer.shieldCharges == 99) {
      nextPlayer.shield = false; nextPlayer.shieldCharges = 0;
    }
    nextPlayer.damageTakenThisTurn = 0;
    final passiveLogs = _eg.applyStartOfTurnPassives(nextPlayer, all, gs.terrainLayout);
    _eg.applyDeathPassives(all);
    await _commitAll(all, passiveLogs.join(' | '));
    // Un passif de début de tour (poison de Damien, etc.) peut tuer un
    // joueur — sans ce check, ni la victoire ni la récompense de Jeanne ne
    // se déclenchaient jamais pour une mort survenue de cette façon.
    if (!nextPlayer.alive) { await _checkWin(all, justDiedId: nextPlayer.uid); }
    await _fb.setPhase(roomId!, GamePhase.ability,
        currentPlayerId: order[next], hasAttacked: false, clearPending: true);
  }

  void _subscribe() {
    _pSub?.cancel(); _gsSub?.cancel(); _stSub?.cancel(); _rSub?.cancel(); _rcSub?.cancel(); _logSub?.cancel(); _privLogSub?.cancel();
    _pSub  = _fb.watchPlayers(roomId!).listen((d) { players = d; notifyListeners(); });
    _gsSub = _fb.watchGameState(roomId!).listen((d) { gameState = d; _maybeForceTurn(); notifyListeners(); });
    _stSub = _fb.watchStatus(roomId!).listen((d) { roomStatus = d; notifyListeners(); });
    _rSub  = _fb.watchResult(roomId!).listen((d) { gameResult = d; _recordMultiResult(d); notifyListeners(); });
    _rcSub = _fb.watchRoleConfirms(roomId!).listen((d) { roleConfirms = d; notifyListeners(); });
    _logSub = _fb.watchLog(roomId!).listen((d) { log = d; notifyListeners(); });
    if (myUid != null) {
      _privLogSub = _fb.watchPrivateLog(roomId!, myUid!).listen((d) { privateLog = d; notifyListeners(); });
    }
  }

  @override
  void dispose() {
    _pSub?.cancel(); _gsSub?.cancel(); _stSub?.cancel(); _rSub?.cancel(); _rcSub?.cancel(); _logSub?.cancel(); _privLogSub?.cancel();
    super.dispose();
  }

  /// Quitte la room actuelle et remet le provider à zéro pour permettre de
  /// créer/rejoindre une nouvelle partie. À appeler avant de retourner à
  /// l'écran d'accueil après une fin de partie.
  Future<void> leaveRoomAndReset() async {
    Prefs.clearRoom();
    _resultRecorded = false;
    _pSub?.cancel(); _gsSub?.cancel(); _stSub?.cancel(); _rSub?.cancel(); _rcSub?.cancel(); _logSub?.cancel(); _privLogSub?.cancel();
    _pSub = _gsSub = _stSub = _rSub = _rcSub = _logSub = _privLogSub = null;
    if (roomId != null) {
      try { await _fb.leaveRoom(roomId!); } catch (_) {}
    }
    roomId = null;
    hostId = null;
    myUid  = null;
    gameState = null;
    players = {};
    roomStatus = 'lobby';
    gameResult = null;
    roleConfirms = 0;
    log = [];
    privateLog = [];
    notifyListeners();
  }

  // ─── Lobby ──────────────────────────────
  Future<void> setReady(bool r) => _fb.setReady(roomId!, r);
  Future<void> changeToken(String tokenId) => _fb.setToken(roomId!, tokenId);
  Future<void> startGame()      => _fb.startGame(roomId!);

  // ─── Actions de jeu ──────────────────────
  Future<void> revealSelf() async {
    final p = _mutableMe();
    p.revealed = true;
    final isClemence = p.character?.abilityEffect == 'builder_power';
    final isJeanne = p.character?.abilityEffect == 'prophete_mark';
    final offered = isClemence ? _eg.builderDraw3() : <String>[];
    await _commitPlayer(p, '🃏 ${p.name} révèle : ${p.character!.name}');
    final revealTs = DateTime.now().millisecondsSinceEpoch;
    // Diffuse la réplique de révélation (visible/audible de tous) — combiné
    // avec la transition de phase suivante dans UNE SEULE écriture Firebase
    // (deux écritures séquentielles créent une fenêtre de race condition).
    if (isClemence) {
      await _fb.setPhase(roomId!, gameState!.phase,
          builderStep: 1, builderOffered: offered,
          publicRevealUid: p.uid, publicRevealTimestamp: revealTs);
    } else if (isJeanne) {
      await _fb.setPhase(roomId!, GamePhase.chooseTarget,
          pendingTargetAction: 'jeanne_mark_target', jeanneUid: p.uid,
          publicRevealUid: p.uid, publicRevealTimestamp: revealTs);
    } else {
      await _fb.setPhase(roomId!, gameState!.phase,
          publicRevealUid: p.uid, publicRevealTimestamp: revealTs);
    }
  }

  /// Clémence : choisit un effet au tour 1 ou 2.
  Future<void> clemenceChooseEffect(String eff) async {
    final gs = gameState!;
    if (gs.builderStep == 1) {
      final next = _eg.builderDraw3(exclude: eff);
      // Force une mise à jour Firebase visible en passant par move puis ability
      await _fb.setPhase(roomId!, GamePhase.ability,
          builderStep: 2, builderEffect1: eff, builderOffered: next,
          lastDiceTimestamp: DateTime.now().millisecondsSinceEpoch); // force diff
      await _fb.addLog(roomId!, '🎨 Clémence choisit l\'effet 1 : ${_eg.builderEffectLabel(eff)}');
    } else if (gs.builderStep == 2) {
      final e1 = gs.builderEffect1!;
      if (_eg.builderCombinedNeedsTarget(e1, eff)) {
        await _fb.setPhase(roomId!, GamePhase.chooseTarget,
            builderStep: 3, builderEffect2: eff,
            builderOffered: const [], pendingTargetAction: 'clemence_target');
        await _fb.addLog(roomId!, '🎨 Clémence choisit l\'effet 2 : ${_eg.builderEffectLabel(eff)} — choisissez une cible');
      } else {
        await _fb.addLog(roomId!, '🎨 Clémence combine : ${_eg.builderEffectLabel(e1)} + ${_eg.builderEffectLabel(eff)}');
        await _clemenceResolve(e1, eff, null);
      }
    }
  }

  /// Clémence : applique les deux effets sur la cible choisie.
  Future<void> clemenceApplyToTarget(Player target) async {
    final gs = gameState!;
    final e1 = gs.builderEffect1!;
    final e2 = gs.builderEffect2!;
    await _clemenceResolve(e1, e2, target);
  }

  /// Mr Casino — le joueur a gagné son pari : choisir une cible pour 3 dégâts.
  /// Elaia étape 1 : choisit la pile à regarder (tenebres/lumiere/vision).
  Future<void> elaiaChooseDeck(String deckName) async {
    final deck = DeckType.values.byName(deckName);
    final (c1, c2) = _eg.peekTwoCards(deck);
    await _fb.setPhase(roomId!, GamePhase.ability,
        elaiaStep: 2, elaiaDeck: deckName,
        elaiaCard1Id: c1.id, elaiaCard2Id: c2.id);
  }

  /// Elaia étape 2 : confirme l'ordre de pioche des 2 cartes regardées.
  /// [firstId] sera piochée en premier, [secondId] juste après.
  Future<void> elaiaConfirmOrder(String firstId, String secondId) async {
    final deckName = gameState?.elaiaDeck; if (deckName == null) return;
    final queue = Map<String, List<String>>.from(
        (gameState?.forcedDeckQueue ?? const {}).map(
            (k, v) => MapEntry(k, List<String>.from(v))));
    queue[deckName] = [firstId, secondId];
    await _fb.addLog(roomId!,
        '🔮 ${me?.name ?? "Elaia"} a organisé la pile ${_deckLabel(deckName)}.');
    await _fb.setPhase(roomId!, GamePhase.ability,
        elaiaStep: 0, forcedDeckQueue: queue);
  }

  String _deckLabel(String d) => switch (d) {
    'tenebres' => 'Ténèbres', 'lumiere' => 'Lumière', 'vision' => 'Vision',
    _ => d,
  };

  /// Damien : cible choisie — mémorise la cible et affiche le choix alcool/poison.
  Future<void> damienChooseTarget(Player target) async {
    final all = _mutableAll();
    final actor = all.firstWhere((p) => p.uid == myUid);
    actor.abilityUsed = true;
    await _commitAll(all, '🍸 ${actor.name} prépare un verre pour ${target.name}…');
    await _fb.setPhase(roomId!, GamePhase.ability,
        clearPending: true, damienTargetUid: target.uid);
  }

  /// Damien : sert l'alcool fort — 4 dégâts instantanés.
  Future<void> damienServeAlcohol() async {
    final targetUid = gameState?.damienTargetUid; if (targetUid == null) return;
    final all = _mutableAll();
    final actor = all.firstWhere((p) => p.uid == myUid);
    final target = all.firstWhere((p) => p.uid == targetUid, orElse: () => actor);
    final log = _eg.damienServeAlcohol(actor, target);
    _eg.applyDeathPassives(all);
    await _commitAll(all, log);
    await _checkWin(all, justDiedId: target.alive ? null : target.uid);
    await _fb.setPhase(roomId!, GamePhase.ability, clearPending: true);
  }

  /// Damien : sert le poison — 3 dégâts/tour pendant 2 tours.
  Future<void> damienServePoison() async {
    final targetUid = gameState?.damienTargetUid; if (targetUid == null) return;
    final all = _mutableAll();
    final actor = all.firstWhere((p) => p.uid == myUid);
    final target = all.firstWhere((p) => p.uid == targetUid, orElse: () => actor);
    final log = _eg.damienServePoison(actor, target);
    await _commitAll(all, log);
    await _fb.setPhase(roomId!, GamePhase.ability, clearPending: true);
  }

  /// Butin : récupère l'équipement choisi sur le cadavre (premier de la file).
  Future<void> lootChooseItem(int equipIndex) async {
    final killerUid = gameState?.lootKillerUid;
    final queue = List<String>.from(gameState?.lootDeadQueue ?? const []);
    if (killerUid == null || queue.isEmpty) return;
    final deadUid = queue.first;
    final all = _mutableAll();
    final killer = all.firstWhere((p) => p.uid == killerUid);
    final dead = all.firstWhere((p) => p.uid == deadUid);
    String log = '';
    if (equipIndex >= 0 && equipIndex < dead.equipment.length) {
      final item = dead.equipment.removeAt(equipIndex);
      killer.equipment.add(item);
      _eg.equipPassivePublic(killer, item);
      log = '🎒 ${killer.name} récupère "${item.name}" sur ${dead.name}';
    }
    await _commitAll(all, log);
    queue.removeAt(0);
    await _fb.setPhase(roomId!, gameState?.phase ?? GamePhase.attack,
        lootKillerUid: queue.isEmpty ? '__clear__' : killerUid,
        lootDeadQueue: queue);
  }

  /// Butin : ignore ce mort, passe au suivant dans la file s'il y en a un.
  Future<void> lootSkip() async {
    final queue = List<String>.from(gameState?.lootDeadQueue ?? const []);
    if (queue.isNotEmpty) queue.removeAt(0);
    await _fb.setPhase(roomId!, gameState?.phase ?? GamePhase.attack,
        lootKillerUid: queue.isEmpty ? '__clear__' : gameState?.lootKillerUid,
        lootDeadQueue: queue);
  }

  Future<void> casinoWin() async {
    await _fb.setPhase(roomId!, GamePhase.chooseTarget,
        pendingTargetAction: 'casino_win');
  }

  /// Mr Casino — le joueur a perdu son pari : subit 2 blessures.
  Future<void> casinoLose() async {
    final all = _mutableAll();
    final me = all.firstWhere((p) => p.uid == myUid);
    _eg.applyDamage(me, 2);
    if (!me.alive) me.killedByUid = me.uid; // mort de son propre pouvoir
    _eg.applyDeathPassives(all);
    await _commitAll(all, '🎰 Mr Casino perd son pari — ${me.name} subit 2 blessures');
    await _checkWin(all, justDiedId: me.alive ? null : me.uid);
    if (!me.alive) {
      // Il ne peut plus jouer son tour s'il vient de mourir — le tour
      // passe immédiatement au joueur suivant au lieu de le laisser
      // continuer (bouger/attaquer) alors qu'il est mort.
      await endTurn();
    } else {
      await _fb.setPhase(roomId!, GamePhase.move, clearPending: true);
    }
  }

  /// Mr Casino — inflige 3 dégâts à la cible choisie après un pari gagné.
  Future<void> casinoApplyDamage(Player target) async {
    final all = _mutableAll();
    final t = all.firstWhere((p) => p.uid == target.uid);
    _eg.applyDamage(t, 3);
    if (!t.alive) t.killedByUid = myUid;
    _eg.applyDeathPassives(all);
    await _commitAll(all, '🎰 Mr Casino inflige 3 blessures à ${t.name} !');
    await _checkWin(all, justDiedId: t.alive ? null : t.uid);
    await _fb.setPhase(roomId!, GamePhase.move, clearPending: true);
  }


  Future<void> jeanneChooseTarget(Player target) async {
    final rewards = _eg.jeanneDraw3();
    await _fb.setPhase(roomId!, GamePhase.ability, clearPending: true,
        markedPlayerUid: target.uid, builderOffered: rewards,
        jeanneUid: myUid);
  }

  /// Jeanne étape 2 : choisit secrètement la récompense.
  Future<void> resolveEquipChoiceMulti(String mode, String actorUid, String targetUid, int idx) async {
    final all = _mutableAll();
    final actor = all.firstWhere((p) => p.uid == actorUid);
    final target = all.firstWhere((p) => p.uid == targetUid);
    final log = _eg.resolveEquipChoice(mode, actor, target, idx);
    _eg.applyDeathPassives(all);
    await _commitAll(all, log);
    await _checkWin(all);
    await _fb.setPhase(roomId!, _postCardPhase(), clearPending: true, peioReturnToMove: false);
  }


  /// Jeanne étape 2 : choisit secrètement la récompense.
  Future<void> jeanneChooseReward(String reward) async {
    final all = _mutableAll();
    final me = all.firstWhere((p) => p.uid == myUid);
    me.abilityUsed = true;
    await _commitAll(all, '🔮 ${me.name} marque un joueur — récompense secrète posée !');
    await _fb.setPhase(roomId!, GamePhase.move, clearPending: true,
        jeanneReward: reward, jeanneUid: myUid, builderOffered: []);
  }
  Future<void> _clemenceResolve(String e1, String e2, Player? target) async {
    final all = _mutableAll();
    final actor = all.firstWhere((p) => p.uid == myUid);
    final tgt = target != null
        ? all.firstWhere((p) => p.uid == target.uid, orElse: () => actor)
        : null;
    final log1 = _eg.applyBuilderEffect(e1, actor, tgt, all, gameState!.terrainLayout);
    final t2 = (tgt != null && !tgt.alive && _eg.builderNeedsTarget(e2)) ? null : tgt;
    final log2 = _eg.applyBuilderEffect(e2, actor, t2, all, gameState!.terrainLayout);
    actor.abilityUsed = true;
    _eg.applyDeathPassives(all);
    await _commitAll(all, [log1, log2].where((l) => l.isNotEmpty).join(' | '));
    await _checkWin(all, justDiedId: tgt != null && !tgt.alive ? tgt.uid : null);
    await _fb.setPhase(roomId!, GamePhase.move, clearPending: true,
        builderStep: 0, builderOffered: const []);
  }



  /// Jason (Caméléon) : se révèle en affichant le nom/icône d'un personnage
  /// (Hunter ou Shadow) actuellement en jeu, au lieu de sa vraie identité.
  Future<void> revealAsDisguise(CharacterCard disguise) async {
    final p = _mutableMe();
    p.revealed = true;
    p.disguiseNameOverride = disguise.name;
    p.disguiseIconOverride = disguise.icon;
    p.disguiseFactionOverride = disguise.faction.name;
    p.disguiseCharIdOverride = disguise.id; // pour afficher HP et carte complète
    await _commitPlayer(p, '🃏 ${p.name} révèle : ${disguise.name}');
  }

  /// Quitte l'écran de révélation des rôles. La phase globale ne passe
  /// à `ability` que lorsque TOUS les joueurs ont confirmé.
  Future<void> confirmRoleReveal() => _fb.confirmRoleSeen(roomId!);

  // Mappe abilityEffect -> nom d'overlay d'animation (mêmes noms que le solo)
  static const Map<String, String> _abilityOverlays = {
    'd4_bonus_attack': 'vlad_mountain',
    'd6_global_attack': 'travert_shockwave',
    'terrain_max_aoe': 'hongyi_dumbbell',
    'd6_lifesteal': 'carapatte_food',
    'd4_all': 'leo_flames_all',
    'full_heal_shield_turn': 'cambou_sheep',
    'd4_heal_neighbors': 'oceane_notes',
    'damage2_then_heal3': 'raph_petals',
    'set_wounds5': 'marion_plants',
    'aoe_zone6': 'artcade_flames',
    'double_move_dice': 'albane_clock',
    'ally_sacrifice_heal': 'amelia_light',
    'draw_dark': 'monkey_demon_eyes',
    'heal_on_same_terrain': 'augustin_wheat',
    'heal_per_equip_eot': 'fijacked_city',
    'shield3': 'louna_shield',
  };

  /// Extrait le résultat d'un dé depuis un log de type "...D4(3)..." ou "...D6(5)..."
  Map<String, int>? _extractDiceFromLog(String log) {
    final m = RegExp(r'D([46])\((\d+)\)').firstMatch(log);
    if (m == null) return null;
    final die = int.parse(m.group(1)!);
    final result = int.parse(m.group(2)!);
    return {'d': die, 'result': result};
  }

  /// Hong Yi : inflige 8 blessures à la cible ET meurt.
  Future<void> hongYiApplyAbility(Player target) async {
    final all = _mutableAll();
    final actor = all.firstWhere((p) => p.uid == myUid);
    final t = all.firstWhere((p) => p.uid == target.uid);
    final dealt = _eg.applyDamage(t, 8);
    if (!t.alive) t.killedByUid = actor.uid;
    // Hong Yi meurt
    actor.wounds = actor.character?.hp ?? 8;
    actor.alive = false;
    actor.abilityUsed = true;
    _eg.applyDeathPassives(all);
    final log = '⚡ ${actor.name} inflige $dealt à ${t.name} — et meurt de sa propre puissance !';
    await _commitAll(all, log);
    // Vérifier la victoire pour les deux morts potentiels
    if (!t.alive) await _checkWin(all, justDiedId: t.uid);
    if (!actor.alive) await _checkWin(all, justDiedId: actor.uid);
    await _fb.setPhase(roomId!, GamePhase.move, clearPending: true,
        abilityOverlay: 'hongyi_dumbbell');
    await endTurn();
  }

  /// Albane : marque abilityUsed après avoir choisi son lancer.
  /// Fifi : confirme ses valeurs de dés choisies.
  Future<void> fifiConfirmChoices(int move, int atk) async {
    await _fb.setPhase(roomId!, GamePhase.move,
        fifiGoldenTurn: true, fifiMoveResult: move, fifiAtkResult: atk);
    await _fb.addLog(roomId!, '🍀 Fifi choisit : déplacement $move · attaque $atk');
  }

  /// Retourne à la phase ability (ex: Vlad sans cible).
  Future<void> backToAbility() =>
      _fb.setPhase(roomId!, GamePhase.ability, clearPending: true);

  Future<void> markAlbaneUsed() async {
    final all = _mutableAll();
    final me = all.firstWhere((p) => p.uid == myUid);
    me.abilityUsed = true;
    await _fb.updatePlayer(roomId!, me);
    await _fb.addLog(roomId!, '⏱ ${me.name} utilise son pouvoir — meilleur lancer choisi !');
  }

  Future<void> useAbility({Player? target}) async {
    final all   = _mutableAll();
    final actor = all.firstWhere((p) => p.uid == myUid);
    final tgt = target != null
        ? all.firstWhere((p) => p.uid == target.uid, orElse: () => actor)
        : null;
    final log = _eg.applyAbility(actor, all, gameState!.terrainLayout, target: tgt);
    if (log == 'draw_dark') {
      // Monkey Raph : retourner en déplacement après la carte
      await _fb.setPhase(roomId!, gameState!.phase, peioReturnToMove: true);
      await drawCard(DeckType.tenebres);
      return;
    }
    if (log == 'draw_light') {
      // Élise : retourner en déplacement après la carte
      await _fb.setPhase(roomId!, gameState!.phase, peioReturnToMove: true);
      await drawCard(DeckType.lumiere);
      return;
    }
    if (log == 'double_move_dice') {
      // Albane : activer le double lancer pour ce tour
      await _commitAll(all, '⏱ Albane active son pouvoir — lancez les dés pour choisir le meilleur !');
      await _fb.setPhase(roomId!, GamePhase.move, clearPending: true);
      return;
    }
    if (log == 'elaia_peek') {
      // Elaia : ouvrir le choix de pile — abilityUsed=true verrouille pour ce
      // tour, réactivé au tour suivant (capacité répétable) automatiquement.
      await _commitAll(all, '🔮 ${actor.name} active son pouvoir de prescience…');
      await _fb.setPhase(roomId!, GamePhase.ability, elaiaStep: 1);
      return;
    }
    if (log.startsWith('tommy_copied:')) {
      final parts = log.split(':');
      final copiedName = parts.length > 1 ? parts[1] : '?';
      final copiedAbilityText = parts.length > 2 ? parts.sublist(2).join(':') : '';
      await _commitAll(all, '🎭 ${actor.name} copie le pouvoir de $copiedName : $copiedAbilityText');
      // Certains pouvoirs se déclenchent normalement à la révélation — pour
      // Tommy (déjà révélé), on les déclenche immédiatement après la copie.
      if (actor.copiedEffect == 'builder_power') {
        final offered = _eg.builderDraw3();
        await _fb.setPhase(roomId!, GamePhase.ability,
            builderStep: 1, builderOffered: offered);
        return;
      }
      if (actor.copiedEffect == 'prophete_mark') {
        await _fb.setPhase(roomId!, GamePhase.chooseTarget,
            pendingTargetAction: 'jeanne_mark_target', jeanneUid: actor.uid);
        return;
      }
      await _fb.setPhase(roomId!, GamePhase.move, clearPending: true);
      return;
    }
    if (log == 'casino_bet') {
      // Mr Casino : positionner directement le pendingTargetAction sans passer par _commitAll
      // (évite la fenêtre de race condition entre deux Firebase writes)
      await _fb.setPhase(roomId!, GamePhase.ability,
          pendingTargetAction: 'casino_bet');
      // Sauvegarder l'état du joueur (abilityUsed) séparément
      final p = all.firstWhere((pp) => pp.uid == myUid);
      await _fb.updatePlayer(roomId!, p);
      return;
    }
    if (log == 'swap_zones') {
      // Richard II échange sa zone actuelle avec une zone choisie
      final myZone = me!.zoneIndex;
      await _fb.setPhase(roomId!, GamePhase.chooseTarget,
          pendingTargetAction: 'swap_zone_pick2', swapZone1: myZone);
      return;
    }
    if (log == 'choose_all_dice') {
      // Fifi : afficher le sélecteur de dés avant d'appliquer
      await _commitAll(all, '🍀 Fifi active son pouvoir — choisissez vos dés !');
      await _fb.setPhase(roomId!, GamePhase.ability,
          pendingTargetAction: 'fifi_dice_picker');
      return;
    }
    if (log == 'bonus_turns_zero') {
      await _commitAll(all, '🥷 Ninja : aucun joueur mort, pouvoir sans effet.');
      await _fb.setPhase(roomId!, GamePhase.move);
      return;
    }
    if (log.startsWith('bonus_turns:')) {
      final deadCount = int.tryParse(log.split(':')[1]) ?? 0;
      await _commitAll(all, '🥷 Ninja active son pouvoir — $deadCount tour(s) bonus !');
      await _fb.setPhase(roomId!, GamePhase.move, bonusTurnsRemaining: deadCount);
      return;
    }
    if (log == 'cible_requise') {
      await _fb.setPhase(roomId!, GamePhase.chooseTarget,
          pendingTargetAction: actor.copiedEffect ?? actor.character!.abilityEffect);
      return;
    }
    if (log == 'cible_vlad') {
      // Vlad : vérifier qu'il y a des cibles adjacentes
      final vladTargets = _eg.attackTargets(actor, all, gameState!.terrainLayout);
      if (vladTargets.isEmpty) {
        await _fb.addLog(roomId!, '💨 Vlad — aucun joueur adjacent à portée.');
        await _fb.setPhase(roomId!, GamePhase.ability);
        return;
      }
      await _fb.setPhase(roomId!, GamePhase.chooseTarget,
          pendingTargetAction: 'ability_vlad_adjacent');
      return;
    }
    if (log == 'terrain_max_aoe') {
      // Hong Yi : signale qu'une cible est requise (tout le monde, pas seulement adjacents)
      await _fb.setPhase(roomId!, GamePhase.chooseTarget,
          pendingTargetAction: 'terrain_max_aoe');
      return;
    }
    if (log == 'trigger_terrain') {
      await _commitAll(all, "🧌 ${actor.name} subit 1 blessure → réactive l'effet du terrain");
      await _fb.setPhase(roomId!, gameState!.phase, peioReturnToMove: true);
      await applyTerrainEffect();
      return;
    }
    _eg.applyDeathPassives(all);
    await _commitAll(all, log);
    await _checkWin(all, justDiedId: tgt != null && !tgt.alive ? tgt.uid
        : (!actor.alive ? actor.uid : null));

    final overlay = _abilityOverlays[actor.copiedEffect ?? actor.character?.abilityEffect ?? ''];
    final dice = _extractDiceFromLog(log);
    // Si l'acteur est mort en utilisant sa capacité (ex: Raph), passer au tour suivant
    if (!actor.alive) {
      await _fb.setPhase(roomId!, GamePhase.move, clearPending: true,
          abilityOverlay: overlay, abilityDiceResult: dice);
      await endTurn();
      return;
    }
    await _fb.setPhase(roomId!, GamePhase.move, clearPending: true,
        abilityOverlay: overlay, abilityDiceResult: dice);
  }

  Future<void> skipAbility() => _fb.setPhase(roomId!, GamePhase.move);

  /// Force le passage en phase "choix de cible" pour une capacité qui offre
  /// un choix explicite (ex: Julien — attaquer vs se soigner).
  Future<void> requestTarget(String pendingTargetAction) =>
      _fb.setPhase(roomId!, GamePhase.chooseTarget, pendingTargetAction: pendingTargetAction);

  /// Efface l'overlay d'animation de capacité une fois jouée
  Future<void> clearAbilityOverlay() =>
      _fb.setPhase(roomId!, gameState?.phase ?? GamePhase.move, clearOverlay: true);

  Future<void> moveTo(int zoneIdx, {int diceSum = 0, int d4 = 0, int d6 = 0}) async {
    final all = _mutableAll();
    final p = all.firstWhere((x) => x.uid == myUid);
    p.zoneIndex = zoneIdx;
    final t = gameState!.terrainLayout[zoneIdx];
    if (diceSum == 7 && p.character?.abilityEffect == 'heal_on_same_terrain' && p.revealed) {
      _eg.applyHeal(p, 2);
      await _commitAll(all, '🚶 ${p.name} → ${t.name}  •  🌾 Augustin (7) — soigné de 2');
    } else {
      await _commitAll(all, '🚶 ${p.name} → ${t.name}');
    }
    await _fb.setPhase(roomId!, GamePhase.zoneEffect,
        richardActivateZone: -1,
        lastDiceResult: d4 > 0 ? {'d4': d4, 'd6': d6, 'sum': diceSum} : null,
        lastDiceLabel: d4 > 0 ? 'Déplacement' : null,
        lastDiceTimestamp: d4 > 0 ? DateTime.now().millisecondsSinceEpoch : null);
  }

  /// Voiture de Clem (capacité) ou Portail du Nether (équipement) : échange
  /// de position avec un autre joueur au lieu de se déplacer normalement.
  Future<void> swapPosition(Player target) async {
    final all = _mutableAll();
    final p = all.firstWhere((x) => x.uid == myUid);
    final t = all.firstWhere((x) => x.uid == target.uid, orElse: () => p);
    final tmp = p.zoneIndex; p.zoneIndex = t.zoneIndex; t.zoneIndex = tmp;
    await _commitAll(all, '🚗 ${p.name} échange sa place avec ${t.name}');
    await _fb.setPhase(roomId!, GamePhase.zoneEffect, richardActivateZone: -1);
  }

  Future<void> applyTerrainEffect({int? zoneOverride}) async {
    final t = gameState!.terrainLayout[zoneOverride ?? me!.zoneIndex];
    switch (t.effect) {
      case 'vision':    await drawCard(DeckType.vision); break;
      case 'lumiere':   await drawCard(DeckType.lumiere); break;
      case 'tenebres':  await drawCard(DeckType.tenebres); break;
      case 'choice':    await _fb.setPhase(roomId!, GamePhase.cardChoice, clearPending: true); break;
      case 'damage9':   await _fb.setPhase(roomId!, GamePhase.chooseTarget, clearPending: true, pendingTargetAction: 'terrain_damage9'); break;
      case 'steal':     await _fb.setPhase(roomId!, GamePhase.chooseTarget, clearPending: true, pendingTargetAction: 'terrain_steal'); break;
      default:          await _fb.setPhase(roomId!, _postCardPhase(), peioReturnToMove: false, clearPending: true); break;
    }
  }

  /// Détermine la phase à utiliser après résolution d'une carte/effet de
  /// terrain. Normalement `attack`, mais Monkey Raph / Élise retournent en
  /// `move` une fois (flag consommé) pour pouvoir se déplacer après avoir
  /// pioché. IMPORTANT : ne fait AUCUNE écriture Firebase elle-même — la
  /// remise à zéro de `peioReturnToMove` doit être incluse dans le MÊME
  /// setPhase que l'appelant (sinon race condition entre deux écritures
  /// séquentielles : le jeu peut rester bloqué en phase cardDrawn).
  GamePhase _postCardPhase() {
    return gameState?.peioReturnToMove == true ? GamePhase.move : GamePhase.attack;
  }

  Future<void> skipTerrainEffect() async =>
      await _fb.setPhase(roomId!, _postCardPhase(), peioReturnToMove: false, clearPending: true);

  /// Résout une cible pour les effets de terrain (Clairière / Tour du Voleur)
  Future<void> applyTerrainTarget(Player target) async {
    final pta = gameState?.pendingTargetAction;
    final all = _mutableAll();
    final actor = all.firstWhere((p) => p.uid == myUid);
    final t = all.firstWhere((p) => p.uid == target.uid, orElse: () => target);

    if (pta == 'terrain_damage9') {
      _eg.applyDamage(t, 2, isTerrain9Dmg: true);
      _eg.applyDeathPassives(all);
      await _commitAll(all, '🏹 ${actor.name} inflige 2 blessures à ${t.name}');
    } else if (pta == 'terrain_steal') {
      if (t.equipment.isNotEmpty) {
        final e = t.equipment.removeAt(0);
        actor.equipment.add(e);
        _eg.equipPassivePublic(actor, e);   // active le passif de l'équipement volé
        _eg.recalcPassives(t);              // retire le passif de la victime
        await _commitAll(all, '🗼 ${actor.name} vole "${e.name}" à ${t.name}');
      } else {
        await _commitAll(all, '🗼 ${t.name} n\'a aucun équipement à voler');
      }
    }
    await _checkWin(all, justDiedId: t.alive ? null : t.uid);
    await _fb.setPhase(roomId!, _postCardPhase(), clearPending: true, peioReturnToMove: false);
  }

  Future<void> drawCard(DeckType deck) async {
    final queue = Map<String, List<String>>.from(
        (gameState?.forcedDeckQueue ?? const {}).map(
            (k, v) => MapEntry(k, List<String>.from(v))));
    final card = _eg.drawCard(deck, forcedQueue: queue);
    await _fb.setPhase(roomId!, GamePhase.cardDrawn,
        pendingAction: card.id, forcedDeckQueue: queue);
    // Cartes Vision : nom secret — log public générique
    if (deck == DeckType.vision) {
      await _fb.addLog(roomId!, '🔮 ${me!.name} pioche une carte Vision (secrète)');
      await _fb.addPrivateLog(roomId!, myUid!, '🔮 Tu as pioché : ${card.name}');
    } else {
      await _fb.addLog(roomId!, '🃏 ${me!.name} pioche : ${card.name}');
    }
  }

  Future<void> applyCard({Player? target}) async {
    final cardId = gameState!.pendingAction; if (cardId == null) return;
    final card = findCardById(cardId); if (card == null) return;
    final all   = _mutableAll();
    final actor = all.firstWhere((p) => p.uid == myUid);
    final tgt = target != null
        ? all.firstWhere((p) => p.uid == target.uid, orElse: () => actor)
        : null;
    final res = _eg.resolveCard(card, actor, all, gameState!.terrainLayout, target: tgt);
    if (res['needsTarget'] == true) {
      await _fb.setPhase(roomId!, GamePhase.chooseTarget, pendingTargetAction: res['action'] as String);
      return;
    }
    if (res['needsTargetChoice'] == true) {
      // Divination X ou Y : la VRAIE cible doit répondre — on commit l'état
      // actuel (rien n'a encore changé) et on ouvre l'attente de réponse.
      await _commitAll(all, '');
      await _fb.setPhase(roomId!, _postCardPhase(), clearPending: true,
          peioReturnToMove: false,
          pendingPunishActorUid: res['punishActorUid'] as String,
          pendingPunishTargetUid: res['punishTargetUid'] as String);
      return;
    }
    if (res['needsSecondTarget'] == true) {
      // Corne des Woods — étape 2 : on doit choisir la victime, restreinte
      // à la portée du joueur forcé d'attaquer.
      await _fb.setPhase(roomId!, GamePhase.chooseTarget, clearPending: true,
          pendingTargetAction: 'corne_des_woods_victim',
          forcedAttackerUid: res['forcedAttackerUid'] as String);
      return;
    }
    if (res['privateRevealUid'] != null) {
      _eg.applyDeathPassives(all);
      await _commitAll(all, res['log'] as String);
      await _checkWin(all);
      await _fb.setPhase(roomId!, _postCardPhase(), clearPending: true,
          peioReturnToMove: false,
          privateRevealTargetUid: res['privateRevealUid'] as String,
          privateRevealForUid: actor.uid);
      return;
    }
    if (res['needsEquipChoice'] == true) {
      await _commitAll(all, '');
      await _fb.setPhase(roomId!, GamePhase.chooseTarget, clearPending: true,
          pendingTargetAction: 'equip_choice',
          forcedAttackerUid: '${res["equipChoiceMode"]}|${res["equipChoiceActorUid"]}|${res["equipChoiceTargetUid"]}');
      return;
    }
    if (res['special'] == 'reroll_move') {
      await _commitAll(all, res['log'] as String);
      final cardDr = res['diceResult'] as Map<String, dynamic>?;
      await _fb.setPhase(roomId!, GamePhase.zoneEffect, clearPending: true,
          lastDiceResult: cardDr != null ? {'d4': cardDr['d4'] as int? ?? 0, 'd6': cardDr['d6'] as int? ?? 0, 'sum': cardDr['sum'] as int? ?? 0} : null,
          lastDiceLabel: 'Ricard',
          lastDiceTimestamp: DateTime.now().millisecondsSinceEpoch);
      return;
    }
    _eg.applyDeathPassives(all);
    // Rattrapage : de nombreux effets de carte infligent des dégâts sans
    // attribuer explicitement killedByUid — sans ça, Tommy ne serait jamais
    // reconnu comme l'auteur du kill quand il joue une carte lui-même.
    for (final d in all.where((x) => !x.alive)) { d.killedByUid ??= actor.uid; }
    await _commitAll(all, res['log'] as String);
    // Une carte peut tuer plusieurs joueurs (AoE, Dynamite...) — vérifier la
    // victoire pour CHAQUE joueur mort, pas seulement la cible unique passée
    // (sinon Tommy/Mango Loco ne gagnent jamais quand le kill vient d'une carte).
    final justDied = all.where((x) => !x.alive).toList();
    if (justDied.isEmpty) {
      await _checkWin(all);
    } else {
      for (final d in justDied) { await _checkWin(all, justDiedId: d.uid); }
    }
    // Diffuser le résultat des dés si la carte en a produit un (Dynamite,
    // Poupée Démoniaque, etc.) — certaines cartes (Poupée Démoniaque) ne
    // lancent qu'un D6 avec d4=0 par design ; il ne faut PAS se baser sur
    // "d4 > 0" pour décider s'il y a un résultat à montrer, sinon ces cartes
    // n'affichent jamais leur dé en multijoueur.
    final cardDice = res['diceResult'] as Map<String, dynamic>?;
    final d4c = cardDice?['d4'] as int? ?? 0;
    final d6c = cardDice?['d6'] as int? ?? 0;
    final sumc = cardDice?['sum'] as int? ?? 0;
    final labelc = cardDice?['label'] as String? ?? '🎲';
    await _fb.setPhase(roomId!, _postCardPhase(), clearPending: true,
        peioReturnToMove: false,
        lastDiceResult: cardDice != null ? {'d4': d4c, 'd6': d6c, 'sum': sumc} : null,
        lastDiceLabel: cardDice != null ? labelc : null,
        lastDiceTimestamp: cardDice != null ? DateTime.now().millisecondsSinceEpoch : null);
  }

  /// Divination X ou Y : la cible répond enfin à la "punition" — donne un
  /// équipement (au choix) à l'auteur de la carte, ou subit 1 blessure.
  Future<void> resolvePunishChoice(bool giveEquipment, {int? equipmentIndex}) async {
    final actorUid = gameState?.pendingPunishActorUid;
    final targetUid = gameState?.pendingPunishTargetUid;
    if (actorUid == null || targetUid == null) return;
    final all = _mutableAll();
    final actor = all.firstWhere((p) => p.uid == actorUid);
    final target = all.firstWhere((p) => p.uid == targetUid);
    final log = _eg.resolvePunishChoice(actor, target, giveEquipment, equipmentIndex: equipmentIndex);
    _eg.applyDeathPassives(all);
    await _commitAll(all, log);
    await _checkWin(all, justDiedId: target.alive ? null : target.uid);
    await _fb.setPhase(roomId!, GamePhase.attack, clearPending: true);
  }

  /// Vision Suprême : ferme la popup de révélation privée une fois consultée.
  Future<void> dismissPrivateReveal() => _fb.clearPrivateReveal(roomId!);

  /// Corne des Woods — étape 2 : la victime est enfin choisie, l'attaque
  /// forcée se résout immédiatement.
  Future<void> resolveCorneVictim(Player victim) async {
    final attackerUid = gameState?.forcedAttackerUid;
    if (attackerUid == null) return;
    final all = _mutableAll();
    final attacker = all.firstWhere((p) => p.uid == attackerUid);
    final v = all.firstWhere((p) => p.uid == victim.uid);
    final res = _eg.resolveCorneDesWoods(attacker, v);
    _eg.applyDeathPassives(all);
    await _commitAll(all, res['log'] as String);
    await _checkWin(all, justDiedId: v.alive ? null : v.uid);
    final dr = res['diceResult'] as Map<String, dynamic>;
    await _fb.setPhase(roomId!, GamePhase.attack, clearPending: true,
        lastDiceResult: {'d4': dr['d4'] as int, 'd6': dr['d6'] as int, 'sum': dr['sum'] as int},
        lastDiceLabel: '🌳 Corne des Woods',
        lastDiceTimestamp: DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> skipCard() async =>
      await _fb.setPhase(roomId!, _postCardPhase(), clearPending: true, peioReturnToMove: false);

  /// Retire le premier équipement avec l'effet donné de l'inventaire du joueur courant.
  Future<void> consumeEquipment(String effect) async {
    final all = _mutableAll();
    final me = all.firstWhere((p) => p.uid == myUid);
    final idx = me.equipment.indexWhere((e) => e.effect == effect);
    if (idx >= 0) {
      me.equipment.removeAt(idx);
      _eg.recalcPassives(me);
      await _commitAll(all, '');
    }
  }



  Future<void> attackPlayer(String targetId, int baseDmg, {int d4 = 0, int d6 = 0}) async {
    if (gameState?.hasAttacked == true) return; // une seule attaque par tour
    final all = _mutableAll();
    final attacker = all.firstWhere((p) => p.uid == myUid);
    final target = all.firstWhere((p) => p.uid == targetId);
    attacker.attackCount++;
    final isMathieuThird = (attacker.copiedEffect ?? attacker.character?.abilityEffect ?? '') == 'third_attack_bonus'
        && attacker.attackCount >= 3;
    bool scottCountered = false;
    String log;
    if (attacker.bazooka) {
      final bazTargets = _eg.attackTargets(attacker, all, gameState!.terrainLayout);
      final bazDmg = baseDmg + attacker.equipment.where((e) => e.effect == 'dague_voleur').length; // Dague(s) du Voleur
      for (final t in bazTargets) {
        _eg.applyDamage(t, bazDmg);
        if (!t.alive) t.killedByUid = attacker.uid;
      }
      log = '💥 ${attacker.name} (Bazooka) — $bazDmg dégâts à tous !';
    } else {
      final res = _eg.resolveAttack(attacker, target, baseDmg);
      log = res['log'] as String;
      if (res['scottCountered'] == true) scottCountered = true;
    }
    final (gegeLog, gegeTriggered) = _eg.applyGegePassiveEx(attacker, target, all);
    if (gegeLog != null) log = '$log\n$gegeLog';
    // Gège le Fantôme : la contre-attaque de Scott EST aussi une attaque d'un
    // Hunter révélé — sans ce check séparé, Gège ne se déclenchait jamais
    // sur les contre-attaques (rôles inversés : Scott devient l'attaquant).
    bool gegeTriggered2 = false;
    if (scottCountered && attacker.alive) {
      final (gegeLog2, t2) = _eg.applyGegePassiveEx(target, attacker, all);
      if (gegeLog2 != null) { log = '$log\n$gegeLog2'; gegeTriggered2 = t2; }
    }
    _eg.applyDeathPassives(all);
    await _commitAll(all, log);
    // Le bazooka peut tuer PLUSIEURS joueurs en même temps — vérifier la
    // victoire/butin/récompense de Jeanne pour CHAQUE mort, pas seulement la
    // cible cliquée (sinon un 2e joueur tué par la même volée était ignoré).
    if (attacker.bazooka) {
      final justDied = all.where((x) => !x.alive).toList();
      if (justDied.isEmpty) {
        await _checkWin(all);
      } else {
        final lootAcc = <MapEntry<String,String>>[];
        for (final d in justDied) { await _checkWin(all, justDiedId: d.uid, lootAccumulator: lootAcc); }
        // Une seule écriture combinée pour TOUTES les opportunités de butin
        // détectées (au lieu d'une écriture par mort qui s'écraseraient).
        if (lootAcc.isNotEmpty) {
          final killerUid = lootAcc.first.key; // même tueur pour tous (même volée)
          final deadQueue = lootAcc.map((e) => e.value).toList();
          await _fb.setPhase(roomId!, gameState?.phase ?? GamePhase.attack,
              lootKillerUid: killerUid, lootDeadQueue: deadQueue);
        }
      }
    } else {
      await _checkWin(all, justDiedId: target.alive ? null : target.uid);
    }
    await _fb.setPhase(roomId!, GamePhase.attack, hasAttacked: true,
        lastDiceResult: d4 > 0 ? {'d4': d4, 'd6': d6, 'sum': baseDmg} : null,
        lastDiceLabel: d4 > 0 ? 'Attaque' : null,
        lastDiceTimestamp: d4 > 0 ? DateTime.now().millisecondsSinceEpoch : null,
        abilityOverlay: (gegeTriggered || gegeTriggered2) ? 'gege_ghost' : scottCountered ? 'scott_counter' : isMathieuThird ? 'mathieu_bullet' : null);
  }

  /// Richard II : sélection d'une zone (étape 1 ou 2).
  Future<void> chooseSwapZone(int zoneIdx) async {
    final gs = gameState!;
    if (gs.swapZone1 == null) {
      await _fb.setPhase(roomId!, GamePhase.chooseTarget,
          pendingTargetAction: 'swap_zone_pick2', swapZone1: zoneIdx);
    } else {
      final z1 = gs.swapZone1!;
      if (z1 == zoneIdx) return;
      final all = _mutableAll();
      final richard = all.firstWhere((p) => p.uid == myUid);
      final richardStartZone = richard.zoneIndex; // avant tout changement
      // Tous les joueurs présents sur les 2 zones échangées suivent leur
      // tuile (échangent aussi de position) — Richard inclus, pour le
      // déplacement visuel sur le plateau.
      for (final p in all) {
        if (p.zoneIndex == z1) p.zoneIndex = zoneIdx;
        else if (p.zoneIndex == zoneIdx) p.zoneIndex = z1;
      }
      // Construire le nouveau layout avec l'échange
      final newLayout = List<Terrain>.from(gs.terrainLayout);
      final tmp = newLayout[z1]; newLayout[z1] = newLayout[zoneIdx]; newLayout[zoneIdx] = tmp;
      final t1name = newLayout[z1].name; final t2name = newLayout[zoneIdx].name;
      await _commitAll(all, '👑 Richard II échange $t2name ↔ $t1name !');
      await _fb.setTerrainLayout(roomId!, newLayout);
      // Richard active l'effet du terrain qui vient d'arriver sur SA case de
      // départ (celui avec lequel il a échangé), pas celui qu'il a emporté
      // avec lui en se déplaçant.
      await _fb.setPhase(roomId!, GamePhase.zoneEffect,
          clearPending: true, swapZone1: -1, swapZone2: -1,
          abilityOverlay: 'richard2_swap', richardActivateZone: richardStartZone);
    }
  }

  Future<void> endTurn() async {
    // Ninja : tours bonus restants
    final bonusLeft = gameState?.bonusTurnsRemaining ?? 0;
    if (bonusLeft > 0) {
      await _fb.setPhase(roomId!, GamePhase.move,
          bonusTurnsRemaining: bonusLeft - 1, hasAttacked: false);
      await _fb.addLog(roomId!, '🥷 Ninja rejoue ! (${bonusLeft - 1} tour(s) restant(s))');
      return;
    }
    final p = _mutableMe();
    if (p.newTurn) {
      p.newTurn = false;
      await _commitPlayer(p, '⏰ ${p.name} joue un tour de plus');
      await _fb.setPhase(roomId!, GamePhase.move, currentPlayerId: myUid, hasAttacked: false);
      return;
    }
    if (p.shield && p.shieldCharges == 99) { p.shield = false; p.shieldCharges = 0; }
    await _fb.updatePlayer(roomId!, p);
    await _fb.addLog(roomId!, '⏩ ${p.name} termine son tour');
    // Effacer fifiGoldenTurn
    if (gameState?.fifiGoldenTurn == true) {
      await _fb.setPhase(roomId!, gameState!.phase, fifiGoldenTurn: false);
    }
    final order = gameState!.playerOrder;
    int next = (order.indexOf(myUid!) + 1) % order.length;
    while (!players[order[next]]!.alive) { next = (next + 1) % order.length; }
    final all = _mutableAll();
    final nextPlayer = all.firstWhere((x) => x.uid == order[next]);
    if (nextPlayer.character?.abilityRepeatable == true) nextPlayer.abilityUsed = false;
    if (nextPlayer.shield && nextPlayer.shieldCharges == 99) {
      nextPlayer.shield = false; nextPlayer.shieldCharges = 0;
    }
    nextPlayer.damageTakenThisTurn = 0; // remise à zéro pour le tracking de Jason
    // Passifs de début de tour (Plat de Tripes, Menus, Fijacked, Scott...)
    final passiveLogs = _eg.applyStartOfTurnPassives(nextPlayer, all, gameState!.terrainLayout);
    _eg.applyDeathPassives(all);
    await _commitAll(all, passiveLogs.join(' | '));
    if (!nextPlayer.alive) { await _checkWin(all, justDiedId: nextPlayer.uid); }
    await _fb.setPhase(roomId!, GamePhase.ability, currentPlayerId: order[next], hasAttacked: false, clearPending: true);
  }

  // ─── Privé ───────────────────────────────
  Player _mutableMe() => players[myUid]!.copy();
  List<Player> _mutableAll() => players.values.map((p) => p.copy()).toList();

  Future<void> _commitPlayer(Player p, String log) async {
    await _fb.updatePlayer(roomId!, p);
    await _fb.addLog(roomId!, log);
  }

  Future<void> _commitAll(List<Player> all, String log) async {
    await _fb.updatePlayers(roomId!, all);
    await _fb.addLog(roomId!, log);
  }

  Future<void> _checkWin(List<Player> all, {String? justDiedId,
      List<MapEntry<String,String>>? lootAccumulator}) async {
    // Jeanne : vérifie si le mort était la cible marquée
    if (justDiedId != null && gameState?.markedPlayerUid == justDiedId) {
      final (log, needsCard, killerUid) = _eg.checkJeanneReward(
          gameState?.markedPlayerUid, gameState?.jeanneReward,
          gameState?.jeanneUid, all);
      if (log.isNotEmpty) {
        // Commit les changements (soins killer + Jeanne)
        await _fb.updatePlayers(roomId!, all);
        await _fb.addLog(roomId!, log);
      }
      // Effacer le marquage
      await _fb.setPhase(roomId!, gameState?.phase ?? GamePhase.attack,
          markedPlayerUid: '__clear__');
      if (needsCard && killerUid == myUid) {
        final gs = gameState;
        if (gs?.jeanneReward == 'heal3_lumiere') await drawCard(DeckType.lumiere);
        if (gs?.jeanneReward == 'draw_vision') await drawCard(DeckType.vision);
      }
    }
    final res = _eg.checkWin(all, justDiedId: justDiedId);
    if (res != null) {
      await _fb.setGameOver(roomId!, List<String>.from(res['winnerIds']!), res['reason'] as String);
      return;
    }
    // Butin : le tueur peut choisir de récupérer un équipement de sa victime.
    // Si un accumulateur est fourni (kills multiples dans une même boucle
    // synchrone, ex: bazooka), on y ajoute SANS écrire Firebase à chaque
    // itération — sinon un 2e appel lirait un `gameState` local pas encore
    // synchronisé et écraserait le résultat du 1er (condition de course).
    if (justDiedId != null) {
      final dead = all.firstWhere((p) => p.uid == justDiedId, orElse: () => all.first);
      final loot = _eg.checkLootOpportunity(dead, all);
      if (loot != null) {
        final (killerUid, deadUid) = loot;
        if (lootAccumulator != null) {
          lootAccumulator.add(MapEntry(killerUid, deadUid));
        } else {
          await _fb.setPhase(roomId!, gameState?.phase ?? GamePhase.attack,
              lootKillerUid: killerUid, lootDeadQueue: [deadUid]);
        }
      }
    }
    // Jason : vient-il de perdre son déguisement (5+ dégâts en un tour) ?
    // Indépendant d'un kill éventuel — diffuse sa vraie révélation à tous.
    final unmasked = _eg.checkDisguiseLost(all);
    if (unmasked != null) {
      unmasked.disguiseJustLost = false;
      await _commitAll(all, '🎭 ${unmasked.name} perd son déguisement — sa vraie identité est révélée !');
      await _fb.setPhase(roomId!, gameState?.phase ?? GamePhase.attack,
          publicRevealUid: unmasked.uid,
          publicRevealTimestamp: DateTime.now().millisecondsSinceEpoch);
    }
  }
}
