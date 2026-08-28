// lib/widgets/reveal_screen.dart
// Animation plein écran de révélation d'un personnage — PARTAGÉE entre le
// solo et le multijoueur (extrait de _RevealFullScreen, solo_screen.dart),
// pour garantir un rendu VISUELLEMENT IDENTIQUE dans les deux modes.
import 'package:flutter/material.dart';
import '../models/models.dart';
import 'card_viewer.dart';
import '../services/persistence.dart';
import 'theme.dart';
import '../data/characters_data.dart';
import '../data/game_data.dart';

class RevealFullScreen extends StatefulWidget {
  final Player player;
  final VoidCallback onDone;
  final bool isRealReveal; // false = simple aperçu privé (Vision Suprême)
  final List<Player>? allPlayers; // pour détecter les interactions entre personnages
  const RevealFullScreen({required this.player, required this.onDone, this.isRealReveal = true, this.allPlayers});
  @override State<RevealFullScreen> createState() => RevealFullScreenState();
}

class RevealFullScreenState extends State<RevealFullScreen>
    with TickerProviderStateMixin {
  late AnimationController _enterAc, _pulseAc;
  late Animation<double> _scale, _fade, _pulse;
  CharInteraction? _interaction;

  @override
  void initState() {
    super.initState();
    _enterAc = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 500));
    _pulseAc = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _enterAc, curve: Curves.easeOutBack));
    _fade  = CurvedAnimation(parent: _enterAc, curve: Curves.easeOut);
    _pulse = Tween<double>(begin: 1.0, end: 1.05)
        .animate(CurvedAnimation(parent: _pulseAc, curve: Curves.easeInOut));
    _enterAc.forward();
    // Réplique de révélation — visible et audible de tous (placeholder audio).
    // Jason déguisé : sonne comme le personnage imité. Une fois le
    // déguisement perdu (disguiseCharIdOverride==null), sonne comme lui-même.
    if (widget.isRealReveal && widget.player.character != null) {
      final voiceId = widget.player.disguiseCharIdOverride ?? widget.player.character!.id;
      audio.playRevealVoice(voiceId);
      // Interaction entre personnages : si un autre joueur déjà révélé
      // matche une interaction connue, jouer sa réplique juste après (léger
      // délai pour ne pas se superposer à la voix de révélation).
      if (widget.allPlayers != null) {
        final effId = widget.player.disguiseCharIdOverride ?? widget.player.character!.id;
        final otherRevealed = widget.allPlayers!
            .where((p) => p.uid != widget.player.uid && p.alive && p.revealed && p.character != null)
            .map((p) => p.character!.id).toSet();
        final it = findRevealInteraction(effId, otherRevealed);
        if (it != null) {
          _interaction = it;
          Future.delayed(const Duration(milliseconds: 4000), () {
            if (mounted) audio.playInteractionVoice(it.key);
          });
        }
      }
    }
    // Auto-dismiss après 3.5s
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() { _enterAc.dispose(); _pulseAc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    final p  = widget.player;
    final c  = p.character;
    // Jason (Caméléon) : affiche le déguisement (Hunter/Shadow imité), pas sa
    // vraie identité — sinon son mécanisme unique est visuellement ignoré
    // lors de l'écran de révélation plein écran.
    final displayChar = p.disguiseCharIdOverride != null
        ? kAllCharacters.where((ch) => ch.id == p.disguiseCharIdOverride).firstOrNull ?? c
        : c;
    final fc = displayChar != null ? factionColor(displayChar.faction.name) : kGold;
    final fb = displayChar != null ? factionBg(displayChar.faction.name) : kBg2;
    final imgPath = displayChar != null ? effectiveCharacterImagePath(displayChar.id) : null;
    final fLabel  = displayChar?.faction.name == 'hunter' ? '🔵 HUNTER'
        : displayChar?.faction.name == 'shadow' ? '🔴 SHADOW' : '🟡 NEUTRE';

    return GestureDetector(
      onTap: widget.onDone,
      child: AnimatedBuilder(
        animation: Listenable.merge([_enterAc, _pulseAc]),
        builder: (_, __) => FadeTransition(
          opacity: _fade,
          child: Container(
            color: Colors.black87,
            child: Stack(children: [
              // Fond coloré
              Positioned.fill(child: Container(
                decoration: BoxDecoration(gradient: RadialGradient(
                  center: Alignment.center, radius: 1.2,
                  colors: [fc.withValues(alpha: 0.2), Colors.transparent])))),

              // Carte centrée
              Center(child: ScaleTransition(scale: _scale,
                child: ScaleTransition(scale: _pulse,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 460),
                    margin: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: kBg2,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: fc, width: 3),
                      boxShadow: [
                        BoxShadow(color: fc.withValues(alpha: 0.7), blurRadius: 50),
                        BoxShadow(color: fc.withValues(alpha: 0.3), blurRadius: 100),
                      ]),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      // Illustration — carte ENTIÈRE (ratio 2:3)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(height: 300,
                            child: AspectRatio(aspectRatio: 2 / 3,
                              child: ShineOverlay(
                                tier: shineTierFor(Prefs.gamesWonWith(displayChar?.name ?? '')),
                                child: imgPath != null
                                  ? Image.asset(imgPath, fit: BoxFit.cover,
                                      cacheWidth: 800, cacheHeight: 1200,
                                      errorBuilder: (_, __, ___) => Container(color: fb,
                                        child: Center(child: Text(displayChar?.icon ?? '?',
                                          style: const TextStyle(fontSize: 72)))))
                                  : Container(color: fb,
                                      child: Center(child: Text(displayChar?.icon ?? '?',
                                        style: const TextStyle(fontSize: 72)))),
                              ))))),
                      // Infos
                      Padding(padding: const EdgeInsets.all(20),
                        child: Column(children: [
                        Text('${p.name} s\'est révélé !',
                          style: cinzel(22, c: fc, fw: FontWeight.w900),
                          textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                          decoration: BoxDecoration(
                            color: fc.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: fc, width: 1.5)),
                          child: Text(fLabel, style: cinzel(14, c: fc, fw: FontWeight.w700))),
                        if (displayChar != null) ...[
                          const SizedBox(height: 8),
                          Text('Il est ${displayChar.name}',
                            style: cinzel(16, c: kGold2, fw: FontWeight.w700)),
                        ],
                        if (widget.isRealReveal && c != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: kBg3, borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: fc.withValues(alpha: 0.4))),
                            child: Text('« ${revealQuoteFor(p.disguiseCharIdOverride ?? c.id)} »',
                              style: body(12, c: kTextSub, fw: FontWeight.w600),
                              textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                        if (_interaction != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: kGold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: kGold.withValues(alpha: 0.5))),
                            child: Text('💬 ${_interaction!.text}',
                              style: body(12, c: kGold2, fw: FontWeight.w600),
                              textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text('Toucher pour continuer', style: body(10, c: kTextDim)),
                      ])),
                    ]),
                  ),
                ))),

              // Particules ✨
              for (final pos in [
                [0.05, 0.08], [0.92, 0.08], [0.05, 0.92], [0.92, 0.92],
                [0.5, 0.04], [0.5, 0.96], [0.04, 0.5], [0.96, 0.5],
              ])
                Positioned(
                  left: pos[0] * MediaQuery.of(ctx).size.width,
                  top:  pos[1] * MediaQuery.of(ctx).size.height,
                  child: AnimatedBuilder(animation: _pulseAc,
                    builder: (_, __) => Opacity(
                      opacity: (_pulseAc.value * 0.8).clamp(0.0, 1.0),
                      child: Text('✨',
                        style: TextStyle(fontSize: 14 + _pulseAc.value * 10))))),
            ]),
          ),
        ),
      ),
    );
  }
}
