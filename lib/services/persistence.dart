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
  }
}
