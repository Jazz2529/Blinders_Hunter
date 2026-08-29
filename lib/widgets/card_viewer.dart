import 'dart:math';
import 'package:flutter/material.dart';
import 'theme.dart';
import '../models/models.dart';
import '../data/characters_data.dart';
import '../services/persistence.dart';
import 'shine_effect.dart';

/// ─── Visionneuse de carte ────────────────────────────────────────────────────
/// Illustration ENTIÈRE (1024×1536, ratio 2:3) à gauche, et à droite le
/// panneau d'infos : nom, faction, PV, capacité et condition de victoire.
/// Sur écran étroit (téléphone), l'illustration passe au-dessus du texte.
/// Tap n'importe où pour fermer.
Future<void> showFullCardDialog(BuildContext ctx, CharacterCard c, {int? hpOverride, int? oscarXpOverride, String? maximeTargetName, String? megFormOverride, int? mathieuAttackCount}) {
  return showDialog(
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
            narrow ? _NarrowLayout(c: c, size: size, hpOverride: hpOverride, oscarXpOverride: oscarXpOverride, maximeTargetName: maximeTargetName, megFormOverride: megFormOverride, mathieuAttackCount: mathieuAttackCount)
                   : _WideLayout(c: c, size: size, hpOverride: hpOverride, oscarXpOverride: oscarXpOverride, maximeTargetName: maximeTargetName, megFormOverride: megFormOverride, mathieuAttackCount: mathieuAttackCount),
            const SizedBox(height: 12),
            Text('Touche l\'écran pour fermer', style: body(12, c: kTextDim)),
          ]),
        ),
      );
    },
  );
}

/// ─── Carte "mystère" — joueur non révélé ────────────────────────────────────
/// Affichée à la place de la vraie carte tant que le joueur n'est pas
/// révélé : silhouette énigmatique + réplique cryptique tirée au hasard.
/// Bascule automatiquement vers showFullCardDialog une fois révélé (c'est
/// à l'appelant de vérifier p.revealed et choisir la bonne fonction).
const List<String> kMysteryLines = [
  '« Les ombres ne révèlent leurs secrets qu\'à ceux qui savent attendre... »',
  '« Un masque de plus dans cette danse macabre. »',
  '« Ami ou ennemi ? Le voile reste épais. »',
  '« Quelque chose rôde derrière ce regard fermé. »',
  '« Son vrai visage se cache encore dans les ténèbres. »',
  '« Ni Hunter, ni Shadow — pour l\'instant, juste une silhouette. »',
  '« Le silence de cette carte en dit plus qu\'il n\'y paraît. »',
  '« Patience, chasseur. Tout se révèle en son temps. »',
];

Future<void> showMysteryCardDialog(BuildContext ctx, Player p) {
  final line = kMysteryLines[Random().nextInt(kMysteryLines.length)];
  return showDialog(
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
            narrow ? _MysteryNarrowLayout(name: p.name, line: line, size: size)
                   : _MysteryWideLayout(name: p.name, line: line, size: size),
            const SizedBox(height: 12),
            Text('Touche l\'écran pour fermer', style: body(12, c: kTextDim)),
          ]),
        ),
      );
    },
  );
}

class _MysteryWideLayout extends StatelessWidget {
  final String name, line;
  final Size size;
  const _MysteryWideLayout({required this.name, required this.line, required this.size});

  @override
  Widget build(BuildContext ctx) {
    double imgH = size.height * 0.75;
    double imgW = imgH * (2 / 3);
    if (imgW + 340 > size.width * 0.94) {
      imgW = size.width * 0.94 - 340;
      imgH = imgW * (3 / 2);
    }
    return Row(mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center, children: [
      _MysteryImage(w: imgW, h: imgH),
      const SizedBox(width: 20),
      SizedBox(width: 320,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: imgH),
          child: _MysteryInfoPanel(name: name, line: line),
        )),
    ]);
  }
}

class _MysteryNarrowLayout extends StatelessWidget {
  final String name, line;
  final Size size;
  const _MysteryNarrowLayout({required this.name, required this.line, required this.size});

  @override
  Widget build(BuildContext ctx) {
    double imgH = size.height * 0.42;
    double imgW = imgH * (2 / 3);
    if (imgW > size.width * 0.85) {
      imgW = size.width * 0.85;
      imgH = imgW * (3 / 2);
    }
    return SizedBox(
      width: size.width * 0.92,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _MysteryImage(w: imgW, h: imgH),
        const SizedBox(height: 12),
        _MysteryInfoPanel(name: name, line: line),
      ]),
    );
  }
}

// ─── Silhouette énigmatique — pas de vraie illustration ─────────────────────
class _MysteryImage extends StatelessWidget {
  final double w, h;
  const _MysteryImage({required this.w, required this.h});

  @override
  Widget build(BuildContext ctx) {
    return Container(
      width: w, height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(w * 0.045),
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [const Color(0xFF1A1420), const Color(0xFF0A0710)]),
        boxShadow: [BoxShadow(
            color: kTextDim.withValues(alpha: 0.35), blurRadius: 30, spreadRadius: 2)],
        border: Border.all(color: kTextDim.withValues(alpha: 0.4), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(w * 0.045),
        child: Stack(alignment: Alignment.center, children: [
          Icon(Icons.help_outline, size: w * 0.5, color: Colors.white.withValues(alpha: 0.08)),
          Text('❓', style: TextStyle(fontSize: w * 0.28)),
        ]),
      ),
    );
  }
}

class _MysteryInfoPanel extends StatelessWidget {
  final String name, line;
  const _MysteryInfoPanel({required this.name, required this.line});

  @override
  Widget build(BuildContext ctx) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: kBg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kTextDim.withValues(alpha: 0.5), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Text(name,
                style: cinzel(20, c: kTextSub, fw: FontWeight.w900),
                textAlign: TextAlign.center)),
            const SizedBox(height: 8),
            Center(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: kBg3, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kTextDim.withValues(alpha: 0.5))),
              child: Text('❓ IDENTITÉ INCONNUE',
                  style: cinzel(12, c: kTextDim, fw: FontWeight.w900, ls: 1)),
            )),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kBg3,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kTextDim.withValues(alpha: 0.3)),
              ),
              child: Text(line,
                style: body(13, c: kTextSub).copyWith(fontStyle: FontStyle.italic),
                textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}


class _WideLayout extends StatelessWidget {
  final CharacterCard c;
  final Size size;
  final int? hpOverride;
  final int? oscarXpOverride;
  final String? maximeTargetName;
  final String? megFormOverride;
  final int? mathieuAttackCount;
  const _WideLayout({required this.c, required this.size, this.hpOverride, this.oscarXpOverride, this.maximeTargetName, this.megFormOverride, this.mathieuAttackCount});

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
          child: _InfoPanel(c: c, fc: fc, hpOverride: hpOverride, oscarXpOverride: oscarXpOverride, maximeTargetName: maximeTargetName, megFormOverride: megFormOverride, mathieuAttackCount: mathieuAttackCount),
        )),
    ]);
  }
}

// ─── Layout étroit (téléphone) : image au-dessus, infos dessous ─────────────
class _NarrowLayout extends StatelessWidget {
  final CharacterCard c;
  final Size size;
  final int? hpOverride;
  final int? oscarXpOverride;
  final String? maximeTargetName;
  final String? megFormOverride;
  final int? mathieuAttackCount;
  const _NarrowLayout({required this.c, required this.size, this.hpOverride, this.oscarXpOverride, this.maximeTargetName, this.megFormOverride, this.mathieuAttackCount});

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
        Expanded(child: _InfoPanel(c: c, fc: fc, hpOverride: hpOverride, oscarXpOverride: oscarXpOverride, maximeTargetName: maximeTargetName, megFormOverride: megFormOverride, mathieuAttackCount: mathieuAttackCount)),
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
    final imgPath = effectiveCharacterImagePath(c.id);
    final tier = shineTierFor(Prefs.gamesWonWith(c.name));
    return Container(
      width: w, height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(w * 0.045),
        boxShadow: [BoxShadow(
            color: fc.withValues(alpha: 0.5), blurRadius: 30, spreadRadius: 2)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(w * 0.045),
        child: ShineOverlay(
          tier: tier,
          child: imgPath != null
              ? SmoothAssetImage(imgPath, fit: BoxFit.contain,
                  // Limite la résolution de décodage à ~2x la taille affichée
                  // — sans ça, une image source haute résolution peut faire
                  // échouer le chargement sur un appareil à RAM limitée.
                  cacheWidth: (w * 2).round(),
                  cacheHeight: (h * 2).round(),
                  placeholderColor: fbg,
                  placeholderIcon: c.icon,
                  width: w, height: h)
              : Container(color: fbg,
                  child: Center(child: Text(c.icon,
                      style: const TextStyle(fontSize: 84)))),
        ),
      ),
    );
  }
}

// ─── Panneau d'infos : nom, faction, PV, capacité, victoire ─────────────────
class _InfoPanel extends StatelessWidget {
  final CharacterCard c;
  final Color fc;
  final int? hpOverride;
  final int? oscarXpOverride;
  final String? maximeTargetName;
  final String? megFormOverride;
  final int? mathieuAttackCount;
  const _InfoPanel({required this.c, required this.fc, this.hpOverride, this.oscarXpOverride, this.maximeTargetName, this.megFormOverride, this.mathieuAttackCount});

  @override
  Widget build(BuildContext ctx) {
    // Agathe : si ce joueur a un PV max volé/gagné, hpOverride contient la
    // valeur RÉELLE actuelle — sinon on retombe sur le PV de base de la carte.
    final effectiveHp = hpOverride ?? c.hp;
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
                child: Text(
                    effectiveHp != c.hp
                        ? '❤️ ${c.hp} → $effectiveHp PV'
                        : '❤️ $effectiveHp PV',
                    style: cinzel(15, c: kGold, fw: FontWeight.w900)),
              )),
              // Oscar : indicateur d'XP cumulée, visible dès qu'on connaît
              // sa valeur actuelle (passé par l'appelant, seulement en partie).
              if (oscarXpOverride != null) ...[
                const SizedBox(height: 8),
                Center(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: kGold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kGold, width: 1.5)),
                  child: Text('🧪 $oscarXpOverride / 13 XP',
                    style: cinzel(14, c: kGold2, fw: FontWeight.w900)),
                )),
              ],
              // Mathieu : compteur d'attaques (3 = bonus +2 dégâts permanent
              // actif) — déplacé ici (sur la carte) plutôt que sur la barre
              // de joueurs, où les 3 ronds provoquaient un débordement dès
              // qu'il avait aussi de l'équipement à afficher.
              if (mathieuAttackCount != null) ...[
                const SizedBox(height: 8),
                Center(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: kGold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kGold, width: 1.5)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('⚔️ ', style: cinzel(13, c: kGold2)),
                    ...List.generate(3, (i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(
                        mathieuAttackCount! > i ? Icons.circle : Icons.circle_outlined,
                        size: 14,
                        color: mathieuAttackCount! >= 3 ? kGold : kTextSub),
                    )),
                  ]),
                )),
              ],
              // Maxime : rappelle qui est le premier joueur à l'avoir blessé
              // (sa cible pour la victoire) — vide tant que personne ne l'a
              // encore touché.
              if (maximeTargetName != null) ...[
                const SizedBox(height: 8),
                Center(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: kRed.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kRed, width: 1.5)),
                  child: Text('🎯 Cible : $maximeTargetName',
                    style: cinzel(13, c: kRed, fw: FontWeight.w900)),
                )),
              ],
              // Meg : forme actuelle (Offensive/Défensive) — info PUBLIQUE,
              // visible de tous les joueurs dès qu'elle est révélée, contrairement
              // à la cible de Maxime qui reste privée.
              if (megFormOverride != null) ...[
                const SizedBox(height: 8),
                Center(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: (megFormOverride == 'offense' ? kRed : kGreen).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: megFormOverride == 'offense' ? kRed : kGreen, width: 1.5)),
                  child: Text(
                    megFormOverride == 'offense'
                        ? '⚔️ Forme actuelle : Offensive (+1 infligé)'
                        : '🛡️ Forme actuelle : Défensive (-1 reçu)',
                    style: cinzel(13, c: megFormOverride == 'offense' ? kRed : kGreen, fw: FontWeight.w900)),
                )),
              ],
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
