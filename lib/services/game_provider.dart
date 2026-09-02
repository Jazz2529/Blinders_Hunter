// lib/services/game_provider.dart
// Provider multijoueur — pont Firebase ↔ UI

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'i18n.dart';
import '../models/models.dart';
import '../data/game_data.dart';
import '../data/interactions_data.dart';
import 'engine.dart';
import 'audio_service.dart';
import 'firebase_service.dart';
import 'persistence.dart';
import 'solo_controller.dart' show AiBrain;

class GameProvider extends ChangeNotifier {
  final FirebaseService _fb = FirebaseService.instance;
  FirebaseService get fb => _fb; // accès lecture (reconnexion, etc.)
  final GameEngine      _eg = GameEngine.instance;
  final AiBrain         _ai = AiBrain(); // pilotage des bots en multijoueur
  static const AiDifficulty _botDifficulty = AiDifficulty.normal;

  // ── Anti-spam centralisé ─────────────────────────────────────────────
  // De nombreux boutons appellent une méthode de GameProvider directement
  // (onTap: () => gp.xxx()), sans passer par le garde local `_act()` de
  // _ActionPanelState (qui n'existe que pour CE widget précis) — un tap
  // rapide et répété pouvait donc déclencher le MÊME effet plusieurs fois
  // avant que le premier aller-retour Firestore ne mette à jour l'état et
  // ne fasse disparaître le bouton. `guardedAction` centralise la
  // protection au niveau du provider, partagé par TOUS les boutons peu
  // importe le widget qui les affiche.
  bool _actionBusy = false;
  // Dés de déplacement DÉJÀ lancés, en attente de confirmation — stockés
  // ICI (sur GameProvider, fourni tout en haut de l'arbre de widgets, donc
  // jamais reconstruit par un changement de réglages d'affichage) plutôt
  // que dans l'état local d'un widget. Sinon, n'importe quel changement
  // ailleurs dans l'appli (ex: modifier l'échelle d'affichage) faisait
  // perdre ce jet et permettait de relancer les dés gratuitement jusqu'à
  // obtenir un résultat plus favorable — un vrai exploit.
  int? pendingMoveD4, pendingMoveD6, pendingMoveSum;
  int? pendingMoveD4b, pendingMoveD6b, pendingMoveSum2; // Boussole Mystique : 2e lancer
  /// Exposé publiquement (et réactif via notifyListeners) pour que
  /// l'interface puisse désactiver VISUELLEMENT les boutons pendant
  /// qu'une action est en cours — seconde couche de protection en plus du
  /// verrou logique ci-dessous, qui empêchait bien un DEUXIÈME appel de
  /// s'exécuter mais ne rendait jamais le bouton visuellement désactivé
  /// (l'utilisateur pouvait donc continuer à appuyer dessus sans retour).
  bool get actionBusy => _actionBusy;
  Future<void> guardedAction(Future<void> Function() fn) async {
    if (_actionBusy) return;
    _actionBusy = true;
    notifyListeners();
    try {
      await fn();
      // IMPORTANT : de nombreuses actions ne mettent à jour QUE Firestore
      // (via _fb.setPhase) sans synchroniser le cache LOCAL immédiatement
      // (contrairement à _commitAll/_commitPlayer, corrigés séparément) —
      // sans cette marge, le bouton redevenait cliquable AVANT que le
      // sondage réseau (~900ms) n'ait rattrapé le nouvel état, permettant
      // de le presser une deuxième fois sur la base d'un affichage encore
      // périmé. Cette pause laisse le temps à au moins un cycle de
      // sondage de passer avant de débloquer l'interface.
      await Future.delayed(const Duration(milliseconds: 1000));
    } finally {
      _actionBusy = false;
      notifyListeners();
    }
  }
  final bool firebaseEnabled;
  GameProvider({this.firebaseEnabled = false});

  String? roomId;
  String? myUid;
  String? hostId;
  List<String>? enabledCharacterIds; // null/vide = tous les personnages (défaut)
  GameState? gameState;
  Map<String, Player> players = {};
  String roomStatus = 'lobby';
  Map<String, dynamic>? gameResult;
  int roleConfirms = 0;
  List<String> log = [];
  List<String> privateLog = []; // logs visibles seulement par ce joueur

  StreamSubscription? _gsSub, _pSub, _stSub, _rSub, _rcSub, _logSub, _privLogSub, _hostSub;

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
    // Hache / Sabre : si aucune cible accessible, s'attaque soi-même — SAUF
    // si le Révolver des Ténèbres est équipé (règle de portée stricte
    // inversée), sinon on proposait à tort un bouton "s'attaquer soi-même"
    // qui n'a aucun sens avec le Révolver et créait un bouton fantôme.
    final hasRevolver = actor.equipment.any((e) => e.effect == 'revolver_tenebres');
    if (targets.isEmpty && (actor.hache || actor.epeeNinja) && !hasRevolver) return [actor];
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
    // Skins de terrain aléatoires (si le réglage est activé) — tirés
    // localement pour toute la durée de cette partie (purement visuel,
    // pas besoin de synchronisation entre joueurs).
    Prefs.rollRandomTerrainSkinsForNewGame();
    _subscribe(); notifyListeners();
    return roomId!;
  }

  Future<void> joinRoom(String code, String name, String token) async {
    await _fb.joinRoom(code.toUpperCase(), name, token);
    roomId = code.toUpperCase(); myUid = _fb.currentUid;
    hostId = await _fb.getHostId(roomId!);
    Prefs.saveRoom(roomId!, myUid!);
    Prefs.rollRandomTerrainSkinsForNewGame();
    _subscribe(); notifyListeners();
  }

  /// Ajoute un bot à la salle — hôte uniquement, lobby uniquement.
  Future<void> addBot() async {
    if (roomId == null || !isHost) return;
    await _fb.addBot(roomId!);
  }

  /// Retire un bot de la salle — hôte uniquement, lobby uniquement.
  Future<void> removeBot(String botUid) async {
    if (roomId == null || !isHost) return;
    await _fb.removeBot(roomId!, botUid);
  }

  /// Expulse un joueur HUMAIN de la salle — réservé à l'hôte, lobby
  /// uniquement (avant le lancement de la partie). Ne s'expulse jamais
  /// lui-même (vérifié aussi côté interface, mais on protège ici aussi).
  Future<void> kickPlayer(String uid) async {
    if (roomId == null || !isHost || uid == myUid) return;
    await _fb.kickPlayer(roomId!, uid);
  }

  /// Récupère la liste actuelle des personnages activés pour cette salle
  /// (appelé à l'ouverture de l'écran de sélection) — liste vide = tous.
  Future<void> fetchEnabledCharacters() async {
    if (roomId == null) return;
    enabledCharacterIds = await _fb.getEnabledCharacters(roomId!);
    notifyListeners();
  }

  /// Met à jour la liste des personnages activés (hôte uniquement).
  Future<void> updateEnabledCharacters(List<String> ids) async {
    if (roomId == null || !isHost) return;
    await _fb.setEnabledCharacters(roomId!, ids);
    enabledCharacterIds = ids;
    notifyListeners();
  }

  /// Quitte une partie EN COURS — le joueur est remplacé par un bot (qui
  /// continue à sa place avec le même personnage/PV/équipement) plutôt que
  /// de simplement bloquer la partie pour tout le monde. Accessible à
  /// n'importe quel joueur, pas seulement l'hôte.
  Future<void> leaveGameAsBot() async {
    if (roomId == null || myUid == null) return;
    await _fb.convertPlayerToBot(roomId!, myUid!);
    Prefs.clearRoom();
    _pSub?.cancel(); _gsSub?.cancel(); _stSub?.cancel(); _rSub?.cancel(); _rcSub?.cancel(); _logSub?.cancel(); _privLogSub?.cancel(); _hostSub?.cancel();
    _pSub = _gsSub = _stSub = _rSub = _rcSub = _logSub = _privLogSub = _hostSub = null;
    _fb.stopPollingRoom(roomId!);
    roomId = null; myUid = null; hostId = null;
    gameState = null; players = {};
    roomStatus = 'lobby';
    gameResult = null;
    log = [];
    privateLog = [];
    notifyListeners();
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
  bool _botDriving = false; // évite 2 pilotages simultanés du même bot

  // Mêmes listes que solo_controller.dart (dupliquées : petites listes
  // statiques, peu de risque de divergence, évite un couplage supplémentaire
  // entre les deux contrôleurs).
  bool _abilityNeedsTarget(String eff) => [
    'damage2_choice','damage2_then_heal3','set_wounds7','steal_equip_choice',
    'damage3_give_dague','d6_global_attack','terrain_max_aoe','d6_lifesteal',
    'swap_equipment','damien_serve','copy_ability','d4_heal_neighbors','luc_ignite','baptiste_revive',
    'lock_ability_while_alive','steal_max_hp','maxence_drunk',
    'store_damage_nils','d4_bonus_attack',
  ].contains(eff);

  bool _cardNeedsTarget(String eff) => [
    'heal_other_d6','heal_other_d4','set_marker7_choice','banane_demonique',
    'vampirisation','blue_shell','veuve_noire','peau_banane','pince_attrape',
    'trebuchet','vision_shadow_2','vision_shadow_1','vision_hunter_1','vision_hunter_2',
    'vision_shadow_heal_or_dmg','vision_hunter_heal_or_dmg','vision_neutral_heal_or_dmg',
    'vision_show_card','vision_punish_neutral_shadow','vision_punish_neutral_hunter',
    'vision_punish_shadow_hunter','vision_hp_12plus','vision_hp_11minus',
  ].contains(eff);

  // Pouvoirs nécessitant un enchaînement d'écrans dédiés (pari, échange de
  // zones, sélecteur de dés, tours bonus, prescience, capacité copiée…) —
  // un bot les ignore prudemment pour l'instant plutôt que de risquer de
  // rester bloqué au milieu d'un flux conçu pour une vraie interface.
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
    // IMPORTANT : convertir aussi ce joueur en bot, pas seulement sauter
    // son tour — sans ça, un joueur qui a fermé l'application ou perdu la
    // connexion (l'architecture actuelle, par sondage HTTP, ne permet pas
    // de détecter une vraie déconnexion en temps réel) obligeait à
    // attendre à NOUVEAU 2 minutes à CHAQUE tour suivant, indéfiniment.
    // Une fois converti, _maybeDriveBot() prend automatiquement le relais
    // pour la suite de la partie.
    if (cur != null && !cur.isBot) {
      await _fb.convertPlayerToBot(roomId!, cur.uid);
    }
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
    bool gameEndedTurn = false;
    if (!nextPlayer.alive) { gameEndedTurn = await _checkWin(all, justDiedId: nextPlayer.uid); }
    if (gameEndedTurn) return;
    // IMPORTANT : si nextPlayer vient de mourir de son PROPRE passif de
    // début de tour (poison de Damien, feu de Luc...), il ne peut évidemment
    // pas jouer son tour — il faut sauter au joueur vivant suivant, EXACTEMENT
    // comme la boucle plus haut le fait déjà pour les morts déjà connues au
    // moment de choisir "next". Sans ça, un joueur mort restait "current",
    // bloquant la partie.
    var realNext = next;
    while (!(all.firstWhere((p) => p.uid == order[realNext]).alive)) {
      realNext = (realNext + 1) % order.length;
    }
    // Le tueur d'un passif de début de tour a droit au même butin qu'après
    // une attaque directe — manquait ENTIÈREMENT ici, donc mourir de cette
        // façon ne permettait JAMAIS à son auteur de récupérer un équipement,
    // même si killedByUid était (lui) correctement renseigné. Le
    // currentPlayerId du VRAI joueur suivant est fixé dans ce même appel :
    // une fois le butin résolu (lootChooseItem/lootSkip), la phase revient
    // à gameState.phase SANS re-préciser currentPlayerId — il doit donc
    // déjà être correct ici, sans quoi la partie restait bloquée sur le
    // joueur mort après résolution du butin.
    if (!nextPlayer.alive && nextPlayer.killedByUid != null) {
      final killer = all.where((p) => p.uid == nextPlayer.killedByUid).firstOrNull;
      if (killer != null && killer.alive && nextPlayer.equipment.isNotEmpty) {
        await _fb.setPhase(roomId!, GamePhase.ability,
            currentPlayerId: order[realNext], hasAttacked: false, clearPending: true,
            lootKillerUid: killer.uid, lootDeadQueue: [nextPlayer.uid]);
        return;
      }
    }
    await _fb.setPhase(roomId!, GamePhase.ability,
        currentPlayerId: order[realNext], hasAttacked: false, clearPending: true);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PILOTAGE DES BOTS EN MULTIJOUEUR
  // Réutilise la même IA de décision que le mode solo (AiBrain, classe
  // publique partagée avec solo_controller.dart) — seule la façon d'ENREGISTRER
  // les résultats change (Firebase au lieu de l'état local). Piloté uniquement
  // par le client de l'hôte, pour éviter que 2 clients ne pilotent le même
  // bot en même temps.
  // ═══════════════════════════════════════════════════════════════════════

  void _maybeDriveBot() {
    if (_botDriving) return;
    if (myUid == null || hostId != myUid) return; // hôte seulement
    if (roomStatus != 'playing' || gameResult != null) return;
    final gs = gameState;
    if (gs == null) return;
    final cur = players[gs.currentPlayerId];
    if (cur == null || !cur.isBot || !cur.alive) return;
    // Ne pas interférer si une résolution est déjà en attente (carte tirée
    // par un joueur humain juste avant, butin en attente, etc.)
    if (gs.pendingAction != null) return;
    if (gs.lootKillerUid != null) return;
    if (gs.pendingPunishActorUid != null) return;
    if (gs.pendingTargetAction != null) return;
    _botDriving = true;
    _botTakeTurn(cur.uid).catchError((e, st) {
      debugPrint('Erreur pilotage bot : $e\n$st');
    }).whenComplete(() => _botDriving = false);
  }

  bool _punishResolving = false;

  /// Résout automatiquement une Divination X ou Y en attente lorsque la
  /// CIBLE (celle qui doit choisir) est un bot — peu importe qui a joué la
  /// carte (humain ou bot). Sans ça, un bot visé ne pouvait jamais
  /// répondre (aucune interface pour lui), et la partie restait bloquée
  /// indéfiniment en attendant une réponse qui ne venait jamais.
  void _maybeResolvePunishForBot() {
    if (_punishResolving) return;
    if (myUid == null || hostId != myUid) return; // hôte seulement
    final gs = gameState;
    if (gs?.pendingPunishActorUid == null) return;
    final targetUid = gs?.pendingPunishTargetUid;
    final target = targetUid != null ? players[targetUid] : null;
    if (target == null || !target.isBot) return; // cible humaine → dialogue normal
    _punishResolving = true;
    resolvePunishChoice(_eg.botPunishChoice(target)).catchError((e, st) {
      debugPrint('Erreur résolution punition (bot ciblé) : $e\n$st');
    }).whenComplete(() => _punishResolving = false);
  }

  Future<void> _botTakeTurn(String botUid) async {
    await Future.delayed(const Duration(milliseconds: 900));
    if (gameState?.currentPlayerId != botUid) return; // état changé entretemps

    var all = _mutableAll();
    var bot = all.where((p) => p.uid == botUid).firstOrNull;
    if (bot == null || !bot.alive) return;
    final layout = gameState!.terrainLayout;
    _ai.remember(all);

    // ── Capacité ──────────────────────────────────────────────────────
    final eff = bot.copiedEffect ?? bot.character!.abilityEffect;
    final canUseCopy = !(eff == 'copy_ability' &&
        !all.any((x) => x.uid != bot!.uid && x.alive && x.revealed &&
            x.character != null &&
            !GameEngine.uncopyableAbilities.contains(x.character!.abilityEffect)));
    if (_ai.shouldUseAbility(bot, all, layout, _botDifficulty) && canUseCopy) {
      if (!bot.revealed) {
        if (eff == 'chameleon_passive') {
          final hunters = all.where((p) => p.character?.faction == Faction.hunter && p.character != null).map((p) => p.character!).toList();
          final shadows = all.where((p) => p.character?.faction == Faction.shadow && p.character != null).map((p) => p.character!).toList();
          if (hunters.isNotEmpty && shadows.isNotEmpty) {
            final pool = [...hunters, ...shadows];
            final disguise = pool[Random().nextInt(pool.length)];
            bot.revealed = true;
            bot.disguiseNameOverride = disguise.name;
            bot.disguiseIconOverride = disguise.icon;
            bot.disguiseFactionOverride = disguise.faction.name;
            bot.disguiseCharIdOverride = disguise.id;
            await _commitAll(all, logT('🃏 {name} révèle : {char}', {'name': bot.name, 'char': disguise.name}));
          } else {
            bot.revealed = true;
            await _commitAll(all, logT('🃏 {name} révèle sa carte', {'name': bot.name}));
          }
        } else {
          bot.revealed = true;
          await _commitAll(all, logT('🃏 {name} révèle sa carte', {'name': bot.name}));
        }
        // Diffuse l'animation de révélation plein écran à TOUS les
        // joueurs, comme pour un joueur humain (voir revealSelf) — ce
        // branchement manquait ENTIÈREMENT pour les bots, qui ne
        // déclenchaient donc jamais cette animation en se révélant.
        await _fb.setPhase(roomId!, gameState?.phase ?? GamePhase.attack,
            publicRevealUid: bot.uid,
            publicRevealTimestamp: DateTime.now().millisecondsSinceEpoch);
        // Laisse le temps à l'animation de révélation d'être VUE avant que
        // le tour du bot ne continue avec d'autres actions — sans cette
        // pause dédiée, la suite du tour pouvait s'enchaîner trop vite et
        // perturber l'affichage de l'animation sur les autres appareils.
        await Future.delayed(const Duration(milliseconds: 2000));
        // Jeanne et Clémence : leur mécanisme se déclenche DÈS la révélation
        // (pas via un bouton "capacité" plus tard) — sans ce branchement, un
        // bot jouant ces personnages ne déclenchait jamais son pouvoir.
        if (eff == 'prophete_mark') {
          final markTarget = _ai.bestTarget(bot, all, _botDifficulty);
          if (markTarget != null) {
            final rewards = _eg.jeanneDraw3();
            final reward = rewards.isNotEmpty ? rewards.first : null;
            bot.abilityUsed = true;
            await _fb.setPhase(roomId!, gameState?.phase ?? GamePhase.attack,
                markedPlayerUid: markTarget.uid, jeanneReward: reward, jeanneUid: bot.uid);
          }
        } else if (eff == 'builder_power') {
          final offered = _eg.builderDraw3();
          if (offered.isNotEmpty) {
            final e1 = offered.first;
            final offered2 = _eg.builderDraw3(exclude: e1);
            final e2 = offered2.isNotEmpty ? offered2.first : e1;
            Player? bTarget;
            if (_eg.builderNeedsTarget(e1) || _eg.builderNeedsTarget(e2)) {
              bTarget = _ai.bestTarget(bot, all, _botDifficulty);
            }
            final log1 = _eg.applyBuilderEffect(e1, bot, bTarget, all, layout);
            final t2 = (bTarget != null && !bTarget.alive && _eg.builderNeedsTarget(e2)) ? null : bTarget;
            final log2 = _eg.applyBuilderEffect(e2, bot, t2, all, layout);
            bot.abilityUsed = true;
            _eg.applyDeathPassives(all);
            await _commitAll(all, [log1, log2].where((l) => l.isNotEmpty).join(' | '));
            final endedBuilder = await _checkWin(all,
                justDiedId: bTarget != null && !bTarget.alive ? bTarget.uid : null);
            if (endedBuilder) return;
            await _fb.setPhase(roomId!, gameState?.phase ?? GamePhase.attack, abilityOverlay: 'clemence_forge');
          }
        }
        await Future.delayed(const Duration(milliseconds: 700));
        all = _mutableAll();
        bot = all.where((p) => p.uid == botUid).firstOrNull;
        if (bot == null || !bot.alive) return;
      }
      final needsTarget = _abilityNeedsTarget(eff);
      Player? target;
      if (eff == 'copy_ability') {
        // Tommy (bot) : choisit un joueur révélé au pouvoir copiable, au hasard
        // — bestTarget() générique ne convient pas ici (pas de notion de
        // "révélé et copiable").
        final candidates = all.where((x) =>
          x.uid != bot!.uid && x.alive && x.revealed && x.character != null &&
          !GameEngine.uncopyableAbilities.contains(x.character!.abilityEffect)).toList();
        if (candidates.isNotEmpty) target = candidates[Random().nextInt(candidates.length)];
      } else if (eff == 'd4_bonus_attack') {
        // Vlad (bot) : portée limitée aux zones ADJACENTES — bestTarget()
        // générique ne convient pas ici (pas de notion de proximité).
        final adjZones = kAdjacences[bot!.zoneIndex];
        final candidates = all.where((x) =>
          x.uid != bot!.uid && x.alive && adjZones.contains(x.zoneIndex)).toList();
        if (candidates.isNotEmpty) target = candidates[Random().nextInt(candidates.length)];
      } else if (needsTarget) target = _ai.bestTarget(bot, all, _botDifficulty, context: eff);
      // Christine (bot) : tire une zone adjacente au hasard elle-même, puisque
      // le moteur exige désormais un choix explicite (humain OU bot).
      String? extraParam;
      if (eff == 'move_adjacent_choice') {
        final adjZones = kAdjacences[bot.zoneIndex];
        extraParam = adjZones[Random().nextInt(adjZones.length)].toString();
      }
      if (eff == 'hailey_copy_hunter') {
        // Hailey (bot) : tire 3 Hunters non joués et en copie un au hasard —
        // mécanique entièrement custom, ne passe pas par _eg.applyAbility().
        final offered = haileyDraw3(all);
        if (offered.isNotEmpty) {
          final chosen = offered[Random().nextInt(offered.length)];
          bot.copiedEffect = chosen.abilityEffect;
          await _commitAll(all, logT('📖 {name} copie le pouvoir de {target} : {ability}', {'name': bot.name, 'target': chosen.name, 'ability': chosen.ability}));
          // Certains pouvoirs se déclenchent normalement à la révélation —
          // Hailey étant déjà révélée au moment de copier, ce déclenchement
          // n'arrive jamais tout seul : on le force manuellement ici (même
          // correctif que pour Tommy, voir plus bas dans ce fichier).
          if (bot.copiedEffect == 'builder_power') {
            final offered2 = _eg.builderDraw3();
            await _fb.setPhase(roomId!, GamePhase.ability,
                builderStep: 1, builderOffered: offered2, abilityOverlay: 'hailey_copy');
            return;
          }
          await _fb.setPhase(roomId!, gameState?.phase ?? GamePhase.attack, abilityOverlay: 'hailey_copy');
        }
      } else if (target != null || !needsTarget) {
        final abLog = _eg.applyAbility(bot, all, layout, target: target, extra: extraParam);
        if (abLog == 'draw_dark' || abLog == 'draw_light') {
          _eg.applyDeathPassives(all);
          await _commitAll(all, '');
          await _botDrawAndResolveCard(botUid, abLog == 'draw_dark' ? DeckType.tenebres : DeckType.lumiere);
          all = _mutableAll();
          bot = all.where((p) => p.uid == botUid).firstOrNull;
          if (bot == null || !bot.alive) return;
        } else if (abLog == 'terrain_max_aoe') {
          final t2 = _ai.bestTarget(bot, all, _botDifficulty);
          if (t2 != null) {
            final abLog2 = _eg.applyAbility(bot, all, layout, target: t2);
            _eg.applyDeathPassives(all);
            await _commitAll(all, abLog2 ?? '');
            final t2now = all.where((p) => p.uid == t2.uid).firstOrNull;
            if (t2now != null && !t2now.alive) {
              if (await _checkWin(all, justDiedId: t2now.uid)) return;
            }
          }
        } else if (abLog == 'damien_target_chosen' && target != null) {
          // Damien (bot) : choisit algorithmiquement — alcool si ça peut
          // tuer d'un coup, sinon poison (dégâts totaux plus élevés sur la
          // durée) — même heuristique que le bot en solo.
          final dmTarget = target; // capture non-nullable : Dart ne propage
          // pas la vérification `target != null` à l'intérieur d'une
          // fermeture (le `.where((p) => ...)` plus bas), d'où l'erreur.
          final remainingHp = _eg.effectiveMaxHp(dmTarget) - dmTarget.wounds;
          final String resolveLog;
          if (remainingHp <= 4) {
            resolveLog = _eg.damienServeAlcohol(bot, dmTarget);
          } else {
            resolveLog = _eg.damienServePoison(bot, dmTarget);
          }
          _eg.applyDeathPassives(all);
          await _commitAll(all, resolveLog);
          final tNow = all.where((p) => p.uid == dmTarget.uid).firstOrNull;
          if (tNow != null && !tNow.alive) {
            if (await _checkWin(all, justDiedId: tNow.uid)) return;
          }
        } else if (abLog == 'trigger_terrain') {
          _eg.applyDeathPassives(all);
          await _commitAll(all, "🧌 ${bot.name} subit 1 blessure → réactive l'effet du terrain");
          await _fb.setPhase(roomId!, gameState?.phase ?? GamePhase.attack, abilityOverlay: 'peio_terrain');
          await _botApplyTerrainEffect(botUid);
          all = _mutableAll();
          bot = all.where((p) => p.uid == botUid).firstOrNull;
          if (bot == null || !bot.alive) return;
        } else if (abLog == 'meg_choice') {
          // Meg (bot) : choix aléatoire de la forme initiale.
          final form = Random().nextBool() ? 'offense' : 'defense';
          final abLog2 = _eg.applyAbility(bot, all, layout, extra: form);
          _eg.applyDeathPassives(all);
          await _commitAll(all, abLog2 ?? '');
          await _fb.setPhase(roomId!, gameState?.phase ?? GamePhase.attack,
              abilityOverlay: form == 'offense' ? 'meg_offense' : 'meg_defense');
        } else if (abLog == 'bonus_turns_zero') {
          await _commitAll(all, logT('🥷 {name} : aucun joueur mort, pouvoir sans effet.', {'name': bot.name}));
        } else if (abLog != null && abLog.startsWith('bonus_turns:')) {
          final deadCount = int.tryParse(abLog.split(':')[1]) ?? 0;
          await _commitAll(all, logT('🥷 {name} active son pouvoir — {n} tour(s) bonus !', {'name': bot.name, 'n': '$deadCount'}));
          await _fb.setPhase(roomId!, gameState?.phase ?? GamePhase.attack,
              bonusTurnsRemaining: deadCount, abilityOverlay: 'ninja_shadow');
        } else if (abLog == 'oscar_choice') {
          // Oscar (bot) : dépense son XP dans la meilleure option accessible.
          var choice = '';
          Player? waterTarget;
          if (bot.oscarXp >= 4) {
            choice = 'fire';
          } else if (bot.oscarXp >= 3) {
            final withEquip = all.where((p) =>
                p.uid != bot!.uid && p.alive && p.equipment.isNotEmpty).toList();
            if (withEquip.isNotEmpty) {
              choice = 'water';
              waterTarget = withEquip[Random().nextInt(withEquip.length)];
            } else if (bot.oscarXp >= 2) {
              choice = 'plant';
            }
          } else if (bot.oscarXp >= 2) {
            choice = 'plant';
          }
          if (choice.isNotEmpty) {
            final abLog2 = _eg.applyAbility(bot, all, layout, target: waterTarget, extra: choice);
            if (abLog2 != 'oscar_not_enough') {
              _eg.applyDeathPassives(all);
              await _commitAll(all, abLog2 ?? '');
              final ovOscar = choice == 'water' ? 'oscar_water' : choice == 'plant' ? 'oscar_plant' : 'oscar_fire';
              await _fb.setPhase(roomId!, gameState?.phase ?? GamePhase.attack, abilityOverlay: ovOscar);
            }
          }
        } else if (abLog == 'choose_all_dice') {
          // Fifi (bot) : dés au maximum, comme indiqué sur sa carte.
          await _commitAll(all, logT('🍀 {name} — tour parfait, dés au maximum !', {'name': bot.name}));
          await _fb.setPhase(roomId!, gameState?.phase ?? GamePhase.attack,
              fifiGoldenTurn: true, fifiMoveResult: 7, fifiAtkResult: 5, abilityOverlay: 'fifi_golden');
        } else if (abLog == 'baptiste_choose_amount' && target != null) {
          // Baptiste (bot) : la cible (un mort) est déjà trouvée par
          // bestTarget() — il ne reste qu'à choisir combien de blessures
          // s'infliger pour le ramener, sans se mettre en danger de mort.
          final maxSelfDmg = _eg.effectiveMaxHp(bot) - bot.wounds - 1;
          final selfDmg = maxSelfDmg > 0 ? (1 + Random().nextInt(maxSelfDmg)) : 0;
          if (selfDmg > 0) {
            final abLog2 = _eg.applyAbility(bot, all, layout, target: target, extra: '$selfDmg');
            _eg.applyDeathPassives(all);
            await _commitAll(all, abLog2 ?? '');
            await _fb.setPhase(roomId!, gameState?.phase ?? GamePhase.attack, abilityOverlay: 'baptiste_revive');
          }
        } else if (abLog == 'swap_zones') {
          // Richard II (bot) : échange sa propre zone avec la meilleure zone
          // accessible (réutilise bestZone(), déjà pondérée par faction/PV),
          // en suivant EXACTEMENT la même séquence que chooseSwapZone()
          // (joueur humain) pour un comportement identique.
          final richardStartZone = bot.zoneIndex;
          final z2 = _ai.bestZone(bot, all, layout, _botDifficulty);
          if (z2 != richardStartZone) {
            for (final p in all) {
              if (p.zoneIndex == richardStartZone) p.zoneIndex = z2;
              else if (p.zoneIndex == z2) p.zoneIndex = richardStartZone;
            }
            final newLayout = List<Terrain>.from(layout);
            final tmp = newLayout[richardStartZone];
            newLayout[richardStartZone] = newLayout[z2];
            newLayout[z2] = tmp;
            final t1name = newLayout[richardStartZone].name;
            final t2name = newLayout[z2].name;
            await _commitAll(all, logT('👑 {name} échange {zone1} ↔ {zone2} !', {'name': bot.name, 'zone1': t2name, 'zone2': t1name}));
            await _fb.setTerrainLayout(roomId!, newLayout);
            await _fb.setPhase(roomId!, GamePhase.zoneEffect,
                // IMPORTANT : Richard II est maintenant à z2 (les zones ont
                // été échangées) — il faut activer le terrain à SA position
                // ACTUELLE (z2), pas à son ancienne position
                // (richardStartZone), qui contient désormais un AUTRE
                // terrain. C'était le bug : il activait systématiquement
                // le terrain sur lequel il se trouvait de base.
                abilityOverlay: 'richard2_swap', richardActivateZone: z2);
            await Future.delayed(const Duration(milliseconds: 700));
            await _botApplyTerrainEffect(botUid);
            all = _mutableAll();
            bot = all.where((p) => p.uid == botUid).firstOrNull;
            if (bot == null || !bot.alive) return;
          }
        } else if (abLog == 'casino_bet') {
          // Mr Casino (bot) : pari aléatoire pair/impair, puis interprète le
          // résultat comme le ferait un joueur humain via _MultiCasinoWidget.
          final betOdd = Random().nextBool();
          final d = _eg.rollD6();
          final wonBet = betOdd == (d % 2 == 1);
          if (wonBet) {
            final t2 = _ai.bestTarget(bot, all, _botDifficulty);
            if (t2 != null) {
              _eg.applyDamage(t2, 3);
              if (!t2.alive) t2.killedByUid = bot.uid;
              _eg.applyDeathPassives(all);
              await _commitAll(all, logT('🎰 {name} gagne son pari ({d}) et inflige 3 blessures à {target} !', {'name': bot.name, 'd': '$d', 'target': t2.name}));
              final endedCasino = await _checkWin(all, justDiedId: t2.alive ? null : t2.uid);
              if (endedCasino) return;
              await _fb.setPhase(roomId!, gameState?.phase ?? GamePhase.attack, abilityOverlay: 'casino_win');
            }
          } else {
            _eg.applyDamage(bot, 2);
            if (!bot.alive) bot.killedByUid = bot.uid;
            _eg.applyDeathPassives(all);
            await _commitAll(all, logT('🎰 {name} perd son pari ({d}) — subit 2 blessures', {'name': bot.name, 'd': '$d'}));
            final endedCasino = await _checkWin(all, justDiedId: bot.alive ? null : bot.uid);
            if (endedCasino) return;
            if (bot.alive) {
              await _fb.setPhase(roomId!, gameState?.phase ?? GamePhase.attack, abilityOverlay: 'casino_lose');
            }
          }
        } else if (abLog != null && abLog.startsWith('christine_moved:')) {
          final movedZone = int.parse(abLog.split(':')[1]);
          _eg.applyDeathPassives(all);
          await _commitAll(all, logT('🗺️ {name} se déplace directement vers {zone}', {'name': bot.name, 'zone': layout[movedZone].name}));
          await _fb.setPhase(roomId!, GamePhase.attack, abilityOverlay: 'christine_map');
          await Future.delayed(const Duration(milliseconds: 700));
          await _botApplyTerrainEffect(botUid);
          all = _mutableAll();
          bot = all.where((p) => p.uid == botUid).firstOrNull;
          if (bot == null || !bot.alive) return;
        } else if (abLog != null && abLog != 'cible_requise' && abLog != 'cible_vlad') {
          _eg.applyDeathPassives(all);
          await _commitAll(all, abLog);
          if (target != null) {
            final tNow = all.where((p) => p.uid == target!.uid).firstOrNull;
            if (tNow != null && !tNow.alive) {
              if (await _checkWin(all, justDiedId: tNow.uid)) return;
            }
          }
        }
      }
    }

    await Future.delayed(const Duration(milliseconds: 700));
    all = _mutableAll();
    bot = all.where((p) => p.uid == botUid).firstOrNull;
    if (bot == null || !bot.alive) return;
    if (gameState?.phase == GamePhase.gameOver) return;

    // ── Déplacement (sauf si son pouvoir l'a déjà déplacé, ex: Christine) ──
    final skipMove = gameState?.phase == GamePhase.zoneEffect ||
        gameState?.phase == GamePhase.attack;
    if (!skipMove) {
      final roll = _eg.rollMove();
      final sum = roll['sum']!;
      int zoneIdx;
      if (sum == 7) {
        zoneIdx = _ai.bestZone(bot, all, layout, _botDifficulty);
      } else {
        final tid = _eg.sumToTerrainId(sum);
        zoneIdx = tid != null ? _eg.terrainLayoutIdx(layout, tid) : (bot.zoneIndex + 1) % 6;
        if (zoneIdx == -1 || zoneIdx == bot.zoneIndex) zoneIdx = (bot.zoneIndex + 1) % 6;
      }
      bot.zoneIndex = zoneIdx;
      await _commitAll(all, logT('🚶 {name} → {zone}', {'name': bot.name, 'zone': layout[zoneIdx].name}));
      await Future.delayed(const Duration(milliseconds: 700));

      // ── Effet de terrain ──
      await _botApplyTerrainEffect(botUid);
      all = _mutableAll();
      bot = all.where((p) => p.uid == botUid).firstOrNull;
      if (bot == null || !bot.alive) return;
      if (gameState?.phase == GamePhase.gameOver) return;

      // ── Carte en attente (piochée par l'effet de terrain) ──
      if (gameState?.pendingAction != null) {
        await Future.delayed(const Duration(milliseconds: 700));
        final card = findCardById(gameState!.pendingAction!);
        if (card != null) {
          Player? cardTarget;
          if (_cardNeedsTarget(card.effect)) {
            cardTarget = _ai.bestTarget(bot, all, _botDifficulty, context: card.effect);
          }
          if (cardTarget != null || !_cardNeedsTarget(card.effect)) {
            final res = _eg.resolveCard(card, bot, all, layout, target: cardTarget);
            if (res['needsTargetChoice'] == true) {
              // Divination X ou Y jouée par un BOT (via une carte "choix"
              // piochée par effet de terrain) : même correctif que dans
              // _botDrawAndResolveCard — la punition ne se résolvait
              // jamais, silencieusement ignorée par le clearPending
              // quelques lignes plus bas.
              await _commitAll(all, '');
              await _fb.setPhase(roomId!, gameState?.phase ?? GamePhase.attack,
                  pendingPunishActorUid: res['punishActorUid'] as String,
                  pendingPunishTargetUid: res['punishTargetUid'] as String,
                  pendingPunishTimestamp: DateTime.now().millisecondsSinceEpoch);
              return;
            }
            if (res['needsTarget'] != true &&
                res['needsSecondTarget'] != true && res['needsEquipChoice'] != true) {
              _eg.applyDeathPassives(all);
              await _commitAll(all, res['log'] as String? ?? '');
              if (await _checkWin(all)) return;
            }
          }
        }
        await _fb.setPhase(roomId!, GamePhase.attack, clearPending: true);
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    all = _mutableAll();
    bot = all.where((p) => p.uid == botUid).firstOrNull;
    if (bot == null || !bot.alive) return;
    if (gameState?.phase == GamePhase.gameOver) return;

    // ── Attaque ──────────────────────────────────────────────────────
    if (_ai.shouldAttack(bot, all, layout, _botDifficulty)) {
      final targets = _eg.attackTargets(bot, all, layout);
      var target = _ai.bestTarget(bot, targets, _botDifficulty, context: 'attack');
      // Maxence : un bot ivre a aussi 10% de chance de se frapper lui-même
      // par confusion (même logique que le joueur humain).
      if (target != null && bot.drunkTurnsRemaining > 0 && bot.uid != target.uid && Random().nextDouble() < 0.10) {
        target = bot;
      }
      if (target != null) {
        final tgt = target; // capture finale — évite la perte du rétrécissement
        // de nullabilité de Dart après réassignation conditionnelle plus haut
        final roll2 = _eg.rollAttack();
        final dmg = roll2['damage']!;
        if (bot.revealed) bot.attackCount++;
        _ai.recordAttack(bot, tgt);
        final attackRes = _eg.resolveAttack(bot, tgt, dmg, all: all);
        _eg.applyDeathPassives(all);
        // Gège le Fantôme : attaque automatiquement en plus dès qu'un
        // Hunter révélé attaque — ce mécanisme manquait ENTIÈREMENT ici,
        // donc ne se déclenchait jamais sur les attaques de bots (le cas
        // le plus fréquent en jeu), alors qu'il fonctionnait déjà pour un
        // joueur humain (voir attackPlayer un peu plus bas).
        final (gegeLog, gegeTriggered) = bot.bazooka
            ? _eg.applyGegePassiveBazooka(bot, all)
            : _eg.applyGegePassiveEx(bot, tgt, all);
        var fullLog = attackRes['log'] as String;
        if (gegeLog != null) fullLog = '$fullLog\n$gegeLog';
        // Gège se déclenche aussi si CE bot subit lui-même une contre-
        // attaque de Scott (rôles inversés — Scott devient l'attaquant).
        bool gegeTriggered2 = false;
        if (attackRes['scottCountered'] == true && bot.alive) {
          final (gegeLog2, t2) = _eg.applyGegePassiveEx(tgt, bot, all);
          if (gegeLog2 != null) { fullLog = '$fullLog\n$gegeLog2'; gegeTriggered2 = t2; }
        }
        await _commitAll(all, fullLog);
        await _fb.setPhase(roomId!, gameState?.phase ?? GamePhase.attack,
            lastDiceResult: {'d4': roll2['d4']!, 'd6': roll2['d6']!, 'sum': dmg},
            lastDiceLabel: 'Attaque',
            lastDiceTimestamp: DateTime.now().millisecondsSinceEpoch,
            abilityOverlay: (gegeTriggered || gegeTriggered2) ? 'gege_ghost' : null);
        final tgtNow = all.where((p) => p.uid == tgt.uid).firstOrNull;
        if (tgtNow != null) {
          if (await _checkWin(all, justDiedId: tgtNow.alive ? null : tgtNow.uid)) return;
        }
      }
    }

    await Future.delayed(const Duration(milliseconds: 600));
    if (gameState?.phase == GamePhase.gameOver) return;
    await endTurn(actingUid: botUid);
  }

  /// Pioche une carte pour un bot ET la résout immédiatement (choix de cible
  /// simple via l'IA si besoin) — version autonome de drawCard()+applyCard(),
  /// nécessaire car ces deux fonctions humaines sont liées à myUid.
  Future<void> _botDrawAndResolveCard(String botUid, DeckType deck) async {
    final queue = Map<String, List<String>>.from(
        (gameState?.forcedDeckQueue ?? const {}).map(
            (k, v) => MapEntry(k, List<String>.from(v))));
    final piles = Map<String, List<String>>.from(
        (gameState?.deckPiles ?? const {}).map(
            (k, v) => MapEntry(k, List<String>.from(v))));
    final card = _eg.drawCard(deck, forcedQueue: queue, deckPiles: piles);
    // Persiste l'état du paquet (quelle carte a été piochée de la pile) —
    // sans ça, l'ordre du paquet ne serait jamais sauvegardé pour les
    // pioches de bots.
    await _fb.setPhase(roomId!, gameState?.phase ?? GamePhase.move,
        forcedDeckQueue: queue, deckPiles: piles);
    var all = _mutableAll();
    var bot = all.where((p) => p.uid == botUid).firstOrNull;
    if (bot == null || !bot.alive) return;
    await _fb.addLog(roomId!,
        deck == DeckType.vision ? logT('🔮 {name} pioche une carte Vision (secrète)', {'name': bot.name})
                                 : logT('🃏 {name} pioche : {card}', {'name': bot.name, 'card': card.name}));
    Player? cardTarget;
    if (_cardNeedsTarget(card.effect)) {
      cardTarget = _ai.bestTarget(bot, all, _botDifficulty, context: card.effect);
    }
    if (cardTarget != null || !_cardNeedsTarget(card.effect)) {
      final res = _eg.resolveCard(card, bot, all, gameState!.terrainLayout, target: cardTarget);
      if (res['needsTargetChoice'] == true) {
        // Divination X ou Y jouée par un BOT : la punition ne se résolvait
        // JAMAIS auparavant — le code l'ignorait purement et simplement,
        // et le clearPending qui suivait plus bas effaçait toute trace de
        // ce qui aurait dû se passer, avant même que quiconque ait pu
        // répondre. On pose maintenant correctement l'état d'attente (la
        // cible — bot ou humain — répondra via _maybeResolvePunishForBot
        // ou le dialogue humain selon le cas).
        await _commitAll(all, '');
        await _fb.setPhase(roomId!, gameState?.phase ?? GamePhase.attack,
            pendingPunishActorUid: res['punishActorUid'] as String,
            pendingPunishTargetUid: res['punishTargetUid'] as String,
            pendingPunishTimestamp: DateTime.now().millisecondsSinceEpoch);
        return;
      }
      if (res['needsTarget'] != true &&
          res['needsSecondTarget'] != true && res['needsEquipChoice'] != true) {
        _eg.applyDeathPassives(all);
        await _commitAll(all, res['log'] as String? ?? '');
        // IMPORTANT : résolution INSTANTANÉE, comme à l'origine — on ne
        // touche JAMAIS à `phase`/`pendingAction` ici (une version
        // précédente le faisait via un délai artificiel + transition de
        // phase temporaire, ce qui a fini par désynchroniser le pilotage
        // des bots : plusieurs tours d'affilée, blocages). L'affichage de
        // la carte passe désormais par un champ DÉDIÉ et INDÉPENDANT de la
        // phase de jeu (lastDrawnCardId/Timestamp), exactement sur le
        // modèle de lastDiceResult qui fonctionne déjà de façon fiable —
        // aucun risque pour la machine à états du tour du bot.
        if (deck != DeckType.vision) {
          await _fb.setPhase(roomId!, gameState?.phase ?? GamePhase.move,
              lastDrawnCardId: card.id,
              lastDrawnCardTimestamp: DateTime.now().millisecondsSinceEpoch);
        }
        await _checkWin(all);
      }
    }
  }

  /// Applique l'effet du terrain courant pour un bot — version autonome de
  /// applyTerrainEffect(), nécessaire car celle-ci lit `me!` (donc myUid).
  Future<void> _botApplyTerrainEffect(String botUid) async {
    final bot = players[botUid];
    if (bot == null) return;
    final t = gameState!.terrainLayout[bot.zoneIndex];
    switch (t.effect) {
      case 'vision':   await _botDrawAndResolveCard(botUid, DeckType.vision); break;
      case 'lumiere':  await _botDrawAndResolveCard(botUid, DeckType.lumiere); break;
      case 'tenebres': await _botDrawAndResolveCard(botUid, DeckType.tenebres); break;
      case 'choice':
        final deck = _ai.bestDeck(bot, _botDifficulty);
        await _botDrawAndResolveCard(botUid, deck);
        break;
      case 'damage9': {
        final all = _mutableAll();
        final b = all.where((p) => p.uid == botUid).firstOrNull;
        if (b != null) {
          final t2 = _ai.bestTarget(b, all, _botDifficulty);
          if (t2 != null) {
            _eg.applyDamage(t2, 2, isTerrain9Dmg: true);
            if (!t2.alive) t2.killedByUid = b.uid;
            _eg.applyDeathPassives(all);
            await _commitAll(all, logT('🏹 {name} inflige 2 blessures à {target}', {'name': b.name, 'target': t2.name}));
            await _checkWin(all, justDiedId: t2.alive ? null : t2.uid);
          }
        }
        break;
      }
      case 'steal': {
        final all = _mutableAll();
        final b = all.where((p) => p.uid == botUid).firstOrNull;
        if (b != null) {
          final t2 = _ai.bestTarget(b, all, _botDifficulty, context: 'steal');
          if (t2 != null && t2.equipment.isNotEmpty) {
            // Choisit le MEILLEUR objet plutôt qu'un tirage aléatoire —
            // même correctif que côté solo.
            var bestIdx = 0; var bestVal = -1;
            for (var i = 0; i < t2.equipment.length; i++) {
              final v = _eg.equipmentValue(t2.equipment[i].effect);
              if (v > bestVal) { bestVal = v; bestIdx = i; }
            }
            final e = t2.equipment.removeAt(bestIdx);
            b.equipment.add(e);
            _eg.equipPassivePublic(b, e);
            _eg.recalcPassives(t2);
            await _commitAll(all, logT('🗼 {name} vole "{item}" à {target}', {'name': b.name, 'item': e.name, 'target': t2.name}));
          }
        }
        break;
      }
    }
  }

  // Évite de réécrire à chaque cycle de sondage — seulement quand le
  // personnage assigné (ou son skin local) change réellement.
  String? _lastSkinSyncCharId;

  /// Synchronise SON PROPRE skin de carte personnage (choisi localement en
  /// boutique) vers son enregistrement joueur — pour qu'un AUTRE joueur en
  /// multijoueur voie SON skin à lui en consultant sa fiche, plutôt que la
  /// préférence locale du joueur qui regarde (ou rien du tout).
  void _syncMySkinIfNeeded() {
    if (myUid == null) return;
    final me = players[myUid];
    final charId = me?.character?.id;
    if (charId == null) return;
    if (_lastSkinSyncCharId == charId) return;
    _lastSkinSyncCharId = charId;
    final localSkin = Prefs.equippedCosmetics()['character:$charId'];
    if (localSkin == me?.equippedCharacterSkin) return; // déjà synchronisé
    unawaited(_fb.setEquippedSkin(roomId!, myUid!, localSkin));
  }

  String? _lastShineSyncCharId;

  /// Synchronise SON PROPRE nombre de victoires (appareil local) avec le
  /// personnage actuellement joué — pour qu'un AUTRE joueur en multijoueur
  /// voie SA vraie étoile en consultant sa fiche, plutôt que le nombre de
  /// victoires local du joueur qui regarde (souvent 0, n'affichant alors
  /// aucune étoile à tort pour un personnage que l'autre joue pourtant
  /// depuis longtemps).
  void _syncMyShineWinsIfNeeded() {
    if (myUid == null) return;
    final me = players[myUid];
    final charName = me?.character?.name;
    if (charName == null) return;
    if (_lastShineSyncCharId == charName) return;
    _lastShineSyncCharId = charName;
    final localWins = Prefs.gamesWonWith(charName);
    if (localWins == (me?.shineWins ?? 0)) return; // déjà synchronisé
    unawaited(_fb.setShineWins(roomId!, myUid!, localWins));
  }

  void _subscribe() {
    _pSub?.cancel(); _gsSub?.cancel(); _stSub?.cancel(); _rSub?.cancel(); _rcSub?.cancel(); _logSub?.cancel(); _privLogSub?.cancel(); _hostSub?.cancel();
    _pSub  = _fb.watchPlayers(roomId!).listen((d) {
      // Détecte une expulsion : si mon propre uid a disparu de la liste des
      // joueurs (alors que la salle contient déjà des données, pour éviter
      // un faux positif pendant la toute première synchronisation après
      // avoir rejoint), c'est que l'hôte m'a expulsé — on se réinitialise
      // proprement plutôt que de continuer à sonder une salle où l'on
      // n'existe plus.
      if (myUid != null && d.isNotEmpty && !d.containsKey(myUid)) {
        players = d;
        leaveRoomAndReset(alreadyRemoved: true);
        return;
      }
      players = d; notifyListeners();
      _syncMySkinIfNeeded();
      _syncMyShineWinsIfNeeded();
    });
    _gsSub = _fb.watchGameState(roomId!).listen((d) { gameState = d; _maybeForceTurn(); _maybeDriveBot(); _maybeResolvePunishForBot(); notifyListeners(); });
    _stSub = _fb.watchStatus(roomId!).listen((d) {
      final wasPlaying = roomStatus == 'playing';
      roomStatus = d;
      // Musique de jeu : se déclenche une seule fois, au moment où la partie
      // démarre réellement (transition lobby → playing) — jusqu'ici rien ne
      // la lançait du tout côté multijoueur.
      if (!wasPlaying && roomStatus == 'playing') audio.playGameMusic();
      notifyListeners();
    });
    _rSub  = _fb.watchResult(roomId!).listen((d) { gameResult = d; _recordMultiResult(d); notifyListeners(); });
    _rcSub = _fb.watchRoleConfirms(roomId!).listen((d) { roleConfirms = d; notifyListeners(); });
    _logSub = _fb.watchLog(roomId!).listen((d) { log = d; notifyListeners(); });
    // Suivi en continu de l'hôte — si l'hôte quitte la salle, ce champ
    // change côté Firebase (transfert automatique) ; sans cette écoute, les
    // autres clients gardaient un hostId périmé et personne ne pouvait plus
    // lancer la partie ni piloter les bots.
    _hostSub = _fb.watchHostId(roomId!).listen((d) { if (d != null) hostId = d; notifyListeners(); });
    if (myUid != null) {
      _privLogSub = _fb.watchPrivateLog(roomId!, myUid!).listen((d) { privateLog = d; notifyListeners(); });
    }
  }

  @override
  void dispose() {
    _pSub?.cancel(); _gsSub?.cancel(); _stSub?.cancel(); _rSub?.cancel(); _rcSub?.cancel(); _logSub?.cancel(); _privLogSub?.cancel(); _hostSub?.cancel();
    super.dispose();
  }

  /// Quitte la room actuelle et remet le provider à zéro pour permettre de
  /// créer/rejoindre une nouvelle partie. À appeler avant de retourner à
  /// l'écran d'accueil après une fin de partie.
  Future<void> leaveRoomAndReset({bool alreadyRemoved = false}) async {
    Prefs.clearRoom();
    _resultRecorded = false;
    _pSub?.cancel(); _gsSub?.cancel(); _stSub?.cancel(); _rSub?.cancel(); _rcSub?.cancel(); _logSub?.cancel(); _privLogSub?.cancel(); _hostSub?.cancel();
    _pSub = _gsSub = _stSub = _rSub = _rcSub = _logSub = _privLogSub = _hostSub = null;
    if (roomId != null) {
      // Si on a déjà été retiré de la salle (expulsion détectée par le
      // listener), pas besoin de retenter une suppression du même nœud —
      // il n'existe déjà plus.
      if (!alreadyRemoved) {
        try { await _fb.leaveRoom(roomId!); } catch (_) {}
      }
      _fb.stopPollingRoom(roomId!);
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

  /// Hailey : tire 3 Hunters non joués (tirage persisté pour que tous les
  /// clients voient les 3 mêmes options, comme builderOffered pour Clémence)
  /// et ouvre l'écran de choix.
  Future<void> haileyOpenChoice() async {
    final all = _mutableAll();
    final offered = haileyDraw3(all).map((c) => c.id).toList();
    await _fb.setPhase(roomId!, GamePhase.chooseTarget,
        pendingTargetAction: 'hailey_choice', haileyOffered: offered);
  }

  /// Hailey : résout le choix — copie l'effet du Hunter sélectionné dans
  /// copiedEffect (même mécanisme que Tommy). Ne touche PAS abilityUsed :
  /// copier un pouvoir n'est pas l'utiliser, c'est la résolution du pouvoir
  /// copié lui-même, plus tard, qui marquera abilityUsed=true.
  Future<void> haileyChoice(String characterId) async {
    final all = _mutableAll();
    final actor = all.firstWhere((p) => p.uid == myUid);
    final chosen = kAllCharacters.where((c) => c.id == characterId).firstOrNull;
    if (chosen == null) {
      await _fb.setPhase(roomId!, GamePhase.move, clearPending: true, haileyOffered: const []);
      return;
    }
    actor.copiedEffect = chosen.abilityEffect;
    await _commitAll(all, logT('📖 {name} copie le pouvoir de {target} : {ability}', {'name': actor.name, 'target': chosen.name, 'ability': chosen.ability}));
    // Certains pouvoirs se déclenchent normalement à la révélation — Hailey
    // étant déjà révélée au moment de copier, ce déclenchement n'arrive
    // jamais tout seul : on le force manuellement ici (même correctif que
    // pour Tommy, voir tommy_copied plus bas dans ce fichier).
    if (actor.copiedEffect == 'builder_power') {
      final offered = _eg.builderDraw3();
      await _fb.setPhase(roomId!, GamePhase.ability,
          haileyOffered: const [], builderStep: 1, builderOffered: offered, abilityOverlay: 'hailey_copy');
      return;
    }
    await _fb.setPhase(roomId!, GamePhase.move, clearPending: true, haileyOffered: const [], abilityOverlay: 'hailey_copy');
  }

  Future<void> revealSelf() async {
    final p = _mutableMe();
    p.revealed = true;
    final isClemence = p.character?.abilityEffect == 'builder_power';
    final isJeanne = p.character?.abilityEffect == 'prophete_mark';
    final offered = isClemence ? _eg.builderDraw3() : <String>[];
    await _commitPlayer(p, logT('🃏 {name} révèle : {char}', {'name': p.name, 'char': p.character!.name}));
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
      await _fb.addLog(roomId!, logT("🎨 Clémence choisit l'effet 1 : {effect}", {'effect': _eg.builderEffectLabel(eff)}));
    } else if (gs.builderStep == 2) {
      final e1 = gs.builderEffect1!;
      if (_eg.builderCombinedNeedsTarget(e1, eff)) {
        await _fb.setPhase(roomId!, GamePhase.chooseTarget,
            builderStep: 3, builderEffect2: eff,
            builderOffered: const [], pendingTargetAction: 'clemence_target');
        await _fb.addLog(roomId!, logT("🎨 Clémence choisit l'effet 2 : {effect} — choisissez une cible", {'effect': _eg.builderEffectLabel(eff)}));
      } else {
        await _fb.addLog(roomId!, logT('🎨 Clémence combine : {effect1} + {effect2}', {'effect1': _eg.builderEffectLabel(e1), 'effect2': _eg.builderEffectLabel(eff)}));
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
        logT('🔮 {name} a organisé la pile {deck}.', {'name': me?.name ?? 'Elaia', 'deck': _deckLabel(deckName)}));
    await _fb.setPhase(roomId!, GamePhase.ability,
        elaiaStep: 0, forcedDeckQueue: queue, abilityOverlay: 'elaia_vision');
  }

  String _deckLabel(String d) => switch (d) {
    'tenebres' => tr('Ténèbres'), 'lumiere' => tr('Lumière'), 'vision' => tr('Vision'),
    _ => d,
  };

  /// Damien : cible choisie — mémorise la cible et affiche le choix alcool/poison.
  Future<void> damienChooseTarget(Player target) async {
    final all = _mutableAll();
    final actor = all.firstWhere((p) => p.uid == myUid);
    actor.abilityUsed = true;
    await _commitAll(all, logT('🍸 {name} prépare un verre pour {target}…', {'name': actor.name, 'target': target.name}));
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
    final endedDamien = await _checkWin(all, justDiedId: target.alive ? null : target.uid);
    if (endedDamien) return;
    await _fb.setPhase(roomId!, GamePhase.ability, clearPending: true, abilityOverlay: 'damien_alcohol');
  }

  /// Damien : sert le poison — 3 dégâts/tour pendant 2 tours.
  Future<void> damienServePoison() async {
    final targetUid = gameState?.damienTargetUid; if (targetUid == null) return;
    final all = _mutableAll();
    final actor = all.firstWhere((p) => p.uid == myUid);
    final target = all.firstWhere((p) => p.uid == targetUid, orElse: () => actor);
    final log = _eg.damienServePoison(actor, target);
    await _commitAll(all, log);
    await _fb.setPhase(roomId!, GamePhase.ability, clearPending: true, abilityOverlay: 'damien_poison');
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
      _eg.recalcPassives(dead); // au cas où il ressuscite (Bob) avec un passif d'objet qu'il n'a plus
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
    await _commitAll(all, logT('🎰 Mr Casino perd son pari — {name} subit 2 blessures', {'name': me.name}));
    // _checkWin() gère désormais TOUTE mort du joueur en cours de tour (y
    // compris auto-infligée) en terminant son tour elle-même — inutile de
    // dupliquer cette logique ici.
    if (await _checkWin(all, justDiedId: me.alive ? null : me.uid)) return;
    await _fb.setPhase(roomId!, GamePhase.move, clearPending: true, abilityOverlay: 'casino_lose');
  }

  /// Mr Casino — inflige 3 dégâts à la cible choisie après un pari gagné.
  Future<void> casinoApplyDamage(Player target) async {
    final all = _mutableAll();
    final t = all.firstWhere((p) => p.uid == target.uid);
    _eg.applyDamage(t, 3);
    if (!t.alive) t.killedByUid = myUid;
    _eg.applyDeathPassives(all);
    await _commitAll(all, logT('🎰 Mr Casino inflige 3 blessures à {target} !', {'target': t.name}));
    final endedCasino = await _checkWin(all, justDiedId: t.alive ? null : t.uid);
    if (endedCasino) return;
    await _fb.setPhase(roomId!, GamePhase.move, clearPending: true, abilityOverlay: 'casino_win');
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
    final endedEquip = await _checkWin(all);
    if (endedEquip) return;
    await _fb.setPhase(roomId!, _postCardPhase(), clearPending: true, peioReturnToMove: false);
  }


  /// Jeanne étape 2 : choisit secrètement la récompense.
  Future<void> jeanneChooseReward(String reward) async {
    final all = _mutableAll();
    final me = all.firstWhere((p) => p.uid == myUid);
    me.abilityUsed = true;
    await _commitAll(all, logT('🔮 {name} marque un joueur — récompense secrète posée !', {'name': me.name}));
    await _fb.setPhase(roomId!, GamePhase.move, clearPending: true,
        jeanneReward: reward, jeanneUid: myUid, builderOffered: [], abilityOverlay: 'jeanne_mark');
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
    final endedBuilder = await _checkWin(all, justDiedId: tgt != null && !tgt.alive ? tgt.uid : null);
    if (endedBuilder) return;
    await _fb.setPhase(roomId!, GamePhase.move, clearPending: true,
        builderStep: 0, builderOffered: const [], abilityOverlay: 'clemence_forge');
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
    await _commitPlayer(p, logT('🃏 {name} révèle : {char}', {'name': p.name, 'char': disguise.name}));
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
    'set_wounds7': 'marion_plants',
    'aoe_zone6': 'artcade_flames',
    'double_move_dice': 'albane_clock',
    'ally_sacrifice_heal': 'amelia_light',
    'draw_dark': 'monkey_demon_eyes',
    'heal_on_same_terrain': 'augustin_wheat',
    'heal_per_equip_eot': 'fijacked_city',
    'shield3': 'louna_shield',
    'lock_ability_while_alive': 'ines_lock',
    'steal_max_hp': 'agathe_drain',
    'luc_ignite': 'luc_ignite',
    'maxence_drunk': 'maxence_drunk',
    'damage3_give_dague': 'marin_dagger',
    'store_damage_nils': 'nils_release',
    'swap_equipment': 'tristan_swap',
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
    // Hong Yi s'inflige 5 blessures en retour (texte de la carte), peut
    // désormais mourir de son propre pouvoir si déjà fortement blessé au
    // préalable. C'était incorrectement 4 auparavant (dans les deux modes).
    final selfDealt = _eg.applyDamage(actor, 5);
    if (!actor.alive) actor.killedByUid = actor.uid;
    actor.abilityUsed = true;
    _eg.applyDeathPassives(all);
    final log = logT("⚡ {name} inflige {dmg} à {target} — et s'inflige {self} blessures en retour !", {'name': actor.name, 'dmg': '$dealt', 'target': t.name, 'self': '$selfDealt'});
    await _commitAll(all, log);
    bool endedHongYi = false;
    if (!t.alive) endedHongYi = await _checkWin(all, justDiedId: t.uid);
    if (!endedHongYi && !actor.alive) endedHongYi = await _checkWin(all, justDiedId: actor.uid);
    if (endedHongYi) return;
    // IMPORTANT : ne PAS terminer le tour ici — Hong Yi doit pouvoir
    // continuer à jouer normalement (se déplacer, attaquer...) après avoir
    // utilisé son pouvoir, exactement comme en solo. Le endTurn() immédiat
    // qui suivait auparavant terminait le tour à tort, empêchant de jouer
    // le reste du tour comme prévu.
    await _fb.setPhase(roomId!, GamePhase.move, clearPending: true,
        abilityOverlay: 'hongyi_dumbbell');
  }

  /// Oscar : traite le choix d'un des 3 éléments (Eau/Plante/Feu). "Eau"
  /// sans target ouvre juste la sélection de cible (qui voler) — avec
  /// target, ou pour Plante/Feu, résout directement.
  Future<void> oscarChoice(String choice, {Player? target}) async {
    if (choice == 'water' && target == null) {
      await _fb.setPhase(roomId!, GamePhase.chooseTarget, pendingTargetAction: 'oscar_water_target');
      return;
    }
    final all = _mutableAll();
    final actor = all.firstWhere((p) => p.uid == myUid);
    final tgt = target != null ? all.firstWhere((p) => p.uid == target.uid, orElse: () => actor) : null;
    final log = _eg.applyAbility(actor, all, gameState!.terrainLayout, target: tgt, extra: choice);
    if (log == 'oscar_not_enough') {
      await _fb.addLog(roomId!, logT("❌ {name} n'a pas assez d'XP pour cette option.", {'name': actor.name}));
      return;
    }
    actor.abilityUsed = true;
    _eg.applyDeathPassives(all);
    await _commitAll(all, log);
    final ovOscar = choice == 'water' ? 'oscar_water' : choice == 'plant' ? 'oscar_plant' : 'oscar_fire';
    await _fb.setPhase(roomId!, GamePhase.move, clearPending: true, abilityOverlay: ovOscar);
  }

  /// Meg : choix initial (une seule fois) de la forme Offensive ou Défensive.
  /// Bascule ensuite automatiquement chaque tour via applyStartOfTurnPassives.
  Future<void> megChooseForm(String form) async {
    final all = _mutableAll();
    final actor = all.firstWhere((p) => p.uid == myUid);
    final log = _eg.applyAbility(actor, all, gameState!.terrainLayout, extra: form);
    actor.abilityUsed = true;
    _eg.applyDeathPassives(all);
    await _commitAll(all, log);
    await _fb.setPhase(roomId!, GamePhase.move, clearPending: true,
        abilityOverlay: form == 'offense' ? 'meg_offense' : 'meg_defense');
  }

  /// Christine : résout le choix de zone adjacente — se déplace directement.
  /// Comme pour Richard II / la Voiture de Clémence, la phase passe à
  /// `zoneEffect` et c'est le joueur qui presse ensuite le bouton "Appliquer
  /// l'effet du terrain" (pas d'auto-résolution ici).
  Future<void> christineChooseZone(int zoneIdx) async {
    final all = _mutableAll();
    final actor = all.firstWhere((p) => p.uid == myUid);
    final log = _eg.applyAbility(actor, all, gameState!.terrainLayout, extra: zoneIdx.toString());
    if (log == 'christine_zone_choice') return; // zone invalide, sécurité
    actor.abilityUsed = true;
    _eg.applyDeathPassives(all);
    await _commitAll(all, logT('🗺️ {name} se déplace directement vers {zone}', {'name': actor.name, 'zone': gameState!.terrainLayout[zoneIdx].name}));
    await _fb.setPhase(roomId!, GamePhase.zoneEffect, clearPending: true,
        richardActivateZone: zoneIdx, abilityOverlay: 'christine_map');
  }

  /// Baptiste étape 1 : cible choisie (un joueur mort) — passe à l'étape
  /// "montant à sacrifier" plutôt que de résoudre directement.
  Future<void> baptisteChooseTarget(Player target) async {
    await _fb.setPhase(roomId!, GamePhase.chooseTarget,
        pendingTargetAction: 'baptiste_amount', baptisteTargetUid: target.uid);
  }

  /// Tristan étape 1 : cible choisie — passe au choix de SON objet à donner.
  Future<void> tristanChooseTarget(Player target) async {
    final me = players[myUid]!;
    if (me.equipment.isEmpty || target.equipment.isEmpty) {
      await _fb.addLog(roomId!,
          "🔄 ${me.name} — échange impossible (équipement manquant chez l'un des deux)");
      await _fb.setPhase(roomId!, GamePhase.move, clearPending: true);
      return;
    }
    await _fb.setPhase(roomId!, GamePhase.chooseTarget,
        pendingTargetAction: 'tristan_give_choice', tristanTargetUid: target.uid);
  }

  /// Tristan étape 2 : objet à donner choisi — passe au choix de l'objet à recevoir.
  Future<void> tristanChooseGive(int myIdx) async {
    await _fb.setPhase(roomId!, GamePhase.chooseTarget,
        pendingTargetAction: 'tristan_receive_choice', tristanGiveIdx: myIdx);
  }

  /// Tristan étape 3 : objet à recevoir choisi — résout l'échange complet.
  Future<void> tristanChooseReceive(int theirIdx) async {
    final targetUid = gameState?.tristanTargetUid;
    final myIdx = gameState?.tristanGiveIdx;
    if (targetUid == null || myIdx == null) return;
    final all = _mutableAll();
    final actor = all.firstWhere((p) => p.uid == myUid);
    final target = all.firstWhere((p) => p.uid == targetUid);
    final log = _eg.applyAbility(actor, all, gameState!.terrainLayout,
        target: target, extra: '$myIdx,$theirIdx');
    actor.abilityUsed = false; // répétable
    _eg.applyDeathPassives(all);
    await _commitAll(all, log);
    // IMPORTANT : vérifie directement la condition (comme dans engine.dart)
    // plutôt que log.contains('invalide') — ce texte est désormais traduit
    // en anglais quand cette langue est active, donc ne contient plus jamais
    // cette sous-chaîne française.
    final wasInvalid = myIdx < 0 || myIdx >= actor.equipment.length ||
        theirIdx < 0 || theirIdx >= target.equipment.length;
    await _fb.setPhase(roomId!, GamePhase.move, clearPending: true,
        tristanTargetUid: '__clear__', tristanGiveIdx: -1,
        abilityOverlay: wasInvalid ? null : 'tristan_swap');
  }

  /// Baptiste étape 2 : montant confirmé — résout la résurrection.
  Future<void> baptisteConfirmAmount(int amount) async {
    final targetUid = gameState?.baptisteTargetUid;
    if (targetUid == null) {
      await _fb.setPhase(roomId!, GamePhase.move, clearPending: true);
      return;
    }
    final all = _mutableAll();
    final actor = all.firstWhere((p) => p.uid == myUid);
    final tgt = all.where((p) => p.uid == targetUid).firstOrNull;
    if (tgt == null) {
      await _fb.setPhase(roomId!, GamePhase.move, clearPending: true,
          baptisteTargetUid: '__clear__');
      return;
    }
    final log = _eg.applyAbility(actor, all, gameState!.terrainLayout, target: tgt, extra: '$amount');
    actor.abilityUsed = true;
    _eg.applyDeathPassives(all);
    await _commitAll(all, log);
    if (!actor.alive) {
      // Sacrifice total : Baptiste vient de mourir en ramenant l'autre à
      // la vie — vérifie la victoire, puis passe au joueur suivant.
      final ended = await _checkWin(all, justDiedId: actor.uid);
      if (ended) return;
      await _fb.setPhase(roomId!, GamePhase.move, clearPending: true,
          baptisteTargetUid: '__clear__', abilityOverlay: 'baptiste_revive');
      await endTurn(actingUid: actor.uid);
      return;
    }
    final ended = await _checkWin(all);
    if (ended) return;
    await _fb.setPhase(roomId!, GamePhase.move, clearPending: true,
        baptisteTargetUid: '__clear__', abilityOverlay: 'baptiste_revive');
  }

  /// Albane : marque abilityUsed après avoir choisi son lancer.
  /// Fifi : confirme ses valeurs de dés choisies.
  Future<void> fifiConfirmChoices(int move, int atk) async {
    await _fb.setPhase(roomId!, GamePhase.move,
        fifiGoldenTurn: true, fifiMoveResult: move, fifiAtkResult: atk);
    await _fb.addLog(roomId!, logT('🍀 Fifi choisit : déplacement {move} · attaque {atk}', {'move': '$move', 'atk': '$atk'}));
  }

  /// Retourne à la phase ability (ex: Vlad sans cible).
  Future<void> backToAbility() =>
      _fb.setPhase(roomId!, GamePhase.ability, clearPending: true);

  Future<void> markAlbaneUsed() async {
    final all = _mutableAll();
    final me = all.firstWhere((p) => p.uid == myUid);
    me.abilityUsed = true;
    await _fb.updatePlayer(roomId!, me);
    players = Map<String, Player>.from(players)..[me.uid] = me;
    await _fb.addLog(roomId!, logT('⏱ {name} utilise son pouvoir — meilleur lancer choisi !', {'name': me.name}));
  }

  /// Rémi : finalise son équipement personnalisé avec les 2 effets choisis
  /// dans la boîte de dialogue (multi_screens.dart) — contrairement au
  /// chemin générique useAbility(), qui n'est utilisé QUE par les bots pour
  /// cette capacité (choix automatique, pas de vraie interface pour eux).
  Future<void> remiCraftEquipment(String choice1, String choice2) async {
    final all = _mutableAll();
    final actor = all.firstWhere((p) => p.uid == myUid);
    actor.abilityUsed = true; // unique
    final label1 = kRemiAllChoices[choice1] ?? choice1;
    final label2 = kRemiAllChoices[choice2] ?? choice2;
    actor.equipment.add(GameCard(
      id: 'remi_custom_${actor.uid}',
      name: tr('Invention de Rémi'),
      deck: DeckType.lumiere,
      type: CardType.equipement,
      text: '$label1\n$label2',
      effect: 'remi_custom:$choice1,$choice2',
    ));
    await _commitAll(all, logT('🛠️ {name} fabrique son équipement personnalisé : "{item1}" + "{item2}"', {'name': actor.name, 'item1': label1, 'item2': label2}));
    await _fb.setPhase(roomId!, GamePhase.move, clearPending: true, abilityOverlay: 'remi_craft');
  }

  Future<void> useAbility({Player? target}) async {
    final all   = _mutableAll();
    final actor = all.firstWhere((p) => p.uid == myUid);
    final tgt = target != null
        ? all.firstWhere((p) => p.uid == target.uid, orElse: () => actor)
        : null;
    // Capturés AVANT l'appel — nécessaire pour distinguer correctement,
    // après coup, "était déjà au maximum" (bloqué, aucun changement) de
    // "vient tout juste d'atteindre le maximum" (succès), qui auraient
    // sinon le même état final indiscernable.
    final preMaxHpModifier = actor.maxHpModifier;
    final preActorEquipEmpty = actor.equipment.isEmpty;
    final preTgtEquipEmpty = tgt?.equipment.isEmpty ?? true;
    final log = _eg.applyAbility(actor, all, gameState!.terrainLayout, target: tgt);
    if ((actor.copiedEffect ?? actor.character?.abilityEffect) == 'full_heal_shield_turn') {
      // Cambou : "passez votre tour" fait partie intégrante du texte de la
      // capacité — ce cas particulier manquait ENTIÈREMENT ici (contrairement
      // au solo, qui appelle humanEndTurn() juste après), laissant le joueur
      // dans la phase capacité au lieu de passer directement au joueur
      // suivant, ce qui perturbait aussi la suite du tour (déplacement,
      // attaque) au lieu du passage de tour attendu.
      await _commitAll(all, log);
      await endTurn(actingUid: myUid);
      return;
    }
    if (log == 'draw_dark') {
      // Monkey Raph : retourner en déplacement après la carte
      await _fb.setPhase(roomId!, gameState!.phase, peioReturnToMove: true);
      await drawCard(DeckType.tenebres);
      return;
    }
    if (log == 'draw_light') {
      // Élise : retourner en déplacement après la carte
      await _fb.setPhase(roomId!, gameState!.phase, peioReturnToMove: true, abilityOverlay: 'elise_light');
      await drawCard(DeckType.lumiere);
      return;
    }
    if (log == 'double_move_dice') {
      // Albane : activer le double lancer pour ce tour
      await _commitAll(all, logT('⏱ Albane active son pouvoir — lancez les dés pour choisir le meilleur !', {}));
      await _fb.setPhase(roomId!, GamePhase.move, clearPending: true);
      return;
    }
    if (log == 'elaia_peek') {
      // Elaia : ouvrir le choix de pile — abilityUsed=true verrouille pour ce
      // tour, réactivé au tour suivant (capacité répétable) automatiquement.
      await _commitAll(all, logT('🔮 {name} active son pouvoir de prescience…', {'name': actor.name}));
      await _fb.setPhase(roomId!, GamePhase.ability, elaiaStep: 1);
      return;
    }
    if (log == 'oscar_choice') {
      // Oscar : ouvre l'écran de choix (Eau/Plante/Feu) — résolu ensuite
      // via oscarChoice(), pas ici (aucun target n'a encore été choisi).
      await _fb.setPhase(roomId!, GamePhase.chooseTarget, pendingTargetAction: 'oscar_choice');
      return;
    }
    if (log == 'meg_choice') {
      // Meg : ouvre l'écran de choix (Offensive/Défensive) — résolu ensuite
      // via megChooseForm(), pas ici (aucun target n'a encore été choisi).
      // Même correctif que pour 'cible_requise' juste plus bas : sans
      // persister actor ici, abilityUsed=true (déjà mis à jour en mémoire
      // par applyAbility()) se perdait au prochain rafraîchissement.
      await _fb.updatePlayer(roomId!, actor);
      players = Map<String, Player>.from(players)..[actor.uid] = actor;
      await _fb.setPhase(roomId!, GamePhase.chooseTarget, pendingTargetAction: 'meg_choice');
      return;
    }
    if (log == 'christine_zone_choice') {
      // Christine : ouvre l'écran de choix de zone adjacente — résolu ensuite
      // via christineChooseZone(), pas ici (aucune zone n'a encore été choisie).
      await _fb.setPhase(roomId!, GamePhase.chooseTarget, pendingTargetAction: 'christine_zone_choice');
      return;
    }
    if (log.startsWith('tommy_copied:')) {
      final parts = log.split(':');
      final copiedName = parts.length > 1 ? parts[1] : '?';
      final copiedAbilityText = parts.length > 2 ? parts.sublist(2).join(':') : '';
      await _commitAll(all, logT('🎭 {name} copie le pouvoir de {target} : {ability}', {'name': actor.name, 'target': copiedName, 'ability': copiedAbilityText}));
      // Tommy utilise sa capacité alors que Richard II est révélé
      if (_eg.checkTommyRichardInteraction(all)) {
        audio.playInteractionVoice(kTommyRichardInteraction.key);
      }
      // Certains pouvoirs se déclenchent normalement à la révélation — pour
      // Tommy (déjà révélé), on les déclenche immédiatement après la copie.
      if (actor.copiedEffect == 'builder_power') {
        final offered = _eg.builderDraw3();
        await _fb.setPhase(roomId!, GamePhase.ability,
            builderStep: 1, builderOffered: offered, abilityOverlay: 'tommy_copy');
        return;
      }
      if (actor.copiedEffect == 'prophete_mark') {
        await _fb.setPhase(roomId!, GamePhase.chooseTarget,
            pendingTargetAction: 'jeanne_mark_target', jeanneUid: actor.uid, abilityOverlay: 'tommy_copy');
        return;
      }
      await _fb.setPhase(roomId!, GamePhase.move, clearPending: true, abilityOverlay: 'tommy_copy');
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
      players = Map<String, Player>.from(players)..[p.uid] = p;
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
      await _commitAll(all, logT('🍀 Fifi active son pouvoir — choisissez vos dés !', {}));
      await _fb.setPhase(roomId!, GamePhase.ability,
          pendingTargetAction: 'fifi_dice_picker', abilityOverlay: 'fifi_golden');
      return;
    }
    if (log == 'bonus_turns_zero') {
      await _commitAll(all, logT('🥷 Ninja : aucun joueur mort, pouvoir sans effet.', {}));
      await _fb.setPhase(roomId!, GamePhase.move);
      return;
    }
    if (log.startsWith('bonus_turns:')) {
      final deadCount = int.tryParse(log.split(':')[1]) ?? 0;
      await _commitAll(all, logT('🥷 Ninja active son pouvoir — {n} tour(s) bonus !', {'n': '$deadCount'}));
      await _fb.setPhase(roomId!, GamePhase.move, bonusTurnsRemaining: deadCount, abilityOverlay: 'ninja_shadow');
      return;
    }
    if (log == 'cible_requise') {
      // IMPORTANT : applyAbility() a déjà mis à jour actor.abilityUsed=true
      // en mémoire (LOCALE, dans `all`), mais RIEN ne l'enregistrait encore
      // dans Firebase à ce stade — seule la phase changeait. Résultat : au
      // prochain rafraîchissement de l'état depuis le serveur, abilityUsed
      // revenait à sa valeur précédente (false), rendant une capacité
      // pourtant UNIQUE (ex: Luc) de nouveau cliquable après utilisation.
      await _fb.updatePlayer(roomId!, actor);
      players = Map<String, Player>.from(players)..[actor.uid] = actor;
      await _fb.setPhase(roomId!, GamePhase.chooseTarget,
          pendingTargetAction: actor.copiedEffect ?? actor.character!.abilityEffect);
      return;
    }
    if (log == 'cible_vlad') {
      // Vlad : vérifier qu'il y a des cibles adjacentes
      final vladTargets = _eg.attackTargets(actor, all, gameState!.terrainLayout);
      if (vladTargets.isEmpty) {
        await _fb.addLog(roomId!, logT('💨 Vlad — aucun joueur adjacent à portée.', {}));
        await _fb.setPhase(roomId!, GamePhase.ability);
        return;
      }
      await _fb.setPhase(roomId!, GamePhase.chooseTarget,
          pendingTargetAction: 'ability_vlad_adjacent');
      return;
    }
    if (log == 'terrain_max_aoe') {
      // Hong Yi : signale qu'une cible est requise (tout le monde, pas
      // seulement adjacents) — même correctif que pour 'cible_requise' :
      // persister actor ici, sinon abilityUsed=true (capacité UNIQUE) se
      // perdait au prochain rafraîchissement, la rendant re-cliquable.
      await _fb.updatePlayer(roomId!, actor);
      players = Map<String, Player>.from(players)..[actor.uid] = actor;
      await _fb.setPhase(roomId!, GamePhase.chooseTarget,
          pendingTargetAction: 'terrain_max_aoe');
      return;
    }
    if (log == 'trigger_terrain') {
      await _commitAll(all, "🧌 ${actor.name} subit 1 blessure → réactive l'effet du terrain");
      await _fb.setPhase(roomId!, gameState!.phase, peioReturnToMove: true, abilityOverlay: 'peio_terrain');
      await applyTerrainEffect();
      return;
    }
    _eg.applyDeathPassives(all);
    await _commitAll(all, log);
    // _checkWin() gère désormais TOUTE mort du joueur en cours de tour (y
    // compris auto-infligée, ex: Raph du Soleil) en terminant son tour
    // elle-même — on vérifie donc son retour au lieu de l'ignorer.
    if (await _checkWin(all, justDiedId: tgt != null && !tgt.alive ? tgt.uid
        : (!actor.alive ? actor.uid : null))) return;

    // Travert : voice line (spéciale si Clémence révélée, sinon générale)
    if ((actor.copiedEffect ?? actor.character?.abilityEffect ?? '') == 'd6_global_attack') {
      audio.playInteractionVoice(_eg.travertInteraction(all).key);
    }

    // IMPORTANT : ces 3 branches vérifiaient auparavant le texte du LOG
    // traduit (ex: log.contains('déjà au maximum')) — une fois la
    // traduction anglaise activée, ce texte ne contient plus jamais ces
    // sous-chaînes françaises, cassant silencieusement la détection.
    // Corrigé en revérifiant directement les CONDITIONS sous-jacentes
    // (identiques à celles utilisées dans engine.dart pour produire ces
    // mêmes messages), indépendamment de la langue active.
    final eff = actor.copiedEffect ?? actor.character?.abilityEffect;
    final overlay = (eff == 'steal_max_hp' && preMaxHpModifier >= 5)
        ? null // Agathe déjà à +5 PV max : aucun effet, pas d'animation
        : (eff == 'swap_equipment' && (preActorEquipEmpty || preTgtEquipEmpty))
          ? null // Tristan : échange impossible (équipement manquant), pas d'animation
          : eff == 'damage2_or_heal1'
            ? (tgt == null ? 'julien_heal' : 'julien_attack')
            : _abilityOverlays[eff ?? ''];
    final dice = _extractDiceFromLog(log);
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
    final isAugustin = p.character?.abilityEffect == 'heal_on_same_terrain' && p.revealed;
    if (isAugustin && diceSum == 7) {
      _eg.applyHeal(p, 2);
      await _commitAll(all, logT('🚶 {name} → {zone}  •  🌾 Augustin (7) — soigné de 2', {'name': p.name, 'zone': t.name}));
    } else if (isAugustin && diceSum >= 2 && diceSum <= 6) {
      _eg.applyHeal(p, 1);
      await _commitAll(all, logT('🚶 {name} → {zone}  •  🌾 Augustin ({n}) — soigné de 1', {'name': p.name, 'zone': t.name, 'n': '$diceSum'}));
    } else if (isAugustin && diceSum >= 8 && diceSum <= 10) {
      // Or persistant (menu principal), pas une ressource de partie — géré
      // localement sur l'appareil de CE joueur, comme le reste de sa
      // progression (or, cosmétiques...).
      Prefs.addGold(20);
      await _commitAll(all, logT('🚶 {name} → {zone}  •  🌾 Augustin ({n}) — trouve 20 pièces d\'or !', {'name': p.name, 'zone': t.name, 'n': '$diceSum'}));
    } else {
      await _commitAll(all, logT('🚶 {name} → {zone}', {'name': p.name, 'zone': t.name}));
    }
    // Déplacement confirmé côté serveur — le jet de dés "en attente" (voir
    // pendingMoveD4 etc, plus haut) n'a plus besoin d'être conservé pour
    // survivre à une reconstruction de widget.
    pendingMoveD4 = pendingMoveD6 = pendingMoveSum = null;
    pendingMoveD4b = pendingMoveD6b = pendingMoveSum2 = null;
    await _fb.setPhase(roomId!, GamePhase.zoneEffect,
        richardActivateZone: -1,
        lastDiceResult: d4 > 0 ? {'d4': d4, 'd6': d6, 'sum': diceSum} : null,
        lastDiceLabel: d4 > 0 ? ui('phase_move') : null,
        lastDiceTimestamp: d4 > 0 ? DateTime.now().millisecondsSinceEpoch : null);
  }

  /// Voiture de Clem (capacité) ou Portail du Nether (équipement) : échange
  /// de position avec un autre joueur au lieu de se déplacer normalement.
  Future<void> swapPosition(Player target) async {
    final all = _mutableAll();
    final p = all.firstWhere((x) => x.uid == myUid);
    final t = all.firstWhere((x) => x.uid == target.uid, orElse: () => p);
    final tmp = p.zoneIndex; p.zoneIndex = t.zoneIndex; t.zoneIndex = tmp;
    await _commitAll(all, logT('🚗 {name} échange sa place avec {target}', {'name': p.name, 'target': t.name}));
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
      final dmg9 = _eg.applyDamage(t, 2, isTerrain9Dmg: true);
      _eg.applyMaximeFirstAttacker(actor, t, dmg9); // Maxime : ce dégât compte comme une "attaque" pour sa condition de victoire
      if (!t.alive) t.killedByUid = actor.uid; // sinon aucun butin possible
      _eg.applyDeathPassives(all);
      await _commitAll(all, logT('🏹 {name} inflige {dmg} blessures à {target}', {'name': actor.name, 'dmg': '$dmg9', 'target': t.name}));
    } else if (pta == 'terrain_steal') {
      if (t.equipment.length > 1) {
        // Plusieurs objets possibles — laisse le joueur choisir LEQUEL
        // voler, au lieu de toujours prendre le premier (comme demandé).
        await _fb.setPhase(roomId!, GamePhase.chooseTarget, clearPending: true,
            stealTargetUid: t.uid, pendingTargetAction: 'terrain_steal_item');
        return;
      }
      if (t.equipment.isNotEmpty) {
        final e = t.equipment.removeAt(0);
        actor.equipment.add(e);
        _eg.equipPassivePublic(actor, e);   // active le passif de l'équipement volé
        _eg.recalcPassives(t);              // retire le passif de la victime
        await _commitAll(all, logT('🗼 {name} vole "{item}" à {target}', {'name': actor.name, 'item': e.name, 'target': t.name}));
      } else {
        await _commitAll(all, logT("🗼 {target} n'a aucun équipement à voler", {'target': t.name}));
      }
    }
    final endedSteal = await _checkWin(all, justDiedId: t.alive ? null : t.uid);
    if (endedSteal) return;
    await _fb.setPhase(roomId!, _postCardPhase(), clearPending: true, peioReturnToMove: false);
  }

  /// Terrain 10 — étape 2 : l'objet précis à voler a été choisi.
  Future<void> resolveStealItem(int equipIdx) async {
    final targetUid = gameState?.stealTargetUid;
    if (targetUid == null) return;
    final all = _mutableAll();
    final actor = all.firstWhere((p) => p.uid == myUid);
    final t = all.firstWhere((p) => p.uid == targetUid, orElse: () => actor);
    if (equipIdx >= 0 && equipIdx < t.equipment.length) {
      final e = t.equipment.removeAt(equipIdx);
      actor.equipment.add(e);
      _eg.equipPassivePublic(actor, e);
      _eg.recalcPassives(t);
      await _commitAll(all, logT('🗼 {name} vole "{item}" à {target}', {'name': actor.name, 'item': e.name, 'target': t.name}));
    }
    final endedSteal2 = await _checkWin(all, justDiedId: t.alive ? null : t.uid);
    if (endedSteal2) return;
    await _fb.setPhase(roomId!, _postCardPhase(), clearPending: true, peioReturnToMove: false);
  }

  Future<void> drawCard(DeckType deck) async {
    final queue = Map<String, List<String>>.from(
        (gameState?.forcedDeckQueue ?? const {}).map(
            (k, v) => MapEntry(k, List<String>.from(v))));
    final piles = Map<String, List<String>>.from(
        (gameState?.deckPiles ?? const {}).map(
            (k, v) => MapEntry(k, List<String>.from(v))));
    final card = _eg.drawCard(deck, forcedQueue: queue, deckPiles: piles);
    await _fb.setPhase(roomId!, GamePhase.cardDrawn,
        pendingAction: card.id, forcedDeckQueue: queue, deckPiles: piles);
    // IMPORTANT : synchroniser le cache LOCAL immédiatement après cette
    // écriture — sans ça, `gameState.forcedDeckQueue`/`deckPiles` restaient
    // PÉRIMÉS sur CET appareil jusqu'au prochain sondage réseau (~900ms).
    // Si un second appel à drawCard() survenait dans cette fenêtre (double
    // clic échappant au verrou, reconstruction de widget, etc.), il
    // relisait la MÊME file de pioche non encore mise à jour et écrasait
    // ensuite le `pendingAction` de la première pioche avec le sien —
    // donnant l'impression que la première carte piochée disparaissait /
    // était annulée. C'était très probablement la cause du bug rapporté.
    if (gameState != null) {
      gameState = GameState.fromJson({
        ...gameState!.toJson(),
        'phase': GamePhase.cardDrawn.name,
        'pendingAction': card.id,
        'forcedDeckQueue': queue,
        'deckPiles': piles,
      });
      notifyListeners();
    }
    // Cartes Vision : nom secret — log public générique
    if (deck == DeckType.vision) {
      await _fb.addLog(roomId!, logT('🔮 {name} pioche une carte Vision (secrète)', {'name': me!.name}));
      await _fb.addPrivateLog(roomId!, myUid!, logT('🔮 Tu as pioché : {card}', {'card': card.name}));
    } else {
      await _fb.addLog(roomId!, logT('🃏 {name} pioche : {card}', {'name': me!.name, 'card': card.name}));
      // Julien pioche le Bucket de Poulet
      if (card.id == 'L16' && me!.character?.id == 'julien') {
        audio.playInteractionVoice(kJulienBucketInteraction.key);
      }
    }
  }

  Future<void> applyCard({Player? target}) async {
    final cardId = gameState!.pendingAction; if (cardId == null) return;
    final card = findCardById(cardId); if (card == null) return;
    final all   = _mutableAll();
    final actor = all.firstWhere((p) => p.uid == myUid);
    // Snapshot des joueurs vivants AVANT résolution — pour n'attribuer le
    // killedByUid de rattrapage qu'aux joueurs qui viennent VRAIMENT de
    // mourir à cause de cette carte, pas à un mort plus ancien d'une autre
    // cause (bot, poison...), ce qui offrait sinon un faux butin.
    final aliveBeforeUids = all.where((x) => x.alive).map((x) => x.uid).toSet();
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
          pendingPunishTargetUid: res['punishTargetUid'] as String,
          pendingPunishTimestamp: DateTime.now().millisecondsSinceEpoch);
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
      final endedPrivate = await _checkWin(all);
      if (endedPrivate) return;
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
    for (final d in all.where((x) => !x.alive && aliveBeforeUids.contains(x.uid))) { d.killedByUid ??= actor.uid; }
    await _commitAll(all, res['log'] as String);
    // Une carte peut tuer plusieurs joueurs (AoE, Dynamite...) — vérifier la
    // victoire pour CHAQUE joueur mort, pas seulement la cible unique passée
    // (sinon Tommy/Mango Loco ne gagnent jamais quand le kill vient d'une carte).
    // IMPORTANT : uniquement les joueurs NOUVELLEMENT morts (aliveBeforeUids) —
    // sinon un joueur déjà mort d'une autre cause se voyait re-proposé en
    // butin à chaque nouvelle carte jouée par n'importe qui.
    final justDied = all.where((x) => !x.alive && aliveBeforeUids.contains(x.uid)).toList();
    bool gameEndedCard = false;
    if (justDied.isEmpty) {
      gameEndedCard = await _checkWin(all);
    } else {
      for (final d in justDied) {
        if (await _checkWin(all, justDiedId: d.uid)) { gameEndedCard = true; break; }
      }
    }
    // Ne JAMAIS écraser l'état "gameOver" fraîchement écrit avec une autre
    // phase — même bug que pour le bazooka, ici pour les cartes à dégâts de
    // zone (Dynamite, Poupée Démoniaque...).
    if (gameEndedCard) return;
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
    final endedPunish = await _checkWin(all, justDiedId: target.alive ? null : target.uid);
    if (endedPunish) return;
    await _fb.setPhase(roomId!, GamePhase.attack, clearPending: true, clearPunish: true);
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
    final endedCorne = await _checkWin(all, justDiedId: v.alive ? null : v.uid);
    if (endedCorne) return;
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
    var target = all.firstWhere((p) => p.uid == targetId);
    // Maxence : un joueur ivre a 10% de chance de se frapper lui-même par
    // confusion au lieu de sa cible voulue.
    if (attacker.drunkTurnsRemaining > 0 && attacker.uid != target.uid && Random().nextDouble() < 0.10) {
      target = attacker;
    }
    // Snapshot des vivants avant l'attaque — pour ne considérer que les morts
    // VRAIMENT causées par cette attaque (bazooka notamment), pas un mort
    // plus ancien resté par erreur non traité.
    final aliveBeforeUids = all.where((x) => x.alive).map((x) => x.uid).toSet();
    // Mathieu : seules les attaques faites une fois révélé comptent pour le
    // seuil des 3 attaques.
    if (attacker.revealed) attacker.attackCount++;
    final isMathieuThird = (attacker.copiedEffect ?? attacker.character?.abilityEffect ?? '') == 'third_attack_bonus'
        && attacker.attackCount >= 3;
    if ((attacker.copiedEffect ?? attacker.character?.abilityEffect ?? '') == 'third_attack_bonus'
        && attacker.attackCount == 3) {
      audio.playInteractionVoice(kMathieuActivateInteraction.key);
    }
    bool scottCountered = false;
    Map<String, int>? counterDice;
    String log;
    _ai.recordAttack(attacker, target);
    if (attacker.bazooka) {
      var bazTargets = _eg.attackTargets(attacker, all, gameState!.terrainLayout);
      // Sabre Hanté Masamune (hache) : si aucune cible accessible, l'attaque
      // se rabat sur soi-même — même garde-fou que le getter `attackTargets`
      // (utilisé par l'interface pour proposer le bouton). Sans ce même
      // repli ICI, la liste réelle utilisée pour résoudre l'attaque restait
      // VIDE alors que l'interface affichait "s'attaquer soi-même" comme
      // possible : la volée de bazooka ne touchait alors personne, pas même
      // l'attaquant, et le tour restait bloqué en boucle.
      final hasRevolver = attacker.equipment.any((e) => e.effect == 'revolver_tenebres');
      if (bazTargets.isEmpty && attacker.hache && !hasRevolver) bazTargets = [attacker];
      // IMPORTANT : la Lance, la Lance de Longinus et l'Épée du Ninja
      // manquaient ENTIÈREMENT ici — seule la Dague du Voleur était prise
      // en compte, alors que resolveAttack() (attaque normale) applique
      // les quatre. Répliqué à l'identique.
      var bazDmg = baseDmg;
      if (attacker.lance && bazDmg > 0) bazDmg += 2;
      if (attacker.lanceLonginus && bazDmg > 0 &&
          attacker.character?.faction == Faction.hunter && attacker.revealed) bazDmg += 2;
      if (bazDmg > 0) bazDmg += attacker.equipment.where((e) => e.effect == 'dague_voleur').length;
      if (attacker.epeeNinja && bazDmg > 0) bazDmg += 2;
      // Carla : si elle porte le bazooka, ses cibles Hunter révélées sont
      // soignées du même montant que les dégâts qui auraient été infligés
      // (aucune réduction, ni sur le soin ni sur les dégâts normaux).
      final isCarlaBaz = (attacker.copiedEffect ?? attacker.character?.abilityEffect ?? '') == 'heal_hunter_on_attack';
      // Oscar : cumule 1 XP par blessure RÉELLEMENT infligée — manquait
      // ENTIÈREMENT ici, cette branche bazooka appliquant les dégâts
      // directement via applyDamage() sans jamais passer par resolveAttack()
      // (seul endroit où ce suivi existait auparavant).
      final isOscarBaz = _eg.effectiveAbility(attacker) == 'oscar_xp_spend' && attacker.revealed;
      for (final t in bazTargets) {
        if (isCarlaBaz && attacker.revealed && t.character?.faction == Faction.hunter && t.revealed) {
          if (bazDmg > 0) _eg.applyHeal(t, bazDmg);
        } else {
          final actualBaz = _eg.applyDamage(t, bazDmg);
          if (isOscarBaz && actualBaz > 0) attacker.oscarXp += actualBaz;
        }
        if (!t.alive) t.killedByUid = attacker.uid;
      }
      log = logT('💥 {name} (Bazooka) — {n} dégâts à tous !', {'name': attacker.name, 'n': '$bazDmg'});
    } else {
      final res = _eg.resolveAttack(attacker, target, baseDmg, all: all);
      log = res['log'] as String;
      if (res['scottCountered'] == true) {
        scottCountered = true;
        // Cast défensif : évite un crash (écran rouge) si jamais l'un de
        // ces champs venait à manquer pour une raison imprévue (Tommy
        // ayant copié le pouvoir de Scott, contre-attaque en chaîne, etc.).
        counterDice = {'d4': (res['counterD4'] as int?) ?? 0,
          'd6': (res['counterD6'] as int?) ?? 0,
          'dmg': (res['counterDmg'] as int?) ?? 0};
      }
    }
    // Gège le Fantôme : variante Bazooka (AoE, un seul jet) si l'attaquant a
    // le Bazooka, sinon variante normale (cible unique).
    final (gegeLog, gegeTriggered) = attacker.bazooka
        ? _eg.applyGegePassiveBazooka(attacker, all)
        : _eg.applyGegePassiveEx(attacker, target, all);
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
    bool gameEnded = false;
    if (attacker.bazooka) {
      final justDied = all.where((x) => !x.alive && aliveBeforeUids.contains(x.uid)).toList();
      if (justDied.isEmpty) {
        gameEnded = await _checkWin(all);
      } else {
        final lootAcc = <MapEntry<String,String>>[];
        for (final d in justDied) {
          if (await _checkWin(all, justDiedId: d.uid, lootAccumulator: lootAcc)) {
            gameEnded = true;
            break; // la partie est terminée — inutile de vérifier les morts suivantes
          }
        }
        // Une seule écriture combinée pour TOUTES les opportunités de butin
        // détectées (au lieu d'une écriture par mort qui s'écraseraient).
        if (!gameEnded && lootAcc.isNotEmpty) {
          final killerUid = lootAcc.first.key; // même tueur pour tous (même volée)
          final deadQueue = lootAcc.map((e) => e.value).toList();
          await _fb.setPhase(roomId!, gameState?.phase ?? GamePhase.attack,
              lootKillerUid: killerUid, lootDeadQueue: deadQueue);
        }
      }
    } else {
      gameEnded = await _checkWin(all, justDiedId: target.alive ? null : target.uid);
    }
    // Si la partie vient de se terminer (victoire détectée ci-dessus), ne
    // JAMAIS écraser l'état "gameOver" fraîchement écrit avec une phase
    // "attack" — c'est exactement ce qui empêchait l'écran de victoire de
    // s'afficher après un kill au bazooka.
    if (gameEnded) return;
    // Baleine : quelqu'un qui vient de mourir dans cette attaque avait-il
    // 'death_heal_allies' ? (couvre aussi le cas Bazooka, où plusieurs
    // joueurs peuvent mourir en même temps).
    final baleineJustDied = attacker.bazooka
        ? all.any((x) => !x.alive && aliveBeforeUids.contains(x.uid) &&
            (x.copiedEffect ?? x.character?.abilityEffect) == 'death_heal_allies')
        : (!target.alive && (target.copiedEffect ?? target.character?.abilityEffect) == 'death_heal_allies');
    await _fb.setPhase(roomId!, GamePhase.attack, hasAttacked: true,
        lastDiceResult: d4 > 0 ? {'d4': d4, 'd6': d6, 'sum': baseDmg} : null,
        lastDiceLabel: d4 > 0 ? 'Attaque' : null,
        lastDiceTimestamp: d4 > 0 ? DateTime.now().millisecondsSinceEpoch : null,
        scottCounterDice: counterDice,
        abilityOverlay: (gegeTriggered || gegeTriggered2) ? 'gege_ghost' : scottCountered ? 'scott_counter' : isMathieuThird ? 'mathieu_bullet' : baleineJustDied ? 'baleine_heal' : null);
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
      await _commitAll(all, logT('👑 Richard II échange {zone1} ↔ {zone2} !', {'zone1': t2name, 'zone2': t1name}));
      await _fb.setTerrainLayout(roomId!, newLayout);
      // IMPORTANT : Richard active l'effet de la zone CIBLE qu'il a choisie
      // (celle avec laquelle il a échangé) — utilisé directement via le
      // paramètre zoneIdx plutôt que recalculé via richard.zoneIndex après
      // coup, pour éliminer tout risque de valeur périmée en cas de
      // réutilisation répétée de cette capacité répétable.
      await _fb.setPhase(roomId!, GamePhase.zoneEffect,
          clearPending: true, swapZone1: -1, swapZone2: -1,
          abilityOverlay: 'richard2_swap', richardActivateZone: zoneIdx);
    }
  }

  Future<void> endTurn({String? actingUid}) async {
    final uid = actingUid ?? myUid!;
    // Ninja : tours bonus restants
    final bonusLeft = gameState?.bonusTurnsRemaining ?? 0;
    if (bonusLeft > 0) {
      await _fb.setPhase(roomId!, GamePhase.move,
          bonusTurnsRemaining: bonusLeft - 1, hasAttacked: false);
      await _fb.addLog(roomId!, logT('🥷 Ninja rejoue ! ({n} tour(s) restant(s))', {'n': '${bonusLeft - 1}'}));
      return;
    }
    final p = players[uid]!.copy();
    // Felipe : si son tour de sursis se termine SANS qu'il ait éliminé
    // personne (le sauvetage automatique dans applyDeathPassives l'aurait
    // déjà géré sinon), il meurt maintenant.
    if (p.felipeOnBorrowedTime && p.alive) {
      p.felipeOnBorrowedTime = false;
      p.alive = false;
      await _commitPlayer(p, logT("🩸 {name} (Felipe) n'a pas pu se sauver à temps — il succombe à ses blessures.", {'name': p.name}));
      final all0 = _mutableAll();
      await _checkWin(all0, justDiedId: p.uid);
      if (gameState?.phase == GamePhase.gameOver) return;
    }
    if (p.newTurn) {
      p.newTurn = false;
      await _commitPlayer(p, '⏰ ${p.name} joue un tour de plus');
      await _fb.setPhase(roomId!, GamePhase.move, currentPlayerId: uid, hasAttacked: false);
      return;
    }
    // IMPORTANT : Louna — ne PAS effacer le bouclier ici (fin du tour du
    // joueur protégé lui-même) ! Ce nettoyage prématuré, absent du solo,
    // faisait expirer l'invulnérabilité dès la fin de SON PROPRE tour
    // d'activation, avant même que les autres joueurs n'aient pu jouer —
    // au lieu de durer jusqu'à la fin de son PROCHAIN tour. Le nettoyage
    // correct se fait plus bas, au DÉBUT du tour suivant du joueur protégé
    // (voir nextPlayer.shield plus loin dans cette fonction).
    // Fifi Été / Theo : mémorise si CE joueur a attaqué pendant SON PROPRE
    // tour qui se termine — ce passif n'existait même pas en multijoueur
    // auparavant.
    p.attackedLastOwnTurn = gameState?.hasAttacked ?? false;
    await _fb.updatePlayer(roomId!, p);
    players = Map<String, Player>.from(players)..[p.uid] = p;
    await _fb.addLog(roomId!, logT('⏩ {name} termine son tour', {'name': p.name}));
    // Effacer fifiGoldenTurn
    if (gameState?.fifiGoldenTurn == true) {
      await _fb.setPhase(roomId!, gameState!.phase, fifiGoldenTurn: false);
    }
    final order = gameState!.playerOrder;
    int next = (order.indexOf(uid) + 1) % order.length;
    while (!players[order[next]]!.alive) { next = (next + 1) % order.length; }
    final all = _mutableAll();
    final nextPlayer = all.firstWhere((x) => x.uid == order[next]);
    if (nextPlayer.character?.abilityRepeatable == true) nextPlayer.abilityUsed = false;
    if (nextPlayer.shield && nextPlayer.shieldCharges == 99) {
      nextPlayer.shield = false; nextPlayer.shieldCharges = 0;
    }
    nextPlayer.damageTakenThisTurn = 0; // remise à zéro pour le tracking de Jason
    // Fifi Été / Theo : +2 dégâts sur la prochaine attaque si pas attaqué
    // lors de SON PROPRE tour précédent.
    final nEff = nextPlayer.copiedEffect ?? nextPlayer.character?.abilityEffect ?? '';
    if (nEff == 'no_attack_buff' && nextPlayer.revealed && !nextPlayer.attackedLastOwnTurn) {
      nextPlayer.bonusMaxHp = 1;
    } else if (nEff == 'no_attack_buff') {
      nextPlayer.bonusMaxHp = 0;
    }
    // Passifs de début de tour (Plat de Tripes, Menus, Fijacked, Scott...)
    final passiveLogs = _eg.applyStartOfTurnPassives(nextPlayer, all, gameState!.terrainLayout);
    _eg.applyDeathPassives(all);
    await _commitAll(all, passiveLogs.join(' | '));
    bool gameEndedTurn2 = false;
    if (!nextPlayer.alive) { gameEndedTurn2 = await _checkWin(all, justDiedId: nextPlayer.uid); }
    if (gameEndedTurn2) return;
    if (!nextPlayer.alive) {
      // Il vient de mourir de son propre feu/poison AVANT même que son tour
      // ne débute officiellement (currentPlayerId pas encore écrit) — on
      // enchaîne directement sur le joueur suivant plutôt que de lui poser
      // une phase "capacité" pour un joueur déjà mort.
      await _fb.addLog(roomId!,
          logT('💀 {name} meurt avant même le début de son tour — passage au joueur suivant', {'name': nextPlayer.name}));
      await endTurn(actingUid: nextPlayer.uid);
      return;
    }
    await _fb.setPhase(roomId!, GamePhase.ability, currentPlayerId: order[next], hasAttacked: false, clearPending: true);
  }

  // ─── Privé ───────────────────────────────
  Player _mutableMe() => players[myUid]!.copy();
  List<Player> _mutableAll() => players.values.map((p) => p.copy()).toList();

  Future<void> _commitPlayer(Player p, String log) async {
    await _fb.updatePlayer(roomId!, p);
    await _fb.addLog(roomId!, log);
    // IMPORTANT : met aussi à jour le cache LOCAL immédiatement — sans ça,
    // un tour de bot qui enchaîne plusieurs actions (déplacement, pioche,
    // capacité, attaque...) et qui relit l'état à chaque étape repartait
    // systématiquement d'un instantané PÉRIMÉ (le sondage réseau, toutes
    // les ~900ms, n'ayant pas encore rattrapé l'écriture précédente) — la
    // dernière écriture écrasait alors purement et simplement ce qui
    // venait d'être fait juste avant (par exemple, un équipement pioché
    // disparaissait sans raison apparente).
    players = Map<String, Player>.from(players)..[p.uid] = p;
    notifyListeners();
  }

  Future<void> _commitAll(List<Player> all, String log) async {
    await _fb.updatePlayers(roomId!, all);
    await _fb.addLog(roomId!, log);
    // Même correctif que _commitPlayer ci-dessus, pour la même raison.
    players = { for (final p in all) p.uid: p };
    notifyListeners();
  }

  Future<bool> _checkWin(List<Player> all, {String? justDiedId,
      List<MapEntry<String,String>>? lootAccumulator}) async {
    // Jeanne : vérifie si le mort était la cible marquée
    if (justDiedId != null && gameState?.markedPlayerUid == justDiedId) {
      final (log, needsCard, killerUid) = _eg.checkJeanneReward(
          gameState?.markedPlayerUid, gameState?.jeanneReward,
          gameState?.jeanneUid, all);
      String? bannerText; int? bannerTs;
      if (log.isNotEmpty) {
        // Commit les changements (soins killer + Jeanne)
        await _fb.updatePlayers(roomId!, all);
        await _fb.addLog(roomId!, log);
        players = { for (final p in all) p.uid: p };
        // Bannière plein écran — bien visible, pas juste une ligne de journal
        final killerP = all.where((p) => p.uid == killerUid).firstOrNull;
        final deadP = all.where((p) => p.uid == justDiedId).firstOrNull;
        if (killerP != null && deadP != null) {
          final rewardName = gameState?.jeanneReward ?? '';
          bannerText = logT('{killer} a éliminé {victim} (cible de Jeanne) !\n{reward}', {'killer': killerP.name, 'victim': deadP.name, 'reward': _eg.jeanneRewardLabel(rewardName)});
          bannerTs = DateTime.now().millisecondsSinceEpoch;
        }
      }
      // Effacer le marquage — combiné avec la bannière dans UNE SEULE écriture
      // (deux écritures séquentielles créent une fenêtre de race condition).
      await _fb.setPhase(roomId!, gameState?.phase ?? GamePhase.attack,
          markedPlayerUid: '__clear__',
          jeanneRewardBanner: bannerText, jeanneRewardBannerTimestamp: bannerTs,
          abilityOverlay: bannerText != null ? 'jeanne_reward' : null);
      if (needsCard && killerUid == myUid) {
        final gs = gameState;
        if (gs?.jeanneReward == 'heal3_lumiere') await drawCard(DeckType.lumiere);
        if (gs?.jeanneReward == 'draw_vision') await drawCard(DeckType.vision);
        // Piochée ici (plutôt que dans applyJeanneReward/checkJeanneReward)
        // pour que, si ce n'est PAS un équipement, la carte reste
        // normalement utilisable (choix de cible) via le flux standard de
        // pioche — au lieu d'être gaspillée.
        if (gs?.jeanneReward == 'equip_tenebres') await drawCard(DeckType.tenebres);
      }
    }
    final res = _eg.checkWin(all, justDiedId: justDiedId);
    if (res != null) {
      await _fb.setGameOver(roomId!, List<String>.from(res['winnerIds']!), res['reason'] as String);
      return true;
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
        final killer = all.firstWhere((p) => p.uid == killerUid, orElse: () => dead);
        if (killer.crucifixArgent) {
          // Crucifix d'Argent : récupère TOUT l'équipement d'un coup, pas
          // de choix à faire — se commit immédiatement, indépendamment de
          // l'accumulateur (il n'y a rien à mettre en file d'attente).
          final items = List<GameCard>.from(dead.equipment);
          if (items.isNotEmpty) {
            dead.equipment.clear();
            killer.equipment.addAll(items);
            _eg.recalcPassives(killer);
            _eg.recalcPassives(dead);
            final names = items.map((e) => '"${e.name}"').join(', ');
            await _commitAll(all,
                logT("✝️ {name} récupère TOUT l'équipement de {target} grâce au Crucifix d'Argent : {items}", {'name': killer.name, 'target': dead.name, 'items': names}));
          }
        } else if (lootAccumulator != null) {
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
      await _commitAll(all, logT('🎭 {name} perd son déguisement — sa vraie identité est révélée !', {'name': unmasked.name}));
      await _fb.setPhase(roomId!, gameState?.phase ?? GamePhase.attack,
          publicRevealUid: unmasked.uid,
          publicRevealTimestamp: DateTime.now().millisecondsSinceEpoch);
    }
    // Fanny : vient-elle de voler une identité (son premier kill) sans être
    // révélée ? Ça la révèle automatiquement, comme pour Jason ci-dessus.
    final fannyRevealed = _eg.checkFannyRevealed(all);
    if (fannyRevealed != null) {
      fannyRevealed.fannyJustRevealed = false;
      await _commitAll(all, logT('🎭 {name} vole une identité — révélation automatique !', {'name': fannyRevealed.name}));
      await _fb.setPhase(roomId!, gameState?.phase ?? GamePhase.attack,
          publicRevealUid: fannyRevealed.uid,
          publicRevealTimestamp: DateTime.now().millisecondsSinceEpoch);
    }
    // Felipe : vient-il de survivre à un coup mortel sans être révélé ?
    // Révélation automatique, comme pour Fanny/Jason ci-dessus.
    final felipeRevealed = _eg.checkFelipeRevealed(all);
    if (felipeRevealed != null) {
      felipeRevealed.felipeJustRevealed = false;
      await _commitAll(all, logT('🩸 {name} survit de justesse — révélation automatique !', {'name': felipeRevealed.name}));
      await _fb.setPhase(roomId!, gameState?.phase ?? GamePhase.attack,
          publicRevealUid: felipeRevealed.uid,
          publicRevealTimestamp: DateTime.now().millisecondsSinceEpoch);
    }
    // Si le joueur DONT C'EST LE TOUR vient de mourir pendant ce même tour —
    // feu de Luc, poison de Damien, Araignée Sanguinaire, capacité qui
    // s'auto-inflige des dégâts, ou n'importe quelle autre source — son
    // tour s'arrête immédiatement et on passe au joueur suivant. On
    // renvoie `true` (comme pour une fin de partie) pour que TOUS les
    // appelants existants, qui font déjà `if (await _checkWin(...)) return;`,
    // arrêtent correctement d'écraser la phase par-dessus celle posée pour
    // le joueur suivant — sans avoir à modifier chaque site un par un.
    final current = gameState != null ? players[gameState!.currentPlayerId] : null;
    if (current != null && !current.alive) {
      await _fb.addLog(roomId!,
          '💀 ${current.name} meurt pendant son propre tour — passage au joueur suivant');
      await endTurn(actingUid: current.uid);
      return true;
    }
    return false;
  }
}
