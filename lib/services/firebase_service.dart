// lib/services/firebase_service.dart
// Toutes les opérations "Firebase" — via l'API REST de Realtime Database.
// Aucune dépendance native (firebase_core/firebase_auth/firebase_database) :
// fonctionne sur TOUTES les plateformes, y compris Windows, via `http`.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../data/tokens_data.dart';
import '../data/game_data.dart';
import 'i18n.dart';
import 'engine.dart';

// ⚠️ Remplace par l'URL de TA Realtime Database (Firebase Console → Realtime
// Database → onglet Données → l'URL affichée en haut, SANS slash final).
const String _kDatabaseUrl =
    'https://blinders-hunter-9f8ae-default-rtdb.europe-west1.firebasedatabase.app';

class FirebaseService {
  static final FirebaseService instance = FirebaseService._internal();
  FirebaseService._internal();

  final GameEngine _eg = GameEngine.instance;
  final Random _rng = Random();
  String? _uid;

  String? get currentUid => _uid;

  // ─────────────────────────────────────────────
  // "AUTH" — identifiant local persistant (pas besoin de compte)
  // ─────────────────────────────────────────────
  Future<String> signInAnonymously() async {
    if (_uid != null) return _uid!;
    final prefs = await SharedPreferences.getInstance();
    var uid = prefs.getString('bh_local_uid');
    if (uid == null) {
      uid = 'u${_rng.nextInt(0x7FFFFFFF)}_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('bh_local_uid', uid);
    }
    _uid = uid;
    return uid;
  }

  /// Génère une nouvelle identité locale (pour tester plusieurs "joueurs"
  /// depuis le même PC en lançant plusieurs fenêtres de l'app).
  Future<String> newIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = 'u${_rng.nextInt(0x7FFFFFFF)}_${DateTime.now().millisecondsSinceEpoch}';
    await prefs.setString('bh_local_uid', uid);
    _uid = uid;
    return uid;
  }

  // ─────────────────────────────────────────────
  // REQUÊTES REST BAS NIVEAU
  // ─────────────────────────────────────────────
  Uri _uri(String path) => Uri.parse('$_kDatabaseUrl/$path.json');

  Future<dynamic> _get(String path) async {
    final resp = await http.get(_uri(path)).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw Exception('Firebase GET $path → HTTP ${resp.statusCode} : ${resp.body}');
    }
    if (resp.body == 'null') return null;
    return jsonDecode(resp.body);
  }

  Future<void> _put(String path, dynamic data) async {
    final resp = await http.put(_uri(path), body: jsonEncode(data))
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw Exception('Firebase PUT $path → HTTP ${resp.statusCode} : ${resp.body}');
    }
  }

  /// PATCH multi-chemins à la racine : data = {"rooms/X/status": "playing", ...}
  Future<void> _patchRoot(Map<String, dynamic> data) async {
    final resp = await http.patch(_uri(''), body: jsonEncode(data))
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw Exception('Firebase PATCH / → HTTP ${resp.statusCode} : ${resp.body}');
    }
  }

  Future<void> _patch(String path, Map<String, dynamic> data) async {
    final resp = await http.patch(_uri(path), body: jsonEncode(data))
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw Exception('Firebase PATCH $path → HTTP ${resp.statusCode} : ${resp.body}');
    }
  }

  Future<void> _delete(String path) async {
    await http.delete(_uri(path)).timeout(const Duration(seconds: 10));
  }

  // ─────────────────────────────────────────────
  // LOBBY — CRÉER / REJOINDRE UNE ROOM
  // ─────────────────────────────────────────────

  /// Crée une nouvelle room et retourne le code à 5 caractères
  Future<String> createRoom(String playerName, String token) async {
    final uid = await signInAnonymously();
    final roomId = _generateRoomCode();
    final tok = kAllTokens.any((t) => t.id == token) ? token : kAllTokens.first.id;

    final roomData = {
      'roomId': roomId,
      'hostId': uid,
      'status': 'lobby',
      'createdAt': {'.sv': 'timestamp'},
      'players': {
        uid: Player(uid: uid, name: playerName, token: tok, isReady: false).toJson(),
      },
      'log': <String>[],
    };

    await _put('rooms/$roomId', roomData);
    return roomId;
  }

  /// Rejoint une room existante
  Future<void> joinRoom(String roomId, String playerName, String token) async {
    final uid = await signInAnonymously();

    final data = await _get('rooms/$roomId');
    if (data == null) throw Exception('Room introuvable : $roomId');
    final room = Map<String, dynamic>.from(data as Map);
    if (room['status'] != 'lobby') throw Exception('Partie déjà commencée');

    final playersMap = Map<String, dynamic>.from(room['players'] ?? {});
    if (playersMap.length >= 7) throw Exception('Room pleine (max 7 joueurs)');
    if (playersMap.containsKey(uid)) return; // déjà dans la room

    final usedTokens = playersMap.values
        .map((p) => (p as Map)['token'] as String? ?? '')
        .toSet();
    final tok = (!usedTokens.contains(token)) ? token
        : kAllTokens.firstWhere((t) => !usedTokens.contains(t.id),
            orElse: () => kAllTokens.first).id;

    final player = Player(uid: uid, name: playerName, token: tok, isReady: false);
    await _put('rooms/$roomId/players/$uid', player.toJson());
  }

  /// Ajoute un bot à la salle (lobby uniquement) — pas de vraie connexion
  /// Firebase Auth, juste un joueur synthétique avec un uid préfixé "bot_"
  /// (convention déjà utilisée par Player.isBot). Prêt automatiquement,
  /// puisqu'un bot n'a personne pour cliquer "prêt" à sa place.
  Future<void> addBot(String roomId) async {
    final data = await _get('rooms/$roomId');
    if (data == null) throw Exception('Room introuvable : $roomId');
    final room = Map<String, dynamic>.from(data as Map);
    if (room['status'] != 'lobby') throw Exception('Partie déjà commencée');

    final playersMap = Map<String, dynamic>.from(room['players'] ?? {});
    if (playersMap.length >= 7) throw Exception('Room pleine (max 7 joueurs)');

    final usedTokens = playersMap.values
        .map((p) => (p as Map)['token'] as String? ?? '')
        .toSet();
    final tok = kAllTokens.firstWhere((t) => !usedTokens.contains(t.id),
        orElse: () => kAllTokens.first).id;

    final botNum = playersMap.keys.where((k) => k.startsWith('bot_')).length + 1;
    final botUid = 'bot_$botNum${DateTime.now().millisecondsSinceEpoch}';
    final bot = Player(uid: botUid, name: 'Bot $botNum', token: tok, isReady: true);
    await _put('rooms/$roomId/players/$botUid', bot.toJson());
  }

  /// Convertit un joueur (mi-partie, en cours de jeu) en bot — appelé quand
  /// un joueur quitte la partie, pour qu'elle puisse continuer sans lui. Ne
  /// touche à rien d'autre (personnage, PV, équipement conservés) : seul
  /// `isBot` passe à `true`, ce qui suffit pour que le mécanisme de
  /// pilotage des bots (déjà générique) prenne le relais automatiquement.
  /// IMPORTANT : contrairement à leaveRoom(), on ne supprime PAS le joueur
  /// — le supprimer casserait l'ordre des tours et perdrait sa progression.
  Future<void> convertPlayerToBot(String roomId, String uid) async {
    await _put('rooms/$roomId/players/$uid/isBot', true);

    // Si le joueur qui part était l'hôte, transférer le rôle à un autre
    // joueur HUMAIN — sinon plus personne ne peut piloter les bots
    // (le pilotage n'est actif que sur l'appareil de l'hôte).
    final currentHost = await _get('rooms/$roomId/hostId');
    if (currentHost == uid) {
      final playersData = await _get('rooms/$roomId/players');
      if (playersData != null) {
        final players = Map<String, dynamic>.from(playersData as Map);
        final humans = players.entries
            .where((e) => e.key != uid && !((e.value as Map)['isBot'] == true))
            .map((e) => e.key).toList();
        if (humans.isNotEmpty) {
          await _put('rooms/$roomId/hostId', humans.first);
        }
      }
    }
  }

  /// Retire un bot de la salle (lobby uniquement, hôte).
  Future<void> removeBot(String roomId, String botUid) async {
    await _delete('rooms/$roomId/players/$botUid');
  }

  /// Expulse un joueur HUMAIN de la salle — lobby uniquement (avant le
  /// lancement de la partie). Même mécanisme que removeBot() : le joueur
  /// peut rejoindre à nouveau avec le code s'il le souhaite.
  Future<void> kickPlayer(String roomId, String uid) async {
    final status = await _get('rooms/$roomId/status');
    if (status != null && status != 'lobby') return; // sécurité : lobby uniquement
    await _delete('rooms/$roomId/players/$uid');
  }

  /// Quitte la room
  /// Statut actuel d'une salle ('lobby' | 'playing' | 'finished') ou null.
  Future<String?> fetchRoomStatus(String roomId) async {
    try {
      final s = await _get('rooms/$roomId/status');
      return s as String?;
    } catch (_) { return null; }
  }

  /// Réinitialise la salle pour rejouer avec les mêmes joueurs :
  /// retour au lobby, joueurs conservés (nom + jeton) mais remis à zéro.
  Future<void> restartRoom(String roomId) async {
    final data = await _get('rooms/$roomId');
    if (data == null) return;
    final playersRaw = Map<String, dynamic>.from(data['players'] ?? {});
    final resetPlayers = <String, dynamic>{};
    for (final e in playersRaw.entries) {
      final p = Map<String, dynamic>.from(e.value);
      resetPlayers[e.key] = Player(
        uid: p['uid'] as String? ?? e.key,
        name: p['name'] as String? ?? 'Joueur',
        token: p['token'] as String? ?? '🎲',
      ).toJson();
    }
    await _patch('rooms/$roomId', {
      'status': 'lobby',
      'gameState': null,
      'result': null,
      'logs': null,
      'privateLogs': null,
      'roleConfirms': null,
      'players': resetPlayers,
    });
  }

  Future<void> leaveRoom(String roomId) async {
    final uid = currentUid;
    if (uid == null) return;
    await _delete('rooms/$roomId/players/$uid');

    // Si le joueur qui part était l'hôte, transférer le rôle à un autre
    // joueur — sinon plus personne ne peut lancer la partie ni piloter les
    // bots, et la salle reste bloquée définitivement.
    final currentHost = await _get('rooms/$roomId/hostId');
    if (currentHost == uid) {
      final playersData = await _get('rooms/$roomId/players');
      if (playersData != null) {
        final remaining = Map<String, dynamic>.from(playersData as Map).keys.toList();
        if (remaining.isNotEmpty) {
          // Préfère un humain (un bot ne peut pas cliquer "lancer la
          // partie" ni piloter les autres bots) — ne prend un bot que s'il
          // ne reste vraiment que ça.
          final newHost = remaining.firstWhere((k) => !k.startsWith('bot_'),
              orElse: () => remaining.first);
          await _put('rooms/$roomId/hostId', newHost);
        }
      }
    }
  }

  /// Récupère l'uid de l'hôte de la room
  Future<String?> getHostId(String roomId) async {
    final data = await _get('rooms/$roomId/hostId');
    return data as String?;
  }

  /// Marque le joueur comme prêt
  Future<void> setReady(String roomId, bool ready) async {
    final uid = currentUid!;
    await _put('rooms/$roomId/players/$uid/isReady', ready);
  }

  /// Change le jeton du joueur courant
  Future<void> setToken(String roomId, String tokenId) async {
    final uid = currentUid!;
    await _put('rooms/$roomId/players/$uid/token', tokenId);
  }

  /// Marque que le joueur courant a vu son rôle. Quand TOUS les joueurs
  /// HUMAINS ont confirmé, passe la phase globale à `ability` (début de
  /// partie) — les bots sont exclus de cette exigence : ils n'ont personne
  /// pour cliquer "j'ai compris" à leur place, donc ce compte n'atteignait
  /// jamais son total et la partie restait bloquée sur cet écran dès qu'un
  /// bot était présent.
  Future<void> confirmRoleSeen(String roomId) async {
    final uid = currentUid!;
    await _put('rooms/$roomId/roleConfirms/$uid', true);

    final playersData = await _get('rooms/$roomId/players');
    final confirmsData = await _get('rooms/$roomId/roleConfirms');
    final playerIds = playersData != null
        ? Map<String, dynamic>.from(playersData as Map).keys
            .where((k) => !k.startsWith('bot_')).toSet()
        : <String>{};
    final confirmedIds = confirmsData != null
        ? Map<String, dynamic>.from(confirmsData as Map).keys.toSet()
        : <String>{};

    if (playerIds.isNotEmpty && playerIds.difference(confirmedIds).isEmpty) {
      // IMPORTANT : fixer turnStartedAt ICI est OBLIGATOIRE — sans ça, ce
      // champ restait à `null` pour le TOUT PREMIER tour de chaque partie
      // (le constructeur de GameState dans startGame() ne le fixe pas non
      // plus), et _maybeForceTurn() refuse d'agir tant qu'il est nul :
      // le minuteur de 2 minutes ne se déclenchait donc JAMAIS pour le
      // premier tour, laissant l'impression que "la corde ne fait rien".
      await _patch('rooms/$roomId/gameState', {
        'phase': GamePhase.ability.name,
        'turnStartedAt': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  /// Nombre de joueurs ayant confirmé avoir vu leur rôle
  Stream<int> watchRoleConfirms(String roomId) {
    return _pollRoom(roomId).map((room) {
      final data = room?['roleConfirms'];
      if (data == null) return 0;
      return Map<String, dynamic>.from(data as Map).length;
    }).distinct();
  }

  // ─────────────────────────────────────────────
  // DÉMARRAGE DE PARTIE
  // ─────────────────────────────────────────────

  /// Lance la partie (host uniquement) — distribue les rôles via GameEngine,
  /// mélange les terrains, initialise le GameState (phase = roleReveal)
  Future<void> startGame(String roomId) async {
    final uid = currentUid!;
    final data = await _get('rooms/$roomId');
    final room = Map<String, dynamic>.from(data as Map);
    if (room['hostId'] != uid) throw Exception('Seul l\'hôte peut lancer la partie');

    final playersMap = Map<String, dynamic>.from(room['players']);
    final playerIds = playersMap.keys.toList();
    final n = playerIds.length;
    if (n < 4) throw Exception('Il faut au minimum 4 joueurs');

    final players = playerIds.map((id) {
      final pm = Map<String, dynamic>.from(playersMap[id] as Map);
      return Player(
        uid: id,
        name: pm['name'] as String? ?? 'Joueur',
        token: pm['token'] as String? ?? kAllTokens.first.id,
        isReady: true,
      );
    }).toList();
    _eg.assignRoles(players);
    for (int i = 0; i < players.length; i++) {
      players[i].zoneIndex = i % 6;
    }

    final terrainLayout = [...kAllTerrains]..shuffle(_rng);
    final playerOrder = [...playerIds]..shuffle(_rng);

    final gameState = GameState(
      roomId: roomId,
      hostId: uid,
      phase: GamePhase.roleReveal,
      currentPlayerId: playerOrder.first,
      playerOrder: playerOrder,
      terrainLayout: terrainLayout,
      turnStartedAt: DateTime.now().millisecondsSinceEpoch,
    );

    final Map<String, dynamic> updates = {
      'rooms/$roomId/status': 'playing',
      'rooms/$roomId/gameState': gameState.toJson(),
      'rooms/$roomId/log': ['important||' + logT('⚔️ La partie commence !', {})],
    };
    for (final p in players) {
      updates['rooms/$roomId/players/${p.uid}'] = p.toJson();
    }

    await _patchRoot(updates);
  }

  // ─────────────────────────────────────────────
  // ACTIONS DE JEU — ÉCRITURE
  // ─────────────────────────────────────────────

  Future<void> updateGameState(String roomId, GameState state) async {
    await _put('rooms/$roomId/gameState', state.toJson());
  }

  /// Met à jour un joueur spécifique
  Future<void> updatePlayer(String roomId, Player player) async {
    await _put('rooms/$roomId/players/${player.uid}', player.toJson());
  }

  /// Synchronise le skin de carte personnage équipé par CE joueur (choisi
  /// localement en boutique) — mise à jour ciblée d'un seul champ plutôt
  /// que réécrire tout le joueur, pour rester léger et sûr même si
  /// d'autres champs changent en même temps ailleurs.
  Future<void> setEquippedSkin(String roomId, String uid, String? skinId) async {
    await _patch('rooms/$roomId/players/$uid', {'equippedCharacterSkin': skinId});
  }

  /// Synchronise le nombre de victoires (LOCAL à l'appareil du joueur) avec
  /// le personnage actuellement joué — pour que les AUTRES joueurs voient sa
  /// vraie étoile en consultant sa fiche.
  Future<void> setShineWins(String roomId, String uid, int wins) async {
    await _patch('rooms/$roomId/players/$uid', {'shineWins': wins});
  }

  /// Met à jour plusieurs joueurs en une seule requête
  Future<void> updatePlayers(String roomId, List<Player> players) async {
    final Map<String, dynamic> updates = {};
    for (final p in players) {
      updates['rooms/$roomId/players/${p.uid}'] = p.toJson();
    }
    await _patchRoot(updates);
  }

  /// Ajoute une entrée au journal (liste de strings "cls||message")
  Future<void> addLog(String roomId, String message, {String cls = ''}) async {
    final current = await _get('rooms/$roomId/log');
    final List<dynamic> log = current != null ? List<dynamic>.from(current as List) : [];
    log.add('$cls||$message');
    if (log.length > 80) log.removeAt(0);
    await _put('rooms/$roomId/log', log);
  }

  /// Log visible seulement par un joueur spécifique (stocké dans son nœud privé).
  Future<void> addPrivateLog(String roomId, String uid, String message) async {
    final current = await _get('rooms/$roomId/privateLogs/$uid');
    final List<dynamic> log = current != null ? List<dynamic>.from(current as List) : [];
    log.add(message);
    if (log.length > 20) log.removeAt(0);
    await _put('rooms/$roomId/privateLogs/$uid', log);
  }

  Stream<List<String>> watchPrivateLog(String roomId, String uid) {
    return _pollRoom(roomId).map((room) {
      final data = room?['privateLogs']?[uid];
      if (data == null) return <String>[];
      return List<dynamic>.from(data as List).map((e) => e as String).toList();
    }).distinct((a, b) => a.length == b.length && (a.isEmpty || a.last == b.last));
  }

  Stream<List<String>> watchLog(String roomId) {
    return _pollRoom(roomId).map((room) {
      final data = room?['log'];
      if (data == null) return <String>[];
      return List<dynamic>.from(data as List).map((e) => e as String).toList();
    }).distinct((a, b) => a.length == b.length && (a.isEmpty || a.last == b.last));
  }

  /// Met à jour la phase ET le joueur courant / actions en attente
  Future<void> setPhase(String roomId, GamePhase phase, {
    String? currentPlayerId,
    String? pendingAction,
    String? pendingTargetAction,
    int? pendingDamage,
    String? attackTargetId,
    bool? hasAttacked,
    String? abilityOverlay,
    Map<String, int>? abilityDiceResult,
    String? pendingPunishActorUid,
    String? pendingPunishTargetUid,
    int? pendingPunishTimestamp,
    String? privateRevealTargetUid,
    String? privateRevealForUid,
    String? forcedAttackerUid,
    String? stealTargetUid,
    bool? peioReturnToMove,
    int? builderStep,
    String? builderEffect1,
    String? builderEffect2,
    List<String>? builderOffered,
    List<String>? haileyOffered,
    String? markedPlayerUid,
    String? tristanTargetUid,
    int? tristanGiveIdx,
    String? jeanneReward,
    String? jeanneUid,
    int? swapZone1,
    int? swapZone2,
    int? bonusTurnsRemaining,
    bool? fifiGoldenTurn,
    int? fifiMoveResult,
    int? fifiAtkResult,
    Map<String, int>? scottCounterDice,
    Map<String, int>? lastDiceResult,
    String? lastDrawnCardId,
    int? lastDrawnCardTimestamp,
    String? lastDiceLabel,
    int? lastDiceTimestamp,
    int? elaiaStep,
    String? elaiaDeck,
    String? elaiaCard1Id,
    String? elaiaCard2Id,
    Map<String, List<String>>? forcedDeckQueue,
    Map<String, List<String>>? deckPiles,
    String? baptisteTargetUid,
    String? damienTargetUid,
    String? lootKillerUid,
    List<String>? lootDeadQueue,
    int? richardActivateZone,
    String? publicRevealUid,
    String? jeanneRewardBanner,
    int? jeanneRewardBannerTimestamp,
    int? publicRevealTimestamp,
    bool clearOverlay = false,
    bool clearPending = false,
  }) async {
    final Map<String, dynamic> updates = {'phase': phase.name};
    if (currentPlayerId != null) {
      updates['currentPlayerId'] = currentPlayerId;
      updates['turnStartedAt'] = DateTime.now().millisecondsSinceEpoch;
    }
    if (clearPending) {
      updates['pendingAction'] = null;
      updates['pendingTargetAction'] = null;
      updates['attackTargetId'] = null;
      updates['pendingDamage'] = null;
      updates['pendingPunishActorUid'] = null;
      updates['pendingPunishTargetUid'] = null;
      updates['pendingPunishTimestamp'] = null;
      updates['privateRevealTargetUid'] = null;
      updates['privateRevealForUid'] = null;
      updates['forcedAttackerUid'] = null;
      updates['stealTargetUid'] = null;
      updates['damienTargetUid'] = null;
      updates['lootKillerUid'] = null;
      updates['lootDeadQueue'] = <String>[];
      updates['richardActivateZone'] = null;
    }
    if (clearOverlay) {
      updates['abilityOverlay'] = null;
      updates['abilityDiceResult'] = null;
    }
    if (pendingAction != null) updates['pendingAction'] = pendingAction;
    if (pendingTargetAction != null) updates['pendingTargetAction'] = pendingTargetAction;
    if (pendingDamage != null) updates['pendingDamage'] = pendingDamage;
    if (attackTargetId != null) updates['attackTargetId'] = attackTargetId;
    if (hasAttacked != null) updates['hasAttacked'] = hasAttacked;
    if (abilityOverlay != null) updates['abilityOverlay'] = abilityOverlay;
    if (abilityDiceResult != null) updates['abilityDiceResult'] = abilityDiceResult;
    if (pendingPunishActorUid != null) updates['pendingPunishActorUid'] = pendingPunishActorUid;
    if (pendingPunishTargetUid != null) updates['pendingPunishTargetUid'] = pendingPunishTargetUid;
    if (pendingPunishTimestamp != null) updates['pendingPunishTimestamp'] = pendingPunishTimestamp;
    if (privateRevealTargetUid != null) updates['privateRevealTargetUid'] = privateRevealTargetUid;
    if (privateRevealForUid != null) updates['privateRevealForUid'] = privateRevealForUid;
    if (forcedAttackerUid != null) updates['forcedAttackerUid'] = forcedAttackerUid;
    if (stealTargetUid != null) updates['stealTargetUid'] = stealTargetUid;
    if (peioReturnToMove != null) updates['peioReturnToMove'] = peioReturnToMove;
    if (builderStep != null) updates['builderStep'] = builderStep;
    if (builderEffect1 != null) updates['builderEffect1'] = builderEffect1;
    if (builderEffect2 != null) updates['builderEffect2'] = builderEffect2;
    if (builderOffered != null) updates['builderOffered'] = builderOffered;
    if (haileyOffered != null) updates['haileyOffered'] = haileyOffered;
    if (markedPlayerUid != null) updates['markedPlayerUid'] = markedPlayerUid;
    if (tristanTargetUid != null) {
      updates['tristanTargetUid'] = tristanTargetUid == '__clear__' ? null : tristanTargetUid;
    }
    if (tristanGiveIdx != null) updates['tristanGiveIdx'] = tristanGiveIdx == -1 ? null : tristanGiveIdx;
    if (jeanneReward != null) updates['jeanneReward'] = jeanneReward;
    if (jeanneUid != null) updates['jeanneUid'] = jeanneUid;
    if (swapZone1 != null) updates['swapZone1'] = swapZone1;
    if (swapZone2 != null) updates['swapZone2'] = swapZone2;
    if (bonusTurnsRemaining != null) updates['bonusTurnsRemaining'] = bonusTurnsRemaining;
    if (fifiGoldenTurn != null) updates['fifiGoldenTurn'] = fifiGoldenTurn;
    if (fifiMoveResult != null) updates['fifiMoveResult'] = fifiMoveResult;
    if (fifiAtkResult != null)  updates['fifiAtkResult']  = fifiAtkResult;
    if (scottCounterDice != null) updates['scottCounterDice'] = scottCounterDice;
    if (lastDiceResult != null) updates['lastDiceResult'] = lastDiceResult;
    if (lastDrawnCardId != null) updates['lastDrawnCardId'] = lastDrawnCardId;
    if (lastDrawnCardTimestamp != null) updates['lastDrawnCardTimestamp'] = lastDrawnCardTimestamp;
    if (lastDiceLabel != null) updates['lastDiceLabel'] = lastDiceLabel;
    if (lastDiceTimestamp != null) updates['lastDiceTimestamp'] = lastDiceTimestamp;
    if (elaiaStep != null) updates['elaiaStep'] = elaiaStep;
    if (elaiaDeck != null) updates['elaiaDeck'] = elaiaDeck;
    if (elaiaCard1Id != null) updates['elaiaCard1Id'] = elaiaCard1Id;
    if (elaiaCard2Id != null) updates['elaiaCard2Id'] = elaiaCard2Id;
    if (forcedDeckQueue != null) updates['forcedDeckQueue'] = forcedDeckQueue;
    if (deckPiles != null) updates['deckPiles'] = deckPiles;
    if (baptisteTargetUid != null) {
      updates['baptisteTargetUid'] = baptisteTargetUid == '__clear__' ? null : baptisteTargetUid;
    }
    if (damienTargetUid != null) updates['damienTargetUid'] = damienTargetUid;
    if (lootKillerUid != null) {
      updates['lootKillerUid'] = lootKillerUid == '__clear__' ? null : lootKillerUid;
    }
    if (lootDeadQueue != null) updates['lootDeadQueue'] = lootDeadQueue;
    if (richardActivateZone != null) {
      updates['richardActivateZone'] = richardActivateZone == -1 ? null : richardActivateZone;
    }
    if (publicRevealUid != null) updates['publicRevealUid'] = publicRevealUid;
    if (jeanneRewardBanner != null) updates['jeanneRewardBanner'] = jeanneRewardBanner;
    if (jeanneRewardBannerTimestamp != null) updates['jeanneRewardBannerTimestamp'] = jeanneRewardBannerTimestamp;
    if (publicRevealTimestamp != null) updates['publicRevealTimestamp'] = publicRevealTimestamp;
    await _patch('rooms/$roomId/gameState', updates);
  }

  /// Efface uniquement les champs de la révélation privée (Vision Suprême),
  /// sans toucher au reste de l'état (phase, cible en cours, etc.)
  Future<void> clearPrivateReveal(String roomId) async {
    await _patch('rooms/$roomId/gameState', {
      'privateRevealTargetUid': null,
      'privateRevealForUid': null,
    });
  }

  /// Met à jour le layout des terrains (Richard II — échange de zones).
  Future<void> setTerrainLayout(String roomId, List<Terrain> layout) async {
    await _patch('rooms/$roomId/gameState', {
      'terrainLayout': layout.map((t) => t.toJson()).toList(),
    });
  }

  /// Fin de partie
  Future<void> setGameOver(String roomId, List<String> winnerIds, String reason) async {
    await _patchRoot({
      'rooms/$roomId/status': 'finished',
      'rooms/$roomId/gameState/phase': GamePhase.gameOver.name,
      'rooms/$roomId/result': {
        'winnerIds': winnerIds,
        'reason': reason,
        'finishedAt': {'.sv': 'timestamp'},
      },
    });
  }

  // ─────────────────────────────────────────────
  // STREAMS — POLLING TEMPS QUASI-RÉEL
  // ─────────────────────────────────────────────

  /// À appeler quand on quitte une salle — sans ça, le sondage en arrière-
  /// plan (la boucle `while(true)`) continuerait indéfiniment même après
  /// que plus personne n'écoute, gaspillant réseau et mémoire sur une
  /// session longue avec plusieurs parties.
  void stopPollingRoom(String roomId) {
    _roomPolls.remove(roomId);
  }


  // ── Sondage UNIFIÉ de toute la room ─────────────────────────────────────
  // Avant : players/gameState/status/result/log/privateLogs/hostId étaient
  // sondés INDÉPENDAMMENT (jusqu'à 8 requêtes HTTP séparées toutes les
  // 1,2s !), ce qui multipliait la charge réseau et la latence perçue —
  // cause principale du lag ressenti en multijoueur. Un seul sondage de
  // `rooms/$roomId` (qui contient déjà TOUT en un seul document) suffit ;
  // chaque watchX() en dérive juste la portion qui l'intéresse, sans
  // requête HTTP supplémentaire. `.distinct()` évite en plus de renotifier
  // les écouteurs quand la valeur extraite n'a pas changé d'un cycle à
  // l'autre (même si LE RESTE de la room, lui, a changé).
  final Map<String, Stream<Map<String, dynamic>?>> _roomPolls = {};
  Stream<Map<String, dynamic>?> _pollRoom(String roomId,
      {Duration interval = const Duration(milliseconds: 900)}) {
    return _roomPolls.putIfAbsent(roomId, () {
      return (() async* {
        while (true) {
          try {
            final data = await _get('rooms/$roomId');
            yield data != null ? Map<String, dynamic>.from(data as Map) : null;
          } catch (_) {
            // ignore les erreurs réseau ponctuelles, on retentera au prochain tour
          }
          await Future.delayed(interval);
        }
      }()).asBroadcastStream();
    });
  }

  Stream<Map<String, Player>> watchPlayers(String roomId) {
    return _pollRoom(roomId).map((room) {
      final data = room?['players'];
      if (data == null) return <String, Player>{};
      final map = Map<String, dynamic>.from(data as Map);
      return map.map((uid, p) => MapEntry(
        uid,
        Player.fromJson(Map<String, dynamic>.from(p as Map)),
      ));
    });
  }

  Stream<GameState?> watchGameState(String roomId) {
    return _pollRoom(roomId).map((room) {
      final data = room?['gameState'];
      if (data == null) return null;
      return GameState.fromJson(Map<String, dynamic>.from(data as Map));
    });
  }

  /// Écoute le statut de la room (lobby/playing/finished)
  Stream<String> watchStatus(String roomId) {
    return _pollRoom(roomId).map((room) => room?['status'] as String? ?? 'lobby').distinct();
  }

  /// Surveille l'hôte en continu — nécessaire pour que TOUS les clients
  /// soient prévenus si l'hôte quitte et que le rôle est transféré (sinon
  /// leur `hostId` local reste périmé et personne ne peut plus lancer la
  /// partie ni piloter les bots).
  Stream<String?> watchHostId(String roomId) {
    return _pollRoom(roomId).map((room) => room?['hostId'] as String?).distinct();
  }

  Stream<Map<String, dynamic>?> watchResult(String roomId) {
    return _pollRoom(roomId).map((room) {
      final data = room?['result'];
      if (data == null) return null;
      return Map<String, dynamic>.from(data as Map);
    });
  }

  // ─────────────────────────────────────────────
  // UTILS
  // ─────────────────────────────────────────────
  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sans I, O, 0, 1
    return List.generate(5, (_) => chars[_rng.nextInt(chars.length)]).join();
  }
}
