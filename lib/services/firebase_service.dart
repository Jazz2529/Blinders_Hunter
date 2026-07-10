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
      uid = 'u${_rng.nextInt(1 << 32)}_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('bh_local_uid', uid);
    }
    _uid = uid;
    return uid;
  }

  /// Génère une nouvelle identité locale (pour tester plusieurs "joueurs"
  /// depuis le même PC en lançant plusieurs fenêtres de l'app).
  Future<String> newIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = 'u${_rng.nextInt(1 << 32)}_${DateTime.now().millisecondsSinceEpoch}';
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

  /// Quitte la room
  Future<void> leaveRoom(String roomId) async {
    final uid = currentUid;
    if (uid == null) return;
    await _delete('rooms/$roomId/players/$uid');
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
  /// ont confirmé, passe la phase globale à `ability` (début de partie).
  Future<void> confirmRoleSeen(String roomId) async {
    final uid = currentUid!;
    await _put('rooms/$roomId/roleConfirms/$uid', true);

    final playersData = await _get('rooms/$roomId/players');
    final confirmsData = await _get('rooms/$roomId/roleConfirms');
    final playerIds = playersData != null
        ? Map<String, dynamic>.from(playersData as Map).keys.toSet()
        : <String>{};
    final confirmedIds = confirmsData != null
        ? Map<String, dynamic>.from(confirmsData as Map).keys.toSet()
        : <String>{};

    if (playerIds.isNotEmpty && playerIds.difference(confirmedIds).isEmpty) {
      await _patch('rooms/$roomId/gameState', {'phase': GamePhase.ability.name});
    }
  }

  /// Nombre de joueurs ayant confirmé avoir vu leur rôle
  Stream<int> watchRoleConfirms(String roomId) {
    return _poll('rooms/$roomId/roleConfirms', (data) {
      if (data == null) return 0;
      return Map<String, dynamic>.from(data as Map).length;
    });
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
    );

    final Map<String, dynamic> updates = {
      'rooms/$roomId/status': 'playing',
      'rooms/$roomId/gameState': gameState.toJson(),
      'rooms/$roomId/log': ['important||⚔️ La partie commence !'],
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
    return _poll('rooms/$roomId/privateLogs/$uid', (data) {
      if (data == null) return <String>[];
      return List<dynamic>.from(data as List).map((e) => e as String).toList();
    });
  }

  Stream<List<String>> watchLog(String roomId) {
    return _poll('rooms/$roomId/log', (data) {
      if (data == null) return <String>[];
      return List<dynamic>.from(data as List).map((e) => e as String).toList();
    });
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
    String? privateRevealTargetUid,
    String? privateRevealForUid,
    String? forcedAttackerUid,
    bool? peioReturnToMove,
    int? builderStep,
    String? builderEffect1,
    String? builderEffect2,
    List<String>? builderOffered,
    String? markedPlayerUid,
    String? jeanneReward,
    String? jeanneUid,
    int? swapZone1,
    int? swapZone2,
    int? bonusTurnsRemaining,
    bool? fifiGoldenTurn,
    int? fifiMoveResult,
    int? fifiAtkResult,
    Map<String, int>? lastDiceResult,
    String? lastDiceLabel,
    int? lastDiceTimestamp,
    bool clearOverlay = false,
    bool clearPending = false,
  }) async {
    final Map<String, dynamic> updates = {'phase': phase.name};
    if (currentPlayerId != null) updates['currentPlayerId'] = currentPlayerId;
    if (clearPending) {
      updates['pendingAction'] = null;
      updates['pendingTargetAction'] = null;
      updates['attackTargetId'] = null;
      updates['pendingDamage'] = null;
      updates['pendingPunishActorUid'] = null;
      updates['pendingPunishTargetUid'] = null;
      updates['privateRevealTargetUid'] = null;
      updates['privateRevealForUid'] = null;
      updates['forcedAttackerUid'] = null;
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
    if (privateRevealTargetUid != null) updates['privateRevealTargetUid'] = privateRevealTargetUid;
    if (privateRevealForUid != null) updates['privateRevealForUid'] = privateRevealForUid;
    if (forcedAttackerUid != null) updates['forcedAttackerUid'] = forcedAttackerUid;
    if (peioReturnToMove != null) updates['peioReturnToMove'] = peioReturnToMove;
    if (builderStep != null) updates['builderStep'] = builderStep;
    if (builderEffect1 != null) updates['builderEffect1'] = builderEffect1;
    if (builderEffect2 != null) updates['builderEffect2'] = builderEffect2;
    if (builderOffered != null) updates['builderOffered'] = builderOffered;
    if (markedPlayerUid != null) updates['markedPlayerUid'] = markedPlayerUid;
    if (jeanneReward != null) updates['jeanneReward'] = jeanneReward;
    if (jeanneUid != null) updates['jeanneUid'] = jeanneUid;
    if (swapZone1 != null) updates['swapZone1'] = swapZone1;
    if (swapZone2 != null) updates['swapZone2'] = swapZone2;
    if (bonusTurnsRemaining != null) updates['bonusTurnsRemaining'] = bonusTurnsRemaining;
    if (fifiGoldenTurn != null) updates['fifiGoldenTurn'] = fifiGoldenTurn;
    if (fifiMoveResult != null) updates['fifiMoveResult'] = fifiMoveResult;
    if (fifiAtkResult != null)  updates['fifiAtkResult']  = fifiAtkResult;
    if (lastDiceResult != null) updates['lastDiceResult'] = lastDiceResult;
    if (lastDiceLabel != null) updates['lastDiceLabel'] = lastDiceLabel;
    if (lastDiceTimestamp != null) updates['lastDiceTimestamp'] = lastDiceTimestamp;
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

  /// Sondage périodique d'un chemin Firebase ; s'arrête quand le Stream est annulé.
  Stream<T> _poll<T>(String path, T Function(dynamic) parse,
      {Duration interval = const Duration(milliseconds: 1200)}) async* {
    while (true) {
      try {
        final data = await _get(path);
        yield parse(data);
      } catch (_) {
        // ignore les erreurs réseau ponctuelles, on retentera au prochain tour
      }
      await Future.delayed(interval);
    }
  }

  Stream<Map<String, Player>> watchPlayers(String roomId) {
    return _poll('rooms/$roomId/players', (data) {
      if (data == null) return <String, Player>{};
      final map = Map<String, dynamic>.from(data as Map);
      return map.map((uid, p) => MapEntry(
        uid,
        Player.fromJson(Map<String, dynamic>.from(p as Map)),
      ));
    });
  }

  Stream<GameState?> watchGameState(String roomId) {
    return _poll('rooms/$roomId/gameState', (data) {
      if (data == null) return null;
      return GameState.fromJson(Map<String, dynamic>.from(data as Map));
    });
  }

  /// Écoute le statut de la room (lobby/playing/finished)
  Stream<String> watchStatus(String roomId) {
    return _poll('rooms/$roomId/status', (data) => data as String? ?? 'lobby');
  }

  Stream<Map<String, dynamic>?> watchResult(String roomId) {
    return _poll('rooms/$roomId/result', (data) {
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
