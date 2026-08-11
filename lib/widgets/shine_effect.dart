// lib/widgets/shine_effect.dart
// Effet brillant animé sur les cartes personnage, selon le nombre de
// parties jouées avec ce personnage :
//   10+ parties  → brillance simple (argentée)
//   100+ parties → brillance dorée
//   500+ parties → brillance arc-en-ciel

import 'package:flutter/material.dart';

enum ShineTier { none, silver, gold, rainbow }

ShineTier shineTierFor(int gamesPlayed) {
  if (gamesPlayed >= 500) return ShineTier.rainbow;
  if (gamesPlayed >= 100) return ShineTier.gold;
  if (gamesPlayed >= 10) return ShineTier.silver;
  return ShineTier.none;
}

/// Enveloppe `child` (typiquement l'illustration d'une carte personnage)
/// avec un balayage lumineux diagonal animé en continu. N'affiche rien de
/// spécial si `tier` est `ShineTier.none` — le child est alors rendu tel quel.
class ShineOverlay extends StatefulWidget {
  final Widget child;
  final ShineTier tier;
  const ShineOverlay({super.key, required this.child, required this.tier});

  @override
  State<ShineOverlay> createState() => _ShineOverlayState();
}

class _ShineOverlayState extends State<ShineOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.tier == ShineTier.rainbow ? 2200 : 2800),
    )..repeat();
  }

  @override
  void dispose() { _ac.dispose(); super.dispose(); }

  List<Color> get _colors {
    switch (widget.tier) {
      case ShineTier.silver:
        return const [
          Colors.transparent, Color(0x00FFFFFF), Color(0xCCFFFFFF), Color(0x00FFFFFF), Colors.transparent,
        ];
      case ShineTier.gold:
        return const [
          Colors.transparent, Color(0x00FFD700), Color(0xE6FFD700), Color(0xFFFFF3B0), Color(0xE6FFD700), Color(0x00FFD700), Colors.transparent,
        ];
      case ShineTier.rainbow:
        return const [
          Colors.transparent,
          Color(0xCCFF3B3B), Color(0xCCFFA83B), Color(0xCCFFF23B),
          Color(0xCC3BFF6B), Color(0xCC3BC0FF), Color(0xCC7A3BFF), Color(0xCCFF3BE0),
          Colors.transparent,
        ];
      case ShineTier.none:
        return const [Colors.transparent, Colors.transparent];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tier == ShineTier.none) return widget.child;
    return ClipRect(
      child: Stack(fit: StackFit.passthrough, children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _ac,
              builder: (_, __) {
                // Balayage diagonal : la bande lumineuse traverse le cadre
                // de coin à coin en boucle. Superposition semi-transparente
                // classique (pas de ShaderMask) — se fond naturellement avec
                // l'image en dessous, quelle que soit son contenu.
                final t = _ac.value; // 0..1
                final shift = (t * 3) - 1; // -1 → 2, pour sortir des 2 côtés
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-1 + shift, -1),
                      end: Alignment(0 + shift, 1),
                      colors: _colors,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }
}
