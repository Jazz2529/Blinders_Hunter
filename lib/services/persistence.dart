import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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
  }

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
  }
}
