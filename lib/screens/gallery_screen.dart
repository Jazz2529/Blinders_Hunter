// lib/screens/gallery_screen.dart
// Catalogue : Galerie des personnages + Galerie des cartes de jeu

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../data/game_data.dart';
import '../data/characters_data.dart';
import '../models/models.dart';
import '../widgets/theme.dart';
import '../widgets/shine_effect.dart';
import '../services/persistence.dart';
import '../data/cosmetics_data.dart';
import '../widgets/card_viewer.dart';

// ═══════════════════════════════════════════════════════════
// ÉCRAN PRINCIPAL — 2 onglets : Personnages / Cartes
// ═══════════════════════════════════════════════════════════
class CardCatalogScreen extends StatefulWidget {
  const CardCatalogScreen({super.key});
  @override State<CardCatalogScreen> createState() => _CardCatalogScreenState();
}

class _CardCatalogScreenState extends State<CardCatalogScreen>
    with SingleTickerProviderStateMixin {
  late TabController _mainTabs;

  @override
  void initState() {
    super.initState();
    _mainTabs = TabController(length: 2, vsync: this);
  }

  @override void dispose() { _mainTabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      backgroundColor: kBg0,
      appBar: AppBar(
        backgroundColor: kBg2, elevation: 0,
        title: Text('📚 Catalogue', style: cinzel(16, c: kGold2)),
        bottom: TabBar(
          controller: _mainTabs,
          indicatorColor: kGold,
          labelColor: kGold,
          unselectedLabelColor: kTextSub,
          labelStyle: const TextStyle(fontFamily: 'Cinzel', fontSize: 12),
          tabs: const [
            Tab(text: '🎭  Personnages'),
            Tab(text: '🃏  Cartes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _mainTabs,
        children: const [
          _CharacterGalleryBody(),
          _CardDeckGalleryBody(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ONGLET 1 — Galerie des personnages (filtre par faction)
// ═══════════════════════════════════════════════════════════
class _CharacterGalleryBody extends StatefulWidget {
  const _CharacterGalleryBody();
  @override State<_CharacterGalleryBody> createState() => _CharacterGalleryBodyState();
}

class _CharacterGalleryBodyState extends State<_CharacterGalleryBody> {
  String _filter = 'all'; // all | hunter | shadow | neutral

  final _factions = [
    ('all',     'Tous',    kGold),
    ('hunter',  'Hunters', const Color(0xFF4A90D9)),
    ('shadow',  'Shadows', kRed),
    ('neutral', 'Neutres', const Color(0xFFB8860B)),
  ];

  List<CharacterCard> get filtered => _filter == 'all'
      ? kAllCharacters
      : kAllCharacters.where((c) => c.faction.name == _filter).toList();

  @override
  Widget build(BuildContext ctx) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: SizedBox(
          height: 34,
          child: ListView(scrollDirection: Axis.horizontal, children: _factions.map((f) {
            final selected = _filter == f.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(f.$2, style: cinzel(11, c: selected ? const Color(0xFF1A0D00) : f.$3)),
                selected: selected,
                selectedColor: f.$3,
                backgroundColor: kBg2,
                side: BorderSide(color: f.$3.withValues(alpha: 0.6)),
                onSelected: (_) => setState(() => _filter = f.$1),
              ),
            );
          }).toList()),
        ),
      ),
      Expanded(
        child: GridView.builder(
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
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════
// ONGLET 2 — Galerie des cartes de jeu (filtre par deck)
// ═══════════════════════════════════════════════════════════
class _CardDeckGalleryBody extends StatefulWidget {
  const _CardDeckGalleryBody();
  @override State<_CardDeckGalleryBody> createState() => _CardDeckGalleryBodyState();
}

class _CardDeckGalleryBodyState extends State<_CardDeckGalleryBody> {
  String _filter = 'all'; // all | vision | lumiere | tenebres

  final _decks = [
    ('all',      'Toutes',    kGold),
    ('vision',   'Vision',    kVisionBg),
    ('lumiere',  'Lumière',   kLumiereBg),
    ('tenebres', 'Ténèbres',  kTenebresBg),
  ];

  List<GameCard> get filtered {
    final all = [...kVisionCards, ...kLumiereCards, ...kTenebresCards];
    // Dédoublonner par nom (les cartes en plusieurs exemplaires ne s'affichent qu'une fois)
    final seen = <String>{};
    final unique = all.where((c) => seen.add(c.name)).toList();
    if (_filter == 'all') return unique;
    return unique.where((c) => c.deck.name == _filter).toList();
  }

  @override
  Widget build(BuildContext ctx) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: SizedBox(
          height: 34,
          child: ListView(scrollDirection: Axis.horizontal, children: _decks.map((d) {
            final selected = _filter == d.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(d.$2, style: cinzel(11, c: selected ? const Color(0xFF1A0D00) : d.$3)),
                selected: selected,
                selectedColor: d.$3,
                backgroundColor: kBg2,
                side: BorderSide(color: d.$3.withValues(alpha: 0.6)),
                onSelected: (_) => setState(() => _filter = d.$1),
              ),
            );
          }).toList()),
        ),
      ),
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 300,
            childAspectRatio: 0.62,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: filtered.length,
          itemBuilder: (ctx, i) => _GameCardTile(card: filtered[i]),
        ),
      ),
    ]);
  }
}

// ─── Vignette carte de jeu (Vision/Lumière/Ténèbres) ────────────────────────
class _GameCardTile extends StatelessWidget {
  final GameCard card;
  const _GameCardTile({required this.card});

  void _showFull(BuildContext ctx) {
    final dc = deckColor(card.deck.name);
    final imgPath = anyCardImagePath(card.effect);
    showDialog(context: ctx, barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (dctx) {
        final size = MediaQuery.of(dctx).size;
        // Plein écran pour l'admirer — l'illustration prend la majorité de
        // l'espace disponible, comme showFullCardDialog pour les personnages.
        double imgH = size.height * 0.62;
        double imgW = imgH * (2 / 3);
        if (imgW > size.width * 0.85) {
          imgW = size.width * 0.85;
          imgH = imgW * (3 / 2);
        }
        return GestureDetector(
          onTap: () => Navigator.pop(dctx),
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: size.width * 0.92,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: imgW, height: imgH,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(imgW * 0.045),
                      boxShadow: [BoxShadow(color: dc.withValues(alpha: 0.5), blurRadius: 30, spreadRadius: 2)],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(imgW * 0.045),
                      child: imgPath != null
                        ? Image.asset(imgPath, fit: BoxFit.contain,
                            cacheWidth: (imgW * 2).round(), cacheHeight: (imgH * 2).round(),
                            errorBuilder: (_, __, ___) => Container(color: dc.withValues(alpha: 0.1),
                              child: Center(child: Text(deckIcon(card.deck.name), style: const TextStyle(fontSize: 84)))))
                        : Container(color: dc.withValues(alpha: 0.1),
                            child: Center(child: Text(deckIcon(card.deck.name), style: const TextStyle(fontSize: 84)))),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kBg2, borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: dc, width: 2),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(card.name, style: cinzel(18, c: kGold2, fw: FontWeight.w900), textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(card.text, style: body(13), textAlign: TextAlign.center),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Text('Touche l\'écran pour fermer', style: body(12, c: kTextDim)),
            ]),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext ctx) {
    final dc = deckColor(card.deck.name);
    final imgPath = anyCardImagePath(card.effect);
    return GestureDetector(
      onTap: () => _showFull(ctx),
      child: Container(
        decoration: BoxDecoration(
          color: kBg2, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: dc, width: 2),
          boxShadow: [BoxShadow(color: dc.withValues(alpha: 0.15), blurRadius: 10)],
        ),
        child: Column(children: [
          Expanded(
            flex: 6,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: imgPath != null
                ? Image.asset(imgPath, fit: BoxFit.contain, width: double.infinity,
                    errorBuilder: (_, __, ___) => Container(color: dc.withValues(alpha: 0.1),
                      child: Center(child: Text(deckIcon(card.deck.name),
                        style: const TextStyle(fontSize: 40)))))
                : Container(color: dc.withValues(alpha: 0.1),
                    child: Center(child: Text(deckIcon(card.deck.name),
                      style: const TextStyle(fontSize: 40)))),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(card.name, style: cinzel(12, c: kGold2, fw: FontWeight.w900),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Expanded(child: Text(card.text, style: body(9, c: kTextSub),
                  maxLines: 4, overflow: TextOverflow.ellipsis)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ANCIEN ÉCRAN (conservé pour compatibilité — redirige vers le catalogue)
// ═══════════════════════════════════════════════════════════
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});
  @override
  Widget build(BuildContext ctx) => const CardCatalogScreen();
}

// ─── Carte personnage dans la galerie ────────────────────────────────────────
class _CharacterCard extends StatefulWidget {
  final CharacterCard char;
  const _CharacterCard({required this.char});

  @override
  State<_CharacterCard> createState() => _CharacterCardState();
}

class _CharacterCardState extends State<_CharacterCard> {
  @override
  Widget build(BuildContext ctx) {
    final c = widget.char;
    final fc = factionColor(c.faction.name);
    final fbg = factionBg(c.faction.name);
    final imgPath = effectiveCharacterImagePath(c.id);
    // Tous les skins POSSÉDÉS pour ce personnage : l'apparence de base
    // (toujours "possédée") + tous les cosmétiques débloqués en boutique
    // pour lui. S'il y en a plus d'un, on affiche un badge permettant de
    // choisir lequel afficher.
    final ownedCosmetics = Prefs.ownedCosmetics();
    final ownedSkinsForChar = cosmeticsFor(CosmeticCategory.character, c.id)
        .where((item) => ownedCosmetics.contains(item.id)).toList();
    final hasMultipleSkins = ownedSkinsForChar.isNotEmpty;

    return GestureDetector(
      // Affiche la carte en plein écran pour l'admirer — un nouveau clic
      // sur l'image (ou n'importe où) referme et revient au catalogue,
      // via showFullCardDialog (même écran que celui utilisé en partie).
      onTap: () => showFullCardDialog(ctx, c),
      // [DEBUG UNIQUEMENT] Appui long : ajoute 15 victoires factices à ce
      // personnage, pour tester les paliers d'effet brillant sans avoir à
      // rejouer des dizaines de parties. Disparaît automatiquement en
      // dehors du mode debug (flutter run), comme le bouton +or.
      onLongPress: !kDebugMode ? null : () {
        for (var i = 0; i < 15; i++) { Prefs.debugAddWin(c.name); }
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text('[DEBUG] +15 victoires pour ${c.name} (total : ${Prefs.gamesWonWith(c.name)}) — quitte et rouvre le catalogue pour voir l\'effet'),
          backgroundColor: kGreen, duration: const Duration(seconds: 3)));
      },
      child: Container(
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
              child: Stack(fit: StackFit.expand, children: [
                ShineOverlay(
                  tier: shineTierFor(Prefs.gamesWonWith(c.name)),
                  child: imgPath != null
                  ? Image.asset(imgPath, fit: BoxFit.contain, width: double.infinity,
                      // Limite la résolution de décodage — une grille peut
                      // afficher jusqu'à 40 personnages en même temps, décoder
                      // chacun à sa pleine résolution source épuiserait vite la
                      // RAM sur un appareil limité (émulateur notamment).
                      cacheWidth: 320,
                      errorBuilder: (_, __, ___) => _fallback(fc, fbg, c.icon))
                  : _fallback(fc, fbg, c.icon),
                ),
                if (hasMultipleSkins)
                  Positioned(
                    bottom: 6, left: 6,
                    child: GestureDetector(
                      // GestureDetector séparé : absorbe le tap pour ne PAS
                      // déclencher l'ouverture de la fiche complète du
                      // personnage par-dessus.
                      onTap: () async {
                        await _showSkinPicker(ctx, c, ownedSkinsForChar);
                        if (mounted) setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: kGold, width: 1.2)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Text('🎨', style: TextStyle(fontSize: 11)),
                          const SizedBox(width: 3),
                          Text('${ownedSkinsForChar.length + 1}',
                            style: cinzel(10, c: kGold, fw: FontWeight.w900)),
                        ]),
                      ),
                    ),
                  ),
              ]),
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
                Text('Appuie pour voir en grand →',
                  style: body(9, c: kTextDim),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _fallback(Color fc, Color fbg, String icon) => Container(
    color: fbg,
    child: Center(child: Text(icon, style: const TextStyle(fontSize: 50))));
}

/// Affiche une popup permettant de choisir l'apparence à utiliser pour ce
/// personnage, parmi l'apparence de base et tous les skins débloqués en
/// boutique pour lui. Le choix est appliqué immédiatement au clic.
Future<void> _showSkinPicker(BuildContext ctx, CharacterCard c, List<CosmeticItem> ownedSkins) {
  final equippedId = Prefs.equippedCosmetics()['character:${c.id}'];
  return showDialog(
    context: ctx,
    builder: (dctx) => AlertDialog(
      backgroundColor: kBg2,
      title: Text('Apparence de ${c.name}', style: cinzel(15, c: kGold2)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Apparence de base — toujours disponible
          _SkinOption(
            label: 'Apparence de base',
            imagePath: characterImagePath(c.id),
            fallbackIcon: c.icon,
            isEquipped: equippedId == null,
            onTap: () {
              Prefs.equipCosmetic('character:${c.id}', null);
              Navigator.pop(dctx);
            },
          ),
          // Chaque skin débloqué
          ...ownedSkins.map((item) => _SkinOption(
            label: item.name,
            imagePath: item.imagePath,
            fallbackIcon: c.icon,
            isEquipped: equippedId == item.id,
            onTap: () {
              Prefs.equipCosmetic('character:${c.id}', item.id);
              Navigator.pop(dctx);
            },
          )),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dctx),
          child: Text('Fermer', style: cinzel(12, c: kTextSub))),
      ],
    ),
  );
}

class _SkinOption extends StatelessWidget {
  final String label;
  final String? imagePath;
  final String fallbackIcon;
  final bool isEquipped;
  final VoidCallback onTap;
  const _SkinOption({required this.label, required this.imagePath,
    required this.fallbackIcon, required this.isEquipped, required this.onTap});

  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isEquipped ? kGold.withValues(alpha: 0.12) : kBg3,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isEquipped ? kGold : kBord2, width: isEquipped ? 2 : 1)),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(width: 40, height: 56,
            child: imagePath != null
              ? Image.asset(imagePath!, fit: BoxFit.cover, cacheWidth: 80,
                  errorBuilder: (_, __, ___) => Center(child: Text(fallbackIcon)))
              : Center(child: Text(fallbackIcon, style: const TextStyle(fontSize: 22)))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: body(13, c: isEquipped ? kGold2 : kText, fw: FontWeight.w600))),
        if (isEquipped) const Icon(Icons.check_circle, color: kGold, size: 20),
      ]),
    ),
  );
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
