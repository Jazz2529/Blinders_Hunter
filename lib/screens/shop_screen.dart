// lib/screens/shop_screen.dart
// Boutique — dépenser l'or gagné en partie pour débloquer des illustrations
// alternatives (personnages, jetons, terrains).

import 'dart:math';
import 'package:flutter/material.dart';
import '../widgets/theme.dart';
import '../data/cosmetics_data.dart';
import '../data/characters_data.dart';
import '../data/game_data.dart';
import '../services/persistence.dart';
import '../services/i18n.dart';

const int kChestCost = 100;
const int kChestItemCount = 2;

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});
  @override State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  int gold = 0;
  Set<String> owned = {};
  Map<String, String> equipped = {};
  bool randomTerrainSkins = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _refresh();
  }

  void _refresh() {
    setState(() {
      gold = Prefs.gold();
      owned = Prefs.ownedCosmetics();
      equipped = Prefs.equippedCosmetics();
      randomTerrainSkins = Prefs.randomTerrainSkins();
    });
  }

  void _buy(CosmeticItem item) {
    if (owned.contains(item.id)) return;
    if (!Prefs.spendGold(item.cost)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ui('shop_not_enough_gold').replaceAll('{n}', '${item.cost - gold}')),
          backgroundColor: kRed));
      return;
    }
    Prefs.unlockCosmetic(item.id);
    // Les jetons n'ont rien à "équiper" — débloqués, ils apparaissent
    // directement comme choix dans le sélecteur. Seuls les personnages et
    // terrains utilisent le mécanisme d'équipement (remplacement en place).
    if (item.category != CosmeticCategory.token) {
      Prefs.equipCosmetic(item.slotKey, item.id);
    }
    _refresh();
  }

  void _toggleEquip(CosmeticItem item) {
    final isEquipped = equipped[item.slotKey] == item.id;
    Prefs.equipCosmetic(item.slotKey, isEquipped ? null : item.id);
    _refresh();
  }

  /// Coffre Mystère : 100 or → 2 cosmétiques aléatoires parmi ceux que le
  /// joueur ne possède pas encore (toutes catégories confondues). S'il en
  /// reste moins de 2, en donne autant que possible. Affiche un petit
  /// écran de révélation une fois l'achat effectué.
  void _openChest() {
    final remaining = kCosmeticsCatalog.where((c) => !owned.contains(c.id)).toList();
    if (remaining.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ui('shop_chest_all_unlocked'))));
      return;
    }
    if (!Prefs.spendGold(kChestCost)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ui('shop_not_enough_gold').replaceAll('{n}', '${kChestCost - gold}')),
          backgroundColor: kRed));
      return;
    }
    remaining.shuffle(Random());
    final won = remaining.take(kChestItemCount).toList();
    for (final item in won) {
      Prefs.unlockCosmetic(item.id);
      if (item.category != CosmeticCategory.token) {
        Prefs.equipCosmetic(item.slotKey, item.id);
      }
    }
    _refresh();
    showDialog(context: context, barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (dctx) => _ChestRevealDialog(items: won));
  }

  @override
  Widget build(BuildContext ctx) => LanguageAware(builder: (ctx) {
    return Scaffold(
      backgroundColor: kBg0,
      appBar: AppBar(
        backgroundColor: kBg1,
        title: Text(ui('shop_title'), style: cinzel(18, c: kGold2)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: kGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kGold)),
              child: Text('$gold 🪙', style: cinzel(14, c: kGold, fw: FontWeight.w900)),
            )),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: kGold,
          labelColor: kGold2,
          unselectedLabelColor: kTextDim,
          tabs: [
            Tab(text: ui('shop_tab_characters')),
            Tab(text: ui('shop_tab_tokens')),
            Tab(text: ui('shop_tab_terrains')),
          ],
        ),
      ),
      body: Column(children: [
        _ChestBanner(gold: gold, onOpen: _openChest),
        Expanded(child: TabBarView(
          controller: _tab,
          children: [
            _grid(CosmeticCategory.character),
            _grid(CosmeticCategory.token),
            _grid(CosmeticCategory.terrain),
          ],
        )),
      ]),
    );
  });

  Widget _grid(CosmeticCategory cat) {
    final items = kCosmeticsCatalog.where((c) => c.category == cat).toList();
    if (items.isEmpty) {
      return Center(child: Text(ui('shop_no_items_yet'), style: body(13, c: kTextDim)));
    }
    final grid = GridView.builder(
      padding: const EdgeInsets.all(16),
      // SliverGridDelegateWithMaxCrossAxisExtent au lieu d'un nombre de
      // colonnes fixe : sur un grand écran PC, un fixe à 2 colonnes forçait
      // chaque carte à s'étirer sur une largeur énorme (bien au-delà de ce
      // qui est lisible/visible). Ici, chaque carte fait au maximum 170px
      // de large, et le nombre de colonnes s'adapte automatiquement.
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 170, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.78),
      itemCount: items.length,
      itemBuilder: (_, i) => _ShopCard(
        item: items[i],
        isOwned: owned.contains(items[i].id),
        isEquipped: equipped[items[i].slotKey] == items[i].id,
        canAfford: gold >= items[i].cost,
        onBuy: () => _buy(items[i]),
        onToggleEquip: () => _toggleEquip(items[i]),
      ),
    );
    if (cat != CosmeticCategory.terrain) return grid;
    // Terrains : réglage "skins aléatoires à chaque partie" au-dessus de la
    // grille — quand activé, ignore le skin équipé fixe et en tire un
    // différent (parmi ceux débloqués) au début de chaque nouvelle partie.
    return Column(children: [
      Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: kGold.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kGold.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          const Text('🎲', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ui('shop_random_terrain_skins'), style: cinzel(12, c: kGold2, fw: FontWeight.w900)),
            Text(ui('shop_random_terrain_desc'),
              style: body(10, c: kTextSub)),
          ])),
          Switch(
            value: randomTerrainSkins,
            activeThumbColor: kGold,
            onChanged: (v) {
              Prefs.setRandomTerrainSkins(v);
              setState(() => randomTerrainSkins = v);
            },
          ),
        ]),
      ),
      Expanded(child: grid),
    ]);
  }
}

class _ShopCard extends StatelessWidget {
  final CosmeticItem item;
  final bool isOwned, isEquipped, canAfford;
  final VoidCallback onBuy, onToggleEquip;
  const _ShopCard({required this.item, required this.isOwned, required this.isEquipped,
    required this.canAfford, required this.onBuy, required this.onToggleEquip});

  String get _label {
    if (item.category == CosmeticCategory.character) {
      return kAllCharacters.where((c) => c.id == item.targetId).firstOrNull?.name ?? item.targetId;
    }
    if (item.category == CosmeticCategory.terrain) {
      return kAllTerrains.where((t) => t.effect == item.targetId).firstOrNull?.name ?? item.targetId;
    }
    return item.targetId;
  }

  @override
  Widget build(BuildContext ctx) {
    return Container(
      decoration: BoxDecoration(
        color: kBg2, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isEquipped ? kGold : kBord2, width: isEquipped ? 2 : 1)),
      child: Column(children: [
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            child: Stack(fit: StackFit.expand, children: [
              Image.asset(item.imagePath, fit: BoxFit.cover,
                cacheWidth: 300,
                errorBuilder: (_, __, ___) => Container(
                  color: kBg3,
                  child: Center(child: Text('🖼️', style: TextStyle(fontSize: 32, color: kTextDim.withValues(alpha: 0.5))))),
              ),
              if (!isOwned)
                Container(color: Colors.black54,
                  child: const Center(child: Icon(Icons.lock, color: Colors.white70, size: 28))),
              if (isEquipped)
                Positioned(top: 6, right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: kGold, borderRadius: BorderRadius.circular(10)),
                    child: Text(ui('shop_equipped'), style: cinzel(9, c: kBg0, fw: FontWeight.w900)))),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Column(children: [
            Text(item.name, style: cinzel(11, c: kGold2, fw: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            if (item.category != CosmeticCategory.token)
              Text(_label, style: body(9, c: kTextDim), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: isOwned
                ? (item.category == CosmeticCategory.token
                    // Les jetons n'ont rien à "équiper" : une fois débloqués,
                    // ils apparaissent directement comme choix supplémentaire
                    // dans le sélecteur de jeton, au même titre que les
                    // jetons de base — pas de bascule ici.
                    ? BHButton(label: '✓ Débloqué — dispo dans le sélecteur', gold: true, onTap: null)
                    : BHButton(
                        label: isEquipped ? '✓ Équipé' : 'Équiper',
                        outlined: !isEquipped,
                        gold: isEquipped,
                        onTap: onToggleEquip,
                      ))
                : BHButton(
                    label: '${item.cost} 🪙',
                    danger: !canAfford,
                    onTap: canAfford ? onBuy : null,
                  ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─── Bandeau Coffre Mystère ─────────────────────────────────────────────────
// Affiché au-dessus des 3 onglets (Personnages/Jetons/Terrains) puisqu'un
// coffre peut donner un objet de N'IMPORTE quelle catégorie.
class _ChestBanner extends StatelessWidget {
  final int gold;
  final VoidCallback onOpen;
  const _ChestBanner({required this.gold, required this.onOpen});

  @override
  Widget build(BuildContext ctx) {
    final canAfford = gold >= kChestCost;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          kGold.withValues(alpha: 0.18), kBg2,
        ], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kGold, width: 1.5),
      ),
      child: Row(children: [
        Text('🎁', style: const TextStyle(fontSize: 32)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ui('shop_mystery_chest'), style: cinzel(14, c: kGold2, fw: FontWeight.w900),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(ui('shop_chest_desc').replaceAll('{n}', '$kChestItemCount'),
              style: body(10, c: kTextSub), maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: BHButton(
            label: '$kChestCost 🪙',
            danger: !canAfford,
            onTap: canAfford ? onOpen : null,
          ),
        ),
      ]),
    );
  }
}

// ─── Révélation du contenu du coffre ────────────────────────────────────────
class _ChestRevealDialog extends StatefulWidget {
  final List<CosmeticItem> items;
  const _ChestRevealDialog({required this.items});

  @override
  State<_ChestRevealDialog> createState() => _ChestRevealDialogState();
}

class _ChestRevealDialogState extends State<_ChestRevealDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    // Timeline (0.0 → 1.0) :
    //   0.00–0.45 : le coffre tremble (anticipation)
    //   0.40–0.55 : éclat doré + le coffre "s'ouvre" (icône qui change)
    //   0.50–1.00 : les objets apparaissent l'un après l'autre (décalés)
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _labelFor(CosmeticItem item) {
    if (item.category == CosmeticCategory.character) {
      return kAllCharacters.where((c) => c.id == item.targetId).firstOrNull?.name ?? item.targetId;
    }
    if (item.category == CosmeticCategory.terrain) {
      return kAllTerrains.where((t) => t.effect == item.targetId).firstOrNull?.name ?? item.targetId;
    }
    return 'Jeton';
  }

  @override
  Widget build(BuildContext ctx) {
    return GestureDetector(
      onTap: () => Navigator.pop(ctx),
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: kBg2, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kGold, width: 2)),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final t = _ctrl.value;
              final shakeT = (t / 0.45).clamp(0.0, 1.0);
              final burstT = ((t - 0.40) / 0.15).clamp(0.0, 1.0);
              final revealT = ((t - 0.50) / 0.50).clamp(0.0, 1.0);
              final opened = t >= 0.45;

              // Secousse : oscillation qui s'amortit à l'approche de l'ouverture.
              final shakeAngle = shakeT < 1.0 ? sin(shakeT * pi * 6) * (1 - shakeT) * 0.18 : 0.0;

              return Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  height: 90,
                  child: Stack(alignment: Alignment.center, children: [
                    // Éclat doré au moment de l'ouverture
                    Opacity(
                      opacity: burstT * (1 - burstT) * 4, // monte puis redescend vite
                      child: Container(
                        width: 140, height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            kGold.withValues(alpha: 0.55), kGold.withValues(alpha: 0),
                          ]),
                        ),
                      ),
                    ),
                    Transform.rotate(
                      angle: shakeAngle,
                      child: Transform.scale(
                        scale: 1.0 + burstT * 0.35,
                        child: Text(opened ? '📦' : '🎁', style: const TextStyle(fontSize: 56)),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
                Text(opened ? ui('shop_chest_opened') : ui('shop_opening'),
                  style: cinzel(18, c: kGold2, fw: FontWeight.w900)),
                const SizedBox(height: 16),
                if (widget.items.isEmpty)
                  Opacity(opacity: revealT,
                    child: Text(ui('shop_no_item_obtained'), style: body(12, c: kTextDim)))
                else ...List.generate(widget.items.length, (i) {
                  final item = widget.items[i];
                  // Décale l'apparition de chaque objet l'un après l'autre.
                  final start = i * 0.4;
                  final itemT = ((revealT - start) / (1 - start)).clamp(0.0, 1.0);
                  return Opacity(
                    opacity: itemT,
                    child: Transform.scale(
                      scale: 0.6 + 0.4 * Curves.easeOutBack.transform(itemT),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: kBg3, borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kGold.withValues(alpha: 0.5))),
                        child: Row(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(item.imagePath, width: 52, height: 52, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 52, height: 52, color: kBg1,
                                child: Center(child: Text('🖼️', style: TextStyle(color: kTextDim.withValues(alpha: 0.5))))),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(item.name, style: cinzel(12, c: kGold2, fw: FontWeight.w700)),
                            if (item.category != CosmeticCategory.token)
                              Text(_labelFor(item), style: body(10, c: kTextSub)),
                          ])),
                        ]),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Opacity(
                  opacity: revealT >= 1.0 ? 1.0 : 0.0,
                  child: Text(ui('tap_close_screen'), style: body(11, c: kTextDim)),
                ),
              ]);
            },
          ),
        ),
      ),
    );
  }
}

