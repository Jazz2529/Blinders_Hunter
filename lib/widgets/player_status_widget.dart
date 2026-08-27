// lib/widgets/player_status_widget.dart
// Widget de statut joueur (jeton + blessures + badges) PARTAGÉ entre le
// solo et le multijoueur — extrait de l'ancien _WoundsColumn (solo_screen.dart)
// pour garantir un rendu VISUELLEMENT IDENTIQUE entre les deux modes, plutôt
// que deux implémentations parallèles qui finissent toujours par diverger.
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../data/tokens_data.dart';
import 'theme.dart';
import 'token_widget.dart';

class PlayerStatusCard extends StatefulWidget {
  final Player player;
  final bool isCurrent, isMe, isFlashing, isMarked;
  final bool victorCharmMaxed;
  final DrunkVision? drunkVision; // Maxence : vision brouillée du joueur QUI REGARDE cet écran
  final void Function(Player)? onTap;
  const PlayerStatusCard({super.key, required this.player, required this.isCurrent,
    required this.isMe, this.isFlashing = false, this.isMarked = false,
    this.victorCharmMaxed = false, this.drunkVision, this.onTap});
  @override State<PlayerStatusCard> createState() => _PlayerStatusCardState();
}

class _PlayerStatusCardState extends State<PlayerStatusCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _flashAc;
  late Animation<Color?> _flashColor;

  @override
  void initState() {
    super.initState();
    _flashAc = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _flashColor = ColorTween(begin: kRed.withValues(alpha: 0.6), end: Colors.transparent)
        .animate(_flashAc);
    if (widget.isFlashing) _flashAc.forward(from: 0);
  }

  @override
  void didUpdateWidget(PlayerStatusCard old) {
    super.didUpdateWidget(old);
    if (widget.isFlashing && !old.isFlashing) _flashAc.forward(from: 0);
  }

  @override
  void dispose() { _flashAc.dispose(); super.dispose(); }

  String _equipIcon(String effect) => switch (effect) {
    'lance'               => '🔱',
    'lance_longinus'      => '☦️',
    'dague'               => '🗡',
    'sainte_tunique'      => '🛡',
    'crucifix_argent'     => '✝️',
    'amulette'            => '📿',
    'broche_de_chance'    => '🍀',
    'boussole_mystique'   => '🧭',
    'sniper'              => '🎯',
    'tenebres_card_immune'=> '🔺',
    'terrain9_immune'     => '👂',
    'triple_dice_choice'  => '⏱',
    _                     => '⚔',
  };

  @override
  Widget build(BuildContext ctx) {
    final p     = widget.player;
    final isMe  = widget.isMe;
    final woundColor = p.wounds >= 10 ? kRed : p.wounds >= 6 ? kGold : kGreen;
    // Maxence : ivresse — carte personnage "hallucinée" pour ce joueur
    // (visuel seulement), qui fait apparaître TOUT LE MONDE comme révélé
    // avec un camp/personnage aléatoire, différent à chaque joueur regardé
    // mais stable tant que la graine ne change pas.
    final drunkCard = widget.drunkVision?.cardFor(p.uid);
    final showRing = drunkCard != null || p.revealed;
    final ringFaction = drunkCard?.faction.name ??
        ((p.alive ? p.disguiseFactionOverride : null) ?? p.character!.faction.name);
    // Blessures toujours visibles — mais PAS les PV max

    return GestureDetector(
      onTap: widget.onTap != null ? () => widget.onTap!(p) : null,
      child: WoundDelta(
      wounds: p.wounds,
      child: AnimatedBuilder(
        animation: _flashAc,
        builder: (_, child) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            color: _flashColor.value ?? (widget.isCurrent ? kGold.withValues(alpha: 0.12) : null),
            borderRadius: BorderRadius.circular(8),
            border: widget.isCurrent ? Border.all(color: kGold, width: 1.5) : null,
          ),
          child: child,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(clipBehavior: Clip.none, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              padding: EdgeInsets.all(showRing ? 2.5 : 0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: showRing ? [
                  BoxShadow(
                    color: factionColor(ringFaction).withValues(alpha: 0.7),
                    blurRadius: 10, spreadRadius: 1)
                ] : null,
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: showRing ? Border.all(
                    color: factionColor(ringFaction), width: 2.5) : null,
                ),
                child: Opacity(
                  opacity: p.alive ? 1.0 : 0.4,
                  child: TokenWidget(tokenId: widget.drunkVision?.tokenFor(p.uid) ?? p.token, size: 30, isDead: !p.alive),
                ),
              ),
            ),
            if (widget.isMarked)
              const Positioned(right: -2, top: -2, child: Text('🔮', style: TextStyle(fontSize: 14))),
          ]),
          const SizedBox(height: 2),
          SizedBox(
            width: 58,
            child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, fontFamily: 'Cinzel',
                fontWeight: isMe ? FontWeight.w900 : FontWeight.w600,
                color: isMe ? kGold : Colors.white)),
          ),
          TweenAnimationBuilder<int>(
            duration: const Duration(milliseconds: 350),
            tween: IntTween(begin: 0, end: p.wounds),
            builder: (_, val, __) => Text(
              !p.alive ? '💀' : (widget.drunkVision != null ? '🗡 ❓' : '🗡 $val'),
              style: TextStyle(fontSize: 11, fontFamily: 'Cinzel',
                fontWeight: FontWeight.w700, color: woundColor)),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              // Luc : joueur en feu — visible de tous, aucune info cachée ici
              // contrairement au charme de Victor.
              if (p.alive && p.lucFireTurnsRemaining > 0)
                Text('🔥 ${p.lucFireTurnsRemaining}',
                  style: const TextStyle(fontSize: 8, fontFamily: 'Cinzel',
                    fontWeight: FontWeight.w900, color: kRed)),
              // Inès : capacité verrouillée — info PUBLIQUE, visible de tous
              // tant que le verrou est actif (Inès en vie).
              if (p.alive && p.abilityLockedByUid != null)
                const Text('🔒', style: TextStyle(fontSize: 10)),
              // Louna : bouclier actif — insensible aux blessures ce tour,
              // info publique visible de tous comme le feu de Luc.
              if (p.alive && p.shield)
                const Text('🛡️', style: TextStyle(fontSize: 10)),
              // Mathieu : compteur d'attaques (3 = bonus +2 dégâts permanent
              // actif) — info PUBLIQUE, visible de tous, comme le feu de Luc.
              if (p.alive && (p.copiedEffect ?? p.character?.abilityEffect) == 'third_attack_bonus')
                Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) => Padding(
                  padding: const EdgeInsets.only(left: 1),
                  child: Icon(
                    p.attackCount > i ? Icons.circle : Icons.circle_outlined,
                    size: 7,
                    color: p.attackCount >= 3 ? kGold : kTextSub),
                ))),
              // Victor : cœur affiché UNIQUEMENT si CE joueur est charmé à
              // 100% ET que la personne qui regarde l'écran est Victor lui-même
              // — cette info reste strictement privée pour tous les autres.
              if (widget.victorCharmMaxed) const Text('💘',
                style: TextStyle(fontSize: 10)),
            ],
          ),
          if (p.equipment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 1,
                children: p.equipment.map((eq) => Tooltip(
                  message: eq.name,
                  child: Text(_equipIcon(eq.effect),
                    style: const TextStyle(fontSize: 9)),
                )).toList(),
              ),
            ),
        ]),
      ),
    ));
  }
}
