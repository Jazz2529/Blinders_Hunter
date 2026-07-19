import 'package:flutter/material.dart';
import 'theme.dart';
import '../models/models.dart';
import '../data/characters_data.dart';

/// ─── Visionneuse de carte ────────────────────────────────────────────────────
/// Illustration ENTIÈRE (1024×1536, ratio 2:3) à gauche, et à droite le
/// panneau d'infos : nom, faction, PV, capacité et condition de victoire.
/// Sur écran étroit (téléphone), l'illustration passe au-dessus du texte.
/// Tap n'importe où pour fermer.
void showFullCardDialog(BuildContext ctx, CharacterCard c) {
  showDialog(
    context: ctx,
    barrierColor: Colors.black.withValues(alpha: 0.88),
    builder: (dctx) {
      final size = MediaQuery.of(dctx).size;
      final narrow = size.width < 640;
      return GestureDetector(
        onTap: () => Navigator.pop(dctx),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            narrow ? _NarrowLayout(c: c, size: size) : _WideLayout(c: c, size: size),
            const SizedBox(height: 12),
            Text('Touche l\'écran pour fermer', style: body(12, c: kTextDim)),
          ]),
        ),
      );
    },
  );
}

// ─── Layout large (PC) : image à gauche, infos à droite ─────────────────────
class _WideLayout extends StatelessWidget {
  final CharacterCard c;
  final Size size;
  const _WideLayout({required this.c, required this.size});

  @override
  Widget build(BuildContext ctx) {
    final fc = factionColor(c.faction.name);
    double imgH = size.height * 0.75;
    double imgW = imgH * (2 / 3);
    // Largeur totale max : image + panneau 320 + marges
    if (imgW + 340 > size.width * 0.94) {
      imgW = size.width * 0.94 - 340;
      imgH = imgW * (3 / 2);
    }
    return Row(mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center, children: [
      _CardImage(c: c, w: imgW, h: imgH),
      const SizedBox(width: 20),
      SizedBox(width: 320,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: imgH),
          child: _InfoPanel(c: c, fc: fc),
        )),
    ]);
  }
}

// ─── Layout étroit (téléphone) : image au-dessus, infos dessous ─────────────
class _NarrowLayout extends StatelessWidget {
  final CharacterCard c;
  final Size size;
  const _NarrowLayout({required this.c, required this.size});

  @override
  Widget build(BuildContext ctx) {
    final fc = factionColor(c.faction.name);
    double imgH = size.height * 0.48;
    double imgW = imgH * (2 / 3);
    if (imgW > size.width * 0.85) {
      imgW = size.width * 0.85;
      imgH = imgW * (3 / 2);
    }
    return SizedBox(
      width: size.width * 0.92,
      height: size.height * 0.86,
      child: Column(children: [
        _CardImage(c: c, w: imgW, h: imgH),
        const SizedBox(height: 12),
        Expanded(child: _InfoPanel(c: c, fc: fc)),
      ]),
    );
  }
}

// ─── Illustration pleine, ratio 2:3, halo faction ────────────────────────────
class _CardImage extends StatelessWidget {
  final CharacterCard c;
  final double w, h;
  const _CardImage({required this.c, required this.w, required this.h});

  @override
  Widget build(BuildContext ctx) {
    final fc = factionColor(c.faction.name);
    final fbg = factionBg(c.faction.name);
    final imgPath = characterImagePath(c.id);
    return Container(
      width: w, height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(w * 0.045),
        boxShadow: [BoxShadow(
            color: fc.withValues(alpha: 0.5), blurRadius: 30, spreadRadius: 2)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(w * 0.045),
        child: imgPath != null
            ? Image.asset(imgPath, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(color: fbg,
                    child: Center(child: Text(c.icon,
                        style: const TextStyle(fontSize: 84)))))
            : Container(color: fbg,
                child: Center(child: Text(c.icon,
                    style: const TextStyle(fontSize: 84)))),
      ),
    );
  }
}

// ─── Panneau d'infos : nom, faction, PV, capacité, victoire ─────────────────
class _InfoPanel extends StatelessWidget {
  final CharacterCard c;
  final Color fc;
  const _InfoPanel({required this.c, required this.fc});

  @override
  Widget build(BuildContext ctx) {
    return GestureDetector(
      onTap: () {}, // absorbe le tap : lire le texte ne ferme pas
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: kBg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: fc, width: 2),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Text(c.name,
                  style: cinzel(20, c: kGold2, fw: FontWeight.w900),
                  textAlign: TextAlign.center)),
              const SizedBox(height: 8),
              Center(child: FactionBadge(c.faction.name)),
              const SizedBox(height: 10),
              Center(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: kBg3, borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kGold.withValues(alpha: 0.5))),
                child: Text('❤️ ${c.hp} PV',
                    style: cinzel(15, c: kGold, fw: FontWeight.w900)),
              )),
              const SizedBox(height: 16),
              _infoBlock('⚡ CAPACITÉ', c.ability, fc),
              const SizedBox(height: 12),
              _infoBlock('🏆 CONDITION DE VICTOIRE', c.winCondition, kGold),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoBlock(String label, String text, Color accent) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: kBg3,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: accent.withValues(alpha: 0.35)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: cinzel(10, c: accent, ls: 1.5)),
      const SizedBox(height: 6),
      Text(text, style: body(13, c: kText)),
    ]),
  );
}
