import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/cosmetics_data.dart';

/// ─── Persistance locale ───────────────────────────────────────────────────
/// Réglages (audio, affichage), salle en cours (reconnexion) et
/// historique des parties. Init obligatoire au démarrage : `await Prefs.init()`.
class Prefs {
  static SharedPreferences? _sp;

  static Future<void> init() async {
    _sp ??= await SharedPreferences.getInstance();
  }

  // ── Audio ──────────────────────────────────────────────────────────────
  static void saveAudio({required bool music, required bool sfx,
      required double musicVol, required double sfxVol}) {
    _sp?.setBool('audio_music', music);
    _sp?.setBool('audio_sfx', sfx);
    _sp?.setDouble('audio_music_vol', musicVol);
    _sp?.setDouble('audio_sfx_vol', sfxVol);
  }

  static ({bool music, bool sfx, double musicVol, double sfxVol})? loadAudio() {
    final m = _sp?.getBool('audio_music');
    if (m == null) return null;
    return (
      music: m,
      sfx: _sp?.getBool('audio_sfx') ?? true,
      musicVol: _sp?.getDouble('audio_music_vol') ?? 0.7,
      sfxVol: _sp?.getDouble('audio_sfx_vol') ?? 0.8,
    );
  }

  // ── Affichage ──────────────────────────────────────────────────────────
  static void saveDisplay({required String mode, required double scale,
      required int resIdx}) {
    _sp?.setString('disp_mode', mode);
    _sp?.setDouble('disp_scale', scale);
    _sp?.setInt('disp_res', resIdx);
  }

  static ({String mode, double scale, int resIdx})? loadDisplay() {
    final m = _sp?.getString('disp_mode');
    if (m == null) return null;
    return (
      mode: m,
      scale: _sp?.getDouble('disp_scale') ?? 1.0,
      resIdx: _sp?.getInt('disp_res') ?? 5,
    );
  }

  // ── Salle en cours (reconnexion) ───────────────────────────────────────
  static void saveRoom(String roomId, String uid) {
    _sp?.setString('room_id', roomId);
    _sp?.setString('room_uid', uid);
  }

  static ({String roomId, String uid})? savedRoom() {
    final r = _sp?.getString('room_id');
    final u = _sp?.getString('room_uid');
    if (r == null || u == null) return null;
    return (roomId: r, uid: u);
  }

  static void clearRoom() {
    _sp?.remove('room_id');
    _sp?.remove('room_uid');
  }

  // ── Historique des parties ─────────────────────────────────────────────
  /// Chaque entrée : {date, mode ('solo'|'multi'), character, faction,
  /// win (bool), reason}
  static List<Map<String, dynamic>> history() {
    final raw = _sp?.getString('game_history');
    if (raw == null) return [];
    try {
      return List<Map<String, dynamic>>.from(
          (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)));
    } catch (_) {
      return [];
    }
  }

  static void addGame({required String mode, required String character,
      required String faction, required bool win, String reason = ''}) {
    final h = history();
    h.insert(0, {
      'date': DateTime.now().millisecondsSinceEpoch,
      'mode': mode,
      'character': character,
      'faction': faction,
      'win': win,
      'reason': reason,
    });
    // Garder les 200 dernières parties
    if (h.length > 200) h.removeRange(200, h.length);
    _sp?.setString('game_history', jsonEncode(h));
    // Compteur séparé, JAMAIS purgé (contrairement à l'historique détaillé
    // limité à 200 entrées) — nécessaire pour les effets brillants qui se
    // basent sur le nombre TOTAL de parties, même après des centaines.
    _incrementGamesPlayed(character);
    if (win) _incrementGamesWon(character);
    // Récompense en or à chaque fin de partie — un seul point d'entrée,
    // partagé par le solo ET le multijoueur, puisque addGame() est déjà
    // appelée de façon fiable des deux côtés.
    addGold(win ? 50 : 10);
    // Quêtes journalières : enregistre le camp joué AUJOURD'HUI (indépendant
    // de la victoire — "jouer" suffit, pas besoin de gagner).
    recordFactionPlayedToday(faction);
    // Temps de jeu total (secondes) — calculé à partir de l'horodatage de
    // DÉBUT de cette partie précise (voir markGameStart), enregistré dès le
    // lancement. Ignore un calcul aberrant (horodatage manquant, ou partie
    // ayant duré plus de 6h — probablement un appareil resté ouvert en
    // arrière-plan sans vraiment jouer) plutôt que de fausser durablement
    // la moyenne/le total affiché.
    final startedAt = _sp?.getInt('current_game_started_at');
    if (startedAt != null) {
      final elapsed = (DateTime.now().millisecondsSinceEpoch - startedAt) ~/ 1000;
      if (elapsed > 0 && elapsed < 6 * 3600) {
        final total = (_sp?.getInt('total_playtime_seconds') ?? 0) + elapsed;
        _sp?.setInt('total_playtime_seconds', total);
      }
      _sp?.remove('current_game_started_at');
    }
  }

  /// À appeler UNE FOIS, juste au lancement effectif d'une partie (début du
  /// premier tour, pas l'écran de lobby) — sert de point de départ pour
  /// calculer la durée de CETTE partie dans addGame() ci-dessus.
  static void markGameStart() {
    _sp?.setInt('current_game_started_at', DateTime.now().millisecondsSinceEpoch);
  }

  /// Temps de jeu total cumulé, en secondes — jamais remis à zéro,
  /// indépendant de l'historique détaillé (limité à 200 parties).
  static int totalPlaytimeSeconds() => _sp?.getInt('total_playtime_seconds') ?? 0;

  /// Nombre de parties jouées avec un personnage donné (toutes confondues,
  /// pas seulement les 200 dernières conservées dans l'historique détaillé —
  /// compteur séparé, incrémenté à chaque partie, qui ne s'efface jamais).
  static int gamesPlayedWith(String characterName) {
    return _sp?.getInt('games_played_$characterName') ?? 0;
  }

  static void _incrementGamesPlayed(String characterName) {
    final current = gamesPlayedWith(characterName);
    _sp?.setInt('games_played_$characterName', current + 1);
  }

  /// Nombre de parties GAGNÉES avec un personnage donné — utilisé pour les
  /// paliers d'effet brillant (contrairement au nombre total de parties
  /// jouées, qui ne compte pas que les victoires).
  static int gamesWonWith(String characterName) {
    return _sp?.getInt('games_won_$characterName') ?? 0;
  }

  static void _incrementGamesWon(String characterName) {
    final current = gamesWonWith(characterName);
    _sp?.setInt('games_won_$characterName', current + 1);
  }

  // ── Or (monnaie de la boutique) ────────────────────────────────────────
  static int gold() => _sp?.getInt('gold') ?? 0;

  static void addGold(int amount) {
    _sp?.setInt('gold', gold() + amount);
  }

  /// Retire de l'or si le solde est suffisant ; renvoie false sinon (achat
  /// refusé, aucun changement).
  static bool spendGold(int amount) {
    final current = gold();
    if (current < amount) return false;
    _sp?.setInt('gold', current - amount);
    return true;
  }

  // ── Cosmétiques (boutique) ─────────────────────────────────────────────
  /// Identifiants des cosmétiques possédés (achetés).
  static Set<String> ownedCosmetics() =>
      (_sp?.getStringList('cosmetics_owned') ?? const []).toSet();

  static void unlockCosmetic(String cosmeticId) {
    final owned = ownedCosmetics();
    owned.add(cosmeticId);
    _sp?.setStringList('cosmetics_owned', owned.toList());
  }

  /// Cosmétique actuellement équipé par catégorie+cible, ex :
  /// 'character:albane' → 'albane_winter' (id du cosmétique).
  /// Absence d'entrée = illustration de base utilisée.
  static Map<String, String> equippedCosmetics() {
    final raw = _sp?.getString('cosmetics_equipped');
    if (raw == null) return {};
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  static void equipCosmetic(String slotKey, String? cosmeticId) {
    final eq = equippedCosmetics();
    if (cosmeticId == null) {
      eq.remove(slotKey); // remet l'illustration de base
    } else {
      eq[slotKey] = cosmeticId;
    }
    _sp?.setString('cosmetics_equipped', jsonEncode(eq));
  }

  // ── Compte (code de récupération) ───────────────────────────────────────
  /// Code du compte lié sur CET appareil — null si aucun compte lié
  /// (progression purement locale, comme avant cette fonctionnalité).
  static String? accountCode() => _sp?.getString('account_code');
  static void setAccountCode(String? code) {
    if (code == null) {
      _sp?.remove('account_code');
    } else {
      _sp?.setString('account_code', code);
    }
  }

  /// Exporte toute la progression (or + cosmétiques) sous forme de données
  /// simples, prêtes à être envoyées vers le compte Firebase.
  static Map<String, dynamic> exportProgressionForAccount() {
    final sp = _sp;
    // Statistiques par personnage (parties jouées/gagnées) — dynamiquement
    // à partir des clés existantes, plutôt que de coder en dur les 60
    // personnages ici (reste synchronisé si la liste évolue).
    final charStats = <String, int>{};
    if (sp != null) {
      for (final k in sp.getKeys()) {
        if (k.startsWith('games_played_') || k.startsWith('games_won_')) {
          charStats[k] = sp.getInt(k) ?? 0;
        }
      }
    }
    return {
      'gold': gold(),
      'cosmeticsOwned': ownedCosmetics().toList(),
      'cosmeticsEquipped': equippedCosmetics(),
      'charStats': charStats,
      // Quêtes : progression des paliers personnage (jamais réinitialisée)
      // ET état des quêtes journalières (date + camps déjà joués + quêtes
      // déjà réclamées aujourd'hui) — sans ça, changer d'appareil en cours
      // de journée aurait permis de refaire les quêtes journalières déjà
      // accomplies sur l'autre appareil.
      'claimedQuests': (sp?.getStringList('claimed_quests') ?? []),
      'dailyQuestDate': sp?.getString('daily_quest_date'),
      'dailyQuestFactions': (sp?.getStringList('daily_quest_factions') ?? []),
    };
  }

  /// Applique une progression reçue du compte (écrase la progression
  /// locale actuelle) — utilisé en se connectant à un compte existant sur
  /// un nouvel appareil.
  static Future<void> importProgressionFromAccount(Map<String, dynamic> data) async {
    final sp = _sp;
    if (sp == null) return;
    final gold = data['gold'] as int? ?? 0;
    await sp.setInt('gold', gold);
    final owned = (data['cosmeticsOwned'] as List?)?.map((e) => e.toString()).toList() ?? [];
    await sp.setStringList('cosmetics_owned', owned);
    final equipped = data['cosmeticsEquipped'] as Map? ?? {};
    await sp.setString('cosmetics_equipped',
        jsonEncode(equipped.map((k, v) => MapEntry(k.toString(), v.toString()))));
    // Stats par personnage : on efface d'abord les anciennes clés locales
    // (sinon un personnage joué UNIQUEMENT sur cet appareil, absent du
    // compte importé, garderait à tort son ancien compteur local).
    for (final k in sp.getKeys().toList()) {
      if (k.startsWith('games_played_') || k.startsWith('games_won_')) {
        await sp.remove(k);
      }
    }
    final charStats = data['charStats'] as Map? ?? {};
    for (final entry in charStats.entries) {
      await sp.setInt(entry.key.toString(), (entry.value as num).toInt());
    }
    // Quêtes
    final claimedQuests = (data['claimedQuests'] as List?)?.map((e) => e.toString()).toList() ?? [];
    await sp.setStringList('claimed_quests', claimedQuests);
    final dailyDate = data['dailyQuestDate'] as String?;
    if (dailyDate != null) {
      await sp.setString('daily_quest_date', dailyDate);
    } else {
      await sp.remove('daily_quest_date');
    }
    final dailyFactions = (data['dailyQuestFactions'] as List?)?.map((e) => e.toString()).toList() ?? [];
    await sp.setStringList('daily_quest_factions', dailyFactions);
  }

  // ── Réinitialisation complète de la progression ────────────────────────
  /// Efface l'or, les cosmétiques (débloqués + équipés), l'historique de
  /// parties et les statistiques par personnage (parties jouées/gagnées) —
  /// remet le compte à zéro comme à la toute première installation.
  /// Ne touche PAS aux réglages audio/affichage ni à une salle en cours de
  /// reconnexion, qui ne sont pas des "progrès" de jeu.
  static Future<void> resetProgress() async {
    final sp = _sp;
    if (sp == null) return;
    await sp.remove('gold');
    await sp.remove('cosmetics_owned');
    await sp.remove('cosmetics_equipped');
    await sp.remove('game_history');
    final statKeys = sp.getKeys().where(
        (k) => k.startsWith('games_played_') || k.startsWith('games_won_'));
    for (final k in statKeys.toList()) {
      await sp.remove(k);
    }
    // Quêtes : sans ça, les compteurs de victoires repartaient à zéro mais
    // les récompenses déjà réclamées restaient marquées comme telles,
    // empêchant de les regagner alors que la progression réelle avait
    // pourtant été effacée.
    await sp.remove('claimed_quests');
    await sp.remove('daily_quest_date');
    await sp.remove('daily_quest_factions');
  }

  // ── Skins de terrain aléatoires ──────────────────────────────────────
  /// Réglage : si activé, chaque nouvelle partie tire un skin au hasard
  /// (parmi ceux DÉBLOQUÉS) pour chaque type de terrain, au lieu d'utiliser
  /// le skin fixe équipé en boutique.
  static bool randomTerrainSkins() => _sp?.getBool('random_terrain_skins') ?? false;
  static void setRandomTerrainSkins(bool value) => _sp?.setBool('random_terrain_skins', value);

  /// Pseudo et jeton du joueur — mémorisés d'une connexion à l'autre,
  /// pour ne pas avoir à les ressaisir/choisir à chaque lancement.
  static String? playerName() => _sp?.getString('player_name');
  static void setPlayerName(String value) => _sp?.setString('player_name', value);
  static String? playerToken() => _sp?.getString('player_token');
  static void setPlayerToken(String value) => _sp?.setString('player_token', value);

  /// Langue de l'interface et du contenu de jeu ('fr' ou 'en') — mémorisée
  /// d'une session à l'autre. Français par défaut.
  static String language() => _sp?.getString('language') ?? 'fr';
  static void setLanguage(String value) => _sp?.setString('language', value);

  /// Tire un skin aléatoire par type de terrain — à appeler une seule fois
  /// au tout début d'une nouvelle partie (solo ou multi). Le résultat est
  /// mémorisé pour toute la durée de la partie (pas un tirage à chaque
  /// affichage, sinon l'illustration changerait sans arrêt à l'écran).
  static void rollRandomTerrainSkinsForNewGame() {
    if (_sp == null) return;
    final owned = ownedCosmetics();
    const terrainTypes = {'vision', 'lumiere', 'tenebres', 'damage9', 'steal', 'choice'};
    final map = <String, String>{};
    final rng = Random();
    for (final t in terrainTypes) {
      final options = kCosmeticsCatalog.where((c) =>
          c.category == CosmeticCategory.terrain && c.targetId == t && owned.contains(c.id)).toList();
      if (options.isNotEmpty) {
        map[t] = options[rng.nextInt(options.length)].id;
      }
    }
    _sp!.setString('terrain_skins_session', jsonEncode(map));
  }

  /// Skins tirés pour la partie en cours (vide si le réglage n'est pas
  /// activé, ou si aucun skin n'était débloqué pour un type de terrain —
  /// dans ce cas ce type retombe simplement sur son skin équipé habituel).
  static Map<String, String> sessionTerrainSkins() {
    final raw = _sp?.getString('terrain_skins_session');
    if (raw == null) return {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      return {};
    }
  }

  // ── Quêtes ───────────────────────────────────────────────────────────────
  // Deux familles bien différentes :
  // - Journalières (3) : jouer une partie avec chaque camp — se réinitialisent
  //   chaque jour, indépendamment des victoires (jouer suffit).
  // - Personnage (60 × 4 paliers) : 1/10/50/100 victoires avec CHAQUE
  //   personnage — jamais réinitialisées, se basent directement sur le
  //   compteur de victoires déjà existant (gamesWonWith), pas de nouveau
  //   compteur à maintenir en parallèle. Seul le statut de RÉCLAMATION (a-t-on
  //   déjà touché l'or de ce palier ?) doit être stocké séparément.

  static String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  /// À appeler à chaque fin de partie — enregistre que ce camp a été joué
  /// AUJOURD'HUI (peu importe la victoire). Les jours précédents sont écrasés
  /// dès que la date change : inutile de garder un historique, seule la
  /// journée EN COURS compte pour ces quêtes.
  static void recordFactionPlayedToday(String faction) {
    final today = _todayKey();
    if (_sp?.getString('daily_quest_date') != today) {
      // Nouveau jour : on repart de zéro (nouvelle date + liste vide) —
      // les anciennes réclamations restent dans claimed_quests (préfixées
      // par leur date), donc aucun risque de re-réclamer une quête d'hier.
      _sp?.setString('daily_quest_date', today);
      _sp?.setStringList('daily_quest_factions', []);
    }
    final list = _sp?.getStringList('daily_quest_factions') ?? [];
    if (!list.contains(faction)) {
      list.add(faction);
      _sp?.setStringList('daily_quest_factions', list);
    }
  }

  /// A-t-on joué ce camp aujourd'hui ? (indépendant d'une éventuelle
  /// réclamation déjà effectuée pour cette quête journalière précise).
  static bool hasPlayedFactionToday(String faction) {
    if (_sp?.getString('daily_quest_date') != _todayKey()) return false;
    return (_sp?.getStringList('daily_quest_factions') ?? []).contains(faction);
  }

  static Set<String> _claimedQuests() =>
      (_sp?.getStringList('claimed_quests') ?? []).toSet();

  /// Une quête journalière est identifiée par camp + DATE (pour permettre de
  /// la réclamer à nouveau chaque jour) ; une quête personnage par nom de
  /// personnage + palier (jamais réinitialisée).
  static bool isQuestClaimed(String questId) => _claimedQuests().contains(questId);

  /// Marque une quête comme réclamée et verse l'or correspondant. Ne fait
  /// rien si déjà réclamée (protection contre un double-tap accidentel).
  static void claimQuest(String questId, int goldReward) {
    final set = _claimedQuests();
    if (set.contains(questId)) return;
    set.add(questId);
    _sp?.setStringList('claimed_quests', set.toList());
    addGold(goldReward);
  }

  /// Identifiant stable d'une quête journalière (inclut la date du jour, ce
  /// qui la rend automatiquement réclamable à nouveau demain).
  static String dailyQuestId(String faction) => 'daily_${faction}_${_todayKey()}';

  /// Identifiant stable d'une quête de palier de victoires pour un personnage.
  static String charQuestId(String characterName, int tier) => 'char_${characterName}_$tier';
}
