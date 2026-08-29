// lib/widgets/shine_effect.dart
// Badge étoile en haut à droite des cartes personnage, selon le nombre de
// victoires jouées avec ce personnage :
//   1+ victoire    → étoile de bronze
//   10+ victoires  → étoile argentée
//   50+ victoires  → étoile dorée
//   100+ victoires → étoile arc-en-ciel

import 'package:flutter/material.dart';

enum ShineTier { none, bronze, silver, gold, rainbow }

ShineTier shineTierFor(int gamesPlayed) {
  if (gamesPlayed >= 100) return ShineTier.rainbow;
  if (gamesPlayed >= 50) return ShineTier.gold;
  if (gamesPlayed >= 10) return ShineTier.silver;
  if (gamesPlayed >= 1) return ShineTier.bronze;
  return ShineTier.none;
}

/// Enveloppe `child` (typiquement l'illustration d'une carte personnage)
/// avec un badge étoile fixe en haut à droite. N'affiche rien de spécial
/// si `tier` est `ShineTier.none` — le child est alors rendu tel quel.
class ShineOverlay extends StatelessWidget {
  final Widget child;
  final ShineTier tier;
  const ShineOverlay({super.key, required this.child, required this.tier});

  @override
  Widget build(BuildContext context) {
    if (tier == ShineTier.none) return child;
    return Stack(fit: StackFit.passthrough, children: [
      child,
      Positioned(
        top: 8, right: 8,
        child: IgnorePointer(
          child: _StarBadge(tier: tier),
        ),
      ),
    ]);
  }
}

class _StarBadge extends StatelessWidget {
  final ShineTier tier;
  const _StarBadge({required this.tier});

  static const _bronzeColors = [Color(0xFFCD8B5E), Color(0xFF8C5A32)];
  static const _silverColors = [Color(0xFFE8E8E8), Color(0xFFB0B0B0)];
  static const _goldColors = [Color(0xFFFFF3B0), Color(0xFFD4A017)];
  static const _rainbowColors = [
    Color(0xFFFF3B3B), Color(0xFFFFA83B), Color(0xFFFFF23B),
    Color(0xFF3BFF6B), Color(0xFF3BC0FF), Color(0xFF7A3BFF), Color(0xFFFF3BE0),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = switch (tier) {
      ShineTier.gold => _goldColors,
      ShineTier.rainbow => _rainbowColors,
      ShineTier.silver => _silverColors,
      _ => _bronzeColors,
    };
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        color: Colors.black45,
        shape: BoxShape.circle,
      ),
      child: ShaderMask(
        shaderCallback: (rect) => LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect),
        child: const Icon(Icons.star, size: 20, color: Colors.white),
      ),
    );
  }
}
