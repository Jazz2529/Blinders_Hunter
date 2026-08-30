// lib/services/engine.dart
// Moteur de jeu pur — aucune dépendance Flutter ou Firebase
// Import: models + data uniquement

import 'dart:math';
import 'engine_abilities.dart';
import '../models/models.dart';
import 'audio_service.dart';
import '../data/game_data.dart';
import '../data/interactions_data.dart';

/// ─── Rémi : les 10 effets possibles pour son équipement personnalisé ───────
/// Il en choisit exactement 2 (communs ou légendaires, sans distinction de
/// tirage — ce sont bien 10 choix FIXES, pas un tirage aléatoire).
const Map<String, String> kRemiCommonChoices = {
  'remi_dmg1': '⚔️ Infligez 1 blessure de plus à chaque attaque',
  'remi_heal1': '💚 Soignez-vous de 1 blessure à chaque attaque',
  'remi_aoe': '💥 Attaquez tous les joueurs à portée en une fois',
  'remi_range': '🎯 Tous les joueurs sont à portée, peu importe la zone',
  'remi_d4only': '🎲 Vos attaques n\'utilisent que le D4 (dégâts = résultat du D4)',
  'remi_steal': '🦹 Volez un équipement à chaque fois que vous infligez des blessures',
  'remi_forceattack': '⚡ Le joueur que vous attaquez doit attaquer quelqu\'un à son prochain tour',
};
const Map<String, String> kRemiLegendaryChoices = {
  'remi_heal2': '💚💚 [Légendaire] Soignez-vous de 2 blessures à chaque attaque',
  'remi_dmg2': '⚔️⚔️ [Légendaire] Infligez 2 blessures de plus à chaque attaque',
  'remi_d6only': '🎲 [Légendaire] Vos attaques n\'utilisent que le D6 (dégâts = résultat du D6)',
};
const Map<String, String> kRemiAllChoices = {...kRemiCommonChoices, ...kRemiLegendaryChoices};

/// Rémi : tire 3 effets au hasard parmi les 10, en rendant les 3
/// légendaires nettement plus rares (poids 1) que les 7 communs (poids 4)
/// — environ 4x moins de chances qu'un légendaire précis sorte qu'un
/// commun précis.
List<String> remiDraw3([Random? rng]) {
  final r = rng ?? Random();
  final weighted = <String>[];
  for (final k in kRemiCommonChoices.keys) { weighted.addAll(List.filled(4, k)); }
  for (final k in kRemiLegendaryChoices.keys) { weighted.addAll(List.filled(1, k)); }
  final result = <String>[];
  final pool = List<String>.from(weighted);
  while (result.length < 3 && pool.isNotEmpty) {
    final pick = pool[r.nextInt(pool.length)];
    if (!result.contains(pick)) result.add(pick);
    pool.removeWhere((k) => k == pick);
  }
  return result;
}

/// Hailey : tire 3 Hunters au hasard parmi ceux NON JOUÉS cette partie
/// (ni elle-même). Si moins de 3 Hunters sont disponibles, en renvoie
/// autant que possible.
List<CharacterCard> haileyDraw3(List<Player> all, [Random? rng]) {
  final r = rng ?? Random();
  final playedIds = all.map((p) => p.character?.id).whereType<String>().toSet();
  final pool = kAllCharacters.where((c) =>
      c.faction == Faction.hunter && c.id != 'hailey' && !playedIds.contains(c.id)).toList();
  pool.shuffle(r);
  return pool.take(3).toList();
}

/// Rémi : renvoie les 2 effets actifs pour CE joueur, d'après l'équipement
/// personnalisé QU'IL PORTE ACTUELLEMENT — pas d'après qui l'a fabriqué.
/// L'effet suit l'objet : si quelqu'un d'autre le vole, c'est lui qui en
/// bénéficie ensuite, plus Rémi.
Set<String> remiActiveChoices(Player p) {
  for (final eq in p.equipment) {
    if (eq.effect.startsWith('remi_custom:')) {
      return eq.effect.substring('remi_custom:'.length).split(',').toSet();
    }
  }
  return const {};
}

class GameEngine with AbilityEngine {
  static final GameEngine instance = GameEngine._();
  GameEngine._();

  final Random _rng = Random();
  @override Random get rng => _rng;

  // ─── Dés ─────────────────────────────────
  int rollD4() => _rng.nextInt(4) + 1;
  int rollD6() => _rng.nextInt(6) + 1;

  Map<String, int> rollMove() {
    final d4 = rollD4(); final d6 = rollD6();
    return {'d4': d4, 'd6': d6, 'sum': d4 + d6};
  }

  Map<String, int> rollAttack() {
    final d4 = rollD4(); final d6 = rollD6();
    return {'d4': d4, 'd6': d6, 'damage': (d4 - d6).abs()};
  }

  // ─── Terrain ─────────────────────────────
  int? sumToTerrainId(int sum) {
    const m = {2: 0, 3: 0, 4: 1, 5: 1, 6: 2, 7: 2, 8: 3, 9: 4, 10: 5};
    return m[sum];
  }

  int terrainLayoutIdx(List<Terrain> layout, int terrainId) =>
      layout.indexWhere((t) => t.id == terrainId);

  List<Player> attackTargets(Player attacker, List<Player> all, List<Terrain> layout) {
    // Gège le Fantôme : ne peut pas attaquer quand révélé (passif seulement)
    final eff = effectiveAbility(attacker);
    if (eff == 'gege_passive' && attacker.revealed) return [];
    final z = attacker.zoneIndex;
    final adj = kAdjacences[z];
    List<Player> result;
    // Révolver des Ténèbres : portée INVERSÉE — uniquement les zones hors
    // de son propre secteur ET hors des zones adjacentes (ne peut plus
    // attaquer dans sa propre zone).
    if (attacker.equipment.any((e) => e.effect == 'revolver_tenebres')) {
      result = all.where((p) => p.alive && p.uid != attacker.uid
          && p.zoneIndex != z && !adj.contains(p.zoneIndex)).toList();
    }
    // Pirate et Sniper = portée infinie — Pirate seulement une fois révélé
    // (son pouvoir est un "passif révélé", pas actif tant qu'il est caché).
    else if (attacker.sniper || (attacker.revealed && (attacker.infiniteRange || eff == 'infinite_range' ||
        remiActiveChoices(attacker).contains('remi_range')))) {
      result = all.where((p) => p.alive && p.uid != attacker.uid).toList();
    } else {
      result = all.where((p) => p.alive && p.uid != attacker.uid
          && (p.zoneIndex == z || adj.contains(p.zoneIndex))).toList();
    }
    // Victor : un joueur charmé à 100% ne peut plus l'attaquer — le retire
    // de la liste de cibles valides, quelle que soit la portée normalement
    // applicable (bouclier "romantique", pas une question de distance).
    final victor = all.where((p) =>
        p.alive && effectiveAbility(p) == 'victor_charm').firstOrNull;
    if (victor != null && (victor.charmLevels[attacker.uid] ?? 0) >= 100) {
      result = result.where((p) => p.uid != victor.uid).toList();
    }
    return result;
  }

  // ─── Dégâts / soins ──────────────────────
  /// PV max réel d'un joueur, en tenant compte du vol de PV max d'Agathe
  /// (positif si elle en a volé, négatif si elle lui en a volé) — jamais
  /// sous 1, pour éviter un PV max nul ou négatif qui n'aurait pas de sens.
  int effectiveMaxHp(Player p) => max(1, (p.character?.hp ?? 1) + p.maxHpModifier);

  /// Effet de capacité "effectif" d'un joueur — vide si Inès l'a verrouillé
  /// (tant qu'elle est en vie). Centralise le blocage : toute capacité qui
  /// se déclenche en comparant ce résultat à un identifiant d'effet est
  /// automatiquement neutralisée pour un joueur verrouillé, qu'il s'agisse
  /// d'une capacité ACTIVE (bouton) ou PASSIVE (déclenchée automatiquement
  /// lors d'une attaque, d'une mort, etc.).
  String effectiveAbility(Player p) {
    if (p.abilityLockedByUid != null) return '';
    return p.copiedEffect ?? p.character?.abilityEffect ?? '';
  }

  /// Maxime : mémorise le PREMIER joueur à lui avoir réellement infligé des
  /// blessures cette partie — sa condition de victoire. Ne s'écrase jamais
  /// une fois posé (seul le tout premier compte).
  void applyMaximeFirstAttacker(Player attacker, Player target, int actualDmg) {
    if (effectiveAbility(target) != 'maxime_double_first') return;
    if (actualDmg <= 0) return;
    if (target.maximeFirstAttackerUid != null) return;
    target.maximeFirstAttackerUid = attacker.uid;
  }

  /// Victor : +20% de charme à la cible attaquée, +10% à tous les joueurs
  /// sur sa zone (peut cumuler avec la cible si elle y est aussi). Se
  /// déclenche à CHAQUE attaque UNE FOIS RÉVÉLÉ, indépendamment des dégâts
  /// réellement infligés — c'est l'action d'attaquer qui compte, pas le
  /// résultat.
  void applyVictorCharm(Player attacker, Player target, List<Player>? all) {
    if (effectiveAbility(attacker) != 'victor_charm') return;
    if (!attacker.revealed) return;
    final curTarget = attacker.charmLevels[target.uid] ?? 0;
    attacker.charmLevels[target.uid] = (curTarget + 30).clamp(0, 100).toInt();
    if (all == null) return;
    for (final other in all) {
      if (other.uid == attacker.uid || !other.alive) continue;
      if (other.zoneIndex == attacker.zoneIndex) {
        final cur = attacker.charmLevels[other.uid] ?? 0;
        attacker.charmLevels[other.uid] = (cur + 10).clamp(0, 100).toInt();
      }
    }
  }

  int applyDamage(Player p, int n, {bool isTenebresCard = false, bool ignoreShield = false, bool isTerrain9Dmg = false}) {
    if (!p.alive) return 0;
    if (isTerrain9Dmg && p.terrainDmgImmune) return 0; // Broche de Chance
    if (isTenebresCard && p.tendebresImmune) return 0;
    // BIBBLE: cartes ténèbres le soignent au lieu de le blesser
    if (isTenebresCard && p.revealed &&
        effectiveAbility(p) == 'tenebres_heal_instead') {
      applyHeal(p, n);
      return 0;
    }
    if (!ignoreShield && p.shield) {
      // Bouclier "insensible pendant 1 tour" : bloque TOUS les dégâts tant
      // qu'il est actif, sans se consommer par montant — il expire au début
      // du PROCHAIN tour du joueur (voir applyStartOfTurnPassives / reset de
      // tour), pas après avoir absorbé un certain nombre de points.
      return 0;
    }
    // Felipe en sursis : insensible à TOUTES les blessures tant que son
    // tour de grâce est en cours — sans ça, n'importe qui pouvait
    // l'achever avant même qu'il ait eu la chance de se sauver.
    if (p.felipeOnBorrowedTime) return 0;
    if (p.sainteTunique) n = max(0, n - 1);
    p.wounds += n;
    // Felipe : passif RÉVÉLÉ — la PREMIÈRE fois qu'il subirait des dégâts
    // létaux, il survit avec 1 PV au lieu de mourir, et dispose d'un tour de
    // sursis pour éliminer quelqu'un (voir applyDeathPassives pour le
    // sauvetage, et la fin de tour pour la mort si le sursis n'a pas
    // suffi). Ne fonctionne QUE s'il est révélé — sinon aucun effet, il
    // meurt normalement comme n'importe qui.
    final isFelipe = effectiveAbility(p) == 'felipe_passive';
    if (isFelipe && p.revealed && !p.felipeOnBorrowedTime && p.wounds >= effectiveMaxHp(p)) {
      p.felipeOnBorrowedTime = true;
      p.wounds = effectiveMaxHp(p) - 1; // 1 PV restant, toujours en vie
    } else if (p.wounds >= effectiveMaxHp(p)) {
      p.alive = false;
    }
    if (n > 0) audio.playDamage();
    // Jason (Caméléon) : perd son déguisement s'il subit 5+ blessures en un seul tour
    if (n > 0 && p.disguiseNameOverride != null) {
      p.damageTakenThisTurn += n;
      if (p.damageTakenThisTurn >= 5) {
        p.disguiseNameOverride = null;
        p.disguiseIconOverride = null;
        p.disguiseFactionOverride = null;
        p.disguiseCharIdOverride = null;
        p.disguiseJustLost = true; // signale l'événement pour déclencher sa vraie révélation
      }
    }
    return n;
  }

  void applyHeal(Player p, int n) {
    if (n > 0) audio.playHeal();
    p.wounds = max(0, p.wounds - n);
  }

  // ─── Pioche ──────────────────────────────
  /// File d'attente de cartes forcées par pile (Elaia). Clé = nom du deck
  /// ('tenebres'|'lumiere'|'vision'), valeur = liste ordonnée d'IDs de cartes
  /// qui seront piochées en priorité (index 0 = prochaine pioche).
  GameCard drawCard(DeckType deck, {Map<String, List<String>>? forcedQueue, Map<String, List<String>>? deckPiles}) {
    final key = deck.name;
    final queue = forcedQueue?[key];
    if (queue != null && queue.isNotEmpty) {
      final forcedId = queue.removeAt(0);
      final pool = deckCards(deck);
      final forced = pool.where((c) => c.id == forcedId).firstOrNull;
      if (forced != null) return forced;
      // Si l'ID forcé n'existe plus (carte retirée du jeu entre-temps), on
      // retombe sur un tirage aléatoire normal.
    }
    final pool = deckCards(deck);
    // Pile réelle, sans remise : chaque carte de la pile ne peut ressortir
    // qu'une fois que TOUTES les autres cartes de la même pile sont sorties
    // — puis la pile se remélange et se remplit automatiquement.
    if (deckPiles != null) {
      var pile = deckPiles[key];
      if (pile == null || pile.isEmpty) {
        pile = pool.map((c) => c.id).toList()..shuffle(_rng);
      }
      final cardId = pile.removeAt(0);
      deckPiles[key] = pile;
      final drawn = pool.where((c) => c.id == cardId).firstOrNull;
      if (drawn != null) return drawn;
      // Sécurité : l'ID ne correspond plus à rien (carte retirée du jeu) —
      // retombe sur un tirage aléatoire classique pour ne jamais planter.
    }
    return pool[_rng.nextInt(pool.length)];
  }

  /// Elaia : regarde 2 cartes distinctes au hasard dans la pile choisie
  /// (simule "les 2 premières cartes de la pile").
  (GameCard, GameCard) peekTwoCards(DeckType deck) {
    final pool = List<GameCard>.from(deckCards(deck));
    pool.shuffle(_rng);
    if (pool.length < 2) return (pool[0], pool[0]);
    return (pool[0], pool[1]);
  }

  /// Damien : sert un alcool fort — 4 dégâts instantanés.
  String damienServeAlcohol(Player actor, Player target) {
    final dealt = applyDamage(target, 4);
    if (!target.alive) target.killedByUid = actor.uid;
    return '🥃 ${actor.name} sert un alcool fort à ${target.name} — $dealt blessures instantanées';
  }

  /// Damien : sert un poison — 3 dégâts au début de chacun des 2 prochains
  /// tours de la cible (6 au total, cumulés).
  String damienServePoison(Player actor, Player target) {
    target.poisonTurnsRemaining = 2;
    target.poisonSourceUid = actor.uid;
    return '☠️ ${actor.name} empoisonne ${target.name} — 3 blessures par tour pendant 2 tours';
  }

  // ─── Effets capacité ─────────────────────
  /// Retourne un message de log. 'draw_dark' = signal pour l'UI.
  /// Effets de capacité que Tommy ne peut pas copier :
  /// - 'chameleon_passive' (Jason) : le déguisement n'a plus de sens puisque
  ///   Tommy est déjà révélé publiquement au moment de copier.
  /// - 'copy_ability' : ne peut pas se copier lui-même.
  static const Set<String> uncopyableAbilities = {
    'chameleon_passive', 'copy_ability',
  };

  String applyAbility(Player actor, List<Player> all, List<Terrain> layout, {Player? target, String? extra}) {
    actor.abilityUsed = true;
    final eff = actor.copiedEffect ?? actor.character!.abilityEffect;
    switch (eff) {
      case 'peek_reorder_deck':
        // Ne PAS forcer abilityUsed=false ici : le défaut (true, posé en tête
        // de fonction) verrouille le pouvoir pour le reste du tour. Il sera
        // réactivé au tour suivant via la réinitialisation standard des
        // capacités répétables (sinon Elaia pouvait relancer le choix de
        // pile en boucle indéfiniment dans le même tour).
        return 'elaia_peek';

      // ── Damien : sert un verre — nécessite une cible puis un choix ──
      case 'damien_serve':
        if (target == null) return 'cible_requise';
        // Le choix (alcool/poison) se fait via un panneau dédié après ceci —
        // ici on signale juste que la cible est mémorisée.
        return 'damien_target_chosen';

      // ── Tommy : copie le pouvoir d'un joueur révélé ──
      case 'copy_ability':
        if (target == null) return 'cible_requise';
        actor.copiedEffect = target.character!.abilityEffect;
        // abilityUsed suit la répétabilité du pouvoir copié
        actor.abilityUsed = !target.character!.abilityRepeatable;
        return 'tommy_copied:${target.character!.name}:${target.character!.ability}';

      case 'full_heal':
        actor.wounds = 0;
        return '💚 ${actor.name} soigne toutes ses blessures';

      case 'shield3':
        actor.shield = true; actor.shieldCharges = 99;
        return '🛡 ${actor.name} est insensible ce tour';

      case 'aoe_zone6':
        final idx = terrainLayoutIdx(layout, 2);
        int hit = 0;
        for (final p in all) {
          if (p.alive && p.uid != actor.uid && p.zoneIndex == idx) {
            applyDamage(p, 2);
            if (!p.alive) p.killedByUid = actor.uid;
            hit++;
          }
        }
        actor.abilityUsed = false; // répétable
        return "🐉 ${actor.name} enflamme la zone 6 — $hit joueur(s) subissent 2 blessures";

      case 'damage2_choice':
        if (target == null) return 'cible_requise';
        applyDamage(target, 2);
        if (!target.alive) target.killedByUid = actor.uid;
        return '⚡ ${actor.name} inflige 2 blessures à ${target.name}';

      // ── Raph (Soleil Levant) : subit 2, soigne la cible de 3 ──
      case 'damage2_then_heal3':
        if (target == null) return 'cible_requise';
        applyDamage(actor, 2);
        applyHeal(target, 3);
        return '🥷 ${actor.name} subit 2 et soigne ${target.name} de 3';

      // ── Inès : verrouille la capacité d'un joueur tant qu'elle est en vie ──
      // ── Meg : choisit une forme (Offensive/Défensive), alterne ensuite seule ──
      case 'meg_shapeshift':
        if (extra == null) return 'meg_choice'; // signal : afficher le choix des 2 formes
        actor.megForm = extra;
        return extra == 'offense'
            ? '🐺 ${actor.name} choisit la forme Offensive (+1 blessure infligée)'
            : '🐺 ${actor.name} choisit la forme Défensive (-1 blessure reçue)';

      case 'lock_ability_while_alive':
        if (target == null) return 'cible_requise';
        target.abilityLockedByUid = actor.uid;
        return '🔒 ${actor.name} verrouille la capacité de ${target.name} tant qu\'elle est en vie';

      // ── Maxence : rend un joueur ivre pendant 2 tours (vision brouillée
      // sur SON écran uniquement — jetons, camps/cartes et blessures) ──
      case 'maxence_drunk':
        if (target == null) return 'cible_requise';
        target.drunkTurnsRemaining = 2;
        target.drunkSeed = _rng.nextInt(999999) + 1; // jamais 0 (0 = "pas de graine")
        return '🍺 ${actor.name} rend ${target.name} complètement ivre pendant 2 tours !';

      // ── Marion : place la cible à exactement 5 blessures (soin ou dégâts) ──
      case 'set_wounds7':
        if (target == null) return 'cible_requise';
        final before = target.wounds;
        target.wounds = 7;
        if (target.wounds >= effectiveMaxHp(target)) target.alive = false;
        final diff = 7 - before;
        if (diff > 0) return '📍 ${actor.name} place ${target.name} à 7 blessures (subit $diff)';
        if (diff < 0) return '📍 ${actor.name} place ${target.name} à 7 blessures (soigné de ${-diff})';
        return '📍 ${actor.name} place ${target.name} à 7 blessures (déjà à 7)';

      // ── Léo : D4 à TOUS les joueurs, lui inclus ──
      case 'd4_all':
        final d = rollD4();
        for (final p in all) { if (p.alive) applyDamage(p, d); }
        return '🔥 ${actor.name} lance D4($d) — TOUS les joueurs subissent $d blessures';

      case 'steal_equip_choice':
        if (target == null || target.equipment.isEmpty) return '${actor.name} — aucun équipement à voler';
        final e = target.equipment.removeAt(_rng.nextInt(target.equipment.length));
        actor.equipment.add(e); _equipPassive(actor, e);
        recalcPassives(target); // sinon la victime garde le passif de l'objet volé
        return '🗡 ${actor.name} vole "${e.name}" à ${target.name}';

      case 'draw_dark':
        actor.abilityUsed = false; // répétable
        return 'draw_dark';

      case 'casino_bet':
        actor.abilityUsed = false; // répétable
        return 'casino_bet';

      case 'swap_zones':
        actor.abilityUsed = false; // répétable
        return 'swap_zones';

      case 'bonus_turns':
        // Ninja : compte les joueurs morts
        final deadCount = all.where((p) => !p.alive).length;
        if (deadCount == 0) {
          actor.abilityUsed = true;
          return 'bonus_turns_zero';
        }
        actor.abilityUsed = true;
        return 'bonus_turns:$deadCount';

      case 'choose_all_dice':
        // Fifi : dés au maximum ce tour
        actor.abilityUsed = true;
        return 'choose_all_dice';

      case 'draw_light':
        actor.abilityUsed = false; // répétable
        return 'draw_light';

      case 'self1_trigger_terrain':
        applyDamage(actor, 1);
        return 'trigger_terrain';

      // ── Marin : 3 dégâts + donne une dague à la cible (répétable) ──
      case 'damage3_give_dague':
        if (target == null) return 'cible_requise';
        final dealtMarin = applyDamage(target, 3);
        if (!target.alive) target.killedByUid = actor.uid;
        final dagueCard = deckCards(DeckType.tenebres)
            .firstWhere((c) => c.effect == 'dague_voleur');
        target.equipment.add(dagueCard);
        recalcPassives(target);
        actor.abilityUsed = false; // répétable
        return '🗡️ ${actor.name} inflige $dealtMarin à ${target.name} et lui donne une Dague du Voleur';

      // ── Julien : 2 dégâts à une cible choisie, ou se soigne de 1 si aucune cible (une fois par tour) ──
      case 'damage2_or_heal1':
        if (target == null) {
          applyHeal(actor, 1);
          return '😈 ${actor.name} se soigne de 1 blessure';
        }
        final dealtJulien = applyDamage(target, 2);
        if (!target.alive) target.killedByUid = actor.uid;
        return '😈 ${actor.name} inflige $dealtJulien blessures à ${target.name}';

      // ── Vlad (Shadow) : D4 dégâts, répétable — portée adjacente seulement ──
      case 'd4_bonus_attack':
        if (target == null) return 'cible_vlad'; // signal : cibles adjacentes seulement
        final d = rollD4();
        final dealt = applyDamage(target, d);
        if (!target.alive) target.killedByUid = actor.uid;
        actor.abilityUsed = false; // répétable
        return '💨 ${actor.name} lance D4($d) → $dealt blessures à ${target.name}';

      // ── Travert : D6 dégâts, unique ──
      case 'd6_global_attack':
        if (target == null) return 'cible_requise';
        final d = rollD6();
        final dealt = applyDamage(target, d);
        if (!target.alive) target.killedByUid = actor.uid;
        return '🎲 ${actor.name} lance D6($d) → $dealt blessures à ${target.name}';

      // ── Nils : stocke les blessures infligées, puis les déverse ──
      case 'store_damage_nils':
        // Stockage automatique et passif (géré dans resolveAttackFull et
        // resolveAttack, basé sur target.revealed) — ce chemin ne sert plus
        // qu'à DÉVERSER ce qui est stocké.
        if (target == null) return 'cible_requise';
        if (actor.storedDamage <= 0) return 'Nils — rien à déverser';
        final stored = actor.storedDamage;
        final dealt = applyDamage(target, stored);
        if (!target.alive) target.killedByUid = actor.uid;
        actor.storedDamage = 0;
        return '📦 ${actor.name} déverse $stored blessures stockées sur ${target.name} ($dealt reçues) !';

      // ── Agathe : vole 1 PV MAX à un joueur, définitivement (max 5x) ──
      case 'steal_max_hp':
        if (actor.maxHpModifier >= 5) return 'Agathe — déjà au maximum (+5 PV max)';
        if (target == null) return 'cible_requise';
        actor.maxHpModifier += 1;
        target.maxHpModifier -= 1;
        // Le vol peut faire mourir la cible si ses blessures actuelles
        // dépassent désormais son nouveau PV max réduit.
        if (target.wounds >= effectiveMaxHp(target)) target.alive = false;
        return '🧛 ${actor.name} vole 1 PV MAX à ${target.name} (elle: ${effectiveMaxHp(actor)} PV max, lui: ${effectiveMaxHp(target)} PV max)';

      // ── Rémi (bot) : choix automatique raisonnable de 2 effets sur 10 ──
      // (le joueur humain passe par sa propre boîte de dialogue de choix —
      // ce chemin n'est utilisé QUE par les bots, qui n'ont pas d'interface).
      case 'craft_equipment_remi':
        if (actor.equipment.any((e) => e.effect.startsWith('remi_custom:'))) {
          return 'Rémi — équipement déjà fabriqué';
        }
        final offered = remiDraw3(_rng);
        final picked = List<String>.from(offered)..shuffle(_rng);
        final c1 = picked[0], c2 = picked[1];
        actor.equipment.add(GameCard(
          id: 'remi_custom_${actor.uid}',
          name: 'Invention de Rémi',
          deck: DeckType.lumiere,
          type: CardType.equipement,
          text: '${kRemiAllChoices[c1]}\n${kRemiAllChoices[c2]}',
          effect: 'remi_custom:$c1,$c2',
        ));
        return '🛠️ ${actor.name} fabrique son équipement personnalisé';

      // ── Christine : choisit une zone adjacente (humain) ou zone fournie
      // par l'appelant (bot — voir solo_controller.dart / game_provider.dart
      // qui tirent un adjacent au hasard et le passent via `extra`).
      case 'move_adjacent_choice':
        final adjZones = kAdjacences[actor.zoneIndex];
        if (extra == null) return 'christine_zone_choice'; // signal : ouvrir le sélecteur de zone
        final chosenZone = int.tryParse(extra);
        if (chosenZone == null || !adjZones.contains(chosenZone)) return 'christine_zone_choice';
        actor.zoneIndex = chosenZone;
        return 'christine_moved:$chosenZone';

      // ── Baptiste : se sacrifie pour ramener un joueur mort à la vie ──
      case 'baptiste_revive':
        if (target == null) return 'cible_requise';
        if (target.alive) return 'baptiste_must_be_dead'; // sécurité : cible invalide
        if (extra == null) return 'baptiste_choose_amount'; // signal : demander le montant
        final maxSelfDmg = effectiveMaxHp(actor) - actor.wounds; // ses PV restants
        if (maxSelfDmg <= 0) return 'baptiste_no_hp_left';
        final requested = int.tryParse(extra) ?? 0;
        final selfDmg = requested.clamp(1, maxSelfDmg);
        actor.wounds += selfDmg;
        if (actor.wounds >= effectiveMaxHp(actor)) {
          actor.alive = false;
          actor.killedByUid = actor.uid; // sacrifice total, personne d'autre ne l'a tué
        }
        final tMax = effectiveMaxHp(target);
        target.wounds = (tMax - selfDmg).clamp(0, tMax);
        target.alive = true;
        target.deathPassiveProcessed = false; // pourra redéclencher ses propres passifs de mort à l'avenir
        return '✝️ ${actor.name} s\'inflige $selfDmg blessures pour ramener ${target.name} à la vie (${target.wounds}/$tMax blessures) !';

      // ── Luc : met le feu à un joueur de son choix ──
      case 'luc_ignite':
        if (target == null) return 'cible_requise';
        target.lucFireTurnsRemaining = 2;
        target.lucFireSourceUid = actor.uid;
        return '🔥 ${actor.name} met le feu à ${target.name} — 2 blessures par tour pendant 2 tours, +1 dégât à ses attaques !';

      // ── Oscar : dépense son XP au choix parmi 3 options ──
      case 'oscar_xp_spend':
        if (extra == null) return 'oscar_choice'; // signal : afficher les 3 options
        if (extra == 'water') {
          if (actor.oscarXp < 3) return 'oscar_not_enough';
          if (target == null) return 'cible_requise';
          if (target.equipment.isEmpty) {
            return '💧 ${actor.name} tente de voler un équipement à ${target.name}, mais il n\'en a aucun !';
          }
          actor.oscarXp -= 3;
          final stolen = target.equipment.removeAt(_rng.nextInt(target.equipment.length));
          actor.equipment.add(stolen);
          equipPassivePublic(actor, stolen);
          recalcPassives(target);
          return '💧 ${actor.name} dépense 3 XP — vole "${stolen.name}" à ${target.name} !';
        }
        if (extra == 'plant') {
          if (actor.oscarXp < 2) return 'oscar_not_enough';
          actor.oscarXp -= 2;
          applyHeal(actor, 2);
          return '🌿 ${actor.name} dépense 2 XP — se soigne de 2 blessures.';
        }
        if (extra == 'fire') {
          if (actor.oscarXp < 4) return 'oscar_not_enough';
          actor.oscarXp -= 4;
          actor.oscarFireBonus = true;
          return '🔥 ${actor.name} dépense 4 XP — sa prochaine attaque ce tour infligera 2 dégâts de plus !';
        }
        return 'oscar_choice';

      // ── Hong Yi : 8 dégâts à la cible, lui-même finit à 1 blessure ──
      case 'terrain_max_aoe':
        if (target == null) return 'cible_requise';
        final dealt = applyDamage(target, 8);
        if (!target.alive) target.killedByUid = actor.uid;
        final selfDealt = applyDamage(actor, 5);
        return '⚡ ${actor.name} inflige $dealt à ${target.name} — et s\'inflige $selfDealt blessures en retour !';

      // ── Carapatte : D6 lifesteal, unique ──
      case 'd6_lifesteal':
        if (target == null) return 'cible_requise';
        final d = rollD6();
        final dealt = applyDamage(target, d);
        if (!target.alive) target.killedByUid = actor.uid;
        applyHeal(actor, dealt);
        return '🐢 ${actor.name} lance D6($d) → inflige $dealt à ${target.name}, se soigne de $dealt';

      // ── Cambou : full heal + bouclier ──
      case 'full_heal_shield_turn':
        actor.wounds = 0; actor.shield = true; actor.shieldCharges = 99;
        actor.abilityUsed = true; // Unique — ne doit plus jamais pouvoir être réutilisé de toute la partie
        return '🌙 ${actor.name} se soigne et se protège';

      // ── Océane : D4 soigne tout le monde SAUF 1 joueur au choix ──
      case 'd4_heal_neighbors':
        if (target == null) return 'cible_requise';
        final d = rollD4();
        int count = 0;
        for (final p in all) {
          if (p.alive && p.uid != target.uid) { applyHeal(p, d); count++; }
        }
        return '🌊 ${actor.name} lance D4($d) — soigne $count joueur(s) (sauf ${target.name})';

      // ── Albane : rembobine (relance ses dés de déplacement, géré côté UI) ──
      case 'double_move_dice':
        return '⏪ ${actor.name} rembobine le temps — relancera ses dés de déplacement';

      // ── Amélia : sacrifice 2 PV pour soigner la cible de 4 ──
      case 'ally_sacrifice_heal':
        actor.abilityUsed = true;
        int shadowsHit = 0; int huntersHealed = 0;
        for (final p in all) {
          if (!p.alive || !p.revealed) continue;
          if (p.character?.faction == Faction.shadow) {
            applyDamage(p, 2);
            shadowsHit++;
          } else if (p.character?.faction == Faction.hunter) {
            applyHeal(p, 2);
            huntersHealed++;
          }
        }
        return '✨ ${actor.name} — $shadowsHit Shadow(s) subissent 2 blessures, $huntersHealed Hunter(s) se soignent de 2';

      // ── Augustin : passif (soin sur 7, géré côté move) ──
      case 'heal_on_same_terrain':
        actor.abilityUsed = false;
        return '🌾 ${actor.name} — passif actif (soigné de 2 sur un résultat de 7)';

      // ── Fijacked : soin = nombre d'équipements ──
      case 'heal_per_equip_eot':
        actor.abilityUsed = false;
        final healAmt = actor.equipment.length;
        if (healAmt > 0) {
          applyHeal(actor, healAmt);
          return '🏗️ ${actor.name} se soigne de $healAmt (équipements)';
        }
        return '🏗️ ${actor.name} — aucun équipement à convertir';

      // ── Tristan : échange un équipement avec un autre joueur ──
      case 'swap_equipment':
        if (target == null) return 'cible_requise';
        if (actor.equipment.isEmpty || target.equipment.isEmpty) {
          actor.abilityUsed = false; // répétable, même en cas d'échec
          return '🔄 ${actor.name} — échange impossible (équipement manquant chez l\'un des deux)';
        }
        // Tristan choisit précisément quel objet il donne et lequel il
        // reçoit (extra au format "monIndex,leurIndex") — les bots, qui ne
        // fournissent pas `extra`, retombent sur un tirage aléatoire des
        // deux côtés (comportement inchangé pour eux).
        int myIdx, theirIdx;
        if (extra != null && extra.contains(',')) {
          final parts = extra.split(',');
          myIdx = int.tryParse(parts[0]) ?? -1;
          theirIdx = int.tryParse(parts[1]) ?? -1;
          if (myIdx < 0 || myIdx >= actor.equipment.length ||
              theirIdx < 0 || theirIdx >= target.equipment.length) {
            actor.abilityUsed = false;
            return '🔄 ${actor.name} — choix d\'équipement invalide';
          }
        } else {
          myIdx = _rng.nextInt(actor.equipment.length);
          theirIdx = _rng.nextInt(target.equipment.length);
        }
        final myCard = actor.equipment.removeAt(myIdx);
        final theirCard = target.equipment.removeAt(theirIdx);
        actor.equipment.add(theirCard);
        target.equipment.add(myCard);
        recalcPassives(actor); recalcPassives(target);
        actor.abilityUsed = false; // répétable
        return '🔄 ${actor.name} échange "${myCard.name}" contre "${theirCard.name}" avec ${target.name}';

      // ── Fanny : aucun pouvoir tant qu'elle n'a pas volé une carte ──
      case 'fanny_none':
        return '🎭 ${actor.name} n\'a encore aucun pouvoir — elle doit d\'abord éliminer un joueur.';

      default:
        return '⚡ ${actor.name} utilise sa capacité';
    }
  }

  // ─── Effets cartes ────────────────────────
  /// Retourne {log, needsTarget, action}
  Map<String, dynamic> resolveCard(GameCard card, Player actor, List<Player> all,
      List<Terrain> layout, {Player? target}) {
    if (card.type == CardType.equipement) {
      actor.equipment.add(card); _equipPassive(actor, card);
      return {'log': '⚔️ ${actor.name} équipe : ${card.name}', 'needsTarget': false};
    }
    final eff = card.effect;
    switch (eff) {
      case 'heal_self_2':
        applyHeal(actor, 2);
        return {'log': '💚 ${actor.name} se soigne de 2', 'needsTarget': false};
      case 'extra_turn':
        actor.newTurn = true;
        return {'log': '⏰ ${actor.name} jouera un tour supplémentaire', 'needsTarget': false};
      case 'hunter_reveal_heal':
        if (actor.character!.faction == Faction.hunter) { actor.revealed = true; actor.wounds = 0; return {'log': '✨ ${actor.name} se révèle et soigne toutes ses blessures', 'needsTarget': false}; }
        return {'log': "${actor.name} ne remplit pas la condition", 'needsTarget': false};
      case 'shadow_reveal_heal':
        if (actor.character!.faction == Faction.shadow) { actor.revealed = true; actor.wounds = 0; return {'log': '🌑 ${actor.name} se révèle et soigne toutes ses blessures', 'needsTarget': false}; }
        return {'log': "${actor.name} ne remplit pas la condition", 'needsTarget': false};
      case 'aoe_same_zone_2':
        for (final p in all) { if (p.alive && p.uid != actor.uid && p.zoneIndex == actor.zoneIndex) applyDamage(p, 2); }
        return {'log': '🔥 Feu Primordial — 2 dégâts sur la zone de ${actor.name}', 'needsTarget': false};
      case 'shield_next_turn':
        actor.shield = true; actor.shieldCharges = 99;
        return {'log': "🛡 ${actor.name} protégé jusqu'au prochain tour", 'needsTarget': false};
      case 'dynamite':
        final d4 = rollD4(); final d6 = rollD6(); final sum = d4 + d6;
        final tid = sumToTerrainId(sum); final idx = tid != null ? terrainLayoutIdx(layout, tid) : -1;
        int hit = 0;
        for (final p in all) {
          if (p.alive && p.zoneIndex == idx) { applyDamage(p, 3, isTenebresCard: true, ignoreShield: true); hit++; }
        }
        final terrainLabel = (idx >= 0 && idx < layout.length)
            ? 'Terrain ${layout[idx].num} — ${layout[idx].name}'
            : 'aucune zone';
        final hitStr = hit > 0
            ? '$hit joueur(s) touché(s), 3 blessures chacun'
            : 'personne sur cette zone';
        return {'log': '💣 Dynamite — D4($d4)+D6($d6)=$sum désigne le $terrainLabel : $hitStr', 'needsTarget': false,
          'diceResult': {'d4': d4, 'd6': d6, 'sum': sum, 'label': 'Dynamite'}};
      case 'terrain4_heal_or_dmg':
        // Terrain 6 = Chapelle Sacrée (id:2) → soigne. Partout ailleurs → 2 dégâts
        final t6idx = terrainLayoutIdx(layout, 2);
        if (actor.zoneIndex == t6idx) { applyHeal(actor, 2); return {'log': '💧 Eau du Temple — sur le terrain 6, soigné de 2', 'needsTarget': false}; }
        applyDamage(actor, 2); return {'log': '💧 Eau du Temple — pas sur le terrain 6, subit 2 dégâts', 'needsTarget': false};
      case 'aoe_all_except_self_2':
        for (final p in all) { if (p.alive && p.uid != actor.uid) applyDamage(p, 2); }
        return {'log': '⚡ Éclair Purificateur — tous les autres joueurs subissent 2 blessures', 'needsTarget': false};
      case 'low_hp_reveal_heal':
        if (actor.character!.hp <= 11) {
          actor.revealed = true; actor.wounds = 0;
          return {'log': '🍫 ${actor.name} (${actor.character!.hp} PV max ≤ 11) se révèle et soigne toutes ses blessures', 'needsTarget': false};
        }
        return {'log': '🍫 ${actor.name} a ${actor.character!.hp} PV max — la carte n\'a aucun effet (besoin ≤ 11 PV max)', 'needsTarget': false};
      case 'force_shadow_reveal':
        if (actor.character?.faction == Faction.shadow && !actor.revealed) {
          actor.revealed = true;
          return {'log': '🪞 Miroir Divin — ${actor.name} est un Shadow, forcé à se révéler !', 'needsTarget': false};
        }
        return {'log': '🪞 Miroir Divin — ${actor.name} n\'est pas Shadow, aucun effet', 'needsTarget': false};
      case 'heal_self_4':
        applyHeal(actor, 4);
        return {'log': '🍗 ${actor.name} se soigne de 4', 'needsTarget': false};
      case 'heal_all_except_self_2':
        for (final p in all) { if (p.alive && p.uid != actor.uid) applyHeal(p, 2); }
        return {'log': '🍓 Fraise Tagada Piquante — tous les autres joueurs se soignent de 2', 'needsTarget': false};
      case 'flamme_arcades':
        final t6idx2 = terrainLayoutIdx(layout, 2);
        if (actor.zoneIndex == t6idx2) {
          applyHeal(actor, 2);
          return {'log': '🔥 Flamme des Arcades — sur le terrain 6, ${actor.name} se soigne de 2', 'needsTarget': false};
        }
        applyDamage(actor, 1);
        return {'log': '🔥 Flamme des Arcades — pas sur le terrain 6, ${actor.name} subit 1', 'needsTarget': false};
      case 'reroll_move':
        final d4r = rollD4(); final d6r = rollD6(); final sumr = d4r + d6r;
        final tidr = sumToTerrainId(sumr);
        final idxr = tidr != null ? terrainLayoutIdx(layout, tidr) : -1;
        if (idxr >= 0) actor.zoneIndex = idxr;
        // Signal 'reroll_move' pour que le controller déclenche l'effet du terrain
        return {'log': '🍾 Bouteille de Ricard — ${actor.name} se déplace (résultat $sumr)',
          'needsTarget': false, 'special': 'reroll_move',
          'diceResult': {'d4': d4r, 'd6': d6r, 'sum': sumr, 'label': 'Ricard'}};
      // Cartes nécessitant une cible
      case 'set_marker7_choice':
      case 'heal_other_d6':
      case 'heal_other_d4':
      case 'banane_demonique':
      case 'vampirisation':
      case 'blue_shell':
      case 'veuve_noire':
      case 'peau_banane':
      case 'pince_attrape':
      case 'trebuchet':
      case 'creation_marin':
      case 'corne_des_woods':
      case 'vision_shadow_2':
      case 'vision_shadow_1':
      case 'vision_hunter_1':
      case 'vision_hunter_2':
      case 'vision_shadow_heal_or_dmg':
      case 'vision_hunter_heal_or_dmg':
      case 'vision_neutral_heal_or_dmg':
      case 'vision_show_card':
      case 'vision_punish_neutral_shadow':
      case 'vision_punish_neutral_hunter':
      case 'vision_punish_shadow_hunter':
      case 'vision_hp_12plus':
      case 'vision_hp_11minus':
        if (target == null) return {'log': '', 'needsTarget': true, 'action': eff};
        return _resolveWithTarget(eff, card, actor, all, target);
      default:
        return {'log': 'Effet: $eff', 'needsTarget': false};
    }
  }

  Map<String, dynamic> _resolveWithTarget(String eff, GameCard card, Player actor,
      List<Player> all, Player target) {
    switch (eff) {
      case 'set_marker7_choice':
        // Le texte de la carte dit "Placez... sur le 7" sans condition —
        // ça doit fonctionner qu'on monte OU qu'on descende le marqueur.
        target.wounds = 7;
        if (target.wounds >= effectiveMaxHp(target)) target.alive = false;
        return {'log': '📍 ${actor.name} place ${target.name} à 7 blessures', 'needsTarget': false};
      case 'heal_other_d6':
        final d = rollD6(); applyHeal(target, d);
        return {'log': '💉 ${target.name} soigné de $d blessures', 'needsTarget': false};
      case 'heal_other_d4':
        final d4f = rollD4(); applyHeal(target, d4f);
        return {'log': '🍓 ${target.name} soigné de $d4f blessures', 'needsTarget': false,
          'diceResult': {'d4': d4f, 'd6': 0, 'sum': d4f, 'label': 'Fraise Tagada'}};
      case 'creation_marin':
        if (actor.equipment.isEmpty) {
          applyDamage(actor, 1);
          return {'log': '🩸 ${actor.name} n\'a aucun équipement à donner — subit 1 blessure', 'needsTarget': false};
        }
        final eMarin = actor.equipment.removeAt(0);
        target.equipment.add(eMarin); _equipPassive(target, eMarin);
        recalcPassives(actor); // sinon il garde le passif de l'objet qu'il vient de donner
        applyDamage(target, 2);
        if (!target.alive) target.killedByUid = actor.uid;
        return {'log': '🩸 ${actor.name} donne "${eMarin.name}" à ${target.name} et lui infligez 2 blessures', 'needsTarget': false};
      case 'corne_des_woods':
        // Étape 1 : `target` est le joueur forcé d'attaquer. On retourne un
        // signal pour que l'UI ouvre une 2e sélection (la victime, parmi les
        // joueurs à la portée du joueur forcé).
        return {'log': '', 'needsTarget': false, 'needsSecondTarget': true,
          'forcedAttackerUid': target.uid};
      case 'banane_demonique':
        final d = rollD6();
        if (d <= 4) {
          applyDamage(target, 3, isTenebresCard: true);
          if (!target.alive) target.killedByUid = actor.uid;
          return {'log': '🍌 d6($d)≤4 — ${target.name} subit 3', 'needsTarget': false,
            'diceResult': {'d4': 0, 'd6': d, 'sum': d, 'label': 'Poupée Démoniaque'}};
        }
        applyDamage(actor, 3, isTenebresCard: true);
        return {'log': '🍌 d6($d)≥5 — ${actor.name} subit 3', 'needsTarget': false,
          'diceResult': {'d4': 0, 'd6': d, 'sum': d, 'label': 'Poupée Démoniaque'}};
      case 'vampirisation':
        applyDamage(target, 2, isTenebresCard: true);
        if (!target.alive) target.killedByUid = actor.uid;
        applyHeal(actor, 1);
        return {'log': '🦇 ${actor.name} vampirise ${target.name}', 'needsTarget': false};
      case 'blue_shell':
        if (target.revealed &&
            effectiveAbility(target) == 'tenebres_heal_instead') {
          // Bibble : cette carte Ténèbres le soigne au lieu de le blesser.
          final wouldBe = target.wounds < 5 ? (5 - target.wounds) : 0;
          if (wouldBe > 0) applyHeal(target, wouldBe);
          return {'log': '🐚 ${target.name} (Bibble) se soigne de $wouldBe au lieu de subir la carte', 'needsTarget': false};
        }
        if (target.wounds < 5) target.wounds = 5;
        return {'log': '🐚 ${target.name} passe à 5 blessures', 'needsTarget': false};
      case 'veuve_noire':
        applyDamage(target, 2, isTenebresCard: true);
        if (!target.alive) target.killedByUid = actor.uid;
        applyDamage(actor, 2, isTenebresCard: true);
        return {'log': '🕷 ${actor.name} inflige 2 à ${target.name} et subit 2', 'needsTarget': false};
      case 'peau_banane':
        if (actor.equipment.isEmpty) { applyDamage(actor, 1, isTenebresCard: true); return {'log': '🍌 ${actor.name} sans équipement — subit 1', 'needsTarget': false}; }
        if (actor.equipment.length > 1) {
          return {'log': '', 'needsTarget': false, 'needsEquipChoice': true,
            'equipChoiceMode': 'give', 'equipChoiceActorUid': actor.uid, 'equipChoiceTargetUid': target.uid};
        }
        final eg = actor.equipment.removeAt(0); target.equipment.add(eg); _equipPassive(target, eg);
        recalcPassives(actor);
        return {'log': '🍌 ${actor.name} donne "${eg.name}" à ${target.name}', 'needsTarget': false};
      case 'pince_attrape':
        if (target.equipment.isEmpty) return {'log': "${target.name} n'a pas d'équipement", 'needsTarget': false};
        if (target.equipment.length > 1) {
          return {'log': '', 'needsTarget': false, 'needsEquipChoice': true,
            'equipChoiceMode': 'steal', 'equipChoiceActorUid': actor.uid, 'equipChoiceTargetUid': target.uid};
        }
        final ep = target.equipment.removeAt(0);
        actor.equipment.add(ep); _equipPassive(actor, ep); recalcPassives(target);
        return {'log': '🗡 ${actor.name} vole "${ep.name}" à ${target.name}', 'needsTarget': false};
      case 'trebuchet':
        if (actor.equipment.isEmpty) { applyDamage(actor, 1, isTenebresCard: true); return {'log': '⚙️ ${actor.name} sans équipement — subit 1', 'needsTarget': false}; }
        final e = actor.equipment.removeAt(0); target.equipment.add(e); _equipPassive(target, e);
        recalcPassives(actor); // sinon il garde le passif de l'objet qu'il vient de perdre (ex: Sainte Tunique)
        applyDamage(target, 3, isTenebresCard: true);
        if (!target.alive) target.killedByUid = actor.uid;
        return {'log': '⚙️ ${actor.name} envoie "${e.name}" + 3 dégâts à ${target.name}', 'needsTarget': false};
      case 'vision_shadow_2': return _vision(actor, target, Faction.shadow, 2);
      case 'vision_shadow_1': return _vision(actor, target, Faction.shadow, 1);
      case 'vision_hunter_2': return _vision(actor, target, Faction.hunter, 2);
      case 'vision_hunter_1': return _vision(actor, target, Faction.hunter, 1);
      case 'vision_shadow_heal_or_dmg':
        return _visionHealOrDmg(actor, target, target.character!.faction == Faction.shadow);
      case 'vision_hunter_heal_or_dmg':
        return _visionHealOrDmg(actor, target, target.character!.faction == Faction.hunter);
      case 'vision_neutral_heal_or_dmg':
        return _visionHealOrDmg(actor, target, target.character!.faction == Faction.neutral);
      case 'vision_show_card':
        // L'UI affiche la carte de `target` UNIQUEMENT à `actor` via cette clé
        // (popup temporaire), ET on mémorise la connaissance de façon
        // PERMANENTE — sans ça, l'acteur ne pouvait plus jamais reconsulter
        // la fiche complète de la cible en cliquant sur son jeton plus tard.
        if (!target.privatelyKnownBy.contains(actor.uid)) {
          target.privatelyKnownBy.add(actor.uid);
        }
        return {'log': '🔮 ${actor.name} découvre secrètement l\'identité de ${target.name}',
          'needsTarget': false, 'privateRevealUid': target.uid};
      case 'vision_punish_neutral_shadow':
        return _visionPunish(actor, target,
          target.character!.faction == Faction.neutral || target.character!.faction == Faction.shadow);
      case 'vision_punish_neutral_hunter':
        return _visionPunish(actor, target,
          target.character!.faction == Faction.neutral || target.character!.faction == Faction.hunter);
      case 'vision_punish_shadow_hunter':
        return _visionPunish(actor, target,
          target.character!.faction == Faction.shadow || target.character!.faction == Faction.hunter);
      case 'vision_hp_12plus':
        if (target.character!.hp >= 12) {
          applyDamage(target, 2);
          if (!target.alive) target.killedByUid = actor.uid;
          return {'log': '🔮 Vision — ${target.name} (12 PV ou plus) subit 2 blessures', 'needsTarget': false};
        }
        return {'log': '🔮 Vision — ${target.name} ne subit aucune blessure', 'needsTarget': false};
      case 'vision_hp_11minus':
        if (target.character!.hp <= 11) {
          applyDamage(target, 1);
          if (!target.alive) target.killedByUid = actor.uid;
          return {'log': '🔮 Vision — ${target.name} (11 PV ou moins) subit 1 blessure', 'needsTarget': false};
        }
        return {'log': '🔮 Vision — ${target.name} ne subit aucune blessure', 'needsTarget': false};
      default: return {'log': eff, 'needsTarget': false};
    }
  }

  /// Cartes "Intuition X" : si la cible est de la faction visée, elle se
  /// soigne de 1 ; sinon elle subit 1 blessure. Le message ne révèle jamais
  /// la vraie faction de la cible.
  Map<String, dynamic> _visionHealOrDmg(Player actor, Player target, bool matches) {
    if (matches) {
      applyHeal(target, 1);
      return {'log': '🔮 Vision — ${target.name} se soigne de 1', 'needsTarget': false};
    }
    applyDamage(target, 1);
    if (!target.alive) target.killedByUid = actor.uid;
    return {'log': '🔮 Vision — ${target.name} subit 1 blessure', 'needsTarget': false};
  }

  /// Cartes "Divination X ou Y" : si la cible NE correspond PAS à la
  /// supposition, elle doit choisir entre donner un équipement à l'auteur
  /// de la carte, ou subir 1 blessure. En multijoueur, ce choix est délégué
  /// à la cible via la phase chooseTarget/respond ; ici on retourne un
  /// signal `needsTargetChoice` que l'appelant (controller/provider) doit
  /// résoudre (en solo : heuristique bot ; en multi : vraie attente).
  Map<String, dynamic> _visionPunish(Player actor, Player target, bool matches) {
    if (!matches) {
      return {'log': '🔮 Vision — ${target.name} ne correspond pas, aucun effet', 'needsTarget': false};
    }
    if (target.equipment.isEmpty) {
      applyDamage(target, 1);
      if (!target.alive) target.killedByUid = actor.uid;
      return {'log': '🔮 Vision — ${target.name} n\'a pas d\'équipement, subit 1 blessure', 'needsTarget': false};
    }
    return {'log': '', 'needsTarget': false, 'needsTargetChoice': true,
      'punishActorUid': actor.uid, 'punishTargetUid': target.uid};
  }

  Map<String, dynamic> _vision(Player actor, Player target, Faction f, int dmg) {
    // Le Caméléon (Jason) : insensible aux cartes Vision, même non révélé —
    // aucune information ne doit jamais filtrer sur sa vraie faction.
    final targetEff = effectiveAbility(target);
    if (targetEff == 'chameleon_passive') {
      return {'log': '🔮 Carte Vision — ${target.name} ne subit aucune blessure', 'needsTarget': false};
    }
    // Ne pas révéler la faction dans les logs publics
    if (target.character!.faction == f) {
      applyDamage(target, dmg);
      if (!target.alive) target.killedByUid = actor.uid;
      return {'log': '🔮 Carte Vision — ${target.name} subit $dmg blessures', 'needsTarget': false};
    }
    return {'log': '🔮 Carte Vision — ${target.name} ne subit aucune blessure', 'needsTarget': false};
  }

  // ─── Attaque ─────────────────────────────
  // Retourne {log, bazookaTargets} si bazooka actif
  Map<String, dynamic> resolveAttackFull(Player attacker, Player target,
      int baseDmg, List<Player> all, {int? attackCount}) {
    int dmg = baseDmg;

    // Équipements attaquant
    if (attacker.lance && dmg > 0) dmg += 2;
    if (attacker.lanceLonginus && dmg > 0 &&
        attacker.character?.faction == Faction.hunter && attacker.revealed) dmg += 2;
    if (dmg > 0) dmg += attacker.equipment.where((e) => e.effect == 'dague_voleur').length;
    // Épée du Ninja : +2 dégâts — désormais ajoutée EN AMONT (comme les
    // autres bonus ci-dessus), avant même le stockage éventuel de Nils.
    // Avant, ce bonus était appliqué APRÈS coup via un second appel à
    // applyDamage() — un chemin que Nils (qui intercepte et stocke AVANT
    // ce point) ne pouvait jamais atteindre, perdant donc ce bonus s'il
    // portait cette épée. Alignée sur resolveAttack (multijoueur), qui ne
    // souffrait pas de ce problème.
    if (attacker.epeeNinja && dmg > 0) dmg += 2;
    // NOTE : la réduction de la Sainte Tunique se fait déjà correctement
    // DANS applyDamage(), en vérifiant le porteur qui SUBIT les dégâts (la
    // cible), pas l'attaquant — une ligne ici vérifiait à tort la Tunique de
    // l'ATTAQUANT, ce qui n'a aucun sens pour un objet défensif. Supprimée.

    // Luc/Peintre passive +1 dmg
    final atkEff = effectiveAbility(attacker);
    if (atkEff == 'ines_plus1_atk' && attacker.revealed) dmg += 1;
    // Meg : forme Offensive active → +1 dégât infligé
    if (atkEff == 'meg_shapeshift' && attacker.megForm == 'offense' && dmg > 0) dmg += 1;
    // Théo Homard +1 dmg si révélé
    if (effectiveAbility(attacker) == 'revealed_plus1_dmg') dmg += 1;
    // Felipe Pompims dernier Hunter +2
    if (atkEff == 'last_hunter_buff' && attacker.bonusMaxHp > 0) dmg += 2;
    // Mathieu : à partir de la 3ème attaque, +2 dégâts PERMANENT sur toutes
    // les attaques suivantes (pas seulement un pic sur la 3ème).
    final mathieuCount = attackCount ?? 0;
    if (effectiveAbility(attacker) == 'third_attack_bonus' && mathieuCount >= 2) dmg += 2;
    // Vache: -1 infligé
    if (effectiveAbility(attacker) == 'reduce_all_by1') dmg = max(0, dmg - 1);
    // Rémi : équipement personnalisé — bonus de dégâts choisis (suit
    // l'équipement, pas le personnage — utile s'il est volé).
    final remiChoices = remiActiveChoices(attacker);
    if (remiChoices.contains('remi_dmg1') && dmg > 0) dmg += 1;
    if (remiChoices.contains('remi_dmg2') && dmg > 0) dmg += 2;
    // Louise: si 0 dmg → 4, sinon +1
    if (effectiveAbility(attacker) == 'zero_wound_power' && attacker.revealed) {
      if (dmg == 0) dmg = 4;
      else dmg += 1;
    }
    // Carla: si cible est un Hunter révélé → soigne du même montant que les
    // dégâts qui auraient été infligés (aucune réduction). Sinon, dégâts
    // normaux sans modification.
    final isCarla = effectiveAbility(attacker) == 'heal_hunter_on_attack';
    if (isCarla && attacker.revealed && target.character?.faction == Faction.hunter && target.revealed) {
      if (dmg > 0) applyHeal(target, dmg);
      return {'log': '🕊 Carla soigne ${target.name} de $dmg au lieu de blesser', 'actualDmg': 0};
    }
    // Fifi Été: +2 si pas attaqué le tour d'avant
    if (effectiveAbility(attacker) == 'no_attack_buff'
        && attacker.revealed && attacker.bonusMaxHp > 0) {
      dmg += 2; attacker.bonusMaxHp = 0; // consume le buff
    }
    // Oscar : "Feu" activé — +2 dégâts sur sa prochaine attaque
    if (attacker.oscarFireBonus) {
      dmg += 2; attacker.oscarFireBonus = false; // consommé
    }
    // Maxime : sa première attaque après s'être révélé inflige le double.
    if (effectiveAbility(attacker) == 'maxime_double_first'
        && attacker.revealed && !attacker.maximeUsedFirstBonus) {
      dmg *= 2; attacker.maximeUsedFirstBonus = true; // consommé, ne se reproduit plus
    }
    // Luc : le joueur EN FEU inflige 1 dégât de plus à ses attaques, tant
    // que le feu dure (indépendamment de qui a attaqué qui).
    if (dmg > 0 && attacker.lucFireTurnsRemaining > 0) dmg += 1;
    // Maxence : passif révélé — chaque attaque lui inflige 1 blessure, mais
    // ajoute 2 dégâts à cette même attaque. Peut potentiellement le tuer
    // lui-même s'il est déjà très affaibli.
    if (effectiveAbility(attacker) == 'maxence_selfharm_boost'
        && attacker.revealed) {
      dmg += 2;
      applyDamage(attacker, 1);
      if (!attacker.alive) attacker.killedByUid = attacker.uid;
    }
    // Tom : dégâts bonus PERMANENTS cumulés (+2 par Shadow éliminé).
    if (dmg > 0 && attacker.tomBonusDmg > 0) dmg += attacker.tomBonusDmg;

    // Toge Sainte (porteur = attaquant) : vos propres attaques infligent 1
    // blessure de moins — appliqué EN DERNIER, après TOUS les bonus
    // d'attaque ci-dessus (dague, Meg forme Offensive, Mathieu, Tom, etc.),
    // pour que le malus réduise bien le total final plutôt que d'être
    // écrasé par un bonus qui s'appliquerait après lui.
    if (attacker.sainteTunique) dmg = max(0, dmg - 1);

    // Protection cible
    if (target.invulnerable) return {'log': '🛡 ${target.name} est invulnérable — attaque bloquée'};
    if (target.fifiAutomneShield) {
      target.fifiAutomneShield = false;
      return {'log': "🍂 Fifi d'Automne annule l'attaque !"};
    }
    // Sainte tunique cible: -1 reçu — géré une seule fois dans applyDamage()
    // (sinon la réduction s'appliquait deux fois pendant une attaque : ici
    // ET à nouveau dans applyDamage, ce qui faisait -2 au lieu de -1).
    // Vache cible: -1 reçu
    if (effectiveAbility(target) == 'reduce_all_by1') dmg = max(0, dmg - 1);
    // Inès passive: -1 reçu
    if (effectiveAbility(target) == 'ines_minus1_recv' && target.revealed) dmg = max(0, dmg - 1);
    // Meg : forme Défensive active → -1 dégât reçu
    if (effectiveAbility(target) == 'meg_shapeshift' && target.megForm == 'defense') dmg = max(0, dmg - 1);
    // Shieldtarget (Vlad Princesse)
    // handled in controller

    // Fourrure de Chaussette : renvoie l'attaque sur l'attaquant lui-même
    if (target.equipment.any((e) => e.effect == 'mirror_damage') || target.mirrorDamage) {
      final reflected = applyDamage(attacker, dmg);
      if (!attacker.alive) attacker.killedByUid = target.uid;
      return {'log': '🪞 ${target.name} renvoie l\'attaque — ${attacker.name} subit $reflected dégâts', 'actualDmg': reflected};
    }

    // Nils : passif automatique — tant qu'il est révélé, ses attaques
    // n'infligent rien, les blessures sont stockées pour être déversées
    // plus tard (bouton dédié) sur un joueur au choix.
    if (attacker.revealed &&
        effectiveAbility(attacker) == 'store_damage_nils') {
      attacker.storedDamage += dmg;
      return {'log': '📦 ${attacker.name} stocke $dmg blessures (total: ${attacker.storedDamage})', 'actualDmg': 0};
    }

    final actual = applyDamage(target, dmg);
    if (!target.alive) target.killedByUid = attacker.uid;
    // Oscar : cumule 1 XP par blessure infligée en attaque — le bonus de
    // l'Épée du Ninja est désormais déjà inclus dans `actual` (voir plus
    // haut), plus besoin de l'ajouter une seconde fois séparément.
    if (effectiveAbility(attacker) == 'oscar_xp_spend' && attacker.revealed && actual > 0) {
      attacker.oscarXp += actual;
    }
    // Victor : charme la cible et tous les joueurs présents sur sa zone —
    // se déclenche à chaque attaque, quel que soit le résultat des dégâts.
    applyVictorCharm(attacker, target, all);
    applyMaximeFirstAttacker(attacker, target, actual);
    String log = '⚔️ ${attacker.name} attaque ${target.name} — $actual dégâts';

    // Rémi : équipement personnalisé — effets choisis qui se déclenchent
    // à chaque attaque réussie (dégâts > 0). Suit l'équipement, pas le
    // personnage.
    if (actual > 0) {
      final remiChoicesA = remiActiveChoices(attacker);
      if (remiChoicesA.contains('remi_heal1')) {
        applyHeal(attacker, 1);
        log += ' | 💚 ${attacker.name} se soigne de 1';
      }
      if (remiChoicesA.contains('remi_heal2')) {
        applyHeal(attacker, 2);
        log += ' | 💚💚 ${attacker.name} se soigne de 2';
      }
      if (remiChoicesA.contains('remi_steal') && target.equipment.isNotEmpty) {
        final stolen = target.equipment.removeAt(0);
        attacker.equipment.add(stolen);
        equipPassivePublic(attacker, stolen);
        recalcPassives(target);
        log += ' | 🦹 ${attacker.name} vole "${stolen.name}"';
      }
      if (remiChoicesA.contains('remi_forceattack') && target.alive) {
        target.forcedToAttackNextTurn = true;
        log += ' | ⚡ ${target.name} devra attaquer quelqu\'un à son prochain tour';
      }
    }

    // NOTE : le Bazooka ne se gère plus ici. humanBazookaAttack() (solo) et
    // la branche dédiée de attackPlayer() (multi) bouclent déjà sur CHAQUE
    // joueur à portée et appliquent les dégâts une seule fois chacun — un
    // ancien bloc de "splash" ici dupliquait ce travail et multipliait les
    // dégâts (chaque cible recevait aussi les dégâts destinés aux AUTRES
    // cibles de la même salve, en plus des siens).

    // Scott: contre-attaque (uniquement s'il survit à l'attaque)
    bool scottCountered = false;
    int? counterD4, counterD6, counterDmg;
    final tEff = effectiveAbility(target);
    if (tEff == 'counter_attack_passive' && target.revealed && target.alive) {
      final cd4 = rollD4(); final cd6 = rollD6();
      final cDmg = (cd4 - cd6).abs();
      final cActual = applyDamage(attacker, cDmg);
      if (!attacker.alive) attacker.killedByUid = target.uid;
      log += ' | 🛡️ ${target.name} contre-attaque — D4($cd4) D6($cd6) → $cActual dégâts';
      scottCountered = true;
      counterD4 = cd4; counterD6 = cd6; counterDmg = cActual;
    }
    // Orion: vole équipement si 0 dégâts
    if (atkEff == 'zero_wound_steal' && actual == 0 && target.equipment.isNotEmpty) {
      final eq = target.equipment.removeAt(0);
      attacker.equipment.add(eq); _equipPassive(attacker, eq); recalcPassives(target);
      log += ' | 🐱 Orion vole "${eq.name}"';
    }
    // Slime passif SUR Slime: quand quelqu'un ATTAQUE Slime, l'attaquant perd un équipement
    final tgtEff2 = effectiveAbility(target);
    if (tgtEff2 == 'attack_discard_equip' && actual > 0 && attacker.equipment.isNotEmpty) {
      final lost = attacker.equipment.removeAt(0);
      recalcPassives(attacker);
      log += ' | 🟢 Slime détruit "${lost.name}" de ${attacker.name}';
    }
    // Rémi Canada: bloque soins cible
    if (atkEff == 'block_healing' && actual > 0) {
      target.cannotHeal = true;
      log += ' | 🍁 ${target.name} ne peut plus se soigner 1 tour';
    }
    // Baleine: soigne alliés à sa mort
    if (!target.alive) {
      final dTEff = effectiveAbility(target);
      if (dTEff == 'death_heal_allies' && target.character!.faction == Faction.hunter) {
        for (final p in all.where((p) => p.alive && p.character!.faction == Faction.hunter && p.revealed)) {
          applyHeal(p, 3);
        }
        log += ' | 🐋 Baleine soigne les Hunters de 3';
      }
      // Fanny: vole la carte — géré dans checkWin via killedByUid

      // Enceinte: bombe à la mort → tous les joueurs vivants subissent 4
      if (target.deathBombDmg > 0) {
        for (final p in all.where((p) => p.alive)) {
          applyDamage(p, target.deathBombDmg);
        }
        log += ' | 💣 Enceinte explose — tous subissent ${target.deathBombDmg} blessures !';
      }
      // Jesus: ressuscite
      final jEff = effectiveAbility(target);
      if (jEff == 'resurrect_once' && !target.revived) {
        target.wounds = 0; target.alive = true; target.revived = true;
        log += ' | ✝️ Jésus ressuscite !';
      }
    }
    // Raphaël Shadow mirror
    if (effectiveAbility(attacker) == 'mirror_damage' && actual > 0) {
      applyDamage(attacker, actual);
      log += ' | ⚔️ Raphaël subit $actual (miroir)';
    }
    // Rat d'Rouen: soigne de 1 si C'EST son attaque qui inflige
    if (effectiveAbility(attacker) == 'heal1_on_own_attack' && attacker.revealed && actual > 0) {
      applyHeal(attacker, 1);
    }
    // Jason neutre: +1 blessure sur toutes ses attaques
    if (effectiveAbility(attacker) == 'lie_vision_plus1' && attacker.revealed) {
      applyDamage(target, 1);
      if (!target.alive) target.killedByUid = attacker.uid;
    }

    return {'log': log, 'actualDmg': actual, 'scottCountered': scottCountered,
      'counterD4': counterD4, 'counterD6': counterD6, 'counterDmg': counterDmg};
  }

  // Compat: legacy string version
  Map<String, dynamic> resolveAttack(Player attacker, Player target, int baseDmg, {List<Player>? all}) {
    int dmg = baseDmg;
    if (attacker.lance && dmg > 0) dmg += 2;
    if (attacker.lanceLonginus && dmg > 0 &&
        attacker.character?.faction == Faction.hunter && attacker.revealed) dmg += 2;
    if (dmg > 0) dmg += attacker.equipment.where((e) => e.effect == 'dague_voleur').length;
    if (attacker.epeeNinja && dmg > 0) dmg += 2;
    // Mathieu : à partir de la 3ème attaque, +2 dégâts PERMANENT sur toutes
    // les attaques suivantes (idem resolveAttackFull, utilisée par les bots).
    if (effectiveAbility(attacker) == 'third_attack_bonus'
        && (attacker.attackCount - 1) >= 2) dmg += 2;
    // Louise : si 0 dmg → 4, sinon +1
    final atkEff = effectiveAbility(attacker);
    if (atkEff == 'zero_wound_power' && attacker.revealed) {
      if (dmg == 0) dmg = 4; else dmg += 1;
    }
    // Carla : si cible est un Hunter révélé → soigne du même montant que les
    // dégâts qui auraient été infligés (identique à resolveAttackFull).
    final isCarla = atkEff == 'heal_hunter_on_attack';
    if (isCarla && attacker.revealed && target.character?.faction == Faction.hunter && target.revealed) {
      if (dmg > 0) applyHeal(target, dmg);
      return {'log': '🕊 ${attacker.name} (Carla) soigne ${target.name} de $dmg au lieu de blesser', 'scottCountered': false};
    }
    // Théo / Fifi Été : +2 si pas attaqué le tour d'avant — manquait ici
    // (seule resolveAttackFull, utilisée par le joueur humain, l'avait),
    // donc jamais consommé/appliqué pour un Théo joué par un bot.
    if (atkEff == 'no_attack_buff' && attacker.revealed && attacker.bonusMaxHp > 0) {
      dmg += 2; attacker.bonusMaxHp = 0; // consume le buff
    }
    // Oscar : "Feu" activé — +2 dégâts sur sa prochaine attaque
    if (attacker.oscarFireBonus) {
      dmg += 2; attacker.oscarFireBonus = false; // consommé
    }
    // Maxime : sa première attaque après s'être révélé inflige le double.
    if (atkEff == 'maxime_double_first' && attacker.revealed && !attacker.maximeUsedFirstBonus) {
      dmg *= 2; attacker.maximeUsedFirstBonus = true;
    }
    // Luc : le joueur EN FEU inflige 1 dégât de plus à ses attaques.
    if (dmg > 0 && attacker.lucFireTurnsRemaining > 0) dmg += 1;
    // Maxence : passif révélé — chaque attaque lui inflige 1 blessure, mais
    // ajoute 2 dégâts à cette même attaque.
    if (atkEff == 'maxence_selfharm_boost' && attacker.revealed) {
      dmg += 2;
      applyDamage(attacker, 1);
      if (!attacker.alive) attacker.killedByUid = attacker.uid;
    }
    // Tom : dégâts bonus PERMANENTS cumulés (+2 par Shadow éliminé).
    if (dmg > 0 && attacker.tomBonusDmg > 0) dmg += attacker.tomBonusDmg;
    // Toge Sainte (porteur = attaquant) : vos propres attaques infligent 1
    // blessure de moins — appliqué EN DERNIER, après tous les bonus
    // d'attaque ci-dessus, comme dans resolveAttackFull.
    if (attacker.sainteTunique) dmg = max(0, dmg - 1);
    // Fourrure de Chaussette : renvoie l'attaque sur l'attaquant lui-même
    if (target.equipment.any((e) => e.effect == 'mirror_damage') || target.mirrorDamage) {
      final reflected = applyDamage(attacker, dmg);
      if (!attacker.alive) attacker.killedByUid = target.uid;
      return {'log': '🪞 ${target.name} renvoie l\'attaque — ${attacker.name} subit $reflected dégâts', 'scottCountered': false};
    }
    // Nils : passif automatique — tant qu'il est révélé (identique à
    // resolveAttackFull, utilisée par le joueur humain).
    if (attacker.revealed &&
        effectiveAbility(attacker) == 'store_damage_nils') {
      attacker.storedDamage += dmg;
      return {'log': '📦 ${attacker.name} stocke $dmg blessures (total: ${attacker.storedDamage})', 'scottCountered': false};
    }
    final actual = applyDamage(target, dmg);
    if (!target.alive) target.killedByUid = attacker.uid;
    // (epeeNinja already included in dmg above)
    // Oscar : cumule 1 XP par blessure infligée en attaque.
    if (effectiveAbility(attacker) == 'oscar_xp_spend' && attacker.revealed && actual > 0) {
      attacker.oscarXp += actual;
    }
    applyVictorCharm(attacker, target, all);
    applyMaximeFirstAttacker(attacker, target, actual);
    String log = '⚔️ ${attacker.name} attaque ${target.name} — $actual dégâts';
    // Scott : contre-attaque (uniquement s'il survit à l'attaque)
    bool scottCountered = false;
    int? counterD4, counterD6, counterDmg;
    final tEff = effectiveAbility(target);
    if (tEff == 'counter_attack_passive' && target.revealed && target.alive) {
      final cd4 = rollD4(); final cd6 = rollD6();
      final cDmg = (cd4 - cd6).abs();
      final cActual = applyDamage(attacker, cDmg);
      if (!attacker.alive) attacker.killedByUid = target.uid;
      log += ' | 🛡️ ${target.name} contre-attaque — D4($cd4) D6($cd6) → $cActual dégâts';
      scottCountered = true;
      counterD4 = cd4; counterD6 = cd6; counterDmg = cActual;
    }
    // Rat d'Rouen : soigne de 1 si C'EST son attaque qui inflige
    final atkEffRat = effectiveAbility(attacker);
    if (atkEffRat == 'heal1_on_own_attack' && attacker.revealed && actual > 0) {
      applyHeal(attacker, 1);
      log += ' | 🐀 ${attacker.name} se soigne de 1';
    }
    return {'log': log, 'scottCountered': scottCountered,
      'counterD4': counterD4, 'counterD6': counterD6, 'counterDmg': counterDmg};
  }

  // Hache du Berserker: attaque avec d4 seulement (pas |d4-d6|)
  Map<String, int> rollHacheAttack() {
    final d4 = rollD4();
    return {'d4': d4, 'd6': 0, 'damage': d4};
  }

  // ─── Victoire ─────────────────────────────────────────────────────────────
  Map<String, dynamic>? checkWin(List<Player> players, {
    String? justDiedId,
    String? justKilledId,   // uid de la victime (pour kill_copied, kill_felipe, etc.)
    String? killerId,        // uid du tueur
    int killsThisTurn = 0,   // Couronne: 2 kills en 1 tour
  }) {
    final alive = players.where((p) => p.alive).toList();
    final hunters = alive.where((p) => p.character!.faction == Faction.hunter).toList();
    final shadows = alive.where((p) => p.character!.faction == Faction.shadow).toList();
    final dead = players.where((p) => !p.alive).toList();

    // Tristan — vérification immédiate (3 équipements de la même couleur)
    for (final p in alive) {
      if (p.character!.winEffect == 'three_same_color_equip') {
        final byDeck = <DeckType, int>{};
        for (final eq in p.equipment) {
          byDeck[eq.deck] = (byDeck[eq.deck] ?? 0) + 1;
        }
        if (byDeck.values.any((count) => count >= 3)) {
          return {'winnerIds': [p.uid],
            'reason': '🔄 ${p.name} (Tristan) possède 3 équipements de la même couleur — Victoire !'};
        }
      }
    }

    // Oscar — vérification immédiate (13 XP cumulée)
    for (final p in alive) {
      if (p.character!.winEffect == 'oscar_xp13' && p.oscarXp >= 13) {
        return {'winnerIds': [p.uid],
          'reason': '🧪 ${p.name} (Oscar) atteint 13 XP cumulée — Victoire !'};
      }
    }

    // Victor — vérification immédiate (2 joueurs charmés à 100%)
    for (final p in alive) {
      if (p.character!.winEffect == 'victor_charm2' &&
          p.charmLevels.values.where((v) => v >= 100).length >= 2) {
        return {'winnerIds': [p.uid],
          'reason': '💘 ${p.name} (Victor) a charmé 2 joueurs — Victoire !'};
      }
    }

    // ── Vérifications à chaque mort ────────────────────────────────────────

    if (justDiedId != null) {
      final deadP = players.firstWhere((p) => p.uid == justDiedId);

      // Léo — premier mort (seulement si personne d'autre ne meurt en même temps)
      if (deadP.character!.winEffect == 'die_first_or_kill_hunters' &&
          dead.length == 1) {
        return {'winnerIds': [deadP.uid], 'reason': '💀 Léo est éliminé en premier — Victoire !'};
      }
      // Si Léo meurt en même temps que quelqu'un d'autre → il perd
      if (deadP.character!.winEffect == 'die_first_or_kill_hunters' &&
          dead.length > 1) {
        // Léo perd — ne pas retourner de victoire pour lui, continuer la vérification normale
      }

      // Fanny — vole la carte de la victime
      if (killerId != null) {
        try {
          final killer = players.firstWhere((p) => p.uid == killerId);
          if (killer.character!.winEffect == 'steal_win') {
            killer.character = deadP.character;
            killer.bonusMaxHp = deadP.bonusMaxHp;
          }
        } catch (_) {}
      }
    }

    // Tommy — est-ce LUI qui a éliminé la personne copiée ?
    for (final p in alive) {
      if (p.character!.winEffect == 'kill_copied' && justDiedId != null) {
        // copiedEffect pointe vers l'effet copié — il faut que CE SOIT Tommy
        // qui ait porté le coup fatal (killedByUid), pas n'importe quelle mort.
        try {
          final victim = players.firstWhere((pp) => pp.uid == justDiedId);
          if (victim.character!.abilityEffect == p.copiedEffect && victim.killedByUid == p.uid) {
            // Si ce kill élimine AUSSI le dernier membre d'une faction, la
            // faction gagnante partage la victoire avec Tommy (même coup) —
            // les membres DÉJÀ MORTS de cette faction gagnent aussi (comme
            // pour une victoire de camp classique), sinon un joueur mort
            // plus tôt dans la partie se retrouvait à tort compté comme
            // perdant alors que son camp vient de gagner.
            final ids = <String>{p.uid};
            if (victim.character!.faction == Faction.hunter && hunters.isEmpty) {
              ids.addAll(shadows.map((s2) => s2.uid));
              ids.addAll(players.where((pp) => !pp.alive && pp.character!.faction == Faction.shadow).map((pp) => pp.uid));
              return {'winnerIds': ids.toList(),
                'reason': '📋 ${p.name} élimine ${victim.name} (pouvoir copié) — les Shadows gagnent aussi !'};
            }
            if (victim.character!.faction == Faction.shadow && shadows.isEmpty) {
              ids.addAll(hunters.map((h2) => h2.uid));
              ids.addAll(players.where((pp) => !pp.alive && pp.character!.faction == Faction.hunter).map((pp) => pp.uid));
              return {'winnerIds': ids.toList(),
                'reason': '📋 ${p.name} élimine ${victim.name} (pouvoir copié) — les Hunters gagnent aussi !'};
            }
            return {'winnerIds': [p.uid], 'reason': '📋 ${p.name} élimine ${victim.name}, dont il avait copié le pouvoir — Victoire !'};
          }
        } catch (_) {}
      }
    }

    // Maxime — a-t-il éliminé le premier joueur à l'avoir blessé ?
    if (justDiedId != null) {
      try {
        final victim = players.firstWhere((p) => p.uid == justDiedId);
        if (victim.killedByUid != null) {
          final killer = players.firstWhere((p) => p.uid == victim.killedByUid);
          if (killer.character!.winEffect == 'maxime_kill_first_attacker' && killer.alive &&
              killer.maximeFirstAttackerUid == victim.uid) {
            return {'winnerIds': [killer.uid],
              'reason': '🗡️ ${killer.name} (Maxime) élimine ${victim.name}, le premier à l\'avoir blessé — Victoire !'};
          }
        }
      } catch (_) {}
    }

    // Mango Loco — a-t-il éliminé un joueur avec 13 PV ou plus ?
    if (justDiedId != null) {
      try {
        final victim = players.firstWhere((p) => p.uid == justDiedId);
        if (victim.character!.hp >= 13 && victim.killedByUid != null) {
          final killer = players.firstWhere((p) => p.uid == victim.killedByUid);
          if (killer.character!.winEffect == 'kill_hp13plus' && killer.alive) {
            // Si ce kill élimine AUSSI le dernier membre d'une faction, la
            // faction gagnante partage la victoire avec Mango (même coup) —
            // même logique que Tommy juste au-dessus, y compris les membres
            // DÉJÀ MORTS de cette faction (qui gagnent aussi).
            final ids = <String>{killer.uid};
            if (victim.character!.faction == Faction.hunter && hunters.isEmpty) {
              ids.addAll(shadows.map((s2) => s2.uid));
              ids.addAll(players.where((pp) => !pp.alive && pp.character!.faction == Faction.shadow).map((pp) => pp.uid));
              return {'winnerIds': ids.toList(),
                'reason': '🥭 ${killer.name} élimine ${victim.name} (13+ PV) — les Shadows gagnent aussi !'};
            }
            if (victim.character!.faction == Faction.shadow && shadows.isEmpty) {
              ids.addAll(hunters.map((h2) => h2.uid));
              ids.addAll(players.where((pp) => !pp.alive && pp.character!.faction == Faction.hunter).map((pp) => pp.uid));
              return {'winnerIds': ids.toList(),
                'reason': '🥭 ${killer.name} élimine ${victim.name} (13+ PV) — les Hunters gagnent aussi !'};
            }
            return {'winnerIds': [killer.uid], 'reason': '🥭 ${killer.name} élimine ${victim.name} (13+ PV) — Victoire !'};
          }
        }
      } catch (_) {}
    }

    // ── Victoires principales ───────────────────────────────────────────────

    // Jason : victoire EXCLUSIVE — dès que la partie serait normalement sur
    // le point de se terminer par élimination totale d'un camp, s'il est
    // vivant à ce moment-là il gagne SEUL et tout le monde d'autre perd,
    // peu importe qui aurait dû gagner à sa place. Vérifié ici (avant les
    // checks de camp) pour prendre le dessus sur une victoire de camp
    // classique — de très loin le scénario le plus fréquent pour terminer
    // une partie (les decks se remélangent automatiquement dès qu'ils sont
    // épuisés, il n'existe pas de "fin de partie" par épuisement de pioche).
    if (shadows.isEmpty || hunters.isEmpty) {
      for (final p in alive) {
        if (p.character!.winEffect == 'survive_solo_win') {
          return {'winnerIds': [p.uid],
            'reason': '🦎 ${p.name} survit jusqu\'à la fin — victoire exclusive, tous les autres joueurs perdent !'};
        }
      }
    }

    // Tous les Shadows morts → Hunters + survive gagnent
    if (shadows.isEmpty) {
      final deadHunters = players.where((p) =>
          !p.alive && p.character!.faction == Faction.hunter);
      final ids = <String>{
        ...hunters.map((p) => p.uid),
        ...deadHunters.map((p) => p.uid), // les Hunters morts gagnent aussi
        ...alive.where((p) {
          final we = p.character!.winEffect;
          return we == 'survive' || we == 'kill_christine_or_hunters';
        }).map((p) => p.uid),
      }.toList();
      return {'winnerIds': ids, 'reason': 'Les Hunters éliminent tous les Shadows !'};
    }

    // Tous les Hunters morts → Shadows + survive gagnent
    if (hunters.isEmpty) {
      final deadShadows = players.where((p) =>
          !p.alive && p.character!.faction == Faction.shadow);
      final ids = <String>{
        ...shadows.map((p) => p.uid),
        ...deadShadows.map((p) => p.uid), // les Shadows morts gagnent aussi
        ...alive.where((p) {
          final we = p.character!.winEffect;
          return we == 'survive';
        }).map((p) => p.uid),
      }.toList();
      return {'winnerIds': ids, 'reason': 'Les Shadows éliminent tous les Hunters !'};
    }

    // ── Conditions spéciales en cours de partie ────────────────────────────

    // Couronne — 2 kills en 1 tour
    if (killsThisTurn >= 2) {
      for (final p in alive) {
        if (p.character!.winEffect == 'two_kills_or_center') {
          return {'winnerIds': [p.uid], 'reason': '👑 Couronne élimine 2 personnages en 1 tour !'};
        }
      }
    }

    // kill_two — a-t-on éliminé 2 personnages ?
    if (killerId != null) {
      try {
        final killer = players.firstWhere((p) => p.uid == killerId);
        final myKills = dead.where((p) => p.killedByUid == killerId).length;
        if (killer.character!.winEffect == 'kill_two' && myKills >= 2) {
          return {'winnerIds': [killer.uid], 'reason': '🗡 ${killer.name} élimine 2 personnages — Victoire !'};
        }
      } catch (_) {}
    }

    // ── Fin de partie ──────────────────────────────────────────────────────
    return null;
  }

  // Méthode publique pour partage d'équipement (Agathe)
  void equipPassivePublic(Player p, GameCard card) => _equipPassive(p, card);

  /// Recalcule les passifs d'un joueur à partir de ses équipements actuels
  /// À appeler après vol ou perte d'équipement
  /// Gège le Fantôme — passif : ne peut pas attaquer lui-même, mais attaque
  /// automatiquement la même cible chaque fois qu'un AUTRE Hunter révélé attaque.
  /// Retourne un message de log si Gège a effectivement attaqué, sinon null.
  (String?, bool) applyGegePassiveEx(Player attacker, Player target, List<Player> all) {
    if (attacker.character?.faction != Faction.hunter || !attacker.revealed) return (null, false);
    Player? gege;
    for (final p in all) {
      if (p.alive && p.revealed && p.uid != attacker.uid &&
          effectiveAbility(p) == 'gege_passive') {
        gege = p; break;
      }
    }
    if (gege == null || !target.alive) return (null, false);
    final r = rollAttack();
    final dealt = applyDamage(target, r['damage']!);
    if (!target.alive) target.killedByUid = gege.uid;
    return ('👻 Gège attaque aussi ${target.name} — D4(${r['d4']}) D6(${r['d6']}) → $dealt blessures', true);
  }

  String? applyGegePassive(Player attacker, Player target, List<Player> all) =>
      applyGegePassiveEx(attacker, target, all).$1;

  /// Gège le Fantôme — variante Bazooka : si le Hunter révélé qui vient
  /// d'attaquer possédait le Bazooka (Mitrailleuse Funeste), Gège inflige
  /// lui aussi des dégâts à TOUS les joueurs à portée, avec un seul jet de
  /// dés (comme le bazooka lui-même), plutôt qu'une attaque simple sur une
  /// seule cible.
  (String?, bool) applyGegePassiveBazooka(Player attacker, List<Player> all) {
    if (attacker.character?.faction != Faction.hunter || !attacker.revealed) return (null, false);
    Player? gege;
    for (final p in all) {
      if (p.alive && p.revealed && p.uid != attacker.uid &&
          effectiveAbility(p) == 'gege_passive') {
        gege = p; break;
      }
    }
    if (gege == null) return (null, false);
    final r = rollAttack();
    final dmg = r['damage']!;
    int hit = 0;
    for (final p in all) {
      if (p.alive && p.uid != gege.uid && p.uid != attacker.uid) {
        applyDamage(p, dmg);
        if (!p.alive) p.killedByUid = gege.uid;
        hit++;
      }
    }
    return ('👻 Gège tire aussi au Bazooka — D4(${r['d4']}) D6(${r['d6']}) → $dmg dégâts à $hit joueur(s)', true);
  }

  /// Résout le choix de la cible pour les cartes "Divination X ou Y" :
  /// `giveEquipment = true` → la cible donne un équipement (choisi par
  /// `equipmentIndex` si fourni, sinon le premier) à l'auteur de la carte.
  /// `giveEquipment = false` → la cible subit 1 blessure à la place.
  String resolvePunishChoice(Player actor, Player target, bool giveEquipment, {int? equipmentIndex}) {
    if (!giveEquipment || target.equipment.isEmpty) {
      applyDamage(target, 1);
      if (!target.alive) target.killedByUid = actor.uid;
      return '🔮 ${target.name} choisit de subir 1 blessure';
    }
    final idx = (equipmentIndex != null && equipmentIndex < target.equipment.length) ? equipmentIndex : 0;
    final e = target.equipment.removeAt(idx);
    actor.equipment.add(e); _equipPassive(actor, e);
    recalcPassives(target); // sinon la cible garde le passif de l'objet donné
    return '🔮 ${target.name} donne "${e.name}" à ${actor.name}';
  }

  /// Heuristique simple pour le mode solo : le bot cible choisit de donner
  /// un équipement seulement s'il en a un ET qu'il a déjà perdu des PV
  /// (signe qu'il préfère préserver sa santé plutôt que son équipement).
  /// Sinon il préfère subir la blessure plutôt que de se délester.
  bool botPunishChoice(Player target) {
    if (target.equipment.isEmpty) return false;
    return target.wounds > 0;
  }

  /// À appeler une seule fois, juste après qu'un coup a potentiellement tué un
  /// joueur (avant le commit). Gère les passifs déclenchés par la mort
  /// (ex: Baleine soigne les Hunters révélés). `deathPassiveProcessed` marque
  /// le mort comme "passif de mort déjà déclenché" pour éviter les
  /// déclenchements multiples si la fonction est appelée plusieurs fois —
  /// un champ DÉDIÉ, séparé de `abilityUsed` : réutiliser ce dernier créait
  /// un vrai bug (un joueur mort ayant déjà utilisé sa capacité UNIQUE avant
  /// de mourir avait abilityUsed=true, ce qui faisait sauter TOUT le
  /// traitement de sa mort — Fanny ne volait jamais sa carte, Felipe n'était
  /// jamais sauvé si SA victime avait déjà agi, etc.
  void applyDeathPassives(List<Player> all) {
    for (final p in all) {
      if (p.alive || p.deathPassiveProcessed) continue;
      final eff = effectiveAbility(p);
      if (eff == 'death_heal_allies' && p.revealed) {
        for (final ally in all.where((a) =>
            a.alive && a.character?.faction == Faction.hunter && a.revealed)) {
          applyHeal(ally, 2);
        }
      }
      if (eff == 'lock_ability_while_alive') {
        // Inès vient de mourir : libère le joueur qu'elle avait verrouillé
        for (final locked in all) {
          if (locked.abilityLockedByUid == p.uid) locked.abilityLockedByUid = null;
        }
      }
      // Bob : revient à la vie avec 1 PV MAX de moins (8 → 7 → 6…) — sauf
      // si ce total tomberait à 0 ou moins, auquel cas il reste mort pour
      // de bon cette fois.
      if (eff == 'bob_resurrect') {
        final newMaxHp = effectiveMaxHp(p) - 1;
        if (newMaxHp > 0) {
          p.maxHpModifier -= 1;
          p.wounds = 0;
          p.alive = true;
          p.killedByUid = null; // il n'est plus "mort", personne ne l'a tué
          p.deathPassiveProcessed = false; // pourra redéclencher ce passif à sa prochaine mort
        }
      }
      // Felipe : s'il est en sursis (a survécu à des dégâts létaux) et que
      // C'EST LUI qui vient d'éliminer ce joueur, il est sauvé — se soigne
      // de 2 blessures au lieu de mourir à la fin de son tour de sursis
      // (relatif à ses blessures actuelles, plus une valeur fixe).
      if (p.killedByUid != null) {
        Player? felipeKiller;
        for (final k in all) { if (k.uid == p.killedByUid) { felipeKiller = k; break; } }
        if (felipeKiller != null && felipeKiller.felipeOnBorrowedTime) {
          felipeKiller.felipeOnBorrowedTime = false;
          applyHeal(felipeKiller, 2);
          felipeKiller.alive = true;
        }
      }
      // Tom : chaque Shadow qu'il élimine lui donne +2 PV MAX (permanent) et
      // +2 dégâts permanents à ses futures attaques. Peut se cumuler
      // plusieurs fois au fil de la partie.
      if (p.killedByUid != null && p.character?.faction == Faction.shadow) {
        Player? tomKiller;
        for (final k in all) { if (k.uid == p.killedByUid) { tomKiller = k; break; } }
        if (tomKiller != null && tomKiller.uid != p.uid && tomKiller.revealed &&
            effectiveAbility(tomKiller) == 'tom_shadow_kill_boost') {
          tomKiller.maxHpModifier += 2;
          tomKiller.tomBonusDmg += 2;
        }
      }
      // Fanny : vole la carte ENTIÈRE de sa PREMIÈRE victime (camp, pouvoir,
      // condition de victoire) — devient effectivement ce personnage, tout
      // en gardant son propre nom/icône/PV. Un seul vol possible (son
      // premier kill) — les suivants ne redéclenchent rien.
      if (p.killedByUid != null) {
        Player? fannyKiller;
        for (final k in all) { if (k.uid == p.killedByUid) { fannyKiller = k; break; } }
        if (fannyKiller != null && fannyKiller.character?.id == 'fanny' &&
            !fannyKiller.fannyHasStolen && p.character != null) {
          fannyKiller.fannyHasStolen = true;
          final victim = p.character!;
          fannyKiller.character = CharacterCard(
            id: 'fanny', name: 'Fanny', icon: '🎭', hp: 12,
            faction: victim.faction,
            ability: victim.ability,
            abilityEffect: victim.abilityEffect,
            abilityRepeatable: victim.abilityRepeatable,
            winCondition: victim.winCondition,
            winEffect: victim.winEffect,
          );
          // Voler une identité révèle automatiquement Fanny si elle ne
          // l'était pas déjà — elle ne peut plus se cacher derrière
          // "aucun pouvoir tant qu'elle n'a tué personne" une fois
          // transformée.
          if (!fannyKiller.revealed) {
            fannyKiller.revealed = true;
            fannyKiller.fannyJustRevealed = true;
          }
        }
      }
      // Crucifix en Argent : récupère TOUS les équipements de la victime
      if (p.killedByUid != null) {
        Player? killer;
        for (final k in all) { if (k.uid == p.killedByUid) { killer = k; break; } }
        if (killer != null && killer.alive &&
            killer.equipment.any((e) => e.effect == 'steal_all_on_kill') &&
            p.equipment.isNotEmpty) {
          for (final eq in List<GameCard>.from(p.equipment)) {
            killer.equipment.add(eq); _equipPassive(killer, eq);
          }
          p.equipment.clear();
          recalcPassives(killer);
        }
      }
      // Ne marque "passif traité" QUE si le joueur est encore mort à la fin
      // de cette itération — sinon ça écrasait la réinitialisation faite
      // par Bob (ressuscité) ou par la cible de Baptiste (ramenée à la vie)
      // PLUS HAUT dans cette même boucle, les empêchant de redéclencher
      // leurs propres passifs de mort lors d'un décès ultérieur.
      if (!p.alive) p.deathPassiveProcessed = true;
    }
  }

  /// Vérifie si le joueur qui vient de mourir avait de l'équipement à
  /// récupérer par son tueur. Retourne (killerUid, deadUid) si une offre de
  /// butin doit être proposée, sinon null. Ne se déclenche pas si le tueur
  /// a déjà volé automatiquement tout l'équipement (Crucifix en Argent).
  (String, String)? checkLootOpportunity(Player dead, List<Player> all) {
    if (dead.alive) return null; // sécurité : jamais de butin sur un joueur encore en vie
    if (dead.equipment.isEmpty || dead.killedByUid == null) return null;
    Player? killer;
    for (final k in all) { if (k.uid == dead.killedByUid) { killer = k; break; } }
    if (killer == null || !killer.alive) return null;
    if (killer.equipment.any((e) => e.effect == 'steal_all_on_kill')) return null; // déjà tout pris
    return (killer.uid, dead.uid);
  }

  /// Vérifie si un joueur vient de perdre son déguisement (Jason, 5+ dégâts
  /// en un tour) — retourne ce joueur pour déclencher sa vraie révélation
  /// (texte + son), ou null si personne n'est concerné. Ne fait QUE lire
  /// l'état ici ; c'est à l'appelant de remettre disguiseJustLost à false
  /// une fois l'animation déclenchée.
  Player? checkDisguiseLost(List<Player> all) {
    for (final p in all) { if (p.disguiseJustLost) return p; }
    return null;
  }

  /// Fanny : vient-elle de voler une identité (et donc de se révéler
  /// automatiquement) ? À appeler après applyDeathPassives, comme pour
  /// checkDisguiseLost (Jason).
  Player? checkFannyRevealed(List<Player> all) {
    for (final p in all) { if (p.fannyJustRevealed) return p; }
    return null;
  }

  /// Travert utilise son pouvoir — réplique spéciale si Clémence est révélée,
  /// sinon réplique générale.
  CharInteraction travertInteraction(List<Player> all) {
    final clemenceRevealed = all.any((p) =>
        p.alive && p.revealed && p.character?.id == 'clemence');
    return clemenceRevealed ? kTravertClemenceInteraction : kTravertGeneralInteraction;
  }

  /// Tommy utilise sa capacité (copie un pouvoir) alors que Richard II est révélé.
  bool checkTommyRichardInteraction(List<Player> all) {
    return all.any((p) => p.alive && p.revealed && p.character?.id == 'richard2');
  }

  /// Vérifie si le joueur mort était la cible de Jeanne et applique la
  /// récompense au tueur si c'est le cas. Retourne (log, needsCard, killerUid).
  /// À appeler après applyDeathPassives.
  (String, bool, String?) checkJeanneReward(
      String? markedUid, String? reward, String? jeanneUid,
      List<Player> all) {
    if (markedUid == null || reward == null) return ('', false, null);
    final dead = all.where((p) => !p.alive && p.uid == markedUid).toList();
    if (dead.isEmpty) return ('', false, null);
    final d = dead.first;
    // killedByUid peut être null (mort par carte/terrain) — fallback sur le premier tueur vivant trouvé
    final killerUid = d.killedByUid;
    Player? killer;
    for (final p in all) {
      if (p.uid == killerUid) { killer = p; break; }
    }
    // Si toujours pas de tueur, utiliser le premier joueur vivant (heuristique)
    killer ??= all.firstWhere((p) => p.alive, orElse: () => d);
    final (log, needsCard) = applyJeanneReward(reward, killer, d, all);
    // Jeanne elle-même se soigne de 3 si encore vivante
    if (jeanneUid != null) {
      for (final p in all) {
        if (p.uid == jeanneUid && p.alive) { applyHeal(p, 3); break; }
      }
    }
    return (log, needsCard, killer.uid);
  }

  /// Corne des Woods — étape 2 : force `forcedAttacker` à attaquer `victim`
  /// avec une attaque normale (dégâts au jet de dés standard).
  Map<String, dynamic> resolveCorneDesWoods(Player forcedAttacker, Player victim) {
    final r = rollAttack();
    final dealt = applyDamage(victim, r['damage']!, isTenebresCard: true);
    if (!victim.alive) victim.killedByUid = forcedAttacker.uid;
    final d4 = r['d4'] as int; final d6 = r['d6'] as int;
    return {
      'log': '🌳 Corne des Woods — ${forcedAttacker.name} est forcé d\'attaquer ${victim.name} : D4($d4) D6($d6) → $dealt blessures',
      'diceResult': {'d4': d4, 'd6': d6, 'sum': r['damage'], 'label': 'Corne des Woods'},
    };
  }

  /// Heuristique simple pour le mode solo : si le joueur forcé est un bot,
  /// la victime est choisie aléatoirement parmi celles à sa portée.
  Player? botCorneVictim(Player forcedAttacker, List<Player> all, List<Terrain> layout) {
    final targets = attackTargets(forcedAttacker, all, layout);
    if (targets.isEmpty) return null;
    return targets[_rng.nextInt(targets.length)];
  }

  // ─── Clémence : Pouvoir Constructeur ─────────────────────────────────────
  // Pool d'effets avec poids (plus le poids est élevé, plus l'effet est fréquent)
  static const List<(String, int)> kBuilderPool = [
    ('dmg2_one',        3),  // inflige 2 blessures à une cible
    ('dmg1_all',        3),  // inflige 1 blessure à tous
    ('heal2_one',       3),  // soigne 2 blessures à une cible
    ('heal1_all',       3),  // soigne tous les joueurs de 1
    ('atk_d4',          3),  // attaque une cible avec D4
    ('dmg4_zone45',     2),  // inflige 4 blessures à tous sur zone 4-5
    ('dmg4_self2',      2),  // inflige 4 blessures à une cible, subit 2
    ('self2_heal3',     2),  // subit 2 blessures, soigne une cible de 3
    ('steal_equip',     1),  // vole un équipement à une cible
    ('force_reveal',    1),  // oblige une cible à se révéler
    ('atk_d6',          1),  // attaque une cible avec D6
  ];

  /// Tire 3 effets distincts depuis le pool pondéré, en excluant optionnellement
  /// un effet déjà choisi (pour le 2ème tour).
  List<String> builderDraw3({String? exclude}) {
    final candidates = <String>[];
    for (final (eff, w) in kBuilderPool) {
      if (eff == exclude) continue;
      for (var i = 0; i < w; i++) candidates.add(eff);
    }
    candidates.shuffle(_rng);
    final picked = <String>[];
    for (final c in candidates) {
      if (!picked.contains(c)) { picked.add(c); if (picked.length == 3) break; }
    }
    return picked;
  }

  /// Indique si un effet Clémence nécessite une cible ou s'applique automatiquement.
  bool builderNeedsTarget(String eff) =>
      !const {'dmg1_all', 'heal1_all', 'dmg4_zone45'}.contains(eff);

  /// Texte affiché pour un effet Clémence.
  String builderEffectLabel(String eff) => switch (eff) {
    'dmg2_one'     => '⚔️ Inflige 2 blessures',
    'dmg1_all'     => '💥 Inflige 1 blessure à tous',
    'heal2_one'    => '💚 Soigne 2 blessures',
    'heal1_all'    => '✨ Soigne tous de 1',
    'atk_d4'       => '🎲 Attaque D4',
    'dmg4_zone45'  => '🔥 Inflige 4 aux joueurs en zone 4-5',
    'dmg4_self2'   => '💀 Inflige 4, subit 2',
    'self2_heal3'  => '🩹 Subit 2, soigne 3',
    'steal_equip'  => '🗡️ Vole un équipement',
    'force_reveal' => '👁️ Oblige à se révéler',
    'atk_d6'       => '🎲 Attaque D6',
    _              => eff,
  };

  /// Applique un effet Clémence sur la cible (ou zone si AoE).
  /// Retourne un message de log.
  String applyBuilderEffect(String eff, Player actor, Player? target,
      List<Player> all, List<Terrain> layout) {
    switch (eff) {
      case 'dmg2_one':
        if (target == null) return '';
        final d = applyDamage(target, 2);
        if (!target.alive) target.killedByUid = actor.uid;
        return '⚔️ Clémence inflige 2 à ${target.name} ($d)';
      case 'dmg1_all':
        for (final p in all) { if (p.alive) applyDamage(p, 1); }
        return '💥 Clémence inflige 1 à tous';
      case 'heal2_one':
        if (target == null) return '';
        applyHeal(target, 2);
        return '💚 Clémence soigne ${target.name} de 2';
      case 'heal1_all':
        for (final p in all) { if (p.alive) applyHeal(p, 1); }
        return '✨ Clémence soigne tout le monde de 1';
      case 'atk_d4':
        if (target == null) return '';
        final r = rollD4(); final d4dmg = applyDamage(target, r);
        if (!target.alive) target.killedByUid = actor.uid;
        return '🎲 Clémence attaque ${target.name} D4($r) → $d4dmg';
      case 'dmg4_zone45':
        final zone45 = [terrainLayoutIdx(layout, 1), terrainLayoutIdx(layout, 2)];
        for (final p in all) {
          if (p.alive && zone45.contains(p.zoneIndex)) {
            applyDamage(p, 4);
            if (!p.alive) p.killedByUid = actor.uid;
          }
        }
        return '🔥 Clémence : 4 blessures à tous en zone 4-5';
      case 'dmg4_self2':
        if (target == null) return '';
        final d4s2 = applyDamage(target, 4);
        if (!target.alive) target.killedByUid = actor.uid;
        applyDamage(actor, 2);
        return '💀 Clémence inflige 4 à ${target.name} ($d4s2) et subit 2';
      case 'self2_heal3':
        if (target == null) return '';
        applyDamage(actor, 2);
        applyHeal(target, 3);
        return '🩹 Clémence subit 2, soigne ${target.name} de 3';
      case 'steal_equip':
        if (target == null) return '';
        if (target.equipment.isNotEmpty) {
          final eq = target.equipment.removeAt(0);
          actor.equipment.add(eq); _equipPassive(actor, eq);
          recalcPassives(target); // sinon la victime garde le passif de l'objet volé
          return '🗡️ Clémence vole "${eq.name}" à ${target.name}';
        }
        return '🗡️ Clémence : ${target.name} n\'a aucun équipement';
      case 'force_reveal':
        if (target == null) return '';
        target.revealed = true;
        return '👁️ Clémence force ${target.name} à se révéler';
      case 'atk_d6':
        if (target == null) return '';
        final r6 = rollD6(); final d6dmg = applyDamage(target, r6);
        if (!target.alive) target.killedByUid = actor.uid;
        return '🎲 Clémence attaque ${target.name} D6($r6) → $d6dmg';
      default: return '';
    }
  }

  /// Indique si au moins un des deux effets nécessite une cible.
  bool builderCombinedNeedsTarget(String eff1, String eff2) =>
      builderNeedsTarget(eff1) || builderNeedsTarget(eff2);

  // ─── Jeanne : Prophétesse ─────────────────────────────────────────────────
  static const List<(String, int)> kJeanneRewardPool = [
    ('heal5',           3),  // Soigner 5 blessures
    ('heal3_lumiere',   3),  // Soigner 3 + carte Lumière
    ('equip_tenebres',  3),  // Carte équipement Ténèbres aléatoire
    ('shield_turn',     3),  // Invulnérable pendant 1 tour
    ('steal_all_equip', 3),  // Prendre TOUS les équipements du tué
    ('heal4_dmg2_all',  3),  // Soigner 4 + infliger 2 à tous
    ('get_dague',       1),  // Obtenir une Dague du Voleur (rare)
    ('self_dmg1',       1),  // Subir 1 blessure (rare, mauvaise récompense)
    ('draw_vision',     1),  // Piocher une carte Vision (rare)
  ];

  /// Tire 3 récompenses distinctes pondérées pour Jeanne.
  List<String> jeanneDraw3() {
    final candidates = <String>[];
    for (final (eff, w) in kJeanneRewardPool) {
      for (var i = 0; i < w; i++) candidates.add(eff);
    }
    candidates.shuffle(_rng);
    final picked = <String>[];
    for (final c in candidates) {
      if (!picked.contains(c)) { picked.add(c); if (picked.length == 3) break; }
    }
    return picked;
  }

  /// Libellé affiché pour une récompense de Jeanne.
  String jeanneRewardLabel(String eff) => switch (eff) {
    'heal5'           => '💚 Se soigner de 5 blessures',
    'heal3_lumiere'   => '💚🃏 Se soigner de 3 + carte Lumière',
    'equip_tenebres'  => '⚔️ Carte équipement Ténèbres aléatoire',
    'shield_turn'     => '🛡️ Invulnérable pendant 1 tour',
    'steal_all_equip' => '💰 Voler TOUS les équipements du joueur tué',
    'heal4_dmg2_all'  => '💥 Se soigner de 4 + infliger 2 à tous',
    'get_dague'       => '🗡️ Obtenir une Dague du Voleur',
    'self_dmg1'       => '🩸 Subir 1 blessure',
    'draw_vision'     => '🔮 Piocher une carte Vision',
    _                 => eff,
  };

  /// Applique la récompense au tueur. `killed` = le joueur marqué qui vient
  /// de mourir, `killer` = celui qui l'a tué, `jeanne` = la Prophétesse.
  (String, bool) applyJeanneReward(String reward, Player killer,
      Player dead, List<Player> all) {
    switch (reward) {
      case 'heal5':
        applyHeal(killer, 5);
        return ('🔮 ${killer.name} reçoit la récompense de Jeanne : +5 soins', false);
      case 'heal3_lumiere':
        applyHeal(killer, 3);
        return ('🔮 ${killer.name} : +3 soins + carte Lumière', true);
      case 'equip_tenebres':
        // La pioche se fait désormais côté appelant (via le même mécanisme
        // que heal3_lumiere/draw_vision) — ainsi, si la carte tirée n'est
        // PAS un équipement, elle reste utilisable normalement (choix de
        // cible) au lieu d'être gaspillée/ignorée.
        return ('🔮 ${killer.name} pioche une carte Ténèbres (récompense de Jeanne)', true);
      case 'invuln_turn':
        killer.shield = true; killer.shieldCharges = 99;
        return ('🔮 ${killer.name} est invulnérable ce tour !', false);
      case 'steal_all_equip':
        for (final eq in List<GameCard>.from(dead.equipment)) {
          killer.equipment.add(eq); _equipPassive(killer, eq);
        }
        dead.equipment.clear();
        return ('🔮 ${killer.name} vole tous les équipements de ${dead.name}', false);
      case 'heal4_dmg2all':
        applyHeal(killer, 4);
        for (final p in all) { if (p.alive && p.uid != killer.uid) applyDamage(p, 2); }
        return ('🔮 ${killer.name} : +4 soins, 2 dégâts à tous les autres !', false);
      case 'get_dague':
        final dague = kTenebresCards.firstWhere((c) => c.effect == 'dague_voleur',
            orElse: () => kTenebresCards.first);
        killer.equipment.add(dague); _equipPassive(killer, dague);
        return ('🔮 ${killer.name} obtient une Dague du Voleur', false);
      case 'self_wound1':
        applyDamage(killer, 1);
        return ('🔮 ${killer.name} subit 1 blessure (récompense de Jeanne)', false);
      case 'draw_vision':
        return ('🔮 ${killer.name} pioche une carte Vision', true);
      default:
        return ('🔮 Récompense inconnue', false);
    }
  }


  /// Résout le choix d'équipement après `needsEquipChoice`.
  /// mode='steal' : actor prend l'équipement de target à l'index donné.
  /// mode='give'  : actor donne son équipement à l'index donné à target.
  String resolveEquipChoice(String mode, Player actor, Player target, int idx) {
    if (mode == 'steal') {
      if (idx >= target.equipment.length) idx = 0;
      final e = target.equipment.removeAt(idx);
      actor.equipment.add(e); _equipPassive(actor, e); recalcPassives(target);
      return '🗡 ${actor.name} vole "${e.name}" à ${target.name}';
    } else {
      if (idx >= actor.equipment.length) idx = 0;
      final e = actor.equipment.removeAt(idx);
      target.equipment.add(e); _equipPassive(target, e); recalcPassives(actor);
      return '🍌 ${actor.name} donne "${e.name}" à ${target.name}';
    }
  }

  /// Richard II : échange deux zones du plateau. TOUS les joueurs présents
  /// sur ces deux zones suivent leur tuile (échangent aussi de position),
  /// SAUF Richard qui doit activer le terrain qui vient d'arriver sur SA
  /// case de départ (celui avec lequel il a échangé), pas celui qu'il a
  /// emporté avec lui. Retourne (log, idxTerrainQueRichardDoitActiver).
  (String, int) swapTerrainZones(int zone1, int zone2, List<Player> all,
      List<Terrain> layout, Player richard) {
    final richardStartZone = richard.zoneIndex; // avant tout changement
    // Échange les deux tuiles dans le layout
    final tmp = layout[zone1];
    layout[zone1] = layout[zone2];
    layout[zone2] = tmp;
    // Tous les joueurs présents sur zone1/zone2 suivent leur tuile (échangent
    // de position avec elle) — Richard inclus, pour le déplacement visuel.
    for (final p in all) {
      if (p.zoneIndex == zone1) p.zoneIndex = zone2;
      else if (p.zoneIndex == zone2) p.zoneIndex = zone1;
    }
    final t1 = layout[zone1]; // nouvelle tuile en zone1 (anciennement zone2)
    final t2 = layout[zone2]; // nouvelle tuile en zone2 (anciennement zone1)
    // Richard active le terrain qui vient d'arriver sur SA case de départ
    // (celui avec lequel il a échangé) — pas celui qu'il a emporté avec lui.
    final richardActivatesZone = richardStartZone;
    return ('👑 Richard II échange ${t2.name} ↔ ${t1.name} !', richardActivatesZone);
  }

  void recalcPassives(Player p) {
    // Reset all equipment-based passives
    p.hache = false; p.sniper = false; p.bazooka = false;
    p.lance = false; p.lanceLonginus = false; p.dague = false; p.sainteTunique = false;
    p.crucifixArgent = false;
    p.epeeNinja = false; p.mirrorDamage = false;
    p.terrainImmune = false; p.terrainDmgImmune = false; p.tendebresImmune = false;
    // Reapply from remaining equipment
    for (final eq in p.equipment) _equipPassive(p, eq);
  }

  // ─── Équipement passif ────────────────────
  void _equipPassive(Player p, GameCard card) {
    switch (card.effect) {
      case 'terrain9_immune':      p.terrainImmune = true; break;
      case 'terrain9_dmg_immune':  p.terrainDmgImmune = true; break;
      case 'sainte_tunique':       p.sainteTunique = true; break;
      case 'crucifix_argent':      p.crucifixArgent = true; break;
      case 'tenebres_card_immune': p.tendebresImmune = true; break;
      case 'lance_lumiere':        p.lance = true; break;
      case 'lance_longinus':       p.lanceLonginus = true; break; // +2 dmg, condition (Hunter révélé) vérifiée à l'attaque
      case 'bazooka':              p.bazooka = true; break;
      case 'hache_berserker':      p.hache = true; break;
      case 'sniper':               p.sniper = true; break;
      case 'dague_voleur':         p.dague = true; break;
      case 'epee_ninja':           p.epeeNinja = true; break;
      case 'mirror_damage':        p.mirrorDamage = true; break;
    }
    // Jason — voice line arme spéciale (une seule fois par partie)
    if (p.character?.id == 'jason' &&
        (card.effect == 'bazooka' || card.effect == 'revolver_tenebres' || card.effect == 'sniper') &&
        !p.jasonWeaponVoicePlayed) {
      p.jasonWeaponVoicePlayed = true;
      audio.playInteractionVoice(kJasonWeaponInteraction.key);
    }
    // Marin révélé reçoit une Dague du Voleur (une seule fois par partie)
    if (p.character?.id == 'marin' && card.effect == 'dague_voleur' && p.revealed &&
        !p.marinDagueVoicePlayed) {
      p.marinDagueVoicePlayed = true;
      audio.playInteractionVoice(kMarinDagueInteraction.key);
    }
  }

  // ─── Distribution des rôles ───────────────
  List<Player> assignRoles(List<Player> players) {
    return assignRolesWithPool(players);
  }

  List<Player> assignRolesWithPool(List<Player> players, {
    List<String>? pool,
    String? forcedCharId,
  }) {
    final n = players.length;
    final rng = Random();
    final cfg = getRoleConfig(n, rng);

    // Filtrer selon la pool si définie
    List<CharacterCard> availHunters = kAllCharacters.where((c) => c.faction == Faction.hunter).toList();
    List<CharacterCard> availShadows = kAllCharacters.where((c) => c.faction == Faction.shadow).toList();
    List<CharacterCard> availNeutrals = kAllCharacters.where((c) => c.faction == Faction.neutral).toList();

    if (pool != null && pool.isNotEmpty) {
      availHunters  = availHunters.where((c) => pool.contains(c.id)).toList();
      availShadows  = availShadows.where((c) => pool.contains(c.id)).toList();
      availNeutrals = availNeutrals.where((c) => pool.contains(c.id)).toList();
      // Fallback si pool trop petite
      if (availHunters.isEmpty)  availHunters  = kAllCharacters.where((c) => c.faction == Faction.hunter).toList();
      if (availShadows.isEmpty)  availShadows  = kAllCharacters.where((c) => c.faction == Faction.shadow).toList();
      if (availNeutrals.isEmpty) availNeutrals = kAllCharacters.where((c) => c.faction == Faction.neutral).toList();
    }

    (availHunters..shuffle(rng));
    (availShadows..shuffle(rng));
    (availNeutrals..shuffle(rng));

    final hunters  = availHunters.take(cfg['hunters']!).toList();
    final shadows  = availShadows.take(cfg['shadows']!).toList();
    final neutrals = availNeutrals.take(cfg['neutrals']!).toList();
    final assigned = [...hunters, ...shadows, ...neutrals]..shuffle(rng);

    for (int i = 0; i < players.length; i++) {
      players[i].character = assigned[i];
    }

    // Forcer le personnage du joueur humain si précisé — en gardant
    // TOUJOURS l'équilibre des factions (2 Hunters / 2 Shadows / 1 Neutre).
    if (forcedCharId != null) {
      final forced = kAllCharacters.where((c) => c.id == forcedCharId).firstOrNull;
      if (forced != null) {
        final human = players.firstWhere((p) => p.uid == 'human', orElse: () => players[0]);
        final humanOldChar = human.character;
        // 1) Quelqu'un a-t-il déjà EXACTEMENT le perso forcé ? Échange simple.
        final exact = players.where((p) => p.character?.id == forcedCharId && p.uid != human.uid).firstOrNull;
        if (exact != null) {
          exact.character = humanOldChar;
          human.character = forced;
        } else if (humanOldChar?.faction == forced.faction) {
          // Même faction qu'avant : simple remplacement, personne d'autre à toucher.
          human.character = forced;
        } else {
          // Le joueur humain change de faction : échanger sa place avec un
          // autre joueur de la faction CIBLE pour ne pas casser l'équilibre
          // (ex: forcer un Neutre alors qu'il avait un Hunter → un autre
          // joueur qui avait le Neutre récupère l'ancien Hunter du joueur).
          final sameTargetFaction = players.where((p) =>
              p.uid != human.uid && p.character?.faction == forced.faction).toList();
          if (sameTargetFaction.isNotEmpty) {
            final victim = sameTargetFaction[rng.nextInt(sameTargetFaction.length)];
            victim.character = humanOldChar;
            human.character = forced;
          } else {
            human.character = forced; // cas limite, ne devrait pas arriver
          }
        }
      }
    }

    return players;
  }
  // ─── Passifs début de tour ──────────────────────────────────────────────────
  List<String> applyStartOfTurnPassives(Player p, List<Player> all,
      List<Terrain> layout, {GameCard? lastLumiereCard}) {
    final logs = <String>[];

    // Plat de Tripes : équipement, fonctionne peu importe l'état de révélation
    if (p.equipment.any((e) => e.effect == 'plat_de_tripes')) {
      applyDamage(p, 1);
      logs.add('🍖 Plat de Tripes — ${p.name} subit 1 blessure');
    }
    // Menu Bon et Pas Cher : équipement, cible aléatoire parmi les vivants
    if (p.equipment.any((e) => e.effect == 'menu_bon_pas_cher')) {
      final candidates = all.where((x) => x.alive).toList();
      if (candidates.isNotEmpty) {
        final t = candidates[_rng.nextInt(candidates.length)];
        applyDamage(t, 1);
        applyHeal(p, 1);
        logs.add('🍔 Menu Bon et Pas Cher — ${p.name} inflige 1 à ${t.name} et se soigne de 1');
      }
    }
    // Menu Cher et Pas Bon : équipement, cible aléatoire parmi les vivants
    if (p.equipment.any((e) => e.effect == 'menu_cher_pas_bon')) {
      final candidates = all.where((x) => x.alive).toList();
      if (candidates.isNotEmpty) {
        final t = candidates[_rng.nextInt(candidates.length)];
        applyHeal(t, 1);
        applyDamage(p, 1);
        logs.add('🍽️ Menu Cher et Pas Bon — ${p.name} soigne ${t.name} de 1 et subit 1');
      }
    }

    // Damien : poison — 3 blessures par tour pendant 2 tours (6 au total)
    if (p.alive && p.poisonTurnsRemaining > 0) {
      applyDamage(p, 3);
      p.poisonTurnsRemaining--;
      logs.add('☠️ ${p.name} subit 3 blessures du poison (${p.poisonTurnsRemaining} tour(s) restant(s))');
      if (!p.alive) p.killedByUid = p.poisonSourceUid; // attribue le kill à Damien
      if (p.poisonTurnsRemaining <= 0) p.poisonSourceUid = null;
    }

    // Luc : feu — 2 blessures par tour pendant 2 tours, +1 dégât aux
    // attaques du joueur en feu tant que ça dure (voir resolveAttackFull et
    // resolveAttack pour ce second effet).
    if (p.alive && p.lucFireTurnsRemaining > 0) {
      applyDamage(p, 2);
      p.lucFireTurnsRemaining--;
      logs.add('🔥 ${p.name} brûle et subit 2 blessures (${p.lucFireTurnsRemaining} tour(s) restant(s))');
      if (!p.alive) p.killedByUid = p.lucFireSourceUid; // attribue le kill à Luc
      if (p.lucFireTurnsRemaining <= 0) p.lucFireSourceUid = null;
    }

    // Maxence : ivresse — purement visuelle (aucun dégât), décompte au
    // début de CHACUN des 2 prochains tours de la victime.
    if (p.alive && p.drunkTurnsRemaining > 0) {
      p.drunkTurnsRemaining--;
      logs.add('🍺 ${p.name} est toujours ivre (${p.drunkTurnsRemaining} tour(s) restant(s))');
      if (p.drunkTurnsRemaining <= 0) p.drunkSeed = 0;
    }

    final eff = effectiveAbility(p);
    if (!p.revealed) return logs;

    // Fijacked: soigne 1 par équipement
    if (eff == 'heal_per_equip_eot' && p.equipment.isNotEmpty) {
      applyHeal(p, p.equipment.length);
      logs.add('🏺 Fijacked soigné de \${p.equipment.length}');
    }
    // Meg : si une forme a déjà été choisie, elle bascule automatiquement
    // (Offensive ↔ Défensive) au début de chacun de ses tours suivants.
    if (eff == 'meg_shapeshift' && p.megForm != null) {
      p.megForm = p.megForm == 'offense' ? 'defense' : 'offense';
      logs.add(p.megForm == 'offense'
          ? '🐺 ${p.name} bascule en forme Offensive (+1 blessure infligée)'
          : '🐺 ${p.name} bascule en forme Défensive (-1 blessure reçue)');
    }
    // (ancien passif Hailey retiré — personnage remplacé par Scott)
    // Augustin: soigne 2 si dé = 7 — géré dans humanMove
    // Léo: D4 all — géré dans humanUseAbility
    // Rat d'Rouen: passif dans resolveAttackFull

    return logs;
  }


  // ─── Délégation capacité (retourne log + special) ───────────────────────────
  Map<String, dynamic> applyAbilityFull(Player actor, List<Player> all,
      List<Terrain> layout, {Player? target}) {
    // Appelle applyAbility et enveloppe le résultat
    try {
      final log = applyAbility(actor, all, layout, target: target);
      if (log == null || log == 'cible_requise') return {'needsTarget': true};
      if (log == 'draw_dark') return {'log': '', 'special': 'draw_dark'};
      if (log == 'draw_light') return {'log': '', 'special': 'draw_light'};
      if (log == 'trigger_terrain') return {'log': '', 'special': 'trigger_terrain'};
      return {'log': log, 'special': null};
    } catch (e) {
      return {'log': 'Erreur pouvoir: $e', 'special': null};
    }
  }


}
