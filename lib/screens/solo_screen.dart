// lib/screens/solo_screen.dart
// Corrections freeze : showDialog simple + terrain9 inline sans modal

import 'dart:math' show sin, cos, Random;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/solo_controller.dart';
import '../services/display_settings.dart';
import 'rules_screen.dart';
import '../widgets/card_viewer.dart';
import '../services/persistence.dart';
import '../widgets/shine_effect.dart';
import '../services/audio_service.dart';
import '../services/engine.dart';
import '../widgets/theme.dart';
import '../widgets/token_widget.dart';
import '../widgets/player_status_widget.dart';
import '../widgets/reveal_screen.dart';
import '../widgets/ability_animations.dart';
import 'home_screen.dart';
import '../widgets/terrain_widget.dart';
import '../data/tokens_data.dart';
import '../data/characters_data.dart';
import '../data/interactions_data.dart';
import '../data/game_data.dart'; // cardImagePath, characterImagePath, terrainImagePath

// ─────────────────────────────────────────────
// SETUP
// ─────────────────────────────────────────────
class SoloSetupScreen extends StatefulWidget {
  final String playerName, playerTokenId;
  const SoloSetupScreen({super.key, required this.playerName, required this.playerTokenId});
  @override State<SoloSetupScreen> createState() => _SoloSetupState();
}

class _SoloSetupState extends State<SoloSetupScreen> with SingleTickerProviderStateMixin {
  AiDifficulty _diff = AiDifficulty.normal;
  String? _forcedCharId;               // null = aléatoire
  late TabController _tabs;
  bool _showCharPicker = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }
  @override void dispose() { _tabs.dispose(); super.dispose(); }

  List<CharacterCard> get _filteredChars {
    final tab = _tabs.index;
    return kAllCharacters.where((c) {
      if (tab == 0) return true;
      if (tab == 1) return c.faction == Faction.hunter;
      if (tab == 2) return c.faction == Faction.shadow;
      return c.faction == Faction.neutral;
    }).toList();
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      backgroundColor: kBg0,
      appBar: AppBar(backgroundColor: kBg2, elevation: 0,
        title: Text('Mode Solo', style: cinzel(16, c: kGold2))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Difficulté ────────────────────────────────────
          const SectionLabel('DIFFICULTÉ'),
          const SizedBox(height: 10),
          Row(children: [
            _DiffBtn(AiDifficulty.easy,   '😴 Facile',    _diff, (d) => setState(() => _diff = d)),
            const SizedBox(width: 8),
            _DiffBtn(AiDifficulty.normal, '⚔️ Normal',    _diff, (d) => setState(() => _diff = d)),
            const SizedBox(width: 8),
            _DiffBtn(AiDifficulty.hard,   '💀 Difficile', _diff, (d) => setState(() => _diff = d)),
          ]),

          const OrnamentDivider(),

          // ── Personnage ────────────────────────────────────
          const SectionLabel('TON PERSONNAGE'),
          const SizedBox(height: 10),

          // Carte sélectionnée
          GestureDetector(
            onTap: () => setState(() => _showCharPicker = !_showCharPicker),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _forcedCharId != null
                  ? factionBg(_charOf(_forcedCharId!)?.faction.name ?? '').withValues(alpha: 0.3)
                  : kBg2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _forcedCharId != null
                    ? factionColor(_charOf(_forcedCharId!)?.faction.name ?? '')
                    : kBord2,
                  width: _forcedCharId != null ? 2 : 1),
              ),
              child: Row(children: [
                // Miniature illustration
                if (_forcedCharId != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(width: 52, height: 52,
                      child: _charImg(_forcedCharId!) ?? Container(color: kBg3,
                        child: Center(child: Text(_charOf(_forcedCharId!)?.icon ?? '?',
                          style: const TextStyle(fontSize: 24))))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_charOf(_forcedCharId!)?.name ?? '', style: cinzel(14, c: kGold2, fw: FontWeight.w700)),
                    const SizedBox(height: 2),
                    _FactionBadgeSmall(_charOf(_forcedCharId!)?.faction.name ?? ''),
                    const SizedBox(height: 4),
                    Text(_charOf(_forcedCharId!)?.ability ?? '',
                      style: body(10, c: kTextSub), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ])),
                ] else ...[
                  const Text('🎲', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Aléatoire', style: cinzel(14, c: kText)),
                    Text('Rôle et personnage assignés au hasard', style: body(11, c: kTextSub)),
                  ])),
                ],
                Icon(_showCharPicker ? Icons.expand_less : Icons.expand_more, color: kGold),
              ]),
            ),
          ),

          if (_forcedCharId != null) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => setState(() { _forcedCharId = null; }),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.close, size: 14, color: kTextDim),
                const SizedBox(width: 4),
                Text('Repasser en aléatoire', style: body(11, c: kTextDim)),
              ]),
            ),
          ],

          // Picker de personnage
          if (_showCharPicker) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: kBg2, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBord)),
              child: Column(children: [
                TabBar(
                  controller: _tabs,
                  onTap: (_) => setState(() {}),
                  indicatorColor: kGold,
                  labelColor: kGold,
                  unselectedLabelColor: kTextSub,
                  labelStyle: const TextStyle(fontFamily: 'Cinzel', fontSize: 10),
                  tabs: const [
                    Tab(text: 'Tous'),
                    Tab(text: '🔵 Hunter'),
                    Tab(text: '🔴 Shadow'),
                  ],
                ),
                SizedBox(
                  height: 240,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4, childAspectRatio: 0.65,
                      crossAxisSpacing: 6, mainAxisSpacing: 6),
                    itemCount: _filteredChars.length,
                    itemBuilder: (_, i) {
                      final c = _filteredChars[i];
                      final sel = _forcedCharId == c.id;
                      final fc = factionColor(c.faction.name);
                      final img = _charImg(c.id);
                      return GestureDetector(
                        onTap: () => setState(() {
                          _forcedCharId = c.id;
                          _showCharPicker = false;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: sel ? fc.withValues(alpha: 0.15) : kBg3,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: sel ? fc : kBord, width: sel ? 2 : 1),
                            boxShadow: sel ? [BoxShadow(color: fc.withValues(alpha: 0.3), blurRadius: 6)] : null,
                          ),
                          child: Column(children: [
                            Expanded(child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                              child: img ?? Container(color: factionBg(c.faction.name),
                                child: Center(child: Text(c.icon,
                                  style: const TextStyle(fontSize: 22)))),
                            )),
                            Padding(
                              padding: const EdgeInsets.all(3),
                              child: Text(c.name,
                                style: cinzel(8, c: sel ? fc : kTextSub, fw: sel ? FontWeight.w700 : FontWeight.normal),
                                textAlign: TextAlign.center,
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ]),
            ),
          ],

          const OrnamentDivider(),

          // ── Composition ───────────────────────────────────
          Container(padding: const EdgeInsets.all(14), decoration: surfaceDecor(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionLabel('COMPOSITION (5 joueurs)'),
              const SizedBox(height: 8),
              _tokenRow(widget.playerTokenId, widget.playerName,
                _forcedCharId != null ? _charOf(_forcedCharId!)?.name ?? 'Choisi' : 'Rôle aléatoire'),
              _tokenRow('jason',  'Bot 1', 'Rôle aléatoire'),
              _tokenRow('carla',  'Bot 2', 'Rôle aléatoire'),
              _tokenRow('raph',   'Bot 3', 'Rôle aléatoire'),
              _tokenRow('marin',  'Bot 4', 'Rôle aléatoire'),
              const SizedBox(height: 6),
              Text('2 Hunters · 2 Shadows · 1 Neutre',
                style: body(12, c: kTextSub).copyWith(fontStyle: FontStyle.italic)),
            ])),

          const SizedBox(height: 24),
          BHButton(label: '⚔  Lancer la partie', onTap: _launch, gold: true),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  CharacterCard? _charOf(String id) =>
    kAllCharacters.where((c) => c.id == id).firstOrNull;

  Widget? _charImg(String id) {
    final path = effectiveCharacterImagePath(id);
    if (path == null) return null;
    return Image.asset(path, fit: BoxFit.cover, cacheWidth: 640,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => const SizedBox.shrink());
  }

  Widget _tokenRow(String tokenId, String name, String role) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      TokenWidget(tokenId: tokenId, size: 32),
      const SizedBox(width: 10),
      Expanded(child: Text(name, style: body(13, fw: FontWeight.w600))),
      Text(role, style: body(12, c: kTextSub)),
    ]),
  );

  void _launch() {
    final ctrl = SoloController(
      difficulty: _diff,
      humanName: widget.playerName,
      humanToken: widget.playerTokenId,
      forcedCharacterId: _forcedCharId,
      characterPool: null,
    );
    ctrl.startGame();
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(value: ctrl, child: const SoloGameScreen())));
  }
}

// ── Bouton difficulté compact ─────────────────────────────────────────────────
class _DiffBtn extends StatelessWidget {
  final AiDifficulty value, current;
  final String label;
  final void Function(AiDifficulty) onTap;
  const _DiffBtn(this.value, this.label, this.current, this.onTap);

  @override
  Widget build(BuildContext ctx) {
    final sel = value == current;
    return Expanded(child: GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: sel ? kGold.withValues(alpha: 0.12) : kBg2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? kGold2 : kBord2, width: sel ? 2 : 1)),
        child: Text(label, textAlign: TextAlign.center,
          style: cinzel(11, c: sel ? kGold2 : kTextSub)),
      ),
    ));
  }
}

// ── Badge faction petit ───────────────────────────────────────────────────────
class _FactionBadgeSmall extends StatelessWidget {
  final String faction;
  const _FactionBadgeSmall(this.faction);
  @override
  Widget build(BuildContext ctx) {
    final fc = factionColor(faction);
    final lbl = faction == 'hunter' ? '🔵 HUNTER'
        : faction == 'shadow' ? '🔴 SHADOW' : '🟡 NEUTRE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: fc.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(5)),
      child: Text(lbl, style: cinzel(8, c: fc)),
    );
  }
}



// ─────────────────────────────────────────────
// JEU SOLO
// ─────────────────────────────────────────────
class SoloGameScreen extends StatefulWidget {
  const SoloGameScreen({super.key});
  @override State<SoloGameScreen> createState() => _SoloGameScreenState();
}

class _SoloGameScreenState extends State<SoloGameScreen> {
  SoloController? _ctrl;

  @override
  void initState() {
    super.initState();
    // Couper la musique lobby → lancer la musique de partie
    audio.fadeOutMusic(ms: 400).then((_) => audio.playGameMusic());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Capturé ici (context encore valide) plutôt que dans dispose() — accéder
    // au Provider depuis dispose() peut échouer une fois le widget retiré.
    _ctrl ??= Provider.of<SoloController>(context, listen: false);
  }

  @override
  void dispose() {
    // Filet de sécurité garanti : dispose() se déclenche TOUJOURS quand cet
    // écran est retiré, peu importe comment (bouton retour, geste système,
    // navigation programmatique...). Sans stopController(), la boucle
    // asynchrone des bots continuait de tourner en arrière-plan (tours
    // suivants + leurs sons) jusqu'à atteindre le tour du joueur humain.
    _ctrl?.stopController();
    audio.stopAllSfx();
    audio.stopMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) => PopScope(
    canPop: false,
    onPopInvoked: (didPop) async {
      if (didPop) return;
      final confirmed = await showDialog<bool>(
        context: ctx,
        builder: (dctx) => AlertDialog(
          backgroundColor: kBg2,
          title: Text('Quitter la partie ?', style: cinzel(16, c: kGold2)),
          content: Text('Tu vas retourner au menu principal. La partie en cours sera perdue.',
            style: body(13)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx, false),
              child: Text('Annuler', style: cinzel(12, c: kTextSub))),
            TextButton(onPressed: () => Navigator.pop(dctx, true),
              child: Text('Quitter', style: cinzel(12, c: kRed))),
          ],
        ),
      );
      if (confirmed == true) {
        // Le bouton retour automatique de l'AppBar (ou le geste retour du
        // téléphone) ne passait par aucun nettoyage — sons ET musique de la
        // partie en cours continuaient de jouer en fond après être revenu au
        // menu (stopAllSfx() seul ne suffisait pas, la musique est séparée).
        audio.stopAllSfx();
        audio.stopMusic();
        if (ctx.mounted) Navigator.of(ctx).pop();
      }
    },
    child: Consumer<SoloController>(
    builder: (_, ctrl, __) {
      final s = ctrl.state;
      if (s == null) return const Scaffold(backgroundColor: kBg0,
        body: Center(child: CircularProgressIndicator(color: kGold)));
      if (s.isOver) return SoloGameOverScreen(ctrl: ctrl);
      if (s.phase == GamePhase.roleReveal) return _RoleRevealScreen(ctrl: ctrl);

      // ── Animation plein écran : révélation d'un joueur ──────────
      if (s.pendingRevealAnimation != null) {
        final rp = s.players.firstWhere(
          (p) => p.uid == s.pendingRevealAnimation,
          orElse: () => s.players.first);
        return RevealFullScreen(player: rp, allPlayers: s.players, onDone: () {
          ctrl.state!.pendingRevealAnimation = null;
          ctrl.notifyListeners();
        });
      }

      // ── Vision Suprême : révèle secrètement la carte d'un joueur ─
      if (s.privateRevealTargetUid != null) {
        final rp = s.players.firstWhere(
          (p) => p.uid == s.privateRevealTargetUid,
          orElse: () => s.players.first);
        return RevealFullScreen(player: rp, isRealReveal: false, onDone: () {
          ctrl.state!.privateRevealTargetUid = null;
          ctrl.notifyListeners();
        });
      }

      // ── Overlay de pouvoir (Art'Cade flammes, etc.) ──────────────
      final overlay = s.abilityOverlay;
      final baseScaffold = Scaffold(
        backgroundColor: kBg0,
        appBar: AppBar(
          backgroundColor: kBg2, elevation: 0,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.isHuman ? '⚔️ Ton tour' : '🤖 ${s.current.name} joue…',
              style: cinzel(15, c: s.isHuman ? kGold2 : kTextSub)),
            Text(s.phase.name, style: body(11, c: kTextSub)),
          ]),
          actions: [
            // Victor uniquement : bouton pour consulter ses barres de charme
            // — privées, jamais visibles par les autres joueurs.
            Builder(builder: (bctx) {
              final me2 = ctrl.state?.players.where((p) => !p.isBot).firstOrNull;
              if (me2?.character?.id != 'victor') return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(left: 4),
                child: TextButton(
                  onPressed: () => showVictorCharmPanel(ctx, me2!, ctrl.state!.players),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.pink.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('💘', style: TextStyle(fontSize: 15)),
                    const SizedBox(width: 4),
                    Text('Charme', style: cinzel(10, c: Colors.pinkAccent)),
                  ]),
                ),
              );
            }),
            const SizedBox(width: 4),
            IconButton(
              icon: const Text('⚙️', style: TextStyle(fontSize: 16)),
              tooltip: 'Réglages',
              onPressed: () => showDialog(context: ctx, builder: (_) => const SettingsDialog()),
            ),
            IconButton(
              icon: const Text('📜', style: TextStyle(fontSize: 18)),
              onPressed: () => _showLog(ctx, ctrl),
            ),
          ],
        ),
        body: _GameLayout(ctrl: ctrl, s: s),
      );

      // Pas d'overlay → retourner le scaffold simple
      if (overlay == null) return baseScaffold;

      // Overlay actif → Stack avec animation par-dessus le jeu
      return Stack(children: [
        baseScaffold,
        // Art'Cade: géré directement dans _MiniBoard sur la tuile
        if (overlay == 'oceane_notes')
          OceaneNotesOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null; ctrl.notifyListeners(); }),
        if (overlay == 'raph_petals')
          RaphPetalsOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null; ctrl.notifyListeners(); }),
        if (overlay == 'monkey_demon_eyes')
          MonkeyDemonEyesOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null; ctrl.notifyListeners(); }),
        if (overlay == 'gege_ghost')
          _GegeGhostOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null; ctrl.notifyListeners(); }),
        if (overlay == 'richard2_swap')
          _RichardSwapOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null; ctrl.notifyListeners(); }),
        if (overlay == 'scott_counter')
          _ScottCounterOverlay(dice: s.scottCounterDice, onDone: () {
            ctrl.state!.abilityOverlay = null; ctrl.notifyListeners(); }),
          _MathieuBulletOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null; ctrl.notifyListeners(); }),
        if (overlay == 'hongyi_dumbbell')
          HongYiDumbbellOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null; ctrl.notifyListeners(); }),
        if (overlay == 'vlad_mountain')
          VladMountainOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null; ctrl.notifyListeners(); }),
        if (overlay == 'travert_shockwave')
          TravertShockwaveOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null; ctrl.notifyListeners(); }),
        if (overlay == 'leo_flames_all')
          LeoFlamesAllOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null; ctrl.notifyListeners(); }),
        if (overlay == 'cambou_sheep')
          CambouSheepOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null; ctrl.notifyListeners(); }),
        if (overlay == 'carapatte_food')
          CarapatteFoodOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null; ctrl.notifyListeners(); }),
        if (overlay == 'augustin_wheat')
          AugustinWheatOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null; ctrl.notifyListeners(); }),
        if (overlay == 'fijacked_city')
          FijackedCityOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null; ctrl.notifyListeners(); }),
        if (overlay == 'louna_shield')
          LounaShieldOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null; ctrl.notifyListeners(); }),
        if (overlay == 'marion_plants')
          MarionPlantsOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null; ctrl.notifyListeners(); }),
        if (overlay == 'amelia_light')
          AmeliaLightOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
        if (overlay == 'albane_clock')
          AlbaneClockOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
        if (overlay == 'baleine_heal')
          BaleineHealOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
        if (overlay == 'christine_map')
          ChristineMapOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
        if (overlay == 'clemence_forge')
          ClemenceForgeOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
        if (overlay == 'elaia_vision')
          ElaiaVisionOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
        if (overlay == 'elise_light')
          EliseLightOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
        if (overlay == 'baptiste_revive')
          BaptisteReviveOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
        if (overlay == 'hailey_copy')
          HaileyCopyOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
        if (overlay == 'remi_craft')
          RemiCraftOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
        if (overlay == 'ines_lock')
          InesLockOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
        if (overlay == 'meg_offense')
          MegFormOverlay(isOffense: true, onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
        if (overlay == 'meg_defense')
          MegFormOverlay(isOffense: false, onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
        if (overlay == 'agathe_drain')
          AgatheDrainOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
        if (overlay == 'damien_alcohol')
          DamienServeOverlay(isPoison: false, onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
        if (overlay == 'damien_poison')
          DamienServeOverlay(isPoison: true, onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
        if (overlay == 'fifi_golden')
          FifiGoldenOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
        if (overlay == 'jeanne_mark')
          JeanneMarkOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
        if (overlay == 'julien_attack')
          JulienOverlay(isAttack: true, onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
        if (overlay == 'julien_heal')
          JulienOverlay(isAttack: false, onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
        if (overlay == 'luc_ignite')
          LucIgniteOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
        if (overlay == 'marin_dagger')
          MarinDaggerOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
        if (overlay == 'casino_win')
          CasinoResultOverlay(isWin: true, onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
        if (overlay == 'casino_lose')
          CasinoResultOverlay(isWin: false, onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
        if (overlay == 'nils_release')
          NilsReleaseOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
        if (overlay == 'ninja_shadow')
          NinjaShadowOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
        if (overlay == 'peio_terrain')
          PeioTerrainOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
        if (overlay == 'oscar_water')
          OscarElementOverlay(element: 'water', onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
        if (overlay == 'oscar_plant')
          OscarElementOverlay(element: 'plant', onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
        if (overlay == 'oscar_fire')
          OscarElementOverlay(element: 'fire', onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
        if (overlay == 'tommy_copy')
          TommyCopyOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
        if (overlay == 'tristan_swap')
          TristanSwapOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
        if (overlay == 'jeanne_reward')
          JeanneRewardOverlay(
            bannerText: ctrl.state!.jeanneRewardBanner ?? '',
            onDone: () {
              ctrl.state!.abilityOverlay = null;
              ctrl.state!.jeanneRewardBanner = null;
              ctrl.notifyListeners();
            }),
        if (overlay == 'maxence_drunk')
          MaxenceDrunkOverlay(onDone: () {
            ctrl.state!.abilityOverlay = null;
            ctrl.notifyListeners();
          }),
      ]);
    },
  ));

  // CORRECTION : showDialog simple, données copiées AVANT l'ouverture


  void _showDiceRef(BuildContext ctx) {
    showDialog(context: ctx, builder: (_) => Dialog(
      backgroundColor: kBg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('🎲 RÉFÉRENCE DES DÉS', style: cinzel(14, c: kGold, fw: FontWeight.w900)),
          const SizedBox(height: 16),
          Text('DÉPLACEMENT (D4 + D6)', style: cinzel(11, c: kGold2)),
          const SizedBox(height: 6),
          ...List.generate(4, (d4) => Row(children: [
            ...List.generate(6, (d6) {
              final sum = (d4+1) + (d6+1);
              return Container(width: 36, height: 32, margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: kBg3, borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: kGold.withValues(alpha: 0.3))),
                child: Center(child: Text('$sum', style: body(11, c: kGold2))));
            }),
          ])),
          const SizedBox(height: 6),
          Text('D4 : 1-4  ×  D6 : 1-6  → somme 2-10', style: body(10, c: kTextSub)),
          const Divider(height: 20, color: Colors.white12),
          Text('ATTAQUE |D4 − D6|', style: cinzel(11, c: kRed)),
          const SizedBox(height: 6),
          Wrap(spacing: 4, runSpacing: 4, children: [
            for (int d4 = 1; d4 <= 4; d4++)
              for (int d6 = 1; d6 <= 6; d6++)
                Container(width: 32, height: 28,
                  decoration: BoxDecoration(color: kBg3, borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: kRed.withValues(alpha: 0.4))),
                  child: Center(child: Text('${(d4-d6).abs()}', style: body(10, c: kRed)))),
          ]),
          const SizedBox(height: 6),
          Text('D4 : 1-4  ×  D6 : 1-6  → |D4−D6| = 0-5', style: body(10, c: kTextSub)),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('Fermer', style: body(13, c: kGold)))),
        ]),
      ),
    ));
  }

  void _showLog(BuildContext ctx, SoloController ctrl) {
    final logs = List<LogEntry>.from(ctrl.state?.log.reversed.take(50).toList() ?? []);
    showModalBottomSheet(
      context: ctx,
      backgroundColor: kBg2,
      builder: (_) => ListView(
        padding: const EdgeInsets.all(14),
        children: logs.map((l) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(l.message, style: TextStyle(fontSize: 12, color: switch (l.cls) {
            'death' => kRed, 'important' => kGold,
            'player' => kGreen, 'bot' => const Color(0xFFA07AF0), _ => kTextSub,
          })),
        )).toList(),
      ),
    );
  }
}  // end _SoloGameScreenState




// ═══════════════════════════════════════════════════════════
// CLÉMENCE — Pouvoir Constructeur
// ═══════════════════════════════════════════════════════════
class _ClemenceBuilderWidget extends StatelessWidget {
  final SoloController ctrl;
  final int step;
  final List<String> offered;
  final String? chosen;
  const _ClemenceBuilderWidget({
    required this.ctrl, required this.step,
    required this.offered, this.chosen});

  @override
  Widget build(BuildContext ctx) {
    final eg = GameEngine.instance;
    const purple = Color(0xFF9B59B6);
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0A2E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: purple, width: 2.5),
        boxShadow: [BoxShadow(color: purple.withValues(alpha: 0.35), blurRadius: 18)],
      ),
      child: Column(children: [
        Text('🎨 CLÉMENCE', style: cinzel(18, c: purple, fw: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(step == 1
          ? 'Choix 1/2 — Sélectionnez un effet'
          : 'Choix 2/2 — Sélectionnez un effet',
          style: body(11, c: kTextSub), textAlign: TextAlign.center),
        if (step == 2 && chosen != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: purple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8)),
            child: Text('✅ Effet 1 : ${eg.builderEffectLabel(chosen!)}',
              style: body(11, c: purple)),
          ),
        ],
        const SizedBox(height: 16),
        ...offered.map((eff) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: BHButton(
            label: eg.builderEffectLabel(eff),
            onTap: () => ctrl.clemenceChooseEffect(eff),
          ),
        )),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// JEANNE — Sélection récompense secrète
// ═══════════════════════════════════════════════════════════
class _JeanneRewardWidget extends StatelessWidget {
  final SoloController ctrl;
  final List<String> rewards;
  const _JeanneRewardWidget({required this.ctrl, required this.rewards});

  @override
  Widget build(BuildContext ctx) {
    final eg = GameEngine.instance;
    const ruby = Color(0xFFAA1144);
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0A2E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ruby, width: 2.5),
        boxShadow: [BoxShadow(color: ruby.withValues(alpha: 0.35), blurRadius: 18)],
      ),
      child: Column(children: [
        Text('🔮 JEANNE', style: cinzel(18, c: ruby, fw: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('Choisissez secrètement la récompense du tueur',
          style: body(11, c: kTextSub), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ...rewards.map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: BHButton(
            label: eg.jeanneRewardLabel(r),
            onTap: () => ctrl.jeanneChooseReward(r),
          ),
        )),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ELAIA — Étape 1 : choisir la pile à regarder
// ═══════════════════════════════════════════════════════════
class _ElaiaDeckChoiceWidget extends StatelessWidget {
  final SoloController ctrl;
  const _ElaiaDeckChoiceWidget({required this.ctrl});

  @override
  Widget build(BuildContext ctx) {
    const purple = Color(0xFF6A3FA0);
    final decks = [
      ('tenebres', '💀 Ténèbres', kTenebresBg),
      ('lumiere',  '✨ Lumière',  kLumiereBg),
      ('vision',   '🔮 Vision',   kVisionBg),
    ];
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kBg2, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: purple, width: 2.5),
        boxShadow: [BoxShadow(color: purple.withValues(alpha: 0.35), blurRadius: 18)],
      ),
      child: Column(children: [
        Text('🔮 ELAIA — PRESCIENCE', style: cinzel(16, c: purple, fw: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('Quelle pile veux-tu regarder ?',
          style: body(11, c: kTextSub), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ...decks.map((d) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: BHButton(label: d.$2, onTap: () => ctrl.elaiaChooseDeck(d.$1)),
        )),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ELAIA — Étape 2 : choisir l'ordre des 2 cartes regardées
// ═══════════════════════════════════════════════════════════
class _ElaiaOrderWidget extends StatelessWidget {
  final SoloController ctrl;
  final GameCard card1, card2;
  const _ElaiaOrderWidget({required this.ctrl, required this.card1, required this.card2});

  @override
  Widget build(BuildContext ctx) {
    const purple = Color(0xFF6A3FA0);
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kBg2, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: purple, width: 2.5),
        boxShadow: [BoxShadow(color: purple.withValues(alpha: 0.35), blurRadius: 18)],
      ),
      child: Column(children: [
        Text('🔮 ELAIA — ORDRE DE PIOCHE', style: cinzel(14, c: purple, fw: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('Choisis quelle carte sera piochée en premier',
          style: body(11, c: kTextSub), textAlign: TextAlign.center),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _elaiaCardPreview(card1)),
          const SizedBox(width: 8),
          Expanded(child: _elaiaCardPreview(card2)),
        ]),
        const SizedBox(height: 14),
        BHButton(label: '1️⃣ ${card1.name}  →  2️⃣ ${card2.name}', gold: true,
          onTap: () => ctrl.elaiaConfirmOrder(card1.id, card2.id)),
        const SizedBox(height: 8),
        BHButton(label: '1️⃣ ${card2.name}  →  2️⃣ ${card1.name}', gold: true,
          onTap: () => ctrl.elaiaConfirmOrder(card2.id, card1.id)),
      ]),
    );
  }

  Widget _elaiaCardPreview(GameCard c) {
    final dc = deckColor(c.deck.name);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kBg3, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dc.withValues(alpha: 0.6))),
      child: Column(children: [
        Text(deckIcon(c.deck.name), style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 6),
        Text(c.name, style: cinzel(11, c: kGold2, fw: FontWeight.w700),
          textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(c.text, style: body(9, c: kTextSub),
          textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// DAMIEN — Choix alcool fort / poison
// ═══════════════════════════════════════════════════════════
class _DamienChoiceWidget extends StatelessWidget {
  final SoloController ctrl;
  final Player target;
  const _DamienChoiceWidget({required this.ctrl, required this.target});

  @override
  Widget build(BuildContext ctx) {
    const wine = Color(0xFF8B0032);
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kBg2, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: wine, width: 2.5),
        boxShadow: [BoxShadow(color: wine.withValues(alpha: 0.35), blurRadius: 18)],
      ),
      child: Column(children: [
        Text('🍸 DAMIEN', style: cinzel(18, c: wine, fw: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('Que sers-tu à ${target.name} ?',
          style: body(12, c: kTextSub), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        BHButton(label: '🥃 Alcool fort — 4 dégâts instantanés',
          onTap: () => ctrl.damienServeAlcohol()),
        const SizedBox(height: 8),
        BHButton(label: '☠️ Poison — 3 dégâts × 2 tours (6 au total)',
          onTap: () => ctrl.damienServePoison()),
      ]),
    );
  }
}
// ═══════════════════════════════════════════════════════════
// BUTIN — récupérer un équipement d'un joueur éliminé
// ═══════════════════════════════════════════════════════════
class _LootChoiceWidget extends StatelessWidget {
  final SoloController ctrl;
  final Player dead;
  const _LootChoiceWidget({required this.ctrl, required this.dead});

  @override
  Widget build(BuildContext ctx) {
    const gold = Color(0xFFB8860B);
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kBg2, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: gold, width: 2.5),
        boxShadow: [BoxShadow(color: gold.withValues(alpha: 0.35), blurRadius: 18)],
      ),
      child: Column(children: [
        Text('🎒 BUTIN', style: cinzel(18, c: gold, fw: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('${dead.name} est éliminé — récupérer un équipement ?',
          style: body(12, c: kTextSub), textAlign: TextAlign.center),
        const SizedBox(height: 14),
        ...dead.equipment.asMap().entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: BHButton(label: '📦 ${e.value.name}',
            onTap: () => ctrl.lootChooseItem(e.key)),
        )),
        const SizedBox(height: 6),
        BHButton(label: 'Ne rien prendre', outlined: true, onTap: () => ctrl.lootSkip()),
      ]),
    );
  }
}
// ═══════════════════════════════════════════════════════════
// ─── Oscar : écran de choix Eau/Plante/Feu ───────────────────────────────
// ─── Baptiste : sélection du montant à sacrifier ─────────────────────────
class _BaptisteAmountWidget extends StatefulWidget {
  final SoloController ctrl;
  const _BaptisteAmountWidget({required this.ctrl});
  @override State<_BaptisteAmountWidget> createState() => _BaptisteAmountWidgetState();
}

class _BaptisteAmountWidgetState extends State<_BaptisteAmountWidget> {
  late int _amount;

  @override
  void initState() {
    super.initState();
    _amount = widget.ctrl.baptisteMaxSelfDmg.clamp(1, 999);
  }

  @override
  Widget build(BuildContext ctx) {
    final maxAmount = widget.ctrl.baptisteMaxSelfDmg;
    final p = widget.ctrl.state!.current;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: surfaceDecor(),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('✝️ Baptiste — Sacrifice', style: cinzel(15, c: kGold2), textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text('Tes PV restants : $maxAmount / ${p.wounds + maxAmount}',
          style: body(12, c: kTextSub), textAlign: TextAlign.center),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
            icon: const Icon(Icons.remove_circle, color: kRed),
            onPressed: _amount > 1 ? () => setState(() => _amount--) : null,
          ),
          Container(
            width: 70, alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: kBg3, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kGold, width: 2)),
            child: Text('$_amount', style: cinzel(22, c: kGold2, fw: FontWeight.w900)),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, color: kGreen),
            onPressed: _amount < maxAmount ? () => setState(() => _amount++) : null,
          ),
        ]),
        const SizedBox(height: 6),
        Text('Le joueur reviendra avec $_amount blessure${_amount > 1 ? "s" : ""}\nde moins que son maximum de vie',
          style: body(11, c: kTextDim), textAlign: TextAlign.center),
        const SizedBox(height: 14),
        BHButton(label: 'Confirmer le sacrifice', danger: true,
          onTap: () => widget.ctrl.humanBaptisteAmount(_amount)),
        const SizedBox(height: 8),
        BHButton(label: 'Annuler', outlined: true, onTap: () {
          widget.ctrl.state!.pendingTargetAction = null;
          widget.ctrl.state!.phase = GamePhase.ability;
          widget.ctrl.notifyListeners();
        }),
      ]),
    );
  }
}

class _OscarChoiceWidget extends StatelessWidget {
  final SoloController ctrl;
  const _OscarChoiceWidget({required this.ctrl});

  @override
  Widget build(BuildContext ctx) {
    final p = ctrl.state!.current;
    final xp = p.oscarXp;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: surfaceDecor(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('🧪 Oscar — Dépenser son XP', style: cinzel(15, c: kGold2), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text('XP actuelle : $xp', style: body(13, c: kGold), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        _OscarOption(icon: '💧', label: 'Eau', cost: 3, xp: xp,
          desc: 'Vole un équipement au joueur de ton choix',
          onTap: () {
            ctrl.state!.pendingTargetAction = 'oscar_water_target';
            ctrl.notifyListeners();
          }),
        const SizedBox(height: 8),
        _OscarOption(icon: '🌿', label: 'Plante', cost: 2, xp: xp,
          desc: 'Te soigne de 2 blessures',
          onTap: () => ctrl.humanOscarChoice('plant')),
        const SizedBox(height: 8),
        _OscarOption(icon: '🔥', label: 'Feu', cost: 4, xp: xp,
          desc: '+2 dégâts à ta prochaine attaque ce tour',
          onTap: () => ctrl.humanOscarChoice('fire')),
        const SizedBox(height: 10),
        BHButton(label: 'Ne rien dépenser', outlined: true, onTap: () {
          ctrl.state!.pendingTargetAction = null;
          ctrl.state!.phase = GamePhase.move;
          ctrl.notifyListeners();
        }),
      ]),
    );
  }
}

class _OscarOption extends StatelessWidget {
  final String icon, label, desc;
  final int cost, xp;
  final VoidCallback onTap;
  const _OscarOption({required this.icon, required this.label, required this.cost,
    required this.xp, required this.desc, required this.onTap});

  @override
  Widget build(BuildContext ctx) {
    final affordable = xp >= cost;
    return GestureDetector(
      onTap: affordable ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: affordable ? kBg3 : kBg2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: affordable ? kGold.withValues(alpha: 0.5) : kBord)),
        child: Row(children: [
          Text(icon, style: TextStyle(fontSize: 22, color: affordable ? null : kTextDim)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$label — ${cost}xp',
                style: cinzel(13, c: affordable ? kGold2 : kTextDim, fw: FontWeight.w700)),
              Text(desc, style: body(11, c: affordable ? kTextSub : kTextDim)),
            ]),
          ),
          if (!affordable) Icon(Icons.lock, size: 16, color: kTextDim),
        ]),
      ),
    );
  }
}

class _CasinoWidget extends StatefulWidget {
  final SoloController ctrl;
  const _CasinoWidget({required this.ctrl});
  @override State<_CasinoWidget> createState() => _CasinoWidgetState();
}

class _CasinoWidgetState extends State<_CasinoWidget>
    with SingleTickerProviderStateMixin {
  bool? _bet;       // null=pas choisi, true=impair, false=pair
  int?  _result;
  bool? _won;
  bool  _rolling = false;
  late AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1400));
  }
  @override void dispose() { _ac.dispose(); super.dispose(); }

  void _roll(bool betOdd) {
    if (_rolling) return;
    setState(() { _bet = betOdd; _result = null; _won = null; _rolling = true; });
    _ac.forward(from: 0).then((_) {
      final d = GameEngine.instance.rollD6();
      setState(() { _result = d; _won = betOdd == (d % 2 == 1); _rolling = false; });
    });
  }

  void _confirm() {
    if (_won == null) return;
    final s = widget.ctrl.state!;
    if (_won!) {
      s.pendingTargetAction = 'casino_win';
      s.phase = GamePhase.chooseTarget;
      widget.ctrl.notifyListeners();
    } else {
      widget.ctrl.applyDamageToHuman(2, reason: '🎰 Casino — pari perdu');
      s.pendingTargetAction = null;
      s.abilityOverlay = 'casino_lose';
      if (!s.current.alive) {
        // Il ne peut plus jouer son tour s'il vient de mourir — passer
        // immédiatement au joueur suivant au lieu de le laisser continuer
        // (se déplacer/attaquer) alors qu'il est mort.
        widget.ctrl.humanEndTurn();
      } else {
        s.phase = GamePhase.move; // peut encore se déplacer après
        widget.ctrl.notifyListeners();
      }
    }
  }

  @override
  Widget build(BuildContext ctx) {
    const gold = Color(0xFFFFD700);
    const dark = Color(0xFF1A0A2E);

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: gold, width: 2.5),
        boxShadow: [BoxShadow(color: gold.withValues(alpha: 0.35), blurRadius: 18)],
      ),
      child: Column(children: [
        Text('🎰 MR CASINO', style: cinzel(20, c: gold, fw: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('Gagnez → infligez 3 blessures   ·   Perdez → subissez 2',
          style: body(11, c: kTextSub), textAlign: TextAlign.center),
        const SizedBox(height: 20),

        // ── Étape 1: Choisir pair ou impair ──────────────────
        if (_bet == null) ...[
          Row(children: [
            Expanded(child: _BetButton(label: 'IMPAIR\n1 · 3 · 5',
              color: const Color(0xFF7B2FBE),
              onTap: () => _roll(true))),
            const SizedBox(width: 12),
            Expanded(child: _BetButton(label: 'PAIR\n2 · 4 · 6',
              color: const Color(0xFF1B6CA8),
              onTap: () => _roll(false))),
          ]),
        ],

        // ── Étape 2: Animation du dé ─────────────────────────
        if (_bet != null) ...[
          // Badge du pari
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: (_bet! ? const Color(0xFF7B2FBE) : const Color(0xFF1B6CA8))
                  .withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _bet! ? const Color(0xFF7B2FBE) : const Color(0xFF1B6CA8))),
            child: Text('Pari : ${_bet! ? "IMPAIR" : "PAIR"}',
              style: cinzel(13, c: gold, fw: FontWeight.w700)),
          ),
          const SizedBox(height: 16),

          // Dé animé façon D6
          AnimatedBuilder(
            animation: _ac,
            builder: (_, __) {
              final displayVal = _result ?? ((_ac.value * 12).floor() % 6 + 1);
              final done = _result != null;
              final faceColor = !done ? gold
                  : (_won! ? kGreen : kRed);
              return Column(children: [
                // Dé (carré avec coins arrondis)
                Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    color: faceColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: faceColor, width: 3),
                    boxShadow: [BoxShadow(
                        color: faceColor.withValues(alpha: 0.4),
                        blurRadius: 16)],
                  ),
                  child: Center(child: Text('$displayVal',
                    style: TextStyle(
                      fontSize: 44,
                      fontFamily: 'Cinzel',
                      fontWeight: FontWeight.w900,
                      color: faceColor))),
                ),
                const SizedBox(height: 10),
                if (_rolling)
                  Text('Lancement...', style: body(12, c: kTextSub))
                else if (done) ...[
                  Text(
                    displayVal % 2 == 1 ? 'IMPAIR' : 'PAIR',
                    style: cinzel(15, c: faceColor, fw: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(_won!
                      ? '🎉 Vous avez gagné !'
                      : '💔 Vous avez perdu…',
                    style: cinzel(14, c: faceColor, fw: FontWeight.w700)),
                ],
              ]);
            },
          ),
          const SizedBox(height: 16),

          // ── Étape 3: Résultat ────────────────────────────────
          if (_result != null) ...[
            if (_won!)
              Text('Choisissez un joueur pour lui infliger 3 blessures',
                style: body(12, c: kGreen), textAlign: TextAlign.center)
            else
              Text('Vous subissez 2 blessures', style: body(12, c: kRed),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            BHButton(
              label: _won! ? '🎯 Choisir une cible (3 blessures)' : '💀 Continuer',
              gold: _won!, danger: !_won!, onTap: _confirm),
          ],
        ],
      ]),
    );
  }
}

// Bouton de pari stylisé
class _BetButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _BetButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 2),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10)],
      ),
      child: Text(label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Cinzel', fontSize: 14,
          fontWeight: FontWeight.w900, color: color,
          height: 1.6)),
    ),
  );
}



// ═══════════════════════════════════════════════════
// FIFI — Sélecteur de dés style molette
// ═══════════════════════════════════════════════════
class _FifiDiceWidget extends StatefulWidget {
  final SoloController ctrl;
  const _FifiDiceWidget({required this.ctrl});
  @override State<_FifiDiceWidget> createState() => _FifiDiceState();
}

class _FifiDiceState extends State<_FifiDiceWidget> {
  int _move = 7;   // déplacement : 2-10
  int _atk  = 3;   // attaque     : 0-5

  @override
  Widget build(BuildContext ctx) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kBg2, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGreen, width: 2.5),
        boxShadow: [BoxShadow(color: kGreen.withValues(alpha: 0.3), blurRadius: 14)],
      ),
      child: Column(children: [
        Text('🍀 FIFI', style: cinzel(20, c: kGreen, fw: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('Choisissez vos valeurs pour ce tour',
          style: body(12, c: kTextSub), textAlign: TextAlign.center),
        const SizedBox(height: 20),

        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          // Déplacement
          _DiceSelector(
            label: '🚶 DÉPLACEMENT',
            value: _move,
            min: 2, max: 10,
            color: kGold2,
            onChanged: (v) => setState(() => _move = v),
          ),
          Container(width: 1, height: 120, color: kBord),
          // Attaque
          _DiceSelector(
            label: '⚔️ ATTAQUE',
            value: _atk,
            min: 0, max: 5,
            color: kRed,
            onChanged: (v) => setState(() => _atk = v),
          ),
        ]),

        const SizedBox(height: 20),
        BHButton(
          label: '✅ Confirmer — Dépl. $_move · Atk. $_atk',
          gold: true,
          onTap: () {
            final s = widget.ctrl.state!;
            s.fifiGoldenTurn = true;
            s.fifiMoveResult = _move;
            s.fifiAtkResult  = _atk;
            s.fifiMoveD4 = (_move / 2).ceil().clamp(1, 4);
            s.fifiMoveD6 = (_move - s.fifiMoveD4).clamp(1, 6);
            s.fifiAtkD4  = (_atk / 2).ceil().clamp(0, 4);
            s.fifiAtkD6  = (_atk - s.fifiAtkD4).clamp(0, 6);
            s.pendingTargetAction = null;
            s.phase = GamePhase.move;
            widget.ctrl.notifyListeners();
          },
        ),
      ]),
    );
  }
}

// Dé façon molette avec flèches haut/bas
class _DiceSelector extends StatelessWidget {
  final String label;
  final int value, min, max;
  final Color color;
  final void Function(int) onChanged;
  const _DiceSelector({
    required this.label, required this.value,
    required this.min, required this.max,
    required this.color, required this.onChanged,
  });

  @override
  Widget build(BuildContext ctx) {
    final canUp   = value < max;
    final canDown = value > min;
    return Column(children: [
      Text(label, style: cinzel(10, c: kTextSub), textAlign: TextAlign.center),
      const SizedBox(height: 10),
      // Flèche haut
      GestureDetector(
        onTap: canUp ? () => onChanged(value + 1) : null,
        child: Icon(Icons.keyboard_arrow_up_rounded,
          size: 32, color: canUp ? color : kBord2)),
      // Carré dé
      AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color, width: 2.5),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10)],
        ),
        child: Center(child: Text('$value',
          style: TextStyle(
            fontSize: 34, fontFamily: 'Cinzel',
            fontWeight: FontWeight.w900, color: color))),
      ),
      // Flèche bas
      GestureDetector(
        onTap: canDown ? () => onChanged(value - 1) : null,
        child: Icon(Icons.keyboard_arrow_down_rounded,
          size: 32, color: canDown ? color : kBord2)),
      const SizedBox(height: 4),
      Text('$min – $max', style: body(9, c: kTextDim)),
    ]);
  }
}


// ═══════════════════════════════════════════════════
// CAPTAIN RICARD — Compteur de sacrifice
// ═══════════════════════════════════════════════════
class _CaptainRicardWidget extends StatefulWidget {
  final SoloController ctrl;
  const _CaptainRicardWidget({required this.ctrl});
  @override State<_CaptainRicardWidget> createState() => _CaptainRicardState();
}

class _CaptainRicardState extends State<_CaptainRicardWidget> {
  int _sacrifice = 1;
  String? _targetUid;

  @override
  Widget build(BuildContext ctx) {
    final s = widget.ctrl.state!;
    final me = s.current;
    final maxSacrifice = (me.character!.hp - me.wounds - 1).clamp(1, 8);
    final targets = s.players.where((p) => p.alive && p.uid != me.uid).toList();

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBg2, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kGold, width: 2)),
      child: Column(children: [
        Text('🍾 CAPTAIN RICARD', style: cinzel(16, c: kGold2, fw: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('Sacrifiez des PV pour soigner un joueur', style: body(12, c: kTextSub)),
        const SizedBox(height: 16),
        // Compteur
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          GestureDetector(
            onTap: () => setState(() => _sacrifice = (_sacrifice - 1).clamp(1, maxSacrifice)),
            child: Container(width: 40, height: 40,
              decoration: BoxDecoration(color: kBg3, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kBord2)),
              child: const Center(child: Text('−', style: TextStyle(fontSize: 22, color: kRed))))),
          const SizedBox(width: 16),
          Column(children: [
            Text('$_sacrifice', style: cinzel(36, c: kRed, fw: FontWeight.w900)),
            Text('PV sacrifiés', style: body(10, c: kTextSub)),
          ]),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => setState(() => _sacrifice = (_sacrifice + 1).clamp(1, maxSacrifice)),
            child: Container(width: 40, height: 40,
              decoration: BoxDecoration(color: kBg3, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kBord2)),
              child: const Center(child: Text('+', style: TextStyle(fontSize: 22, color: kGreen))))),
        ]),
        const SizedBox(height: 6),
        Text('→ soigne $_sacrifice blessures', style: cinzel(14, c: kGreen)),
        const SizedBox(height: 16),
        // Cible
        Text('Choisissez qui soigner :', style: body(12, c: kTextSub)),
        const SizedBox(height: 8),
        ...targets.map((t) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: GestureDetector(
            onTap: () => setState(() => _targetUid = t.uid),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _targetUid == t.uid ? kGold.withValues(alpha: 0.12) : kBg3,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _targetUid == t.uid ? kGold : kBord2,
                  width: _targetUid == t.uid ? 2 : 1)),
              child: Row(children: [
                TokenWidget(tokenId: t.token, size: 28), const SizedBox(width: 8),
                Expanded(child: Text(t.name, style: body(13))),
                Text('🗡 ${t.wounds}', style: body(12, c: kTextSub)),
              ]),
            ),
          ),
        )),
        const SizedBox(height: 12),
        BHButton(
          label: _targetUid == null ? "🍾 Choisissez une cible d'abord" : '🍾 Sacrifier $_sacrifice PV → Soigner $_sacrifice',
          danger: _targetUid != null,
          onTap: _targetUid == null ? () {} : () {
            final target = s.players.firstWhere((p) => p.uid == _targetUid);
            widget.ctrl.state!.current.character; // access
            widget.ctrl.applyDamageToHuman(_sacrifice);
            widget.ctrl.healPlayer(_targetUid!, _sacrifice);
            widget.ctrl.state!.current.abilityUsed = true;
            widget.ctrl.logAbility('🍾 Captain Ricard sacrifie $_sacrifice PV → soigne ${target.name} de $_sacrifice');
            widget.ctrl.state!.pendingTargetAction = null;
            widget.ctrl.state!.phase = GamePhase.move;
            widget.ctrl.notifyListeners();
          },
        ),
        BHButton(label: 'Annuler', outlined: true, onTap: () {
          widget.ctrl.state!.pendingTargetAction = null;
          widget.ctrl.state!.phase = GamePhase.ability;
          widget.ctrl.notifyListeners();
        }),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ÉCRAN DE RÉVÉLATION DE RÔLE — s'affiche 5 secondes au démarrage
// ═══════════════════════════════════════════════════════════════════
class _RoleRevealScreen extends StatefulWidget {
  final SoloController ctrl;
  const _RoleRevealScreen({required this.ctrl});
  @override State<_RoleRevealScreen> createState() => _RoleRevealScreenState();
}

class _RoleRevealScreenState extends State<_RoleRevealScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgAc;
  late AnimationController _cardAc;
  late AnimationController _textAc;

  @override
  void initState() {
    super.initState();
    _bgAc   = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _cardAc = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _textAc = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

    // Séquence : bg → carte → texte
    _bgAc.forward().then((_) =>
      _cardAc.forward().then((_) =>
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) _textAc.forward();
        })
      )
    );
    // Auto-dismiss après 5 secondes
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) widget.ctrl.confirmRoleReveal();
    });
  }

  @override
  void dispose() { _bgAc.dispose(); _cardAc.dispose(); _textAc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    final s = widget.ctrl.state;
    if (s == null) return const SizedBox.shrink();
    final me = s.players.firstWhere((p) => !p.isBot, orElse: () => s.players.first);
    final char = me.character;
    if (char == null) return const SizedBox.shrink();

    final faction = char.faction.name;
    final fc  = factionColor(faction);
    final fbg = factionBg(faction);
    final imgPath = effectiveCharacterImagePath(char.id);

    final roleLabel = switch (faction) {
      'hunter'  => 'HUNTER',
      'shadow'  => 'SHADOW',
      'neutral' => 'NEUTRE',
      _         => faction.toUpperCase(),
    };
    final roleEmoji = switch (faction) {
      'hunter'  => '🔵', 'shadow' => '🔴', 'neutral' => '🟡', _ => '⚪',
    };

    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _bgAc, curve: Curves.easeIn),
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center, radius: 1.3,
              colors: [fbg, Colors.black.withValues(alpha: 0.97)],
            ),
          ),
          child: SafeArea(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [

              // ── Texte rôle ─────────────────────────────
              FadeTransition(
                opacity: CurvedAnimation(parent: _textAc, curve: Curves.easeIn),
                child: Column(children: [
                  Text('TU ES UN', style: cinzel(13, c: fc.withValues(alpha: 0.75), ls: 6)),
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(roleEmoji, style: const TextStyle(fontSize: 30)),
                    const SizedBox(width: 10),
                    Text(roleLabel, style: cinzel(44, c: fc, fw: FontWeight.w900).copyWith(
                      shadows: [Shadow(color: fc.withValues(alpha: 0.8), blurRadius: 24)])),
                    const SizedBox(width: 10),
                    Text(roleEmoji, style: const TextStyle(fontSize: 30)),
                  ]),
                  const SizedBox(height: 4),
                  Text(char.name, style: cinzel(20, c: kGold2, fw: FontWeight.w700)),
                ]),
              ),

              const SizedBox(height: 24),

              // ── Carte personnage ────────────────────────
              AnimatedBuilder(
                animation: _cardAc,
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, (1 - CurvedAnimation(parent: _cardAc, curve: Curves.easeOutBack).value) * 60),
                  child: Transform.scale(
                    scale: CurvedAnimation(parent: _cardAc, curve: Curves.easeOutBack).value.clamp(0.0, 1.0),
                    child: child,
                  ),
                ),
                child: Container(
                  width: 230,
                  decoration: BoxDecoration(
                    color: kBg2,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: fc, width: 3),
                    boxShadow: [
                      BoxShadow(color: fc.withValues(alpha: 0.5), blurRadius: 28, spreadRadius: 2),
                      const BoxShadow(color: Colors.black54, blurRadius: 10),
                    ],
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    // Illustration — carte ENTIÈRE (ratio 2:3)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 270,
                          child: AspectRatio(
                            aspectRatio: 2 / 3,
                            child: imgPath != null
                              ? Image.asset(imgPath, fit: BoxFit.cover,
                                  cacheWidth: 720, cacheHeight: 1080,
                                  errorBuilder: (_, __, ___) => Container(color: fbg,
                                    child: Center(child: Text(char.icon,
                                      style: const TextStyle(fontSize: 60)))))
                              : Container(color: fbg, child: Center(
                                  child: Text(char.icon, style: const TextStyle(fontSize: 60)))),
                          ),
                        ),
                      ),
                    ),
                    // Stats
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(char.name,
                            style: cinzel(15, c: kGold2, fw: FontWeight.w900),
                            overflow: TextOverflow.ellipsis)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: fc.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(color: fc.withValues(alpha: 0.6))),
                            child: Text('${char.hp} PV', style: cinzel(11, c: fc))),
                        ]),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity, padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: fbg.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(8)),
                          child: Text(char.ability,
                            style: body(10, c: kText), textAlign: TextAlign.center)),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity, padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: kBg3,
                            borderRadius: BorderRadius.circular(8)),
                          child: Column(children: [
                            Text('🏆 OBJECTIF', style: cinzel(8, c: kTextSub, ls: 1)),
                            const SizedBox(height: 3),
                            Text(char.winCondition,
                              style: body(10, c: kGold2),
                              textAlign: TextAlign.center),
                          ])),
                      ]),
                    ),
                  ]),
                ),
              ),

              const SizedBox(height: 20),

              // ── Bouton ──────────────────────────────────
              FadeTransition(
                opacity: CurvedAnimation(parent: _textAc, curve: Curves.easeIn),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: GestureDetector(
                    onTap: () => widget.ctrl.confirmRoleReveal(),
                    child: Container(
                      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: fc.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: fc, width: 2),
                        boxShadow: [BoxShadow(color: fc.withValues(alpha: 0.3), blurRadius: 12)]),
                      child: Text("J'ai compris — Commencer !",
                        textAlign: TextAlign.center,
                        style: cinzel(15, c: fc, fw: FontWeight.w700)),
                    ),
                  ),
                ),
              ),

            ]),
          ),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────
// LAYOUT PC — tout visible sur 1 écran
// Gauche : plateau + classement
// Droite : actions + log
// ─────────────────────────────────────────────
class _GameLayout extends StatelessWidget {
  final SoloController ctrl;
  final SoloState s;
  const _GameLayout({required this.ctrl, required this.s});

  @override
  Widget build(BuildContext ctx) {
    return LayoutBuilder(builder: (ctx, bc) {
      final w = bc.maxWidth;
      final h = bc.maxHeight;
      final isWide = !DisplaySettings.instance.isMobileFor(w);

      if (isWide) {
        // ── Layout PC : 3 zones ──────────────────────────────────
        // GAUCHE : plateau + leaderboard
        // DROITE : carte perso (colonne) + actions (colonne)
        final leftW  = (w * 0.45).clamp(260.0, 460.0);
        final rightW = w - leftW - 1;

        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

          // ── Gauche : plateau + classement ────────────────────
          SizedBox(width: leftW, child: Column(children: [
            SizedBox(height: (h * 0.17).clamp(95, 125),
              child: _HpLeaderboard(ctrl: ctrl)),
            Expanded(child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 4, 8),
              child: _MiniBoard(ctrl: ctrl),
            )),
          ])),

          Container(width: 1, color: kBord),

          // ── Droite : header + actions + log ─────────────────
          SizedBox(width: rightW, child: Column(children: [
            _TurnHeader(ctrl: ctrl, s: s),
            Expanded(child: _ActionColumn(ctrl: ctrl, s: s)),
            SizedBox(height: (h * 0.18).clamp(60, 110),
              child: _LogStrip(ctrl: ctrl)),
          ])),

        ]);

      } else {
        // ── Layout mobile : colonne ─────────────────────────────
        return Column(children: [
          SizedBox(height: (h * 0.16).clamp(100, 130),
            child: _HpLeaderboard(ctrl: ctrl)),
          SizedBox(height: (h * 0.38).clamp(130, 280),
            child: _MiniBoard(ctrl: ctrl)),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: _ActionColumn(ctrl: ctrl, s: s),
          )),
          SizedBox(height: (h * 0.09).clamp(44, 60),
            child: _LogStrip(ctrl: ctrl)),
        ]);
      }
    });
  }
}

// Header de tour (colonne droite PC)
class _TurnHeader extends StatelessWidget {
  final SoloController ctrl;
  final SoloState s;
  const _TurnHeader({required this.ctrl, required this.s});

  @override
  Widget build(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kBg2,
        border: Border(bottom: BorderSide(color: kBord)),
      ),
      child: Row(children: [
        TokenWidget(tokenId: s.current.token, size: 30),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            s.isHuman ? '⚔️ Ton tour' : '🤖 Tour de ${s.current.name}',
            style: cinzel(12, c: s.isHuman ? kGold2 : kTextSub),
          ),
          Text(_phaseLabel(s.phase), style: body(10, c: kTextDim)),
        ])),

      ]),
    );
  }

  String _phaseLabel(GamePhase p) => switch (p.name) {
    'ability'      => 'Phase : Capacité',
    'move'         => 'Phase : Déplacement',
    'zoneEffect'   => 'Phase : Effet terrain',
    'cardDrawn'    => 'Phase : Carte piochée',
    'attack'       => 'Phase : Attaque',
    _              => p.name,
  };
}


class _ActionColumn extends StatelessWidget {
  final SoloController ctrl;
  final SoloState s;
  const _ActionColumn({required this.ctrl, required this.s});

  @override
  Widget build(BuildContext ctx) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 300),
    transitionBuilder: (child, anim) => FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
          .animate(anim),
        child: child)),
    child: KeyedSubtree(
      key: ValueKey(s.phase.name + (s.isHuman ? 'h' : 'b')),
      child: s.isHuman && !s.botThinking
        ? _SoloActionPanel(ctrl: ctrl)
        : _BotPanel(ctrl: ctrl),
    ),
  );
}


// ─── Carte personnage joueur (colonne gauche du panel droit) ──────────────────
class _PlayerCardSide extends StatelessWidget {
  final SoloController ctrl;
  const _PlayerCardSide({required this.ctrl});

  @override
  Widget build(BuildContext ctx) {
    final s = ctrl.state!;
    final me = s.players.firstWhere((p) => !p.isBot, orElse: () => s.players.first);
    final c = me.character;
    if (c == null) return const SizedBox.shrink();

    final fc  = factionColor(c.faction.name);
    final fbg = factionBg(c.faction.name);
    final img = effectiveCharacterImagePath(c.id);
    final woundColor = me.wounds >= 10 ? kRed : me.wounds >= 6 ? kGold : kGreen;

    return Container(
      color: kBg1,
      child: Column(children: [
        // Illustration
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              border: me.revealed ? Border.all(color: fc, width: 2) : null,
            ),
            child: img != null
              ? SmoothAssetImage(img, fit: BoxFit.cover, width: double.infinity, height: double.infinity,
                  cacheWidth: 640,
                  placeholderColor: fbg,
                  placeholderIcon: c.icon,
                  errorBuilder: (_, __, ___) => _fallback(c, fbg))
              : _fallback(c, fbg),
          ),
        ),
        // Infos compactes
        Container(
          width: double.infinity,
          color: kBg2,
          padding: const EdgeInsets.all(8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Nom + faction
            Text(c.name, style: cinzel(11, c: fc, fw: FontWeight.w900),
              overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: fc.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4)),
                child: Text(
                  c.faction.name == 'hunter' ? '🔵 HUNTER'
                  : c.faction.name == 'shadow' ? '🔴 SHADOW' : '🟡 NEUTRE',
                  style: cinzel(7, c: fc)),
              ),
            ]),
            const SizedBox(height: 6),
            // Blessures
            Row(children: [
              Text('🗡', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text('${me.wounds} blessures',
                style: body(11, c: woundColor, fw: FontWeight.w700)),
            ]),
            const SizedBox(height: 6),
            // Objectif
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: kBg3, borderRadius: BorderRadius.circular(6)),
              child: Column(children: [
                Text('🏆 OBJECTIF', style: cinzel(7, c: kTextSub, ls: 1)),
                const SizedBox(height: 2),
                Text(c.winCondition, style: body(9, c: kGold2),
                  textAlign: TextAlign.center, maxLines: 3,
                  overflow: TextOverflow.ellipsis),
              ]),
            ),
            // Équipements
            if (me.equipment.isNotEmpty) ...[
              const SizedBox(height: 4),
              ...me.equipment.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('⚙️ ${e.name}', style: body(9, c: kTextSub),
                  overflow: TextOverflow.ellipsis),
              )),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _fallback(CharacterCard c, Color fbg) => Container(
    color: fbg,
    child: Center(child: Text(c.icon, style: const TextStyle(fontSize: 48))));
}

// ─────────────────────────────────────────────
// CLASSEMENT BLESSURES (PV max cachés)
// ─────────────────────────────────────────────
class _HpLeaderboard extends StatelessWidget {
  final SoloController ctrl;
  const _HpLeaderboard({required this.ctrl});

  @override
  Widget build(BuildContext ctx) {
    final s = ctrl.state!;
    // Trie par blessures croissantes (moins blessé = en tête)
    final players = List<Player>.from(s.players);
    players.sort((a, b) {
      if (!a.alive && b.alive) return 1;
      if (a.alive && !b.alive) return -1;
      return a.wounds.compareTo(b.wounds);
    });

    // Maxence : si LE JOUEUR HUMAIN (celui qui regarde cet écran) est
    // ivre, sa vision de tout le monde est brouillée — jetons, camps/
    // cartes et blessures. Reste null (pas d'effet) tant qu'il n'est pas
    // rendu ivre.
    final humanViewer = s.players.where((pp) => !pp.isBot).firstOrNull;
    final drunkVision = DrunkVision.forViewer(humanViewer);

    return Container(
      color: kBg1,
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('🗡 BLESSURES', style: cinzel(8, c: kGold, ls: 2)),
        const SizedBox(height: 3),
        Expanded(
          child: Row(children: players.map((p) {
            // Victor : cœur visible UNIQUEMENT si c'est LUI (le joueur
            // humain) qui a charmé CE joueur à 100% — reste privé pour
            // n'importe qui d'autre, y compris pour la cible elle-même.
            final victorMe = s.players.where((pp) =>
                !pp.isBot && pp.character?.id == 'victor').firstOrNull;
            final maxed = victorMe != null && (victorMe.charmLevels[p.uid] ?? 0) >= 100;
            return Expanded(
              child: PlayerStatusCard(
                player: p,
                isCurrent: s.players.indexOf(p) == s.currentIdx,
                isMe: !p.isBot,
                isFlashing: s.woundFlashUid == p.uid,
                isMarked: s.markedPlayerUid == p.uid,
                victorCharmMaxed: maxed,
                drunkVision: drunkVision,
                onTap: (target) { _showOpponentCard(ctx, target, isMe: !target.isBot); },
              ),
            );
          }).toList()),
        ),
      ]),
    );
  }

  void _showOpponentCard(BuildContext ctx, Player p, {bool isMe = false}) {
    final c = p.character;
    // Jason (Caméléon) : affiche le déguisement (Hunter/Shadow imité) tant
    // qu'il est VIVANT — mort, il révèle sa vraie identité comme tout le
    // monde (convention "les cartes se retournent à la mort"). Pour SOI-MÊME,
    // on affiche toujours sa vraie carte, jamais un déguisement.
    final displayChar = (!isMe && p.alive && p.disguiseCharIdOverride != null)
        ? kAllCharacters.where((ch) => ch.id == p.disguiseCharIdOverride).firstOrNull ?? c
        : c;
    final isNils = (p.copiedEffect ?? c?.abilityEffect) == 'store_damage_nils';
    // Vision Suprême : connaissance privée permanente — le joueur qui a
    // découvert secrètement cette identité peut la reconsulter à tout
    // moment ensuite, comme s'il était révélé, mais seulement pour lui.
    final myUid = ctrl.state?.players.where((pp) => !pp.isBot).firstOrNull?.uid;
    final knowsPrivately = myUid != null && p.privatelyKnownBy.contains(myUid);
    // Un joueur MORT révèle toujours son vrai rôle en cliquant sur son
    // jeton — même s'il n'avait jamais été révélé de son vivant (convention
    // "les cartes se retournent à la mort", comme sur un vrai plateau).
    // Pour SOI-MÊME : toujours la vraie carte, peu importe la révélation.
    if ((isMe || p.revealed || !p.alive || knowsPrivately) && displayChar != null) {
      final maximeTarget = (isMe && displayChar.id == 'maxime' && p.maximeFirstAttackerUid != null)
          ? ctrl.state?.players.where((pp) => pp.uid == p.maximeFirstAttackerUid).firstOrNull
          : null;
      showFullCardDialog(ctx, displayChar, hpOverride: displayChar.hp + p.maxHpModifier,
        oscarXpOverride: displayChar.id == 'oscar' ? p.oscarXp : null,
        maximeTargetName: (isMe && displayChar.id == 'maxime')
          ? (maximeTarget?.name ?? 'Personne pour le moment') : null,
        megFormOverride: displayChar.abilityEffect == 'meg_shapeshift' ? p.megForm : null).then((_) {
        if ((p.equipment.isNotEmpty || isNils) && ctx.mounted) _showEquipmentForSolo(ctx, p);
      });
    } else {
      // Pas révélé (et encore en vie) : carte "mystère" (silhouette +
      // réplique cryptique), mais l'équipement reste visible — info
      // publique quel que soit le statut de révélation.
      showMysteryCardDialog(ctx, p).then((_) {
        if ((p.equipment.isNotEmpty || isNils) && ctx.mounted) _showEquipmentForSolo(ctx, p);
      });
    }
  }

  /// Équipement — info publique, affichée quel que soit le statut de
  /// révélation du joueur (contrairement à la carte de personnage).
  void _showEquipmentForSolo(BuildContext ctx, Player p) {
    final items = p.equipment;
    final isNils = (p.copiedEffect ?? p.character?.abilityEffect) == 'store_damage_nils';
    showDialog(context: ctx, builder: (_) => Dialog(
      backgroundColor: kBg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 520),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Text('🎒', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(child: Text('ÉQUIPEMENTS — ${p.name.toUpperCase()}',
              style: cinzel(13, c: kGold2, fw: FontWeight.w900),
              overflow: TextOverflow.ellipsis)),
          ]),
          if (isNils) ...[
            const SizedBox(height: 12),
            // Compteur public — visible de tous, révélé ou non, comme
            // demandé : "blessures stockées" par Nils.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: kRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kRed.withValues(alpha: 0.5)),
              ),
              child: Text('📦 Blessures stockées : ${p.storedDamage}',
                style: cinzel(13, c: kRed, fw: FontWeight.w800),
                textAlign: TextAlign.center),
            ),
          ],
          const SizedBox(height: 14),
          if (items.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('Aucun équipement pour ce joueur.',
                style: body(12, c: kTextSub), textAlign: TextAlign.center))
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final eq = items[i];
                  final dc = deckColor(eq.deck.name);
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kBg3, borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: dc.withValues(alpha: 0.5))),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(deckIcon(eq.deck.name), style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(eq.name, style: cinzel(12, c: kGold2, fw: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(eq.text, style: body(11, c: kTextSub)),
                      ])),
                    ]),
                  );
                },
              ),
            ),
          const SizedBox(height: 14),
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('Fermer', style: cinzel(12, c: kTextSub))),
        ]),
      ),
    ));
  }
}


// ─────────────────────────────────────────────
// PLATEAU AVEC IMAGES ET ADJACENCES
// ─────────────────────────────────────────────
class _MiniBoard extends StatelessWidget {
  final SoloController ctrl;
  const _MiniBoard({required this.ctrl});

  @override
  Widget build(BuildContext ctx) {
    final s = ctrl.state!;
    final human = s.players.firstWhere((p) => !p.isBot, orElse: () => s.current);
    final humanZone = human.zoneIndex;

    final playerData = s.players.where((p) => p.alive).map((p) => {
      'zoneIndex': p.zoneIndex,
      'tokenId': p.token,
      'alive': p.alive,
      'revealed': p.revealed,
      'faction': p.disguiseFactionOverride ?? p.character?.faction.name ?? '',
    }).toList();

    return Container(
      color: kBg1,
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
      child: Column(children: [
        Expanded(
          child: LayoutBuilder(builder: (ctx, bc) {
            // Position de la tuile zone6 dans la grille 3×2
            final zone6idx = s.terrainLayout.indexWhere((t) => t.effect == 'lumiere');
            final idx = zone6idx < 0 ? 4 : zone6idx;
            const gap = 4.0; const cols = 3; const rows = 2;
            final tileW = (bc.maxWidth  - gap * (cols - 1)) / cols;
            final tileH = (bc.maxHeight - gap * (rows - 1)) / rows;
            final col = idx % cols; final row = idx ~/ cols;
            final tx = col * (tileW + gap);
            final ty = row * (tileH + gap);

            return Stack(children: [
              GameBoard(
                terrainLayout: s.terrainLayout,
                players: playerData,
                humanZoneIndex: humanZone,
                showAdjacent: true,
                trappedZones: {
                  for (final e in s.trappedZones.entries)
                    e.key: switch(e.value) {
                      '2'            => '🦞',
                      'freeze'       => '🥷',
                      'ability_block'=> '🏕️',
                      _              => '⚠️',
                    }
                },
              ),
              // Flammes Art'Cade sur la tuile Chapelle Sacrée
              if (s.abilityOverlay == 'artcade_flames')
                Positioned(
                  left: tx, top: ty, width: tileW, height: tileH,
                  child: ArtcadeFlameOverlay(onDone: () {
                    ctrl.state!.abilityOverlay = null;
                    ctrl.notifyListeners();
                  }),
                ),
            ]);
          }),
        ),
        const SizedBox(height: 2),
        const AdjacencyLegend(),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// BOT PANEL
// ─────────────────────────────────────────────
class _BotPanel extends StatelessWidget {
  final SoloController ctrl;
  const _BotPanel({required this.ctrl});

  @override
  Widget build(BuildContext ctx) {
    final s = ctrl.state!;
    final last = s.log.isNotEmpty ? s.log.last.message : '';
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 10),
      TokenWidget(tokenId: s.current.token, size: 48),
      const SizedBox(height: 4),
      Text('${s.current.name} réfléchit…', style: cinzel(13, c: kTextSub)),
      const SizedBox(height: 12),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: LinearProgressIndicator(backgroundColor: kBord2, color: kGold, minHeight: 4),
      ),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(last, style: body(12, c: kTextSub),
          textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
      // Vision = secret total, Lumière/Ténèbres = visible
      if (ctrl.state!.pendingCard != null && !ctrl.state!.pendingCardIsSecret)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _CardWidget(card: ctrl.state!.pendingCard!),
        )
      else if (ctrl.state!.pendingCard != null && ctrl.state!.pendingCardIsSecret)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A0A2E).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.purple.shade400, width: 1.5)),
            child: Row(children: [
              const Text('🔮', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(child: Text(
                '${ctrl.state!.current.name} a pioché une carte Vision secrète.',
                style: body(12, c: Colors.purple.shade200))),
            ]),
          ),
        ),
    ]);
  }
}

// ─────────────────────────────────────────────
// PANEL D'ACTION HUMAIN
// CORRECTION principale : terrain9 géré INLINE sans modal
// ─────────────────────────────────────────────
class _SoloActionPanel extends StatefulWidget {
  final SoloController ctrl;
  const _SoloActionPanel({required this.ctrl});
  @override State<_SoloActionPanel> createState() => _SoloActionPanelState();
}

class _SoloActionPanelState extends State<_SoloActionPanel> {
  int? _d4, _d6, _sum;
  int? _d4b, _d6b, _sum2; // Albane: second roll
  bool _albaneChose = false; // true = lancer choisi, afficher zones si sum==7
  int? _atkD4, _atkD6, _atkDmg;
  int? _atkD4b, _atkD6b; // Mango Loco : 2ème lancer si cible costaude (13+ PV)
  String? _atkTarget;
  // Pour terrain9 et steal : on montre les cibles inline
  bool _showingTargetList = false;
  String? _targetContext; // 'terrain_damage9' | 'terrain_steal' | 'card' | 'ability'

  SoloController get ctrl => widget.ctrl;
  SoloState get s => ctrl.state!;

  @override
  Widget build(BuildContext ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
    Text(_phaseLabel(), style: cinzel(11, c: kGold, ls: 2)),
    const SizedBox(height: 10),
    ..._buildActions(ctx),
  ]);

  String _phaseLabel() => switch (s.phase.name) {
    'ability'      => 'Capacité unique',
    'move'         => 'Déplacement',
    'zoneEffect'   => 'Effet du terrain',
    'cardChoice'   => 'Choisir un deck',
    'cardDrawn'    => 'Carte piochée',
    'chooseTarget' => 'Choisir une cible',
    'attack'       => 'Attaque',
    _              => s.phase.name,
  };

  List<Widget> _buildActions(BuildContext ctx) {
    final me = s.current;

    // ── Butin : récupérer l'équipement d'un joueur qu'on vient d'éliminer ──
    // (file d'attente — plusieurs morts simultanées, ex: bazooka, passent
    // une par une sans que la 2ème n'écrase la 1ère)
    if (s.lootKillerUid != null && s.lootDeadQueue.isNotEmpty) {
      final dead = s.players.where((p) => p.uid == s.lootDeadQueue.first).firstOrNull;
      if (dead != null && dead.equipment.isNotEmpty) {
        return [_LootChoiceWidget(ctrl: ctrl, dead: dead)];
      } else {
        // plus rien à récupérer pour ce mort — passer au suivant silencieusement
        ctrl.lootSkip();
      }
    }
    // ── Choix de passif (Luc / Peintre) ──────────────────────
    // ── Animation dé de pouvoir ──────────────────────────────
    if (s.abilityDiceResult != null) {
      return [_AbilityDiceRoll(
        ctrl: ctrl,
        result: Map<String,int>.from(s.abilityDiceResult!),
      )];
    }
    if (s.pendingTargetAction == 'choose_passive') {
      return _buildPassiveChoice(ctx);
    }
    // ── Choix Inès ────────────────────────────────────────────
    if (s.pendingTargetAction == 'ines_choose') {
      return _buildInesChoice(ctx);
    }
    // ── Mr Casino: pari pair/impair ───────────────────────────
    if (s.pendingTargetAction == 'casino_bet') {
      return [_CasinoWidget(ctrl: ctrl)];
    }
    // ── Fifi: molette dés ─────────────────────────────────────
    if (s.pendingTargetAction == 'fifi_dice_picker') {
      return [_FifiDiceWidget(ctrl: ctrl)];
    }
    // ── Captain Ricard: compteur sacrifice ───────────────────
    if (s.pendingTargetAction == 'captain_ricard_counter') {
      return [_CaptainRicardWidget(ctrl: ctrl)];
    }
    // ── Si on attend une cible via ability ──────────────────
    // Ces pouvoirs ont besoin de choisir une cible → afficher liste directement
    final abilityTargetActions = {
      'ability_vladimir', 'ability_hong_yi', 'ability_travert',
      'ability_carapatte', 'ability_elaia', 'casino_win',
      'ability_julien', 'ability_jazzon', 'ability_marin_shadow',
      'ability_enceinte', 'ability_ingenieur', 'terrain_damage9',
      'ability_set5', 'ability_raph_heal', 'ability_tristan', 'ability_marin',
      'ability_damien',
      'ability_tommy',
      'ability_oceane', 'ability_nils', 'ability_agathe',
      'corne_des_woods_victim', 'corne_des_woods', 'creation_marin', 'heal_other_d4',
      'clemence_target', 'jeanne_mark_target', 'equip_choice',
      'swap_zone_pick1', 'swap_zone_pick2', 'jeanne_mark_target', 'christine_zone_pick',
      'tristan_give_choice', 'tristan_receive_choice',
    };
    if (abilityTargetActions.contains(s.pendingTargetAction)) {
      return _buildInlineTargetList(ctx);
    }
    // ── Si on attend une cible (inline, sans modal) ──────────
    if (_showingTargetList) {
      return _buildInlineTargetList(ctx);
    }

    switch (s.phase) {
      // ── CAPACITÉ ──────────────────────────────────────────
      case GamePhase.ability:
        // Clémence : afficher le widget de construction si le builder est actif
        if (s.builderStep > 0 && s.builderStep < 3) {
          return [_ClemenceBuilderWidget(ctrl: ctrl, step: s.builderStep,
            offered: s.builderOffered, chosen: s.builderEffect1)];
        }
        // Jeanne étape 2 : choisir la récompense secrète
        if (s.jeanneStep == 2 && s.builderOffered.isNotEmpty) {
          return [_JeanneRewardWidget(ctrl: ctrl, rewards: s.builderOffered)];
        }
        // Elaia étape 1 : choisir la pile à regarder
        if (s.elaiaStep == 1) {
          return [_ElaiaDeckChoiceWidget(ctrl: ctrl)];
        }
        // Elaia étape 2 : choisir l'ordre de pioche des 2 cartes regardées
        if (s.elaiaStep == 2 && s.elaiaCard1Id != null && s.elaiaCard2Id != null) {
          return [_ElaiaOrderWidget(ctrl: ctrl,
            card1: findCardById(s.elaiaCard1Id!)!,
            card2: findCardById(s.elaiaCard2Id!)!)];
        }
        // Damien : cible choisie — choisir alcool fort ou poison
        if (s.damienTargetUid != null) {
          final damienTarget = s.players.where((x) => x.uid == s.damienTargetUid).firstOrNull;
          if (damienTarget != null) {
            return [_DamienChoiceWidget(ctrl: ctrl, target: damienTarget)];
          }
        }
        final c = me.character!;
        // Tommy : si un pouvoir est copié, afficher SA description et SA répétabilité
        final effChar = me.copiedEffect != null
            ? kAllCharacters.where((ch) => ch.abilityEffect == me.copiedEffect).firstOrNull ?? c
            : c;
        final freq = effChar.abilityRepeatable ? '🔄 Chaque tour' : '🔒 1 fois par partie';
        // Passifs auto-activés (pas besoin d'appuyer)
        final autoPassives = {'heal2_same_hunter','heal_per_equip_eot',
          'last_hunter_buff','no_attack_buff','heal_on_same_terrain','death_heal_allies',
          'lumiere_copy','heal_hunter_on_attack','scott_passive','gege_passive','baleine_passive',
          'reroll_d6_attack', 'felipe_passive',
          'fifi_ete_passive','allied_invulnerable','infinite_range','revealed_plus1_dmg',
          'tenebres_heal_instead','attack_discard_equip','rat_passive','reduce_all_by1',
          'zero_wound_steal','slime_passive','heal1_on_own_attack','remi_canada_passive',
          'mathieu_passive','third_attack_bonus','counter_roll_cancel','draw_on_hit_dual_target',
          'chameleon_passive','counter_attack_passive','zero_wound_power','builder_power',
          'prophete_mark','double_attack_if_tanky','fanny_none','victor_charm','maxime_double_first','bob_resurrect','maxence_selfharm_boost','tom_shadow_kill_boost'};
        final isAutoPassive = me.revealed && autoPassives.contains(me.copiedEffect ?? c.abilityEffect);
        return [
          // Indicateurs d'état spéciaux Shadow
          if (s.fifiGoldenTurn)
            _StatusBanner('🍀 Tour parfait actif — dés au maximum !', kGreen),
          if (s.raphShadowMultiAtk)
            _StatusBanner('⚔️ Mode multi-attaque actif (subis autant que tu infliges)', kRed),
          if (s.ninjaExtraTurns > 0)
            _StatusBanner('🥷 ${s.ninjaExtraTurns} tours bonus restants', kGold),
          if (s.fifiGoldenTurn)
            _StatusBanner('🍀 Tour parfait actif — choisissez vos dés !', kGreen),
          // Jeanne : rappel visible de tous — qui est marqué
          if (s.markedPlayerUid != null)
            _StatusBanner(
              '🔮 Joueur marqué : ${s.players.where((p) => p.uid == s.markedPlayerUid).firstOrNull?.name ?? "?"}',
              kRed),
          // Passif auto
          if (isAutoPassive)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: kGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kGreen.withValues(alpha: 0.4))),
              child: Row(children: [
                const Text('✅', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(child: Text('Passif actif automatiquement — aucune action requise',
                  style: body(11, c: kGreen))),
              ]),
            ),
          // Info capacité
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: surfaceDecor(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('⚡ CAPACITÉ UNIQUE', style: cinzel(9, c: kGold, ls: 1)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: effChar.abilityRepeatable
                      ? kGreen.withValues(alpha: 0.2) : kGold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(freq, style: body(9,
                    c: effChar.abilityRepeatable ? kGreen : kGold)),
                ),
              ]),
              const SizedBox(height: 4),
              Text(effChar.ability, style: body(12)),
              if (effChar.abilityEffect == 'meg_shapeshift' && me.megForm != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: (me.megForm == 'offense' ? kRed : kGreen).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: (me.megForm == 'offense' ? kRed : kGreen).withValues(alpha: 0.5))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(me.megForm == 'offense' ? '⚔️' : '🛡️', style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        me.megForm == 'offense'
                            ? 'Forme actuelle : Offensive (+1 infligé)'
                            : 'Forme actuelle : Défensive (-1 reçu)',
                        style: cinzel(11, c: me.megForm == 'offense' ? kRed : kGreen)),
                    ]),
                  ),
                ),
              // Mathieu : nombre d'attaques effectuées — dès la 3ème, le bonus
              // de +2 dégâts devient permanent. Affiché en ronds pour rendre
              // la progression lisible d'un coup d'œil.
              if (effChar.abilityEffect == 'third_attack_bonus')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: (me.attackCount >= 3 ? kGold : kTextSub).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: (me.attackCount >= 3 ? kGold : kTextSub).withValues(alpha: 0.5))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      ...List.generate(3, (i) => Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: Icon(
                          me.attackCount > i ? Icons.circle : Icons.circle_outlined,
                          size: 12,
                          color: me.attackCount >= 3 ? kGold : kTextSub),
                      )),
                      const SizedBox(width: 6),
                      Text(
                        me.attackCount >= 3
                            ? 'Bonus +2 dégâts actif (${me.attackCount} attaques)'
                            : 'Attaques : ${me.attackCount}/3',
                        style: cinzel(11, c: me.attackCount >= 3 ? kGold : kTextSub)),
                    ]),
                  ),
                ),
            ]),
          ),
          // Équipements actifs
          if (me.equipment.isNotEmpty)
            _EquipmentPanel(player: me),
          if (!me.revealed)
            BHButton(label: '🃏 Se révéler',
              onTap: () {
                if (me.character!.abilityEffect == 'chameleon_passive') {
                  _showJasonDisguiseChoice();
                  return;
                }
                ctrl.humanReveal(); setState(() {});
              }),
          if (me.revealed && !me.abilityUsed && !isAutoPassive &&
              !(effChar.abilityEffect == 'store_damage_nils' && me.storedDamage < 1) &&
              me.abilityLockedByUid == null)
            BHButton(
              label: effChar.abilityEffect == 'store_damage_nils'
                  ? '📦 Déverser ${me.storedDamage} blessures stockées'
                  : effChar.abilityEffect == 'craft_equipment_remi'
                    ? '🛠️ Fabriquer mon équipement'
                    : effChar.abilityEffect == 'hailey_copy_hunter'
                      ? '📖 Copier un pouvoir Hunter'
                      : '⚡ Activer ma capacité',
              onTap: () => _handleAbility()),
          if (me.revealed && me.abilityUsed && !effChar.abilityRepeatable)
            Padding(padding: const EdgeInsets.only(bottom: 8),
              child: Text('Capacité utilisée pour cette partie.',
                style: body(12, c: kTextSub))),
          if (me.revealed && !me.abilityUsed && me.abilityLockedByUid != null)
            Padding(padding: const EdgeInsets.only(bottom: 8),
              child: Text('🔒 Votre capacité est verrouillée par Inès.',
                style: body(12, c: kTextSub))),
          BHButton(label: 'Passer → Déplacement',
            onTap: () { ctrl.humanSkipAbility(); setState(() {}); }, outlined: true),
        ];

      // ── DÉPLACEMENT ───────────────────────────────────────
      case GamePhase.move:
        final hasBoussole = me.equipment.any((e) => e.effect == 'double_dice_choice');
        final hasDoubleMove = (s.hasDoubleMove && me.revealed || hasBoussole) && !_albaneChose;
        final isDemiSel = me.character?.abilityEffect == 'stay_retrigger_terrain' && me.revealed;
        final isVoiture = (me.character?.abilityEffect == 'swap_position' && me.revealed)
            || me.equipment.any((e) => e.effect == 'swap_position_equip');
        final isRichard = me.character?.abilityEffect == 'swap_terrains' && me.revealed;
        return [
          // Options spéciales avant de lancer les dés
          if (isDemiSel && _sum == null)
            BHButton(label: '🧂 Rester sur place (réactive terrain)',
              onTap: () { ctrl.humanUseAbility(); ctrl.humanSkipAbility(); setState(() {}); }),
          if (isVoiture && _sum == null)
            BHButton(label: '🚗 Échanger de place avec un joueur',
              onTap: () => setState(() { _showingTargetList = true; _targetContext = 'voiture'; })),
          if (isRichard && _sum == null)
            BHButton(label: '🔀 Échanger 2 terrains au lieu de bouger',
              onTap: () => setState(() { _showingTargetList = true; _targetContext = 'richard'; })),
          if (_sum == null)
            if (s.fifiGoldenTurn && s.fifiMoveResult > 0)
              BHButton(label: '🍀 Fifi — Déplacer (résultat: ${s.fifiMoveResult})', gold: true,
                onTap: () {
                  setState(() { _d4 = s.fifiMoveD4; _d6 = s.fifiMoveD6; _sum = s.fifiMoveResult; });
                })
            else if (hasDoubleMove)
              // Albane / Boussole : lancer les deux d'un coup
              BHButton(
                label: hasBoussole ? '🧭 Boussole — lancer 2 dés (choisir le meilleur)' : '⏱ Albane — lancer 2 dés (choisir le meilleur)',
                gold: true,
                onTap: () {
                  final r1 = GameEngine.instance.rollMove();
                  final r2 = GameEngine.instance.rollMove();
                  setState(() {
                    _d4 = r1['d4'] as int; _d6 = r1['d6'] as int; _sum = r1['sum'] as int;
                    _d4b = r2['d4'] as int; _d6b = r2['d6'] as int; _sum2 = r2['sum'] as int;
                  });
                })
            else
              BHButton(label: '🎲 Lancer les dés (d4 + d6)', onTap: _rollDice)
          else if (_sum2 != null) ...[
            // Albane / Boussole : choisir entre les 2 résultats — empilés
            // verticalement (pas côte à côte) pour éviter tout débordement
            // sur écran étroit, chaque widget de dés ayant besoin de plus
            // de place que ce qu'une moitié d'écran peut offrir.
            Text('LANCER 1', style: cinzel(11, c: kTextDim, ls: 2)),
            const SizedBox(height: 4),
            _DiceWidget(d4: _d4!, d6: _d6!, sum: _sum!, isAttack: false),
            const SizedBox(height: 10),
            Text('LANCER 2', style: cinzel(11, c: kTextDim, ls: 2)),
            const SizedBox(height: 4),
            _DiceWidget(d4: _d4b!, d6: _d6b!, sum: _sum2!, isAttack: false),
            const SizedBox(height: 8),
            BHButton(label: '✅ Choisir lancer 1 ($_sum)', gold: true,
              onTap: () {
                setState(() { _sum2 = null; _d4b = null; _d6b = null; _albaneChose = true; });
                if (_sum != 7) _applyMove(_sum!);
              }),
            BHButton(label: '✅ Choisir lancer 2 ($_sum2)', gold: true,
              onTap: () {
                final chosen = _sum2!;
                setState(() { _sum = chosen; _sum2 = null; _d4b = null; _d6b = null; _albaneChose = true; });
                if (chosen != 7) _applyMove(chosen);
              }),
          ] else ...[
            _DiceWidget(d4: _d4!, d6: _d6!, sum: _sum!, isAttack: false),
            const SizedBox(height: 10),
            if (_sum == 7) ..._buildZoneChoices()
            else _buildAutoMove(),
          ],
        ];

      // ── CHOIX DE CARTE (terrain 4-5 : Marché des Ombres) ─────
      case GamePhase.cardChoice:
        return [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: surfaceDecor(),
            child: Column(children: [
              Text('🏪 Marché des Ombres', style: cinzel(14, c: kGold2)),
              const SizedBox(height: 4),
              Text('Choisissez le type de carte à piocher', style: body(12, c: kTextSub)),
            ]),
          ),
          const SizedBox(height: 8),
          BHButton(label: '🔵 Carte Lumière',
            onTap: () { ctrl.humanDrawCard(DeckType.lumiere); setState(() {}); }),
          BHButton(label: '🔴 Carte Ténèbres',
            onTap: () { ctrl.humanDrawCard(DeckType.tenebres); setState(() {}); }),
          BHButton(label: '🔮 Carte Vision',
            onTap: () { ctrl.humanDrawCard(DeckType.vision); setState(() {}); }),
        ];

      // ── EFFET TERRAIN ─────────────────────────────────────
      case GamePhase.zoneEffect:
        final terrain = ctrl.terrainOf(me);
        return [
          if (terrain != null) Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: surfaceDecor(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${terrain.icon} ${terrain.name}', style: cinzel(13, c: kGold2)),
              const SizedBox(height: 3),
              Text(terrain.keyword, style: body(12, c: kTextSub)),
            ]),
          ),
          // CORRECTION : terrain9 et steal déclenchent la liste inline
          if (terrain?.effect == 'choice') ...[
            BHButton(label: '✨ Lumière',
              onTap: () { ctrl.humanDrawCard(DeckType.lumiere); setState(() {}); }),
            BHButton(label: '🌑 Ténèbres',
              onTap: () { ctrl.humanDrawCard(DeckType.tenebres); setState(() {}); }),
            BHButton(label: '🔮 Vision',
              onTap: () { ctrl.humanDrawCard(DeckType.vision); setState(() {}); }),
          ] else if (terrain?.effect == 'damage9') ...[
            BHButton(label: '🏹 Infliger 2 dégâts → choisir une cible',
              onTap: () {
                // Ne PAS appeler humanApplyTerrainEffect() ici — ça change la phase
                // On set directement pendingTargetAction dans le state
                ctrl.state!.pendingTargetAction = 'terrain_damage9';
                setState(() { _showingTargetList = true; _targetContext = 'terrain_damage9'; });
              }),
            BHButton(label: 'Ignorer → Attaquer',
              onTap: () { ctrl.humanSkipTerrain(); setState(() {}); }, outlined: true),
          ] else if (terrain?.effect == 'steal') ...[
            BHButton(label: '🗼 Voler un équipement → choisir une cible',
              onTap: () => setState(() {
                _showingTargetList = true;
                _targetContext = 'terrain_steal';
              })),
            BHButton(label: 'Ignorer → Attaquer',
              onTap: () { ctrl.humanSkipTerrain(); setState(() {}); }, outlined: true),
          ] else ...[
            BHButton(label: 'Appliquer l\'effet',
              onTap: () { ctrl.humanApplyTerrainEffect(); setState(() {}); }),
            BHButton(label: 'Ignorer → Attaquer',
              onTap: () { ctrl.humanSkipTerrain(); setState(() {}); }, outlined: true),
          ],
        ];

      // ── CARTE PIOCHÉE ─────────────────────────────────────
      case GamePhase.cardDrawn:
        final card = s.pendingCard;
        if (card == null) return [];
        final isVision = card.deck == DeckType.vision;
        return [
          if (isVision)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1A0A2E).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade300, width: 1.5)),
              child: Row(children: [
                const Text('🔮', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text('Carte Vision — secrète, visible uniquement par toi',
                  style: body(11, c: Colors.purple.shade200)),
              ]),
            ),
          _CardWidget(card: card),
          const SizedBox(height: 10),
          BHButton(label: '✅ Appliquer l\'effet',
            onTap: () => _applyCard()),
          // Pas de bouton "Ignorer" — une carte piochée doit être appliquée
        ];

      // ── CHOOSE TARGET (via controller state) ──────────────
      case GamePhase.chooseTarget:
        // Vérifier d'abord les widgets spéciaux avant la liste de cibles
        if (s.pendingTargetAction == 'casino_bet') return [_CasinoWidget(ctrl: ctrl)];
        if (s.pendingTargetAction == 'fifi_dice_picker') return [_FifiDiceWidget(ctrl: ctrl)];
        if (s.pendingTargetAction == 'captain_ricard_counter') return [_CaptainRicardWidget(ctrl: ctrl)];
        if (s.pendingTargetAction == 'oscar_choice') return [_OscarChoiceWidget(ctrl: ctrl)];
        if (s.pendingTargetAction == 'baptiste_amount') return [_BaptisteAmountWidget(ctrl: ctrl)];
        return _buildInlineTargetList(ctx);

      // ── ATTAQUE ───────────────────────────────────────────
      case GamePhase.attack:
        final targets = s.raphShadowMultiAtk
          ? ctrl.humanAttackTargets
          : ctrl.humanAttackTargets;
        final alreadyAttacked = s.hasAttackedThisTurn && !s.raphShadowMultiAtk;
        final hasHache = me.hache && me.equipment.any((e) => e.effect == 'hache_berserker');
        final mustAttack = hasHache && !s.hasAttackedThisTurn && targets.isNotEmpty;
        final isMathieu = (me.copiedEffect ?? me.character?.abilityEffect) == 'third_attack_bonus';
        return [
          // Compteur Mathieu — bonus permanent à partir de la 3ème attaque
          if (isMathieu && !alreadyAttacked)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: kBg3, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: me.attackCount >= 2 ? kRed : kGold.withValues(alpha: 0.4))),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (me.attackCount >= 2) ...[
                  const Icon(Icons.bolt, size: 16, color: kRed),
                  const SizedBox(width: 4),
                  Text('Bonus actif : +2 dégâts par attaque', style: body(11, c: kRed, fw: FontWeight.w700)),
                ] else ...[
                  Text('⚔️ Attaques : ', style: body(11, c: kTextSub)),
                  ...List.generate(3, (i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Icon(
                      i < me.attackCount ? Icons.circle : Icons.circle_outlined,
                      size: 14, color: kGold),
                  )),
                  Text('  ⚡ 3ème = +2 dmg (permanent !)', style: body(11, c: kTextSub)),
                ],
              ]),
            ),
          // Équipements actifs
          if (me.equipment.isNotEmpty && !alreadyAttacked)
            _EquipmentPanel(player: me),
          if (alreadyAttacked)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kBg3, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBord2)),
              child: Row(children: [
                const Text('⚔️', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text('Tu as déjà attaqué ce tour.', style: body(13, c: kTextSub)),
              ]),
            )
          else if (targets.isEmpty)
            Padding(padding: const EdgeInsets.only(bottom: 8),
              child: Text('Aucune cible accessible.', style: body(13, c: kTextSub))),
          if (!alreadyAttacked && _atkDmg == null) ...[
            // Hache info
            if (hasHache)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: kRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kRed.withValues(alpha: 0.4))),
                child: Row(children: [
                  const Text('🪓', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Hache du Berserker — tu DOIS attaquer. Dés : d4 seulement.',
                    style: body(11, c: kRed))),
                ]),
              ),
            // Bazooka OU Rémi (choix "attaque tous à portée") : affiche les
            // cibles à portée (info) + bouton unique pour tout attaquer
            if (me.bazooka || remiActiveChoices(me).contains('remi_aoe')) ...[
              if (targets.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: kRed.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kRed.withValues(alpha: 0.3))),
                  child: Row(children: [
                    const Text('💥', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(
                      'Attaque groupée — ${targets.length} joueur${targets.length > 1 ? "s" : ""} à portée : ${targets.map((t) => t.name).join(", ")}',
                      style: body(11, c: kRed))),
                  ]),
                ),
                BHButton(
                  label: '💥 Attaquer (tous les joueurs à portée)',
                  danger: true,
                  onTap: () {
                    audio.playDice();
                    final remiChoicesMe2 = remiActiveChoices(me);
                    if (remiChoicesMe2.contains('remi_d4only')) {
                      final d4 = GameEngine.instance.rollD4();
                      setState(() { _atkD4 = d4; _atkD6 = null; _atkDmg = d4; _atkTarget = '__bazooka__'; });
                      return;
                    }
                    if (remiChoicesMe2.contains('remi_d6only')) {
                      final d6 = GameEngine.instance.rollD6();
                      setState(() { _atkD4 = null; _atkD6 = d6; _atkDmg = d6; _atkTarget = '__bazooka__'; });
                      return;
                    }
                    final r = GameEngine.instance.rollAttack();
                    setState(() { _atkD4 = r['d4']; _atkD6 = r['d6']; _atkDmg = r['damage']; _atkTarget = '__bazooka__'; });
                  }),
              ] else
                Padding(padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Aucune cible à portée.', style: body(13, c: kTextSub))),
            ],
            // Attaque normale (sans bazooka ni choix Rémi équivalent)
            if (!me.bazooka && !remiActiveChoices(me).contains('remi_aoe'))
              ...targets.map((t) => _TargetBtn(
                player: t, danger: true,
                prefix: hasHache ? '🪓 Attaquer ' : 'Attaquer ',
                onTap: () => hasHache ? _startHacheAtk(t.uid) : _startAtk(t.uid),
              )),
          ] else if (!alreadyAttacked) ...[
            if (_atkD4b != null) ...[
              Text('🥭 Cible costaude (13 PV+) — attaque doublée !',
                style: cinzel(11, c: kGold2), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('LANCER 1', style: cinzel(10, c: kTextDim, ls: 2)),
              const SizedBox(height: 4),
              _DiceWidget(d4: _atkD4!, d6: _atkD6!,
                sum: (_atkD4! - _atkD6!).abs(), isAttack: true),
              const SizedBox(height: 10),
              Text('LANCER 2', style: cinzel(10, c: kTextDim, ls: 2)),
              const SizedBox(height: 4),
              _DiceWidget(d4: _atkD4b!, d6: _atkD6b!,
                sum: (_atkD4b! - _atkD6b!).abs(), isAttack: true),
              const SizedBox(height: 6),
              Text('= $_atkDmg dégâts au total', style: cinzel(14, c: kRed, fw: FontWeight.w900),
                textAlign: TextAlign.center),
              const SizedBox(height: 10),
            ] else
              _DiceWidget(d4: _atkD4 ?? 0, d6: _atkD6 ?? 0, sum: _atkDmg!, isAttack: true),
            const SizedBox(height: 10),
            // Pas de bouton Annuler — une attaque lancée ne peut pas être annulée
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: kRed.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kRed.withValues(alpha: 0.3))),
              child: Row(children: [
                const Text('⚠️', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Dés lancés — tu dois confirmer l\'attaque.',
                  style: body(11, c: kRed))),
              ]),
            ),
            BHButton(label: '💥 Confirmer l\'attaque', danger: true, onTap: _confirmAtk),
            // Emilien : passif — une SEULE relance du D6 par tour. Non
            // disponible pour le bazooka ni le double-lancer de Mango
            // (structures différentes).
            if (me.revealed && _atkD4b == null && !me.emilienRerolledThisTurn &&
                (me.copiedEffect ?? me.character?.abilityEffect) == 'reroll_d6_attack') ...[
              const SizedBox(height: 8),
              BHButton(
                label: '🎲 Relancer le D6 (1 fois par tour)',
                outlined: true,
                onTap: () {
                  audio.playDice();
                  final newD6 = GameEngine.instance.rollD6();
                  setState(() {
                    _atkD6 = newD6;
                    _atkDmg = (_atkD4! - newD6).abs();
                    me.emilienRerolledThisTurn = true;
                  });
                }),
            ],
          ],
          const SizedBox(height: 4),
          if (mustAttack)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: kRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kRed.withValues(alpha: 0.5))),
              child: Row(children: [
                const Text('🪓', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(child: Text('Tu DOIS attaquer avant de terminer le tour !',
                  style: body(11, c: kRed))),
              ]),
            )
          // Une attaque en attente de confirmation (dés déjà lancés) DOIT
          // être résolue — impossible de terminer le tour pour la contourner
          // et échapper aux dégâts qu'elle va infliger.
          else if (_atkDmg != null)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: kRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kRed.withValues(alpha: 0.5))),
              child: Row(children: [
                const Text('⚔️', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(child: Text('Tu dois confirmer ton attaque avant de terminer le tour !',
                  style: body(11, c: kRed))),
              ]),
            )
          else
            _PulseButton(
              label: 'Terminer le tour →',
              onTap: () { ctrl.humanEndTurn(); setState(() {}); },
            ),
        ];

      default: return [];
    }
  }

  // ── Liste de cibles INLINE (correction freeze terrain9) ──
  List<Widget> _buildInlineTargetList(BuildContext ctx) {
    final me = s.current;
    final context = _targetContext ?? s.pendingTargetAction ?? '';
    bool needsEquip = context.contains('steal') || context == 'oscar_water_target';

    var targets = s.players.where((p) => p.alive && p.uid != me.uid).toList();
    if (needsEquip) targets = targets.where((p) => p.equipment.isNotEmpty).toList();
    // Clémence peut se cibler elle-même
    if (context == 'clemence_target') {
      targets = s.players.where((p) => p.alive).toList();
    }
    // Terrain 9 : peut aussi se cibler soi-même
    if (context == 'terrain_damage9') {
      targets = s.players.where((p) => p.alive).toList();
    }
    // Premier Secours ("vous compris") : peut aussi se cibler soi-même
    if (context == 'set_marker7_choice') {
      targets = s.players.where((p) => p.alive).toList();
    }
    // Marion : peut aussi se cibler elle-même
    if (context == 'ability_set5') {
      targets = s.players.where((p) => p.alive).toList();
    }
    // Baptiste : ne peut cibler QUE des joueurs morts, pour les ramener à la vie
    if (context == 'baptiste_target') {
      targets = s.players.where((p) => !p.alive).toList();
    }

    // Richard II : sélection d'une zone à échanger avec la sienne
    if (context == 'swap_zone_pick1' || context == 'swap_zone_pick2') {
      final myZoneIdx = s.current.zoneIndex;
      return [
        Container(padding: const EdgeInsets.all(10), decoration: surfaceDecor(),
          child: Text('👑 Richard II — Choisissez la zone à échanger avec la vôtre',
            style: cinzel(12, c: kGold2))),
        const SizedBox(height: 8),
        ...s.terrainLayout.asMap().entries.where((e) => e.key != myZoneIdx).map((entry) {
          final idx = entry.key;
          final terrain = entry.value;
          final playersHere = s.players.where((p) => p.alive && p.zoneIndex == idx).map((p) => p.token).join(' ');
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: BHButton(
              label: 'Zone ${idx + 1} — ${terrain.icon} ${terrain.name}${playersHere.isNotEmpty ? "  ($playersHere)" : ""}',
              onTap: () {
                setState(() { _showingTargetList = false; _targetContext = null; });
                ctrl.humanChooseSwapZone(idx);
              },
            ),
          );
        }),
      ];
    }

    // Tristan étape 2 : choisir SON équipement à donner
    if (context == 'tristan_give_choice') {
      final p = s.current;
      return [
        Container(padding: const EdgeInsets.all(10), decoration: surfaceDecor(),
          child: Text('🔄 Tristan — Quel objet donnez-vous ?', style: cinzel(12, c: kGold2))),
        const SizedBox(height: 8),
        ...p.equipment.asMap().entries.map((entry) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: BHButton(
            label: entry.value.name,
            onTap: () => ctrl.humanTristanChooseGive(entry.key),
          ),
        )),
      ];
    }
    // Tristan étape 3 : choisir l'équipement à RECEVOIR chez la cible
    if (context == 'tristan_receive_choice') {
      final targetUid = s.tristanTargetUid;
      final t = targetUid != null
          ? s.players.firstWhere((pl) => pl.uid == targetUid, orElse: () => s.current)
          : s.current;
      return [
        Container(padding: const EdgeInsets.all(10), decoration: surfaceDecor(),
          child: Text('🔄 Tristan — Quel objet de ${t.name} voulez-vous en échange ?',
            style: cinzel(12, c: kGold2))),
        const SizedBox(height: 8),
        ...t.equipment.asMap().entries.map((entry) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: BHButton(
            label: entry.value.name,
            onTap: () => ctrl.humanTristanChooseReceive(entry.key),
          ),
        )),
      ];
    }

    // Christine : choix direct d'une des 2 zones ADJACENTES (pas de dés)
    if (context == 'christine_zone_pick') {
      final myZoneIdx = s.current.zoneIndex;
      final adj = kAdjacences[myZoneIdx];
      return [
        Container(padding: const EdgeInsets.all(10), decoration: surfaceDecor(),
          child: Text('🗺️ Christine — Choisissez votre prochain terrain',
            style: cinzel(12, c: kGold2))),
        const SizedBox(height: 8),
        ...adj.map((idx) {
          final terrain = s.terrainLayout[idx];
          final playersHere = s.players.where((p) => p.alive && p.zoneIndex == idx).map((p) => p.token).join(' ');
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: BHButton(
              label: 'Zone ${idx + 1} — ${terrain.icon} ${terrain.name}${playersHere.isNotEmpty ? "  ($playersHere)" : ""}',
              onTap: () {
                setState(() { _showingTargetList = false; _targetContext = null; });
                ctrl.humanChooseChristineZone(idx);
              },
            ),
          );
        }),
      ];
    }

    // Choix d'équipement (pince_attrape / peau_banane avec plusieurs items)
    if (context == 'equip_choice') {
      final mode = s.equipChoiceMode ?? 'steal';
      final srcUid = mode == 'steal' ? s.equipChoiceTargetUid : s.equipChoiceActorUid;
      final src = srcUid != null ? s.players.firstWhere((p) => p.uid == srcUid, orElse: () => s.current) : s.current;
      final equipList = src.equipment;
      final title2 = mode == 'steal' ? '🗡 Choisissez l\'équipement à voler' : '🍌 Choisissez l\'équipement à donner';
      return [
        Container(padding: const EdgeInsets.all(10), decoration: surfaceDecor(),
          child: Text(title2, style: cinzel(12, c: kGold2))),
        const SizedBox(height: 8),
        ...equipList.asMap().entries.map((entry) => BHButton(
          label: entry.value.name,
          onTap: () { setState(() { _showingTargetList = false; _targetContext = null; }); ctrl.humanResolveEquipChoice(entry.key); },
        )),
      ];
    }

    // Vlad: uniquement les joueurs adjacents
    if (context == 'ability_vladimir') {
      const adjMap = [[1,5],[0,2],[1,3],[2,4],[3,5],[4,0]];
      final myZone = me.zoneIndex.clamp(0, 5);
      final adjZones = adjMap[myZone];
      targets = targets.where((p) =>
        p.zoneIndex == me.zoneIndex || adjZones.contains(p.zoneIndex)
      ).toList();
    }
    // Tommy: uniquement les joueurs révélés au pouvoir copiable
    if (context == 'ability_tommy') {
      targets = targets.where((p) => p.revealed && p.character != null &&
        !GameEngine.uncopyableAbilities.contains(p.character!.abilityEffect)).toList();
    }

    String title = 'Choisir une cible';
    if (context == 'terrain_damage9')     title = '🏹 Qui infliger 2 dégâts ?';
    if (context.contains('steal'))        title = '🗼 Voler l\'équipement de qui ?';
    if (context.contains('heal'))         title = '💚 Qui soigner ?';
    if (context == 'ability_vladimir')    title = '💨 Vlad — Joueur adjacent (D4)';
    if (context == 'ability_travert')     title = '🎲 Travert — Choisissez une cible (D6) — UNIQUE';
    if (context == 'ability_hong_yi')     title = '⚡ Hong Yi — Cible (8 mutuels)';
    if (context == 'ability_carapatte')   title = '🐢 Carapatte — Cible (D6 lifesteal)';
    if (context == 'ability_set5')        title = '📍 Marion — Choisissez un joueur (placé à 7 blessures)';
    if (context == 'ability_ines')        title = '🔒 Inès — Choisissez le joueur dont vous verrouillez la capacité';
    if (context == 'ability_damien')      title = '🍸 Damien — Choisissez qui servir';
    if (context == 'ability_tommy')       title = '🎭 Tommy — Copier le pouvoir de qui ?';
    if (context == 'ability_oceane')      title = '🌊 Océane — Qui exclure du soin ?';
    if (context == 'ability_nils')        title = '📦 Nils — Déverser ${me.storedDamage} blessures stockées sur qui ?';
    if (context == 'oscar_water_target')  title = '💧 Oscar — Voler un équipement à qui ?';
    if (context == 'baptiste_target')     title = '✝️ Baptiste — Quel joueur mort ramener à la vie ?';
    if (context == 'ability_agathe')      title = '🧛 Agathe — Voler 1 PV MAX à qui ?';
    if (context == 'ability_raph_heal')   title = '🥷 Raph (Soleil Levant) — Choisissez qui soigner de 3 (vous subissez 2)';
    if (context == 'ability_tristan')     title = '🔄 Tristan — Choisissez un joueur avec qui échanger';
    if (context == 'heal_other_d4')       title = '🍓 Fraise Tagada — Choisissez qui soigner (D4)';
    if (context == 'creation_marin')      title = '🩸 Création de Marin — Choisissez une cible';
    if (context == 'corne_des_woods')     title = '🌳 Corne des Woods — Qui doit attaquer ?';
    if (context == 'corne_des_woods_victim') title = '🌳 Corne des Woods — Choisissez la victime';
    if (context == 'clemence_target')        title = '🎨 Clémence — Choisissez une cible';
    if (context == 'jeanne_mark_target')     title = '🔮 Jeanne — Choisissez qui marquer';
    if (context == 'jeanne_mark_target')     title = '🔮 Jeanne — Marquez un joueur';
    if (context == 'ability_julien')      title = '😈 Julien — Choisissez une cible (2 dégâts)';
    if (context == 'ability_marin')       title = '🗡️ Marin — Choisissez une cible (3 dégâts + dague)';
    if (context == 'ability_hong_yi')     title = '⚡ Hong Yi — Cible (9 blessures mutuelles) — UNIQUE';
    if (context == 'casino_win')          title = '🎰 Mr Casino — Infligez 3 blessures à qui ?';
    if (context == 'swap_zone_pick1')     title = '👑 Richard II — Zone 1';
    if (context == 'swap_zone_pick2')     title = '👑 Richard II — Zone 2';

    return [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: surfaceDecor(),
        child: Text(title, style: cinzel(12, c: kGold2)),
      ),
      const SizedBox(height: 8),
      if (targets.isEmpty)
        Padding(padding: const EdgeInsets.only(bottom: 8),
          child: Text('Aucune cible valide.', style: body(13, c: kTextSub)))
      else
        ...targets.map((t) => _TargetBtn(
          player: t,
          onTap: () => _resolveTarget(t),
        )),
      BHButton(label: 'Annuler',  outlined: true,
        onTap: () {
          // Pour les capacités, revenir à la phase ability
          final isAbility = context.startsWith('ability_');
          if (isAbility) {
            ctrl.state!.pendingTargetAction = null;
            ctrl.state!.phase = GamePhase.ability;
            ctrl.notifyListeners();
          } else if (_targetContext != null) {
            ctrl.humanSkipTerrain();
          }
          setState(() { _showingTargetList = false; _targetContext = null; });
        }),
    ];
  }


  // ── Choix passif Luc / Peintre ───────────────────────────────────────────
  List<Widget> _buildPassiveChoice(BuildContext ctx) {
    void choose(String passive, String label) {
      ctrl.state!.lucPassive = passive;
      ctrl.state!.pendingTargetAction = null;
      ctrl.humanSkipAbility();
      setState(() {});
    }
    return [
      Container(padding: const EdgeInsets.all(10), decoration: surfaceDecor(),
        child: Text('Choisissez votre forme passive :', style: cinzel(12, c: kGold))),
      const SizedBox(height: 8),
      BHButton(label: '💚 Soignez 1 blessure au début de chaque tour',
        onTap: () => choose('heal1_per_turn', '+1 soin/tour')),
      BHButton(label: '⚔️ +1 blessure sur chaque attaque',
        onTap: () => choose('plus1_dmg', '+1 dégât/attaque')),
      BHButton(label: '🃏 Piochez 1 carte supplémentaire',
        onTap: () => choose('extra_card', '+1 carte/pioche')),
    ];
  }

  // ── Choix passif Inès ─────────────────────────────────────────────────────
  List<Widget> _buildInesChoice(BuildContext ctx) {
    void choose(String passive, String label) {
      ctrl.state!.current.copiedEffect = passive;
      ctrl.state!.pendingTargetAction = null;
      setState(() {});
    }
    return [
      Container(padding: const EdgeInsets.all(10), decoration: surfaceDecor(),
        child: Text('Inès — choisissez votre bonus :', style: cinzel(12, c: kGold))),
      const SizedBox(height: 8),
      BHButton(label: '🛡️ Subir 1 blessure de moins',
        onTap: () => choose('ines_minus1_recv', '−1 reçu')),
      BHButton(label: '⚔️ Infliger 1 blessure de plus',
        onTap: () => choose('ines_plus1_atk', '+1 infligé')),
    ];
  }

  void _resolveTarget(Player target) {
    // Capturer le context AVANT setState (qui efface _targetContext)
    final context = _targetContext ?? s.pendingTargetAction ?? '';
    // Effacer l'état local SEULEMENT après avoir capturé le context
    setState(() { _showingTargetList = false; _targetContext = null; });
    // Ne PAS effacer pendingTargetAction ici — chaque branche le fait elle-même

    if (context == 'terrain_damage9') {
      ctrl.humanApplyTerrainTarget(target.uid);
    } else if (context == 'oscar_water_target') {
      ctrl.humanOscarWaterTarget(target);
    } else if (context == 'baptiste_target') {
      ctrl.humanUseAbility(target: target);
    } else if (context == 'terrain_steal') {
      ctrl.state!.pendingTargetAction = 'terrain_steal';
      ctrl.humanApplyTerrainTarget(target.uid);
    } else if (context == 'casino_win') {
      ctrl.state!.pendingTargetAction = null;
      ctrl.applyDamageToPlayer(target.uid, 3);
      ctrl.logAbility('🎰 Mr Casino inflige 3 blessures à ${target.name} !');
      ctrl.state!.abilityOverlay = 'casino_win';
      ctrl.state!.phase = GamePhase.move;
      ctrl.notifyListeners();
    } else if (context == 'voiture') {
      // Voiture de Clem (capacité) ou Portail du Nether (équipement) : échange de position
      final p = ctrl.state!.current;
      final tmp = p.zoneIndex; p.zoneIndex = target.zoneIndex; target.zoneIndex = tmp;
      p.abilityUsed = true;
      ctrl.logAbility('🚗 ${p.name} échange sa place avec ${target.name}');
      ctrl.state!.skipMovement = true;
      ctrl.state!.phase = GamePhase.zoneEffect;
      ctrl.notifyListeners();
    } else if (context == 'jeanne_mark_target') {
      ctrl.humanChooseTarget(target.uid);
    } else if (context == 'clemence_target') {
      ctrl.humanChooseTarget(target.uid);
    } else if (context == 'jeanne_mark_target') {
      ctrl.jeanneChooseTarget(target.uid);
    } else if (context == 'ability_tristan') {
      ctrl.humanTristanChooseTarget(target.uid);
    } else if (context.startsWith('ability_')) {
      // Pour les abilities, pendingTargetAction est encore valide
      // car humanUseAbility lit l'effet depuis le character, pas le pendingTargetAction
      ctrl.humanUseAbility(target: target);
    } else {
      ctrl.humanApplyCard(target: target);
    }
    setState(() {});
  }

  // ── Helpers ──────────────────────────────────────────────

  void _applyMove(int sum) {
    // Applique le mouvement avec le résultat choisi
    const m = {2: 0, 3: 0, 4: 1, 5: 1, 6: 2, 8: 3, 9: 4, 10: 5};
    if (sum == 7) {
      // Stay in choose mode — handled by _buildZoneChoices
      setState(() { _sum = 7; _sum2 = null; });
      return;
    }
    final tid = m[sum];
    int idx = tid != null ? s.terrainLayout.indexWhere((t) => t.id == tid) : -1;
    if (idx == -1 || idx == s.current.zoneIndex) idx = (s.current.zoneIndex + 1) % 6;
    ctrl.humanMove(idx);
    // Augustin: se soigne de 2 si 7
    if (sum == 7 && s.current.character?.abilityEffect == 'heal_on_same_terrain' && s.current.revealed) {
      ctrl.state!.players[ctrl.state!.currentIdx].wounds =
        (ctrl.state!.players[ctrl.state!.currentIdx].wounds - 2).clamp(0, 999);
    }
    setState(() { _d4 = _d6 = _sum = null; _sum2 = null; _d4b = null; _d6b = null; _albaneChose = false; });
  }

  void _rollDice() {
    audio.playDice();
    final r = GameEngine.instance.rollMove();
    setState(() { _d4 = r['d4']; _d6 = r['d6']; _sum = r['sum']; });
    // Augustin: passif sur résultat 7
    if (r['sum'] == 7 && s.current.character?.abilityEffect == 'heal_on_same_terrain' && s.current.revealed) {
      ctrl.healPlayer(s.current.uid, 2);
    }
  }

  List<Widget> _buildZoneChoices() => List.generate(6, (i) {
    if (i == s.current.zoneIndex) return const SizedBox.shrink();
    final t = s.terrainLayout[i];
    return BHButton(
      label: '${t.icon} ${t.num} — ${t.name}',
      onTap: () { ctrl.humanMove(i); setState(() { _d4 = _d6 = _sum = null; _sum2 = null; _d4b = null; _d6b = null; }); },
    );
  });

  Widget _buildAutoMove() {
    const m = {2: 0, 3: 0, 4: 1, 5: 1, 6: 2, 8: 3, 9: 4, 10: 5};
    final tid = m[_sum];
    int idx = tid != null ? s.terrainLayout.indexWhere((t) => t.id == tid) : -1;
    if (idx == -1 || idx == s.current.zoneIndex) idx = (s.current.zoneIndex + 1) % 6;
    final t = s.terrainLayout[idx];
    return BHButton(
      label: '→ ${t.icon} ${t.name}  (${t.keyword})',
      onTap: () { ctrl.humanMove(idx); setState(() { _d4 = _d6 = _sum = null; _sum2 = null; _d4b = null; _d6b = null; }); },
    );
  }

  /// Rémi : propose 3 effets tirés au hasard parmi les 10 disponibles
  /// (légendaires nettement plus rares), et il en choisit exactement 2
  /// parmi CES 3 (pas parmi tous les 10).
  /// Hailey : 3 Hunters non joués tirés au hasard — choisit d'en copier le
  /// pouvoir. Résolu entièrement côté interface (pas de cible à choisir),
  /// comme Rémi.
  void _showHaileyChoiceDialog() {
    final offered = haileyDraw3(s.players, Random());
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dctx) => Dialog(
        backgroundColor: kBg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 480),
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              const Text('📖', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(child: Text('COPIER LE POUVOIR DE QUI ?',
                style: cinzel(13, c: kGold2, fw: FontWeight.w900))),
            ]),
            const SizedBox(height: 4),
            Text('Ce choix est définitif — 3 Hunters non joués cette partie.',
              style: body(11, c: kTextSub)),
            const SizedBox(height: 12),
            if (offered.isEmpty)
              Padding(padding: const EdgeInsets.all(20),
                child: Text('Aucun Hunter disponible à copier cette partie.',
                  style: body(12, c: kTextDim), textAlign: TextAlign.center)),
            // Sécurité supplémentaire : ce Dialog a une hauteur FIXE
            // (maxHeight: 480) sans défilement — si le contenu dépasse
            // malgré la limite de lignes ci-dessus, il peut au moins
            // défiler plutôt que déborder.
            Flexible(child: SingleChildScrollView(child: Column(children: [
            ...offered.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(dctx);
                  ctrl.humanHaileyChoice(c.id);
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kBg3, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kGold.withValues(alpha: 0.5))),
                  child: Row(children: [
                    Text(c.icon, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.name, style: cinzel(13, c: kGold2, fw: FontWeight.w700)),
                      // IMPORTANT : certaines capacités ont une description
                      // longue — sans limite, ça pouvait faire déborder ce
                      // Dialog à hauteur FIXE (480px max, sans défilement).
                      Text(c.ability, style: body(11, c: kTextSub),
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                    ])),
                  ]),
                ),
              ),
            )),
            ]))),
          ]),
        ),
      ),
    );
  }

  void _showRemiCraftDialog() {
    final offered = remiDraw3();
    final selected = <String>{};
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx2, setDialogState) => Dialog(
          backgroundColor: kBg2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460, maxHeight: 480),
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Text('🛠️', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(child: Text('CHOISISSEZ 2 EFFETS PARMI CES 3 (${selected.length}/2)',
                  style: cinzel(13, c: kGold2, fw: FontWeight.w900))),
              ]),
              const SizedBox(height: 4),
              Text('Cet équipement sera permanent — choisissez avec soin.',
                style: body(11, c: kTextSub)),
              const SizedBox(height: 12),
              ...offered.map((key) => _RemiChoiceRow(
                label: kRemiAllChoices[key]!,
                legendary: kRemiLegendaryChoices.containsKey(key),
                selected: selected.contains(key),
                onTap: () => setDialogState(() {
                  if (selected.contains(key)) {
                    selected.remove(key);
                  } else if (selected.length < 2) {
                    selected.add(key);
                  }
                }),
              )),
              const SizedBox(height: 14),
              BHButton(
                label: '🛠️ Fabriquer (${selected.length}/2)',
                danger: true,
                onTap: selected.length == 2 ? () {
                  final list = selected.toList();
                  Navigator.pop(dctx2);
                  ctrl.remiCraftEquipment(list[0], list[1]);
                  setState(() {});
                } : null,
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _showMegChoiceDialog() {
    showDialog(context: context, builder: (dctx) => AlertDialog(
      backgroundColor: kBg2,
      title: Text('🐺 Meg — Choisissez votre forme', style: cinzel(16, c: kGold2)),
      content: Text('Cette forme alternera automatiquement au début de chacun de vos tours suivants.',
        style: body(13)),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(dctx);
            ctrl.humanMegChooseForm('offense'); setState(() {});
          },
          child: Text('⚔️ Offensive (+1 infligé)', style: cinzel(12, c: kRed)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(dctx);
            ctrl.humanMegChooseForm('defense'); setState(() {});
          },
          child: Text('🛡️ Défensive (-1 reçu)', style: cinzel(12, c: kGreen)),
        ),
      ],
    ));
  }

  void _showJulienChoice() {
    showDialog(context: context, builder: (dctx) => AlertDialog(
      backgroundColor: kBg2,
      title: Text('😈 Julien', style: cinzel(16, c: kGold2)),
      content: Text('Infliger 2 blessures à un joueur, ou se soigner de 1 blessure ?',
        style: body(13)),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(dctx);
            setState(() { _showingTargetList = true; _targetContext = 'ability_julien'; });
          },
          child: Text('⚔️ Attaquer', style: cinzel(12, c: kRed)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(dctx);
            ctrl.humanJulienHeal(); setState(() {});
          },
          child: Text('💚 Se soigner', style: cinzel(12, c: kGreen)),
        ),
      ],
    ));
  }

  void _showJasonDisguiseChoice() {
    final hunters = s.players
        .where((p) => p.character?.faction == Faction.hunter && p.character != null)
        .map((p) => p.character!)
        .toList();
    final shadows = s.players
        .where((p) => p.character?.faction == Faction.shadow && p.character != null)
        .map((p) => p.character!)
        .toList();
    if (hunters.isEmpty || shadows.isEmpty) {
      ctrl.humanReveal(); setState(() {});
      return;
    }
    final hunterPick = hunters[Random().nextInt(hunters.length)];
    final shadowPick = shadows[Random().nextInt(shadows.length)];
    showDialog(context: context, builder: (dctx) => AlertDialog(
      backgroundColor: kBg2,
      title: Text('🦎 Jason — Choisissez votre déguisement', style: cinzel(15, c: kGold2)),
      content: Text('Les autres joueurs verront ce personnage à la place du vôtre.',
        style: body(12, c: kTextSub)),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(dctx);
            ctrl.humanRevealAsDisguise(hunterPick); setState(() {});
          },
          child: Text('${hunterPick.icon} ${hunterPick.name} (Hunter)', style: cinzel(12, c: kGold)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(dctx);
            ctrl.humanRevealAsDisguise(shadowPick); setState(() {});
          },
          child: Text('${shadowPick.icon} ${shadowPick.name} (Shadow)', style: cinzel(12, c: kRed)),
        ),
      ],
    ));
  }

  void _handleAbility() {
    final me = s.current;
    final eff = me.copiedEffect ?? me.character!.abilityEffect;
    // Julien : choix explicite entre attaquer une cible ou se soigner
    if (eff == 'damage2_or_heal1') {
      _showJulienChoice();
      return;
    }
    // Rémi : ouvre le sélecteur de 2 effets parmi 10
    if (eff == 'craft_equipment_remi') {
      _showRemiCraftDialog();
      return;
    }
    // Hailey : ouvre le sélecteur de pouvoir Hunter à copier (3 au hasard)
    if (eff == 'hailey_copy_hunter') {
      _showHaileyChoiceDialog();
      return;
    }
    // Meg : ouvre le choix entre forme Offensive et forme Défensive
    if (eff == 'meg_shapeshift') {
      _showMegChoiceDialog();
      return;
    }
    // Toutes ces capacités gèrent elles-mêmes leur transition de phase à
    // l'intérieur de humanUseAbility() — ne JAMAIS appeler humanSkipAbility()
    // après, ça écraserait la phase qu'elles viennent de définir.
    final selfManaged = {
      'damage2_choice', 'damage2_then_heal3', 'set_wounds7', 'steal_equip_choice',
      'swap_equipment', 'damage3_give_dague', 'd6_global_attack', 'd6_lifesteal',
      'terrain_max_aoe', 'damien_serve', 'copy_ability',
      'self1_trigger_terrain', 'draw_light', 'draw_dark', 'peek_reorder_deck',
      'casino_bet', 'swap_zones', 'd4_bonus_attack', 'store_damage_nils', 'steal_max_hp',
      'move_adjacent_choice', 'oscar_xp_spend', 'luc_ignite', 'baptiste_revive',
      'lock_ability_while_alive', 'maxence_drunk',
    };
    if (selfManaged.contains(eff)) {
      ctrl.humanUseAbility();
      setState(() {});
      return;
    }
    ctrl.humanUseAbility(); ctrl.humanSkipAbility(); setState(() {});
  }

  void _applyCard() {
    final card = s.pendingCard; if (card == null) return;
    final needsTarget = [
      'heal_other_d6', 'set_marker7_choice', 'banane_demonique', 'vampirisation',
      'blue_shell', 'veuve_noire', 'peau_banane', 'pince_attrape', 'trebuchet',
      'vision_shadow_2', 'vision_shadow_1', 'vision_hunter_1', 'vision_hunter_2',
    ].contains(card.effect);
    if (needsTarget) {
      // IMPORTANT : on utilise l'effet RÉEL de la carte (pas la chaîne
      // générique 'card') — sinon les overrides spécifiques par effet plus
      // bas (ex: set_marker7_choice qui autorise l'auto-ciblage) ne
      // correspondaient jamais, empêchant le joueur de se cibler lui-même
      // alors même que le texte de la carte le permet explicitement.
      setState(() { _showingTargetList = true; _targetContext = card.effect; });
    } else {
      ctrl.humanApplyCard(); setState(() {});
    }
  }

  void _startHacheAtk(String targetId) {
    final s = ctrl.state!;
    final me = s.current;
    final eff = me.copiedEffect ?? me.character?.abilityEffect;
    final target = s.players.where((p) => p.uid == targetId).firstOrNull;
    if (eff == 'double_attack_if_tanky' && target != null && target.revealed && target.character!.hp >= 13) {
      // 🥭 Mango Loco + Sabre Hanté Masamune : cible costaude → double
      // lancer même en D4 forcé, dégâts additionnés (même règle que pour
      // une attaque normale — le Sabre ne doit pas faire perdre ce passif).
      final r1 = ctrl.rollHacheAttack();
      final r2 = ctrl.rollHacheAttack();
      setState(() {
        _atkD4 = r1['d4']!; _atkD6 = 0;
        _atkD4b = r2['d4']!; _atkD6b = 0;
        _atkDmg = (r1['damage'] as int) + (r2['damage'] as int);
        _atkTarget = targetId;
      });
      return;
    }
    final r = ctrl.rollHacheAttack(); // d4 seulement
    setState(() {
      _atkD4 = r['d4']!; _atkD6 = 0; _atkDmg = r['damage']; _atkTarget = targetId;
    });
  }

  void _startAtk(String targetId) {
    audio.playDice();
    final s = ctrl.state!;
    if (s.fifiGoldenTurn) {
      // 🍀 Fifi — tour parfait : dégâts forcés selon les dés choisis
      setState(() {
        _atkD4 = s.fifiAtkD4; _atkD6 = s.fifiAtkD6;
        _atkDmg = s.fifiAtkResult; _atkTarget = targetId;
      });
      return;
    }
    final me = s.current;
    final eff = me.copiedEffect ?? me.character?.abilityEffect;
    final target = s.players.where((p) => p.uid == targetId).firstOrNull;
    // Rémi : équipement personnalisé — si le choix D4/D6 uniquement est
    // actif, on ne lance QUE ce dé (pas les deux), et les dégâts sont son
    // résultat brut directement.
    final remiChoicesMe = remiActiveChoices(me);
    if (remiChoicesMe.contains('remi_d4only')) {
      final d4 = GameEngine.instance.rollD4();
      setState(() { _atkD4 = d4; _atkD6 = null; _atkDmg = d4; _atkTarget = targetId; });
      return;
    }
    if (remiChoicesMe.contains('remi_d6only')) {
      final d6 = GameEngine.instance.rollD6();
      setState(() { _atkD4 = null; _atkD6 = d6; _atkDmg = d6; _atkTarget = targetId; });
      return;
    }
    if (eff == 'double_attack_if_tanky' && target != null && target.revealed && target.character!.hp >= 13) {
      // 🥭 Mango Loco : cible costaude (13+ PV) → double lancer, dégâts additionnés
      final r1 = GameEngine.instance.rollAttack();
      final r2 = GameEngine.instance.rollAttack();
      setState(() {
        _atkD4 = r1['d4']; _atkD6 = r1['d6'];
        _atkD4b = r2['d4']; _atkD6b = r2['d6'];
        _atkDmg = (r1['damage'] as int) + (r2['damage'] as int);
        _atkTarget = targetId;
      });
      return;
    }
    final r = GameEngine.instance.rollAttack();
    setState(() {
      _atkD4 = r['d4']; _atkD6 = r['d6'];
      _atkDmg = r['damage']; _atkTarget = targetId;
    });
  }

  void _confirmAtk() {
    if (_atkDmg == null) return;
    // Rémi : équipement personnalisé — si le choix D4/D6 uniquement est
    // actif, les dégâts sont le résultat BRUT du dé choisi, pas |D4-D6|.
    if (remiActiveChoices(s.current).contains('remi_d4only') && _atkD4 != null) {
      _atkDmg = _atkD4;
    } else if (remiActiveChoices(s.current).contains('remi_d6only') && _atkD6 != null) {
      _atkDmg = _atkD6;
    }
    audio.playDamage();
    if (_atkTarget == '__bazooka__') {
      // Bazooka: une seule méthode qui attaque tous sans rebuild intermédiaire
      ctrl.humanBazookaAttack(_atkDmg!);
    } else if (_atkTarget != null) {
      ctrl.humanAttack(_atkTarget!, _atkDmg!);
    }
    setState(() { _atkD4 = _atkD6 = _atkDmg = _atkD4b = _atkD6b = null; _atkTarget = null; });
  }
}

// ─────────────────────────────────────────────
// WIDGETS PARTAGÉS
// ─────────────────────────────────────────────

// ─── Victor : panneau privé de charme ────────────────────────────────────
/// Liste des barres de charme de chaque joueur — visible UNIQUEMENT par
/// Victor (aucun autre joueur ni la cible elle-même ne voit jamais cette
/// info, y compris une fois à 100%). Fonction top-level (pas une méthode
/// de classe) : appelée depuis plusieurs endroits de l'interface.
void showVictorCharmPanel(BuildContext ctx, Player victor, List<Player> allPlayers) {
  final others = allPlayers.where((p) => p.uid != victor.uid).toList();
  showDialog(
    context: ctx,
    builder: (dctx) => AlertDialog(
      backgroundColor: kBg2,
      title: Text('💘 Charme — privé', style: cinzel(15, c: Colors.pinkAccent)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(mainAxisSize: MainAxisSize.min,
          children: others.map((p) {
            final pct = victor.charmLevels[p.uid] ?? 0;
            final maxed = pct >= 100;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(p.alive ? p.name : '${p.name} 💀',
                    style: body(13, c: p.alive ? kText : kTextDim))),
                  Text('$pct%', style: cinzel(13,
                    c: maxed ? Colors.pinkAccent : kTextSub, fw: FontWeight.w900)),
                ]),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct / 100, minHeight: 8,
                    backgroundColor: kBg3,
                    valueColor: AlwaysStoppedAnimation(
                      maxed ? Colors.pinkAccent : Colors.pink.withValues(alpha: 0.6)),
                  ),
                ),
                if (maxed) Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text('💘 Charmé — ne peut plus t\'attaquer',
                    style: body(10, c: Colors.pinkAccent)),
                ),
              ]),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dctx),
          child: Text('Fermer', style: cinzel(12, c: kTextSub))),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════
// ANIMATION DÉ DE POUVOIR (Vlad D4, Travert D6, Carapatte D6...)
// ═══════════════════════════════════════════════════════════════

class _AbilityDiceRoll extends StatefulWidget {
  final SoloController ctrl;
  final Map<String, int> result;
  const _AbilityDiceRoll({required this.ctrl, required this.result});
  @override State<_AbilityDiceRoll> createState() => _AbilityDiceRollState();
}

class _AbilityDiceRollState extends State<_AbilityDiceRoll>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    // Même durée que Casino : 1400ms de défilement rapide
    _ac = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1400));

    _ac.forward().then((_) {
      if (!mounted) return;
      setState(() => _revealed = true);
      // Auto-dismiss après 2s
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (!mounted) return;
        widget.ctrl.state!.abilityDiceResult = null;
        widget.ctrl.notifyListeners();
      });
    });
  }

  @override void dispose() { _ac.dispose(); super.dispose(); }

  Widget _dieBox(int val, int sides, Color color) => Container(
    width: 90, height: 90,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: sides == 4
          ? BorderRadius.circular(10)
          : BorderRadius.circular(18),
      border: Border.all(color: color, width: 3),
      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 16)],
    ),
    child: Center(child: Text('$val',
      style: TextStyle(fontSize: 44, fontFamily: 'Cinzel',
        fontWeight: FontWeight.w900, color: color))),
  );

  @override
  Widget build(BuildContext ctx) {
    final d      = widget.result['d'] ?? 6;
    final result = widget.result['result'] ?? 0;
    final dmg    = widget.result['dmg'] ?? 0;
    final d4val  = widget.result['d4val'];
    final d6val  = widget.result['d6val'];
    final isBombe = d4val != null && d6val != null;
    final isD4   = d == 4 && !isBombe;
    final sides  = isD4 ? 4 : 6;
    final color  = dmg >= 6 ? kRed : dmg >= 3 ? kGold : kGreen;
    final label  = isBombe ? 'BOMBE  D4 + D6' : (isD4 ? 'D4' : 'D6');

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0A2E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color, width: 2.5),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 18)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: cinzel(13, c: kTextSub, ls: 2)),
        const SizedBox(height: 14),

        // ── Dé(s) ─────────────────────────────────────────────
        AnimatedBuilder(
          animation: _ac,
          builder: (_, __) {
            if (_revealed) {
              // Résultat final — même style que Casino
              if (isBombe) {
                return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _dieBox(d4val!, 4, color),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('+', style: cinzel(24, c: kGold))),
                  _dieBox(d6val!, 6, color),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('=$result', style: cinzel(24, c: kGold))),
                ]);
              }
              return _dieBox(result, sides, color);
            }
            // Défilement rapide de chiffres — EXACTEMENT comme Casino
            final spinning = ((_ac.value * 18).floor() % sides) + 1;
            return _dieBox(spinning, sides, kBord2);
          },
        ),

        const SizedBox(height: 14),

        // ── Texte résultat ─────────────────────────────────────
        if (_revealed) ...[
          Text(
            isBombe
              ? 'Résultat : $result'
              : dmg > 0
                ? '$dmg blessure${dmg > 1 ? "s" : ""}'
                : 'Soigne ${ -dmg } blessure${ -dmg > 1 ? "s" : "" }',
            style: cinzel(18, c: color, fw: FontWeight.w900)),
        ] else
          Text('Lancement...', style: body(13, c: kTextSub)),
      ]),
    );
  }
}


class _DiceWidget extends StatefulWidget {
  final int d4, d6, sum;
  final bool isAttack;
  const _DiceWidget({required this.d4, required this.d6, required this.sum, required this.isAttack});
  @override State<_DiceWidget> createState() => _DiceWidgetState();
}

class _DiceWidgetState extends State<_DiceWidget>
    with TickerProviderStateMixin {
  late AnimationController _rollAc;  // animation dés qui roulent (0.5s)
  late AnimationController _revealAc; // apparition résultat
  late Animation<double> _rollD4x, _rollD4y;
  late Animation<double> _rollD6x, _rollD6y;
  late Animation<double> _rollRotD4, _rollRotD6;
  late Animation<double> _revealScale, _revealFade;
  bool _showResult = false;

  @override
  void initState() {
    super.initState();
    // ── Phase 1 : dés qui bougent (500ms) ──
    _rollAc = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 500));
    _rollD4x = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: -60, end: 30), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 30, end: -15), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: -15, end: 0),  weight: 30),
    ]).animate(CurvedAnimation(parent: _rollAc, curve: Curves.easeInOut));
    _rollD4y = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: -30, end: 20), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 20, end: -10), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: -10, end: 0),  weight: 30),
    ]).animate(CurvedAnimation(parent: _rollAc, curve: Curves.easeIn));
    _rollD6x = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 60, end: -25), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: -25, end: 15), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 15, end: 0),   weight: 30),
    ]).animate(CurvedAnimation(parent: _rollAc, curve: Curves.easeInOut));
    _rollD6y = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 20, end: -30), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: -30, end: 15), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 15, end: 0),   weight: 30),
    ]).animate(CurvedAnimation(parent: _rollAc, curve: Curves.easeIn));
    _rollRotD4 = Tween<double>(begin: -2.0, end: 0)
        .animate(CurvedAnimation(parent: _rollAc, curve: Curves.easeOut));
    _rollRotD6 = Tween<double>(begin: 2.0, end: 0)
        .animate(CurvedAnimation(parent: _rollAc, curve: Curves.easeOut));

    // ── Phase 2 : révélation résultat ──
    _revealAc = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 350));
    _revealScale = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _revealAc, curve: Curves.easeOutBack));
    _revealFade = CurvedAnimation(parent: _revealAc, curve: Curves.easeOut);

    // Lancer : roll → puis révéler
    _rollAc.forward().then((_) {
      if (mounted) setState(() => _showResult = true);
      _revealAc.forward();
    });
  }

  @override void dispose() {
    _rollAc.dispose(); _revealAc.dispose(); super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // ── Les deux dés qui bougent ──────────────
      SizedBox(height: 70,
        child: LayoutBuilder(builder: (lctx, constraints) {
          // Décalages d'animation mis à l'échelle selon la largeur réelle —
          // évite le débordement quand 2 dés sont affichés côte à côte
          // (Albane/Boussole) sur un écran étroit.
          final scale = (constraints.maxWidth / 260).clamp(0.35, 1.0);
          return AnimatedBuilder(
            animation: _rollAc,
            builder: (_, __) => Stack(alignment: Alignment.center, children: [
              // d4
              Transform.translate(
                offset: Offset(_rollD4x.value * scale, _rollD4y.value),
                child: Transform.rotate(angle: _rollRotD4.value,
                  child: _RollingDie(
                    value: widget.d4, label: 'd4',
                    color: widget.isAttack ? kRed : kGold,
                    rolling: !_showResult,
                  )),
              ),
              // d6
              Transform.translate(
                offset: Offset((_rollD6x.value + 60) * scale, _rollD6y.value),
                child: Transform.rotate(angle: _rollRotD6.value,
                  child: _RollingDie(
                    value: widget.d6, label: 'd6',
                    color: widget.isAttack ? kRed : kGold,
                    rolling: !_showResult,
                  )),
              ),
            ]),
          );
        }),
      ),
      // ── Résultat (apparaît après le roll) ─────
      if (_showResult)
        AnimatedBuilder(
          animation: _revealAc,
          builder: (_, child) => FadeTransition(
            opacity: _revealFade,
            child: Transform.scale(scale: _revealScale.value, child: child),
          ),
          child: _buildContent(),
        ),
    ]);
  }

  Widget _buildContent() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: widget.isAttack ? kShadow.withValues(alpha: 0.1) : kGold.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: widget.isAttack
        ? kShadow.withValues(alpha: 0.6) : kGold.withValues(alpha: 0.4)),
    ),
    child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _Face(value: widget.d4, label: 'd4'),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(widget.isAttack ? '−' : '+', style: cinzel(20, c: kTextDim))),
        _Face(value: widget.d6, label: 'd6'),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('=', style: cinzel(20, c: kTextDim))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: (widget.isAttack ? kRed : kGold).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: widget.isAttack ? kRed : kGold),
          ),
          child: Text('${widget.sum}',
            style: cinzel(28, c: widget.isAttack ? kRed : kGold2, fw: FontWeight.w900)),
        ),
      ]),
      const SizedBox(height: 6),
      Text(widget.isAttack
        ? '|d4(${widget.d4}) − d6(${widget.d6})| = ${widget.sum} dégâts'
        : 'd4(${widget.d4}) + d6(${widget.d6}) = ${widget.sum}',
        style: body(11, c: kTextSub)),
      if (!widget.isAttack && widget.sum == 7)
        Padding(padding: const EdgeInsets.only(top: 4),
          child: Text('🎯 Choisis ta destination !', style: cinzel(11, c: kGold))),
      if (widget.isAttack && widget.sum == 0)
        Padding(padding: const EdgeInsets.only(top: 4),
          child: Text('Attaque ratée !', style: body(11, c: kTextDim))),
    ]),
  );
}

class _Face extends StatelessWidget {
  final int value; final String label;
  const _Face({required this.value, required this.label});
  @override
  Widget build(BuildContext ctx) => Container(
    width: 48, height: 48,
    decoration: BoxDecoration(
      color: kBg3, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: kBord2, width: 1.5)),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('$value', style: cinzel(20, c: kGold2, fw: FontWeight.w900)),
      Text(label, style: body(8, c: kTextDim)),
    ]),
  );
}


/// Dé animé — affiche des valeurs aléatoires qui défilent pendant le roll
class _RollingDie extends StatefulWidget {
  final int value;
  final String label;
  final Color color;
  final bool rolling;
  const _RollingDie({required this.value, required this.label,
    required this.color, required this.rolling});
  @override State<_RollingDie> createState() => _RollingDieState();
}

class _RollingDieState extends State<_RollingDie> {
  int _display = 1;
  late final Stream<int> _stream;

  @override
  void initState() {
    super.initState();
    _stream = Stream.periodic(const Duration(milliseconds: 60), (i) => i);
    _stream.listen((i) {
      if (mounted && widget.rolling) {
        setState(() => _display = (i % 6) + 1);
      }
    });
  }

  @override
  Widget build(BuildContext ctx) {
    final shown = widget.rolling ? _display : widget.value;
    return Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        color: kBg3,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.rolling ? kBord2 : widget.color,
          width: widget.rolling ? 1.5 : 2.5),
        boxShadow: widget.rolling ? null : [
          BoxShadow(color: widget.color.withValues(alpha: 0.4), blurRadius: 8)
        ],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('$shown',
          style: cinzel(22,
            c: widget.rolling ? kTextDim : widget.color,
            fw: FontWeight.w900)),
        Text(widget.label, style: body(8, c: kTextDim)),
      ]),
    );
  }
}

/// Carte piochée affichée avec illustration
/// showAsSecret = true → carte Vision vue par les autres (dos affiché)
class _CardWidget extends StatelessWidget {
  final GameCard card;
  final bool showAsSecret;
  const _CardWidget({required this.card, this.showAsSecret = false});

  @override
  Widget build(BuildContext ctx) {
    // Carte Vision secrète → afficher le dos
    if (showAsSecret) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1A2E1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3A6020), width: 1.5),
        ),
        child: Column(children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            child: Image.asset(
              'assets/images/cards/vision_other.png',
              height: 160, width: double.infinity, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 100, color: const Color(0xFF1A2E1A),
                child: const Center(child: Text('🔮', style: TextStyle(fontSize: 40))))),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Text('CARTE VISION', style: cinzel(11, c: const Color(0xFF7B4FD4), ls: 2)),
              const SizedBox(height: 4),
              Text('Un joueur a pioché une carte Vision secrète',
                style: body(12, c: kTextSub), textAlign: TextAlign.center),
            ]),
          ),
        ]),
      );
    }

    // Carte normale → afficher l'illustration
    final dc = deckColor(card.deck.name);
    final imgPath = anyCardImagePath(card.effect);

    return EntranceScale(child: Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: dc.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dc.withValues(alpha: 0.6)),
        boxShadow: [BoxShadow(color: dc.withValues(alpha: 0.15), blurRadius: 10)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Illustration
        if (imgPath != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 240,
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: Image.asset(imgPath, fit: BoxFit.contain,
                      cacheWidth: 640, cacheHeight: 960,
                      errorBuilder: (_, __, ___) => Container(
                        height: 80, color: dc.withValues(alpha: 0.1),
                        child: Center(child: Text(deckIcon(card.deck.name),
                          style: const TextStyle(fontSize: 40))))),
                  ),
                ),
              ),
            ),
          )
        else
          Container(
            height: 80, width: double.infinity,
            decoration: BoxDecoration(
              color: dc.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Center(child: Text(deckIcon(card.deck.name),
              style: const TextStyle(fontSize: 40))),
          ),

        // Infos
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(deckLabel(card.deck.name), style: cinzel(9, c: dc, ls: 1)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: dc.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  card.type == CardType.equipement ? '⚔ Équipement' : '✨ Usage unique',
                  style: body(9, c: dc)),
              ),
            ]),
            const SizedBox(height: 6),
            Text(card.name, style: cinzel(15, c: kGold2, fw: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(card.text, style: body(12)),
          ]),
        ),
      ]),
    ));
  }
}

/// Rémi : une ligne sélectionnable dans le sélecteur d'effets.
class _RemiChoiceRow extends StatelessWidget {
  final String label;
  final bool selected, legendary;
  final VoidCallback onTap;
  const _RemiChoiceRow({required this.label, required this.selected,
    required this.onTap, this.legendary = false});

  @override
  Widget build(BuildContext ctx) {
    final accent = legendary ? kGold : kGold2;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.15) : kBg3,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? accent : kBord2, width: selected ? 2 : 1),
        ),
        child: Row(children: [
          Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18, color: selected ? accent : kTextDim),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: body(12, c: selected ? kText : kTextSub))),
        ]),
      ),
    );
  }
}

class _TargetBtn extends StatelessWidget {
  final Player player; final VoidCallback onTap;
  final bool danger; final String prefix;
  const _TargetBtn({required this.player, required this.onTap,
    this.danger = false, this.prefix = ''});

  @override
  Widget build(BuildContext ctx) {
    final hpColor = player.wounds >= 10 ? kRed : player.wounds >= 6 ? kGold : kGreen;
    // Pas de % basé sur les PV max (info secrète)
    return Container(
      width: double.infinity, margin: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: danger ? kShadow.withValues(alpha: 0.12) : kBg3,
          foregroundColor: danger ? kRed : kText,
          side: BorderSide(color: danger ? kShadow : kBord2),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0, alignment: Alignment.centerLeft),
        child: Row(children: [
          TokenWidget(tokenId: player.token, size: 30),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$prefix${player.name} (${player.token})', style: TextStyle(
              fontFamily: 'Cinzel', fontSize: 13,
              fontWeight: FontWeight.w700, color: danger ? kRed : kText)),
            const SizedBox(height: 4),
            // Blessures uniquement — pas de barre basée sur les PV max
            Text('${player.wounds} blessure${player.wounds > 1 ? "s" : ""}',
              style: body(10, c: hpColor)),
          ])),
          const SizedBox(width: 8),
          Text('🗡 ${player.wounds}',
            style: TextStyle(fontSize: 11, fontFamily: 'Cinzel', color: hpColor)),
        ]),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String icon, label, text;
  const _InfoCard(this.icon, this.label, this.text);
  @override
  Widget build(BuildContext ctx) => Container(
    width: double.infinity, padding: const EdgeInsets.all(10),
    decoration: surfaceDecor(border: kBord),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(icon, style: const TextStyle(fontSize: 14)), const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: cinzel(9, c: kTextSub, ls: 1)),
        const SizedBox(height: 2),
        Text(text, style: body(12)),
      ])),
    ]),
  );
}

// ─────────────────────────────────────────────
// LOG STRIP
// ─────────────────────────────────────────────
class _LogStrip extends StatelessWidget {
  final SoloController ctrl;
  const _LogStrip({required this.ctrl});
  @override
  Widget build(BuildContext ctx) {
    final logs = ctrl.state!.log.reversed.take(2).toList();
    return Container(
      color: kBg1,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: logs.map((l) => Text(l.message,
          style: TextStyle(fontSize: 11, color: switch (l.cls) {
            'death' => kRed, 'important' => kGold,
            'player' => kGreen, _ => kTextSub,
          }),
          maxLines: 1, overflow: TextOverflow.ellipsis)).toList()),
    );
  }
}




// ─── Bannière de statut ───────────────────────────────────────────────────────
class _StatusBanner extends StatelessWidget {
  final String message;
  final Color color;
  const _StatusBanner(this.message, this.color);

  @override
  Widget build(BuildContext ctx) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(message, style: body(11, c: color)),
  );
}

// ─── Panel équipements actifs ─────────────────────────────────────────────────
class _EquipmentPanel extends StatelessWidget {
  final Player player;
  const _EquipmentPanel({required this.player});

  @override
  Widget build(BuildContext ctx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kGold.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kGold.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('⚔️ ÉQUIPEMENTS ACTIFS', style: cinzel(9, c: kGold, ls: 1)),
        const SizedBox(height: 6),
        ...player.equipment.map((eq) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            Text(_icon(eq.effect), style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(eq.name, style: cinzel(11, c: kGold2)),
              Text(_effectDesc(eq.effect), style: body(10, c: kTextSub)),
            ])),
          ]),
        )),
      ]),
    );
  }

  String _icon(String e) => switch (e) {
    'hache_berserker'     => '🪓',
    'sniper'              => '🔫',
    'bazooka'             => '💥',
    'dague_voleur'        => '🗡',
    'lance_lumiere'       => '✨',
    'sainte_tunique'      => '🛡',
    'crucifix_argent'     => '✝️',
    'tenebres_card_immune'=> '🔺',
    'terrain9_immune'     => '👂',
    'triple_dice_choice'  => '⏱',
    _                     => '⚔',
  };

  String _effectDesc(String e) => switch (e) {
    'hache_berserker'     => 'Tu DOIS attaquer — dés : d4 seulement',
    'sniper'              => 'Attaque uniquement les zones hors de portée',
    'bazooka'             => 'Attaque touche aussi tous les joueurs à portée',
    'dague_voleur'        => '+1 blessure sur chaque attaque qui touche',
    'lance_lumiere'       => '+2 blessures sur chaque attaque qui touche',
    'sainte_tunique'      => '−1 blessure reçue et infligée',
    'crucifix_argent'     => 'Récupère TOUT l\'équipement d\'un joueur éliminé',
    'tenebres_card_immune'=> 'Immunisé aux cartes Ténèbres (sauf Bombe)',
    'terrain9_immune'     => "Immunisé à l'effet du terrain 9",
    'triple_dice_choice'  => 'Lance 2 fois les dés au déplacement — choisis',
    _                     => 'Effet passif actif',
  };
}

// ─── Bouton pulsé ────────────────────────────────────────────────────────────
class _PulseButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _PulseButton({required this.label, required this.onTap});
  @override State<_PulseButton> createState() => _PulseButtonState();
}

class _PulseButtonState extends State<_PulseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.04)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeInOut));
  }

  @override void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) => AnimatedBuilder(
    animation: _scale,
    builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
    child: BHButton(label: widget.label, onTap: widget.onTap, outlined: true),
  );
}

// ─────────────────────────────────────────────
// GAME OVER
// ─────────────────────────────────────────────
// Audio handled in SoloGameOverScreen init
class SoloGameOverScreen extends StatefulWidget {
  final SoloController ctrl;
  const SoloGameOverScreen({super.key, required this.ctrl});
  @override State<SoloGameOverScreen> createState() => _SoloGameOverScreenState();
}

class _SoloGameOverScreenState extends State<SoloGameOverScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgAc;
  late AnimationController _contentAc;

  @override
  void initState() {
    super.initState();
    // Win/lose music
    final isWinner = widget.ctrl.state?.winnerIds.contains(widget.ctrl.state?.players.firstWhere((p) => !p.isBot, orElse: () => widget.ctrl.state!.players.first).uid) ?? false;
    if (isWinner) audio.playWin(); else audio.playLose();
    audio.fadeOutMusic();

    // Enregistrer la partie dans l'historique local
    final st = widget.ctrl.state;
    if (st != null) {
      final human = st.players.firstWhere((p) => p.uid == 'human',
          orElse: () => st.players.first);
      Prefs.addGame(
        mode: 'solo',
        character: human.character?.name ?? '?',
        faction: human.character?.faction.name ?? '?',
        win: st.winnerIds.contains('human'),
      );
    }

    _bgAc = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _contentAc = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _bgAc.forward().then((_) => _contentAc.forward());
  }

  @override void dispose() { _bgAc.dispose(); _contentAc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    final s = widget.ctrl.state!;
    final iWon = s.winnerIds.contains('human');
    final winners = s.players.where((p) => s.winnerIds.contains(p.uid)).toList();
    final losers = s.players.where((p) => !s.winnerIds.contains(p.uid)).toList();

    // Determine winning faction
    String winFaction = '';
    if (winners.isNotEmpty) {
      winFaction = winners.first.character?.faction.name ?? '';
      // If mixed (neutrals), use first winner's faction
    }
    final fc = factionColor(winFaction.isEmpty ? 'hunter' : winFaction);
    final fbg = factionBg(winFaction.isEmpty ? 'hunter' : winFaction);

    final factionLabel = switch(winFaction) {
      'hunter'  => 'LES HUNTERS',
      'shadow'  => 'LES SHADOWS',
      'neutral' => 'LES NEUTRES',
      _         => 'LES JOUEURS',
    };
    final factionEmoji = switch(winFaction) {
      'hunter' => '🔵', 'shadow' => '🔴', 'neutral' => '🟡', _ => '⚔️',
    };

    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _bgAc, curve: Curves.easeIn),
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter, radius: 1.5,
              colors: [fc.withValues(alpha: 0.25), Colors.black],
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _contentAc, curve: Curves.easeIn),
              child: LayoutBuilder(builder: (bctx, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(children: [
                        const SizedBox(height: 24),

                // ── Titre victoire ───────────────────────────────
                Column(children: [
                  Text(factionEmoji, style: const TextStyle(fontSize: 64)),
                  const SizedBox(height: 8),
                  Text('$factionLabel', style: cinzel(32, c: fc, fw: FontWeight.w900).copyWith(
                    shadows: [Shadow(color: fc.withValues(alpha: 0.8), blurRadius: 24)])),
                  const SizedBox(height: 4),
                  Text('ONT GAGNÉ !', style: cinzel(22, c: kGold2, fw: FontWeight.w700, ls: 4)),
                  const SizedBox(height: 8),
                  Text(s.winnerMessage ?? '', style: body(13, c: kTextSub),
                    textAlign: TextAlign.center,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                ]),

                const SizedBox(height: 24),

                // ── Cartes des gagnants (centrées) ─────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10, runSpacing: 10,
                    children: winners.map((w) {
                      final c2 = w.character;
                      final imgPath = c2 != null ? effectiveCharacterImagePath(c2.id) : null;
                      final wFc = factionColor(c2?.faction.name ?? '');
                      final isDead = !w.alive;
                      return Container(
                        width: 120,
                        decoration: BoxDecoration(
                          color: kBg2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDead ? kTextDim : wFc, width: 2.5),
                          boxShadow: isDead ? null
                            : [BoxShadow(color: wFc.withValues(alpha: 0.4), blurRadius: 10)],
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          // Illustration — en niveaux de gris + icône tombale
                          // pour un gagnant mort, mais la carte reste bien
                          // visible (juste "éteinte", pas cachée).
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                            child: SizedBox(
                              height: 130, width: double.infinity,
                              child: Stack(fit: StackFit.expand, children: [
                                ColorFiltered(
                                  colorFilter: isDead
                                    ? const ColorFilter.matrix(<double>[
                                        0.2126, 0.7152, 0.0722, 0, 0,
                                        0.2126, 0.7152, 0.0722, 0, 0,
                                        0.2126, 0.7152, 0.0722, 0, 0,
                                        0, 0, 0, 1, 0,
                                      ])
                                    // Filtre neutre (n'altère pas l'image) —
                                    // BlendMode.dst ignore complètement la
                                    // couleur source, contrairement à
                                    // multiply avec du transparent qui
                                    // aurait noirci l'image entière.
                                    : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                                  child: imgPath != null
                                    ? Image.asset(imgPath, fit: BoxFit.cover,
                                        cacheHeight: 520,
                                        errorBuilder: (_, __, ___) => Container(color: fbg,
                                          child: Center(child: Text(c2?.icon ?? '?',
                                            style: const TextStyle(fontSize: 40)))))
                                    : Container(color: fbg, child: Center(
                                        child: Text(c2?.icon ?? '?', style: const TextStyle(fontSize: 40)))),
                                ),
                                if (isDead) ...[
                                  Container(color: Colors.black.withValues(alpha: 0.45)),
                                  const Center(child: Text('🪦', style: TextStyle(fontSize: 36))),
                                ],
                              ]),
                            ),
                          ),
                          // Infos
                          Padding(
                            padding: const EdgeInsets.all(7),
                            child: Column(children: [
                              Text(c2?.name ?? w.name,
                                style: cinzel(11, c: isDead ? kTextDim : wFc, fw: FontWeight.w700),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 3),
                              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                TokenWidget(tokenId: w.token, size: 16),
                                const SizedBox(width: 4),
                                Flexible(child: Text(w.name,
                                  style: body(9, c: kTextSub),
                                  overflow: TextOverflow.ellipsis)),
                              ]),
                            ]),
                          ),
                        ]),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Perdants ─────────────────────────────────────
                if (losers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(children: [
                      Text('ÉLIMINÉS', style: cinzel(10, c: kTextDim, ls: 3)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8, runSpacing: 6, alignment: WrapAlignment.center,
                        children: losers.map((p) => Row(mainAxisSize: MainAxisSize.min, children: [
                          TokenWidget(tokenId: p.token, size: 22, isDead: true),
                          const SizedBox(width: 4),
                          Text(p.name, style: body(11, c: kTextDim)),
                        ])).toList(),
                      ),
                    ]),
                  ),

                const SizedBox(height: 24),

                // ── Bouton rejouer ───────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  child: Column(children: [
                    GestureDetector(
                      onTap: () => widget.ctrl.startGame(),
                      child: Container(
                        width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: fc.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: fc, width: 2)),
                        child: Text('↺ Rejouer', textAlign: TextAlign.center,
                          style: cinzel(16, c: fc, fw: FontWeight.w700))),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => HomeScreen()), (_) => false),
                      child: Container(
                        width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: kBord2)),
                        child: Text('🏠 Menu principal', textAlign: TextAlign.center,
                          style: cinzel(14, c: kTextSub))),
                    ),
                  ]),
                ),
                      ]),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}


// ─── Gège Fantôme overlay ─────────────────────────────────────────────────────
class _GegeGhostOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const _GegeGhostOverlay({required this.onDone});
  @override State<_GegeGhostOverlay> createState() => _GegeGhostOverlayState();
}
class _GegeGhostOverlayState extends State<_GegeGhostOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _opacity;
  late Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 25),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 25),
    ]).animate(_ac);
    _slide = Tween(begin: 0.0, end: -60.0).animate(
      CurvedAnimation(parent: _ac, curve: Curves.easeOut));
    _ac.forward().then((_) => widget.onDone());
  }
  @override void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) => AnimatedBuilder(
    animation: _ac,
    builder: (_, __) => Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Transform.translate(
            offset: Offset(0, _slide.value),
            child: Opacity(
              opacity: _opacity.value,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('👻', style: TextStyle(fontSize: 72)),
                const SizedBox(height: 8),
                Text('Gège attaque !',
                  style: TextStyle(fontSize: 18, color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black, blurRadius: 8)])),
              ]),
            ),
          ),
        ),
      ),
    ),
  );
}


// ═══════════════════════════════════════════════════════════
// RICHARD II — Animation d'échange de terrains
// ═══════════════════════════════════════════════════════════
class _RichardSwapOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const _RichardSwapOverlay({required this.onDone});
  @override State<_RichardSwapOverlay> createState() => _RichardSwapOverlayState();
}
class _RichardSwapOverlayState extends State<_RichardSwapOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _ac.forward().then((_) { if (mounted) widget.onDone(); });
  }
  @override void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    const purple = Color(0xFF9B59B6);
    return AnimatedBuilder(
      animation: _ac,
      builder: (_, __) {
        final t = _ac.value;
        final opacity = t < 0.1 ? t * 10 : t > 0.85 ? (1.0 - t) / 0.15 : 1.0;
        // Deux tuiles qui se croisent
        final offset1 = Offset(lerpDouble(-80, 80, t)!, 0);
        final offset2 = Offset(lerpDouble(80, -80, t)!, 0);
        // Particules
        final particles = List.generate(12, (i) {
          final angle = (i / 12) * 6.28 + t * 3.14;
          final r = 80 + 40 * t;
          return Offset(cos(angle) * r, sin(angle) * r * 0.5);
        });
        return Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: CustomPaint(
                painter: _SwapPainter(offset1, offset2, particles, purple, t),
                child: Center(
                  child: Text('👑', style: TextStyle(
                    fontSize: 48 + 20 * sin(t * 3.14),
                    shadows: [Shadow(color: purple.withValues(alpha: 0.8), blurRadius: 20)],
                  )),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SwapPainter extends CustomPainter {
  final Offset o1, o2;
  final List<Offset> particles;
  final Color color;
  final double t;
  _SwapPainter(this.o1, this.o2, this.particles, this.color, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..color = color.withValues(alpha: 0.7)..style = PaintingStyle.fill;
    // Tuile 1
    final rect1 = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center + o1, width: 60, height: 60), const Radius.circular(10));
    canvas.drawRRect(rect1, paint..color = color.withValues(alpha: 0.5));
    // Tuile 2
    final rect2 = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center + o2, width: 60, height: 60), const Radius.circular(10));
    canvas.drawRRect(rect2, paint..color = color.withValues(alpha: 0.5));
    // Particules
    paint.color = color.withValues(alpha: 0.6 * (1 - t));
    for (final p in particles) {
      canvas.drawCircle(center + p, 4, paint);
    }
  }

  @override
  bool shouldRepaint(_SwapPainter old) => true;
}

// ═══════════════════════════════════════════════════════════
// MATHIEU — Animation point qui fonce sur l'écran (3e attaque)
// ═══════════════════════════════════════════════════════════
class _MathieuBulletOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const _MathieuBulletOverlay({required this.onDone});
  @override State<_MathieuBulletOverlay> createState() => _MathieuBulletOverlayState();
}
class _MathieuBulletOverlayState extends State<_MathieuBulletOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scale = Tween(begin: 0.05, end: 4.0).animate(
      CurvedAnimation(parent: _ac, curve: Curves.easeIn));
    _opacity = TweenSequence([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_ac);
    _ac.forward().then((_) { if (mounted) widget.onDone(); });
  }
  @override void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) => AnimatedBuilder(
    animation: _ac,
    builder: (_, __) => Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: _opacity.value,
          child: Center(
            child: Transform.scale(
              scale: _scale.value,
              child: Container(
                width: 60, height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFCC0000),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0x88FF0000), blurRadius: 30, spreadRadius: 10)],
                ),
                child: const Center(child: Text('⚔️', style: TextStyle(fontSize: 28))),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════
// SCOTT — Animation contre-attaque (bouclier + flash)
// ═══════════════════════════════════════════════════════════
class _ScottCounterOverlay extends StatefulWidget {
  final VoidCallback onDone;
  final Map<String, int>? dice;
  const _ScottCounterOverlay({required this.onDone, this.dice});
  @override State<_ScottCounterOverlay> createState() => _ScottCounterOverlayState();
}
class _ScottCounterOverlayState extends State<_ScottCounterOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _opacity;
  late Animation<double> _scale;
  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_ac);
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.3, end: 1.2), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _ac, curve: Curves.elasticOut));
    _ac.forward().then((_) { if (mounted) widget.onDone(); });
  }
  @override void dispose() { _ac.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext ctx) => AnimatedBuilder(
    animation: _ac,
    builder: (_, __) => Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: _opacity.value,
          child: Center(
            child: Transform.scale(
              scale: _scale.value,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('🛡️', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 8),
                Text('CONTRE-ATTAQUE !',
                  style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900, color: Colors.orange,
                    shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                  )),
                if (widget.dice != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: kBg1.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      'D4(${widget.dice!['d4']})  D6(${widget.dice!['d6']})  →  ${widget.dice!['dmg']} dégâts',
                      style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
    ),
  );
}
