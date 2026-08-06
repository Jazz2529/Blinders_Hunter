// lib/services/audio_service.dart
// Service audio centralisé — musiques + effets sonores
// Package: audioplayers ^6.0.0

import 'dart:io' show Platform;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService extends ChangeNotifier {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  // ── Players ──────────────────────────────────────────────────────────────
  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer   = AudioPlayer();
  final AudioPlayer _sfxPlayer2  = AudioPlayer(); // pour chevauchements
  final AudioPlayer _voicePlayer = AudioPlayer(); // dédié aux voice lines (révélation + interactions) — évite qu'un effet générique (_sfx2) ou qu'une 2e voice line ne coupe la précédente avant la fin
  final AudioPlayer _ropePlayer  = AudioPlayer(); // son dédié "corde qui brûle"

  // ── Volumes (0.0 → 1.0) ──────────────────────────────────────────────────
  double _musicVolume = 0.7;
  double _sfxVolume   = 0.8;
  bool   _musicEnabled = true;
  bool   _sfxEnabled   = true;

  String? _currentMusic;
  // Compteur de génération : incrémenté à CHAQUE changement de musique.
  // Permet à un fadeOutMusic() en cours d'annuler son arrêt final si une
  // NOUVELLE musique a démarré entre-temps (évite qu'un fade-out tardif
  // vienne couper la musique qui vient tout juste de commencer — c'est ce
  // qui causait "la musique ne s'arrête/ne redémarre pas correctement" lors
  // des changements rapides d'écran, ex: victoire → clic rapide → menu).
  int _musicGeneration = 0;

  double get musicVolume  => _musicVolume;
  double get sfxVolume    => _sfxVolume;
  bool   get musicEnabled => _musicEnabled;
  bool   get sfxEnabled   => _sfxEnabled;

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    await _loadPrefs();
    // IMPORTANT (Android/iOS uniquement) : par défaut sur mobile, chaque
    // lecteur audio demande le "focus audio" en exclusivité — ce qui met la
    // musique en pause dès qu'un effet sonore démarre. Sur PC ce souci
    // n'existe pas (mixage libre par défaut) — et il s'avère qu'appliquer ce
    // réglage sur PC perturbait carrément la lecture audio (plus de son du
    // tout), donc on le limite strictement aux plateformes mobiles.
    bool isMobile = false;
    try { isMobile = Platform.isAndroid || Platform.isIOS; } catch (_) {}
    if (isMobile) {
      final mixContext = AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
      );
      try { await AudioPlayer.global.setAudioContext(mixContext); } catch (_) {}
      for (final p in [_musicPlayer, _sfxPlayer, _sfxPlayer2, _voicePlayer, _ropePlayer]) {
        try { await p.setAudioContext(mixContext); } catch (_) {}
      }
    }
    await _musicPlayer.setVolume(_musicEnabled ? _musicVolume : 0.0);
    await _sfxPlayer.setVolume(_sfxEnabled ? _sfxVolume : 0.0);
    await _sfxPlayer2.setVolume(_sfxEnabled ? _sfxVolume : 0.0);
    await _voicePlayer.setVolume(_sfxEnabled ? _sfxVolume : 0.0);
    await _ropePlayer.setVolume(_sfxEnabled ? _sfxVolume : 0.0);
  }

  // ── Musiques ──────────────────────────────────────────────────────────────
  Future<void> playLobbyMusic() async {
    _musicGeneration++;
    if (_currentMusic == 'lobby') return;
    _currentMusic = 'lobby';
    try {
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(_musicEnabled ? _musicVolume : 0.0);
      await _musicPlayer.play(AssetSource('audio/music_lobby.mp3'));
    } catch (e) {
      debugPrint('Audio: music_lobby.mp3 not found — $e');
    }
  }

  Future<void> playGameMusic() async {
    _musicGeneration++;
    if (_currentMusic == 'game') return;
    _currentMusic = 'game';
    try {
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(_musicEnabled ? _musicVolume : 0.0);
      await _musicPlayer.play(AssetSource('audio/music_game.mp3'));
    } catch (e) {
      debugPrint('Audio: music_game.mp3 not found — $e');
    }
  }

  Future<void> stopMusic() async {
    _musicGeneration++;
    _currentMusic = null;
    await _musicPlayer.stop();
  }

  /// Arrête TOUS les effets sonores/bruits de partie (dégâts, dés, voice
  /// lines, corde qui brûle...) — à appeler systématiquement en quittant une
  /// partie (retour au menu), sinon un son en cours (ex: corde qui brûle en
  /// boucle) continue indéfiniment même sur l'écran d'accueil. Ne touche PAS
  /// à la musique — appeler stopMusic()/playLobbyMusic() séparément pour ça.
  Future<void> stopAllSfx() async {
    try { await _sfxPlayer.stop(); } catch (_) {}
    try { await _sfxPlayer2.stop(); } catch (_) {}
    try { await _voicePlayer.stop(); } catch (_) {}
    try { await _ropePlayer.stop(); } catch (_) {}
  }

  Future<void> fadeOutMusic({int ms = 800}) async {
    final myGeneration = ++_musicGeneration;
    double v = _musicVolume;
    const steps = 20;
    final stepTime = ms ~/ steps;
    for (int i = 0; i < steps; i++) {
      if (_musicGeneration != myGeneration) return; // annulé par une nouvelle musique
      v = _musicVolume * (1 - (i + 1) / steps);
      await _musicPlayer.setVolume(v.clamp(0.0, 1.0));
      await Future.delayed(Duration(milliseconds: stepTime));
    }
    if (_musicGeneration != myGeneration) return; // annulé pendant le dernier délai
    _currentMusic = null;
    await _musicPlayer.stop();
    await _musicPlayer.setVolume(_musicEnabled ? _musicVolume : 0.0);
  }

  // ── Effets sonores ────────────────────────────────────────────────────────
  Future<void> playDice()   => _sfx('sfx_dice.mp3');
  Future<void> playCard()   => _sfx('sfx_card.mp3');
  Future<void> playDamage() => _sfx('sfx_damage.mp3');
  Future<void> playHeal()   => _sfx('sfx_heal.mp3');
  Future<void> playReveal() => _sfx('sfx_reveal.mp3');
  Future<void> playWin()    => _sfx2('sfx_win.mp3');
  Future<void> playLose()   => _sfx2('sfx_lose.mp3');

  // ── Corde qui brûle (alerte minuteur bas) ───────────────────────────────
  // PLACEHOLDER : remplacer 'sfx_rope_burning.mp3' par le vrai fichier une
  // fois ajouté dans assets/audio/. En boucle tant que la corde est visible
  // (30 dernières secondes du tour), coupé dès qu'elle disparaît.
  Future<void> playRopeBurningSound() async {
    if (!_sfxEnabled) return;
    try {
      await _ropePlayer.setReleaseMode(ReleaseMode.loop);
      await _ropePlayer.setVolume(_sfxVolume);
      await _ropePlayer.play(AssetSource('audio/sfx_rope_burning.mp3'));
    } catch (e) {
      debugPrint('Audio: sfx_rope_burning.mp3 not found (placeholder) — $e');
    }
  }

  Future<void> stopRopeBurningSound() async {
    try { await _ropePlayer.stop(); } catch (_) {}
  }

  // ── Interaction entre personnages (voice lines) ─────────────────────────
  // PLACEHOLDER : cherche 'assets/audio/interact_<key>.mp3'. Utilise le
  // lecteur secondaire pour ne pas couper le son de révélation en cours.
  Future<void> playInteractionVoice(String key) async {
    if (!_sfxEnabled) return;
    try {
      await _voicePlayer.stop();
      await _voicePlayer.setVolume(_sfxVolume);
      await _voicePlayer.play(AssetSource('audio/interact_$key.mp3'));
    } catch (e) {
      debugPrint('Audio: interact_$key.mp3 not found (placeholder) — $e');
    }
  }

  // ── Réplique de révélation (voix du personnage) ─────────────────────────
  // PLACEHOLDER : cherche 'assets/audio/reveal_<id>.mp3'. Remplace ces
  // fichiers un par un au fur et à mesure que tu les enregistres — aucun
  // changement de code nécessaire. Utilise un lecteur dédié (_voicePlayer)
  // pour ne pas couper un autre effet sonore en cours (dégâts, dés...) NI
  // se faire couper par un effet générique qui utiliserait _sfxPlayer2.
  Future<void> playRevealVoice(String characterId) async {
    if (!_sfxEnabled) return;
    try {
      await _voicePlayer.stop();
      await _voicePlayer.setVolume(_sfxVolume);
      await _voicePlayer.play(AssetSource('audio/reveal_$characterId.mp3'));
    } catch (e) {
      debugPrint('Audio: reveal_$characterId.mp3 not found (placeholder) — $e');
    }
  }

  Future<void> _sfx(String name) async {
    if (!_sfxEnabled) return;
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.setVolume(_sfxVolume);
      await _sfxPlayer.play(AssetSource('audio/$name'));
    } catch (e) {
      debugPrint('Audio: $name not found — $e');
    }
  }

  Future<void> _sfx2(String name) async {
    if (!_sfxEnabled) return;
    try {
      await _sfxPlayer2.stop();
      await _sfxPlayer2.setVolume(_sfxVolume);
      await _sfxPlayer2.play(AssetSource('audio/$name'));
    } catch (e) {
      debugPrint('Audio: $name not found — $e');
    }
  }

  // ── Paramètres ────────────────────────────────────────────────────────────
  Future<void> setMusicVolume(double v) async {
    _musicVolume = v.clamp(0.0, 1.0);
    await _musicPlayer.setVolume(_musicEnabled ? _musicVolume : 0.0);
    await _savePrefs(); notifyListeners();
  }

  Future<void> setSfxVolume(double v) async {
    _sfxVolume = v.clamp(0.0, 1.0);
    await _sfxPlayer.setVolume(_sfxEnabled ? _sfxVolume : 0.0);
    await _sfxPlayer2.setVolume(_sfxEnabled ? _sfxVolume : 0.0);
    await _voicePlayer.setVolume(_sfxEnabled ? _sfxVolume : 0.0);
    await _ropePlayer.setVolume(_sfxEnabled ? _sfxVolume : 0.0);
    await _savePrefs(); notifyListeners();
  }

  Future<void> toggleMusic() async {
    _musicEnabled = !_musicEnabled;
    await _musicPlayer.setVolume(_musicEnabled ? _musicVolume : 0.0);
    await _savePrefs(); notifyListeners();
  }

  Future<void> toggleSfx() async {
    _sfxEnabled = !_sfxEnabled;
    await _sfxPlayer.setVolume(_sfxEnabled ? _sfxVolume : 0.0);
    await _sfxPlayer2.setVolume(_sfxEnabled ? _sfxVolume : 0.0);
    await _voicePlayer.setVolume(_sfxEnabled ? _sfxVolume : 0.0);
    await _ropePlayer.setVolume(_sfxEnabled ? _sfxVolume : 0.0);
    if (!_sfxEnabled) await stopRopeBurningSound();
    await _savePrefs(); notifyListeners();
  }

  // ── Persistance ───────────────────────────────────────────────────────────
  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('musicVol', _musicVolume);
    await p.setDouble('sfxVol',   _sfxVolume);
    await p.setBool('musicOn',    _musicEnabled);
    await p.setBool('sfxOn',      _sfxEnabled);
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    _musicVolume  = p.getDouble('musicVol') ?? 0.7;
    _sfxVolume    = p.getDouble('sfxVol')   ?? 0.8;
    _musicEnabled = p.getBool('musicOn')    ?? true;
    _sfxEnabled   = p.getBool('sfxOn')      ?? true;
  }

  void dispose() {
    _musicPlayer.dispose();
    _sfxPlayer.dispose();
    _sfxPlayer2.dispose();
    _voicePlayer.dispose();
    super.dispose();
  }
}

// Singleton global accessible partout
final audio = AudioService();
