// lib/screens/gallery_screen.dart
// Galerie de tous les personnages

import 'package:flutter/material.dart';
import '../data/game_data.dart';
import '../data/characters_data.dart';
import '../models/models.dart';
import '../widgets/theme.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});
  @override State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String _filter = 'all'; // all | hunter | shadow | neutral

  final _factions = [
    ('all',     'Tous',    kGold),
    ('hunter',  'Hunters', const Color(0xFF4A90D9)),
    ('shadow',  'Shadows', kRed),
    ('neutral', 'Neutres', const Color(0xFFB8860B)),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() => setState(() =>
        _filter = _factions[_tabs.index].$1));
  }

  @override void dispose() { _tabs.dispose(); super.dispose(); }

  List<CharacterCard> get filtered => _filter == 'all'
      ? kAllCharacters
      : kAllCharacters.where((c) => c.faction.name == _filter).toList();

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      backgroundColor: kBg0,
      appBar: AppBar(
        backgroundColor: kBg2, elevation: 0,
        title: Text('Galerie des Personnages', style: cinzel(16, c: kGold2)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: kGold,
          labelColor: kGold,
          unselectedLabelColor: kTextSub,
          labelStyle: const TextStyle(fontFamily: 'Cinzel', fontSize: 11),
          tabs: _factions.map((f) => Tab(text: f.$2)).toList(),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 300,
          childAspectRatio: 0.58,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: filtered.length,
        itemBuilder: (ctx, i) => _CharacterCard(char: filtered[i]),
      ),
    );
  }
}

// ─── Carte personnage dans la galerie ────────────────────────────────────────
class _CharacterCard extends StatefulWidget {
  final CharacterCard char;
  const _CharacterCard({required this.char});
  @override State<_CharacterCard> createState() => _CharacterCardState();
}

class _CharacterCardState extends State<_CharacterCard>
    with SingleTickerProviderStateMixin {
  bool _flipped = false;
  late AnimationController _ac;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _anim = CurvedAnimation(parent: _ac, curve: Curves.easeInOut);
  }

  @override void dispose() { _ac.dispose(); super.dispose(); }

  void _flip() {
    if (_flipped) { _ac.reverse(); } else { _ac.forward(); }
    setState(() => _flipped = !_flipped);
  }

  @override
  Widget build(BuildContext ctx) {
    final c = widget.char;
    final fc = factionColor(c.faction.name);
    final fbg = factionBg(c.faction.name);
    final imgPath = characterImagePath(c.id);

    return GestureDetector(
      onTap: _flip,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) {
          final angle = _anim.value * 3.14159;
          final showBack = _anim.value > 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: showBack
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(3.14159),
                  child: _buildBack(c, fc, fbg))
              : _buildFront(c, fc, fbg, imgPath),
          );
        },
      ),
    );
  }

  Widget _buildFront(CharacterCard c, Color fc, Color fbg, String? imgPath) {
    return Container(
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fc, width: 2),
        boxShadow: [
          BoxShadow(color: fc.withValues(alpha: 0.2), blurRadius: 12),
          const BoxShadow(color: Colors.black45, blurRadius: 6),
        ],
      ),
      child: Column(children: [
        // Illustration
        Expanded(
          flex: 6,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: imgPath != null
              ? Image.asset(imgPath, fit: BoxFit.cover, width: double.infinity,
                  errorBuilder: (_, __, ___) => _fallback(fc, fbg, c.icon))
              : _fallback(fc, fbg, c.icon),
          ),
        ),
        // Infos
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(c.name,
                  style: cinzel(14, c: kGold2, fw: FontWeight.w900),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
                _HpBadge(hp: c.hp, faction: c.faction.name),
              ]),
              const SizedBox(height: 3),
              FactionBadge(c.faction.name),
              const SizedBox(height: 4),
              Text('Appuie pour voir les détails →',
                style: body(9, c: kTextDim),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildBack(CharacterCard c, Color fc, Color fbg) {
    final freq = c.abilityRepeatable ? '🔄 Chaque tour' : '🔒 1 fois/partie';
    return Container(
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fc, width: 2),
        boxShadow: [BoxShadow(color: fc.withValues(alpha: 0.2), blurRadius: 12)],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: fbg.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: [
            Text(c.icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(c.name, style: cinzel(14, c: kGold2, fw: FontWeight.w900),
              textAlign: TextAlign.center),
            const SizedBox(height: 3),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              FactionBadge(c.faction.name, small: true),
              const SizedBox(width: 6),
              _HpBadge(hp: c.hp, faction: c.faction.name),
            ]),
          ]),
        ),
        const SizedBox(height: 8),
        // Capacité
        _InfoRow('⚡', 'CAPACITÉ', c.ability, suffix: freq),
        const SizedBox(height: 6),
        // Condition victoire
        _InfoRow('🏆', 'OBJECTIF', c.winCondition),
        const Spacer(),
        Text('Appuie pour revenir',
          style: body(9, c: kTextDim), textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _fallback(Color fc, Color fbg, String icon) => Container(
    color: fbg,
    child: Center(child: Text(icon, style: const TextStyle(fontSize: 50))));
}

class _HpBadge extends StatelessWidget {
  final int hp;
  final String faction;
  const _HpBadge({required this.hp, required this.faction});

  @override
  Widget build(BuildContext ctx) {
    final col = faction == 'hunter' ? const Color(0xFF4A90D9)
        : faction == 'shadow' ? kRed : const Color(0xFFB8860B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: col.withValues(alpha: 0.6)),
      ),
      child: Text('$hp PV', style: cinzel(10, c: col)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String icon, label, text;
  final String? suffix;
  const _InfoRow(this.icon, this.label, this.text, {this.suffix});

  @override
  Widget build(BuildContext ctx) => Container(
    width: double.infinity, padding: const EdgeInsets.all(8),
    decoration: surfaceDecor(border: kBord),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('$icon $label', style: cinzel(8, c: kTextSub, ls: 1)),
        if (suffix != null) ...[
          const Spacer(),
          Text(suffix!, style: body(8, c: kGold)),
        ],
      ]),
      const SizedBox(height: 3),
      Text(text, style: body(11)),
    ]),
  );
}
