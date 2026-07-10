// lib/services/audio_service.dart
// Service audio centralisé — musiques + effets sonores
// Package: audioplayers ^6.0.0

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

  // ── Volumes (0.0 → 1.0) ──────────────────────────────────────────────────
  double _musicVolume = 0.7;
  double _sfxVolume   = 0.8;
  bool   _musicEnabled = true;
  bool   _sfxEnabled   = true;

  String? _currentMusic;

  double get musicVolume  => _musicVolume;
  double get sfxVolume    => _sfxVolume;
  bool   get musicEnabled => _musicEnabled;
  bool   get sfxEnabled   => _sfxEnabled;

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    await _loadPrefs();
    await _musicPlayer.setVolume(_musicEnabled ? _musicVolume : 0.0);
    await _sfxPlayer.setVolume(_sfxEnabled ? _sfxVolume : 0.0);
    await _sfxPlayer2.setVolume(_sfxEnabled ? _sfxVolume : 0.0);
  }

  // ── Musiques ──────────────────────────────────────────────────────────────
  Future<void> playLobbyMusic() async {
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
    _currentMusic = null;
    await _musicPlayer.stop();
  }

  Future<void> fadeOutMusic({int ms = 800}) async {
    double v = _musicVolume;
    const steps = 20;
    final stepTime = ms ~/ steps;
    for (int i = 0; i < steps; i++) {
      v = _musicVolume * (1 - (i + 1) / steps);
      await _musicPlayer.setVolume(v.clamp(0.0, 1.0));
      await Future.delayed(Duration(milliseconds: stepTime));
    }
    await stopMusic();
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
    super.dispose();
  }
}

// Singleton global accessible partout
final audio = AudioService();
