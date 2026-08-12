// lib/screens/shop_screen.dart
// Boutique — dépenser l'or gagné en partie pour débloquer des illustrations
// alternatives (personnages, jetons, terrains).

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../widgets/theme.dart';
import '../data/cosmetics_data.dart';
import '../data/characters_data.dart';
import '../data/game_data.dart';
import '../services/persistence.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});
  @override State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  int gold = 0;
  Set<String> owned = {};
  Map<String, String> equipped = {};

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
    });
  }

  void _buy(CosmeticItem item) {
    if (owned.contains(item.id)) return;
    if (!Prefs.spendGold(item.cost)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pas assez d\'or — il te manque ${item.cost - gold} 🪙'),
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

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      backgroundColor: kBg0,
      appBar: AppBar(
        backgroundColor: kBg1,
        title: Text('Boutique', style: cinzel(18, c: kGold2)),
        actions: [
          // Bouton de test, visible UNIQUEMENT en mode debug (flutter run) —
          // disparaît automatiquement dans une vraie build release, donc
          // aucun risque qu'il se retrouve dans la version partagée à tes
          // amis.
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.greenAccent),
              tooltip: '[DEBUG] +10000 or',
              onPressed: () { Prefs.addGold(10000); _refresh(); },
            ),
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
          tabs: const [
            Tab(text: '🎭 Personnages'),
            Tab(text: '🪙 Jetons'),
            Tab(text: '🗺️ Terrains'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _grid(CosmeticCategory.character),
          _grid(CosmeticCategory.token),
          _grid(CosmeticCategory.terrain),
        ],
      ),
    );
  }

  Widget _grid(CosmeticCategory cat) {
    final items = kCosmeticsCatalog.where((c) => c.category == cat).toList();
    if (items.isEmpty) {
      return Center(child: Text('Aucun article pour le moment.', style: body(13, c: kTextDim)));
    }
    return GridView.builder(
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
                    child: Text('ÉQUIPÉ', style: cinzel(9, c: kBg0, fw: FontWeight.w900)))),
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
