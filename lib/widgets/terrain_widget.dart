// lib/widgets/terrain_widget.dart
// Terrains avec images PNG + adjacences visibles + layout stable

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../data/game_data.dart';
import '../data/characters_data.dart';
import '../data/tokens_data.dart';
import 'theme.dart';

// ─── Plateau — remplace GridView par un layout fixe 2×3 ─────────────────────
// Utilise LayoutBuilder pour s'adapter EXACTEMENT à l'espace disponible
// sans jamais déborder ni disparaître.
class GameBoard extends StatelessWidget {
  final List<Terrain> terrainLayout;
  final List<Map<String, dynamic>> players;
  final int humanZoneIndex;
  final bool showAdjacent;
  final Set<int> targetableZones;
  final void Function(int)? onZoneTap;
  final Map<int, String> trappedZones;

  const GameBoard({
    super.key,
    required this.terrainLayout,
    required this.players,
    required this.humanZoneIndex,
    this.showAdjacent = true,
    this.targetableZones = const {},
    this.onZoneTap,
    this.trappedZones = const {},
  });

  @override
  Widget build(BuildContext context) {
    final adjacent = Set<int>.from(kAdjacences[humanZoneIndex]);
    return LayoutBuilder(builder: (ctx, bc) {
      // Calcule la taille de chaque tuile exactement
      const cols = 3;
      const rows = 2;
      const gap = 4.0;
      final tileW = (bc.maxWidth  - gap * (cols - 1)) / cols;
      final tileH = (bc.maxHeight - gap * (rows - 1)) / rows;

      return SizedBox(
        width: bc.maxWidth,
        height: bc.maxHeight,
        child: Stack(
          children: List.generate(6, (i) {
            final col = i % cols;
            final row = i ~/ cols;
            final left = col * (tileW + gap);
            final top  = row * (tileH + gap);
            final terrain = terrainLayout[i];
            final zonePlayers = players
                .where((p) => p['zoneIndex'] == i && p['alive'] == true)
                .toList();

            return Positioned(
              left: left, top: top,
              width: tileW, height: tileH,
              child: TerrainTile(
                terrain: terrain,
                playerTokenIds: zonePlayers,
                isCurrentZone: i == humanZoneIndex,
                isAdjacentZone: showAdjacent && adjacent.contains(i),
                isTargetable: targetableZones.contains(i),
                onTap: onZoneTap != null ? () => onZoneTap!(i) : null,
                trapIcon: trappedZones[i],
              ),
            );
          }),
        ),
      );
    });
  }
}

// ─── Tuile terrain ───────────────────────────────────────────────────────────
class TerrainTile extends StatelessWidget {
  final Terrain terrain;
  final List<Map<String, dynamic>> playerTokenIds;
  final bool isCurrentZone;
  final bool isAdjacentZone;
  final bool isTargetable;
  final VoidCallback? onTap;
  final String? trapIcon;

  const TerrainTile({
    super.key,
    required this.terrain,
    required this.playerTokenIds,
    this.isCurrentZone = false,
    this.isAdjacentZone = false,
    this.isTargetable = false,
    this.onTap,
    this.trapIcon,
  });

  @override
  Widget build(BuildContext context) {
    final zonePlayers = playerTokenIds; // already filtered by zone in GameBoard
    Color borderColor;
    double borderWidth;
    Color? glowColor;

    if (isCurrentZone)       { borderColor = kGold2; borderWidth = 3;   glowColor = kGold2; }
    else if (isTargetable)   { borderColor = kRed;   borderWidth = 2.5; glowColor = kRed; }
    else if (isAdjacentZone) { borderColor = kGold;  borderWidth = 2;   glowColor = null; }
    else                     { borderColor = kBord;  borderWidth = 1;   glowColor = null; }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: kBg2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: glowColor != null
              ? [BoxShadow(color: glowColor.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 1)]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Stack(children: [
            // ── Image de fond ──────────────────
            Positioned.fill(child: _TerrainImg(effect: terrain.effect)),

            // ── Dégradé bas pour lisibilité ────
            Positioned.fill(child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                  stops: const [0.35, 1.0],
                ),
              ),
            )),

            // ── Overlay adjacent (fond doré) ───
            if (isAdjacentZone && !isCurrentZone)
              Positioned.fill(child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: kGold.withValues(alpha: 0.10),
                ),
              )),

            // ── Nom + numéro en bas ─────────────
            Positioned(bottom: 0, left: 0, right: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(3, 0, 3, 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(terrain.name,
                      style: const TextStyle(
                        fontFamily: 'Cinzel', fontSize: 6.5,
                        color: Color(0xFFF0C040), fontWeight: FontWeight.w700,
                        shadows: [Shadow(color: Colors.black, blurRadius: 3)]),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(
                          color: _ec(terrain.effect).withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(terrain.num, style: TextStyle(
                          fontFamily: 'Cinzel', fontSize: 7.5,
                          color: _ec(terrain.effect), fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 2),
                      Text(_ei(terrain.effect),
                        style: const TextStyle(fontSize: 7)),
                    ]),
                  ],
                ),
              ),
            ),

            // ── Badge → accessible ──────────────
            if (isAdjacentZone && !isCurrentZone)
              Positioned(top: 3, left: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: kGold.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: [BoxShadow(color: kGold.withValues(alpha: 0.4), blurRadius: 4)],
                  ),
                  child: const Text('→', style: TextStyle(
                    fontSize: 9, color: Color(0xFF1A0D00),
                    fontWeight: FontWeight.w900)),
                )),

            // ── Badge ici ──────────────────────
            if (isCurrentZone)
              Positioned(top: 3, left: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: kGold2.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: [BoxShadow(color: kGold2.withValues(alpha: 0.5), blurRadius: 5)],
                  ),
                  child: const Text('★', style: TextStyle(
                    fontSize: 8, color: Color(0xFF1A0D00),
                    fontWeight: FontWeight.w900)),
                )),

            // ── Jetons des joueurs — au centre de la tuile ─
            if (zonePlayers.isNotEmpty)
              Positioned.fill(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _TokensOverlay(players: zonePlayers),
                    ],
                  ),
                ),
              ),
            // Trap indicator
            if (trapIcon != null)
              Positioned(
                bottom: 4, right: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange, width: 1.5),
                  ),
                  child: Text(trapIcon!, style: const TextStyle(fontSize: 16)),
                ),
              ),

            // ── Overlay ciblable ───────────────
            if (isTargetable)
              Positioned.fill(child: Container(
                decoration: BoxDecoration(
                  color: kRed.withValues(alpha: 0.15)),
                child: const Center(child: Text('🎯',
                  style: TextStyle(fontSize: 16))),
              )),
          ]),
        ),
      ),
    );
  }

  Color _ec(String e) => switch (e) {
    'vision'   => const Color(0xFF7B4FD4),
    'lumiere'  => const Color(0xFF1A9466),
    'tenebres' => const Color(0xFFCC2222),
    'damage9'  => kRed,
    'steal'    => kGold,
    'choice'   => const Color(0xFFB8860B),
    _ => kGold,
  };

  String _ei(String e) => switch (e) {
    'vision' => '🔮', 'lumiere' => '✨', 'tenebres' => '🌑',
    'damage9' => '🏹', 'steal' => '🗼', 'choice' => '🏪', _ => '?',
  };
}

// ─── Image terrain ───────────────────────────────────────────────────────────
class _TerrainImg extends StatelessWidget {
  final String effect;
  const _TerrainImg({required this.effect});

  @override
  Widget build(BuildContext context) {
    final path = terrainImagePath(effect);
    if (path == null) return _fallback(effect);
    return Image.asset(path, fit: BoxFit.contain,
      cacheWidth: 400, // images sources en 1060x1484 — bien trop grand pour une tuile de plateau
      errorBuilder: (_, __, ___) => _fallback(effect));
  }

  Widget _fallback(String e) => Container(
    color: kBg2,
    child: Center(child: Text(_ei(e),
      style: const TextStyle(fontSize: 24))));

  String _ei(String e) => switch (e) {
    'vision' => '🔮', 'lumiere' => '⛪', 'tenebres' => '🔨',
    'damage9' => '🏹', 'steal' => '🗼', 'choice' => '🏪', _ => '?',
  };
}

// ─── Jetons overlay ──────────────────────────────────────────────────────────
class _TokensOverlay extends StatelessWidget {
  final List<Map<String, dynamic>> players; // {tokenId, revealed, faction}
  const _TokensOverlay({required this.players});

  @override
  Widget build(BuildContext context) {
    final shown = players.take(5).toList();
    const tileSize = 26.0;
    const overlap = 8.0;
    final totalW = tileSize + (shown.length - 1) * (tileSize - overlap);

    return SizedBox(
      width: totalW.clamp(tileSize, 150),
      height: tileSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: shown.asMap().entries.map((e) {
          final p = e.value;
          final tokenId = p['tokenId'] as String? ?? '';
          final revealed = p['revealed'] as bool? ?? false;
          final faction = p['faction'] as String? ?? '';
          final token = findToken(tokenId);
          final imgPath = token?.imagePath;

          // Couleur du cadre selon faction si révélé
          Color borderColor = Colors.white;
          double borderWidth = 1.5;
          List<BoxShadow> shadows = const [BoxShadow(color: Colors.black, blurRadius: 4)];

          if (revealed && faction.isNotEmpty) {
            borderColor = _factionColor(faction);
            borderWidth = 2.5;
            shadows = [
              BoxShadow(color: Colors.black, blurRadius: 4),
              BoxShadow(color: borderColor.withValues(alpha: 0.6), blurRadius: 8, spreadRadius: 0.5),
            ];
          }

          return Positioned(
            left: e.key * (tileSize - overlap),
            child: Container(
              width: tileSize, height: tileSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: borderWidth),
                boxShadow: shadows,
              ),
              child: ClipOval(
                child: imgPath != null
                  ? Image.asset(imgPath, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallback(token?.fallbackEmoji ?? '?'))
                  : _fallback('?'),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _factionColor(String f) => switch (f) {
    'hunter'  => const Color(0xFF1E6ECC),
    'shadow'  => const Color(0xFFCC2222),
    'neutral' => const Color(0xFFB8860B),
    _         => Colors.white,
  };

  Widget _fallback(String emoji) => Container(
    color: const Color(0xFF2A2A2A),
    child: Center(child: Text(emoji, style: const TextStyle(fontSize: 10))));
}

// ─── Légende adjacence ───────────────────────────────────────────────────────
class AdjacencyLegend extends StatelessWidget {
  const AdjacencyLegend({super.key});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _dot(kGold2),
      const SizedBox(width: 3),
      Text('Ta zone', style: body(8, c: kTextSub)),
      const SizedBox(width: 8),
      _dot(kGold),
      const SizedBox(width: 3),
      Text('Accessible (→)', style: body(8, c: kTextSub)),
    ],
  );

  Widget _dot(Color c) => Container(
    width: 7, height: 7,
    decoration: BoxDecoration(shape: BoxShape.circle, color: c));
}

// ─── Carte personnage complète ────────────────────────────────────────────────
class CharacterCardFull extends StatelessWidget {
  final String characterId;
  final String characterName;
  final String faction;
  final int hp;
  final int wounds;
  final String ability;
  final String winCondition;
  final List<String> equipmentNames;
  final bool hideHp;

  const CharacterCardFull({
    super.key,
    required this.characterId,
    required this.characterName,
    required this.faction,
    required this.hp,
    required this.wounds,
    required this.ability,
    required this.winCondition,
    this.equipmentNames = const [],
    this.hideHp = false,
  });

  @override
  Widget build(BuildContext context) {
    final fc = factionColor(faction);
    final fbg = factionBg(faction);
    final imgPath = characterImagePath(characterId);
    final pct = ((hp - wounds) / hp).clamp(0.0, 1.0);
    final hpColor = pct < 0.3 ? kRed : pct < 0.6 ? kGold : kGreen;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: fc, width: 2),
        boxShadow: [
          BoxShadow(color: fc.withValues(alpha: 0.3), blurRadius: 20),
          const BoxShadow(color: Colors.black54, blurRadius: 10),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: SizedBox(
            height: 180, width: double.infinity,
            child: imgPath != null
              ? Image.asset(imgPath, fit: BoxFit.cover,
                  cacheWidth: 560, cacheHeight: 360,
                  errorBuilder: (_, __, ___) => _fallbackBg(fc, fbg))
              : _fallbackBg(fc, fbg),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Row(children: [
              Expanded(child: Text(characterName,
                style: cinzel(16, c: kGold2, fw: FontWeight.w900))),
              FactionBadge(faction, small: true),
            ]),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: surfaceDecor(border: kBord),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('🗡 Blessures : $wounds',
                    style: cinzel(10, c: hpColor)),
                  const Spacer(),
                  if (!hideHp) Text('/ $hp PV', style: body(10, c: kTextDim)),
                ]),
                if (!hideHp) ...[
                  const SizedBox(height: 4),
                  ClipRRect(borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct, minHeight: 5,
                      backgroundColor: kBord,
                      valueColor: AlwaysStoppedAnimation(hpColor))),
                ],
              ]),
            ),
            const SizedBox(height: 6),
            _InfoRow('⚡', 'CAPACITÉ', ability),
            const SizedBox(height: 4),
            _InfoRow('🏆', 'OBJECTIF', winCondition),
            if (equipmentNames.isNotEmpty) ...[
              const SizedBox(height: 4),
              _InfoRow('⚔️', 'ÉQUIPEMENTS', equipmentNames.join(', ')),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _fallbackBg(Color fc, Color fbg) => Container(
    color: fbg,
    child: Center(child: Text(
      faction == 'hunter' ? '⚔️' : faction == 'shadow' ? '🌑' : '⭐',
      style: const TextStyle(fontSize: 60))));
}

class _InfoRow extends StatelessWidget {
  final String icon, label, text;
  const _InfoRow(this.icon, this.label, this.text);
  @override
  Widget build(BuildContext ctx) => Container(
    width: double.infinity, padding: const EdgeInsets.all(8),
    decoration: surfaceDecor(border: kBord),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(icon, style: const TextStyle(fontSize: 12)),
      const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: cinzel(8, c: kTextSub, ls: 1)),
        const SizedBox(height: 1),
        Text(text, style: body(11)),
      ])),
    ]),
  );
}
