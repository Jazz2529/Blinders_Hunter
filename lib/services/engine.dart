// lib/services/engine.dart
// Moteur de jeu pur — aucune dépendance Flutter ou Firebase
// Import: models + data uniquement

import 'dart:math';
import 'engine_abilities.dart';
import '../models/models.dart';
import 'audio_service.dart';
import '../data/game_data.dart';

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
    final eff = attacker.copiedEffect ?? attacker.character?.abilityEffect ?? '';
    if (eff == 'gege_passive' && attacker.revealed) return [];
    final z = attacker.zoneIndex;
    final adj = kAdjacences[z];
    // Révolver des Ténèbres : portée INVERSÉE — uniquement les zones hors
    // de son propre secteur ET hors des zones adjacentes (ne peut plus
    // attaquer dans sa propre zone).
    if (attacker.equipment.any((e) => e.effect == 'revolver_tenebres')) {
      return all.where((p) => p.alive && p.uid != attacker.uid
          && p.zoneIndex != z && !adj.contains(p.zoneIndex)).toList();
    }
    // Pirate et Sniper = portée infinie
    if (attacker.infiniteRange || attacker.sniper || eff == 'infinite_range') {
      return all.where((p) => p.alive && p.uid != attacker.uid).toList();
    }
    return all.where((p) => p.alive && p.uid != attacker.uid
        && (p.zoneIndex == z || adj.contains(p.zoneIndex))).toList();
  }

  // ─── Dégâts / soins ──────────────────────
  int applyDamage(Player p, int n, {bool isTenebresCard = false, bool ignoreShield = false, bool isTerrain9Dmg = false}) {
    if (!p.alive) return 0;
    if (isTerrain9Dmg && p.terrainDmgImmune) return 0; // Broche de Chance
    if (isTenebresCard && p.tendebresImmune) return 0;
    // BIBBLE: cartes ténèbres le soignent au lieu de le blesser
    if (isTenebresCard && p.revealed &&
        (p.copiedEffect ?? p.character?.abilityEffect ?? '') == 'tenebres_heal_instead') {
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
    if (p.sainteTunique) n = max(0, n - 1);
    p.wounds += n;
    if (p.wounds >= p.character!.hp) p.alive = false;
    if (n > 0) audio.playDamage();
    // Jason (Caméléon) : perd son déguisement s'il subit 5+ blessures en un seul tour
    if (n > 0 && p.disguiseNameOverride != null) {
      p.damageTakenThisTurn += n;
      if (p.damageTakenThisTurn >= 5) {
        p.disguiseNameOverride = null;
        p.disguiseIconOverride = null;
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
  GameCard drawCard(DeckType deck, {Map<String, List<String>>? forcedQueue}) {
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

  String applyAbility(Player actor, List<Player> all, List<Terrain> layout, {Player? target}) {
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
          if (p.alive && p.uid != actor.uid && p.zoneIndex == idx) { applyDamage(p, 2); hit++; }
        }
        actor.abilityUsed = false; // répétable
        return "🐉 ${actor.name} enflamme la zone 6 — $hit joueur(s) subissent 2 blessures";

      case 'damage2_choice':
        if (target == null) return 'cible_requise';
        applyDamage(target, 2);
        return '⚡ ${actor.name} inflige 2 blessures à ${target.name}';

      // ── Raph (Soleil Levant) : subit 2, soigne la cible de 3 ──
      case 'damage2_then_heal3':
        if (target == null) return 'cible_requise';
        applyDamage(actor, 2);
        applyHeal(target, 3);
        return '🥷 ${actor.name} subit 2 et soigne ${target.name} de 3';

      // ── Marion : place la cible à exactement 5 blessures (soin ou dégâts) ──
      case 'set_wounds5':
        if (target == null) return 'cible_requise';
        final before = target.wounds;
        target.wounds = 5;
        if (target.wounds >= target.character!.hp) target.alive = false;
        final diff = 5 - before;
        if (diff > 0) return '📍 ${actor.name} place ${target.name} à 5 blessures (subit $diff)';
        if (diff < 0) return '📍 ${actor.name} place ${target.name} à 5 blessures (soigné de ${-diff})';
        return '📍 ${actor.name} place ${target.name} à 5 blessures (déjà à 5)';

      // ── Léo : D4 à TOUS les joueurs, lui inclus ──
      case 'd4_all':
        final d = rollD4();
        for (final p in all) { if (p.alive) applyDamage(p, d); }
        return '🔥 ${actor.name} lance D4($d) — TOUS les joueurs subissent $d blessures';

      case 'steal_equip_choice':
        if (target == null || target.equipment.isEmpty) return '${actor.name} — aucun équipement à voler';
        final e = target.equipment.removeAt(_rng.nextInt(target.equipment.length));
        actor.equipment.add(e); _equipPassive(actor, e);
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
        return '😈 ${actor.name} inflige $dealtJulien blessures à ${target.name}';

      // ── Vlad (Shadow) : D4 dégâts, répétable — portée adjacente seulement ──
      case 'd4_bonus_attack':
        if (target == null) return 'cible_vlad'; // signal : cibles adjacentes seulement
        final d = rollD4();
        final dealt = applyDamage(target, d);
        actor.abilityUsed = false; // répétable
        return '💨 ${actor.name} lance D4($d) → $dealt blessures à ${target.name}';

      // ── Travert : D6 dégâts, unique ──
      case 'd6_global_attack':
        if (target == null) return 'cible_requise';
        final d = rollD6();
        final dealt = applyDamage(target, d);
        return '🎲 ${actor.name} lance D6($d) → $dealt blessures à ${target.name}';

      // ── Hong Yi : 8 dégâts à la cible, lui-même meurt ──
      case 'terrain_max_aoe':
        if (target == null) return 'cible_requise';
        final dealt = applyDamage(target, 8);
        actor.wounds = actor.character!.hp; actor.alive = false;
        return '⚡ ${actor.name} inflige $dealt à ${target.name} — et meurt de sa propre puissance !';

      // ── Carapatte : D6 lifesteal, unique ──
      case 'd6_lifesteal':
        if (target == null) return 'cible_requise';
        final d = rollD6();
        final dealt = applyDamage(target, d);
        applyHeal(actor, dealt);
        return '🐢 ${actor.name} lance D6($d) → inflige $dealt à ${target.name}, se soigne de $dealt';

      // ── Cambou : full heal + bouclier ──
      case 'full_heal_shield_turn':
        actor.wounds = 0; actor.shield = true; actor.shieldCharges = 99;
        return '🌙 ${actor.name} se soigne et se protège';

      // ── Océane : D4 soigne soi + voisins ──
      case 'd4_heal_neighbors':
        final d = rollD4();
        final order = all.where((x) => x.alive).toList();
        final idx = order.indexWhere((x) => x.uid == actor.uid);
        if (idx >= 0 && order.length >= 3) {
          final prev = order[(idx - 1 + order.length) % order.length];
          final next = order[(idx + 1) % order.length];
          applyHeal(actor, d); applyHeal(prev, d); applyHeal(next, d);
          return '🌊 ${actor.name} lance D4($d) — soigne ${actor.name}, ${prev.name}, ${next.name}';
        }
        applyHeal(actor, d);
        return '🌊 ${actor.name} lance D4($d) — se soigne de $d';

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
        final myIdx = _rng.nextInt(actor.equipment.length);
        final theirIdx = _rng.nextInt(target.equipment.length);
        final myCard = actor.equipment.removeAt(myIdx);
        final theirCard = target.equipment.removeAt(theirIdx);
        actor.equipment.add(theirCard);
        target.equipment.add(myCard);
        recalcPassives(actor); recalcPassives(target);
        actor.abilityUsed = false; // répétable
        return '🔄 ${actor.name} échange "${myCard.name}" contre "${theirCard.name}" avec ${target.name}';

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
        int revealedCount = 0;
        for (final p in all) {
          if (p.alive && p.character?.faction == Faction.shadow &&
              (p.copiedEffect ?? p.character?.abilityEffect ?? '') != 'chameleon_passive' &&
              !p.revealed) {
            p.revealed = true; revealedCount++;
          }
        }
        return {'log': '🪞 Miroir Divin — $revealedCount Shadow(s) forcé(s) à se révéler', 'needsTarget': false};
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
        if (target.wounds < 7) target.wounds = 7;
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
        applyDamage(target, 2);
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
          return {'log': '🍌 d6($d)≤4 — ${target.name} subit 3', 'needsTarget': false,
            'diceResult': {'d4': 0, 'd6': d, 'sum': d, 'label': 'Poupée Démoniaque'}};
        }
        applyDamage(actor, 3, isTenebresCard: true);
        return {'log': '🍌 d6($d)≥5 — ${actor.name} subit 3', 'needsTarget': false,
          'diceResult': {'d4': 0, 'd6': d, 'sum': d, 'label': 'Poupée Démoniaque'}};
      case 'vampirisation':
        applyDamage(target, 2, isTenebresCard: true); applyHeal(actor, 1);
        return {'log': '🦇 ${actor.name} vampirise ${target.name}', 'needsTarget': false};
      case 'blue_shell':
        if (target.wounds < 5) target.wounds = 5;
        return {'log': '🐚 ${target.name} passe à 5 blessures', 'needsTarget': false};
      case 'veuve_noire':
        applyDamage(target, 2, isTenebresCard: true); applyDamage(actor, 2, isTenebresCard: true);
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
        final e = actor.equipment.removeAt(0); target.equipment.add(e); _equipPassive(target, e); applyDamage(target, 3, isTenebresCard: true);
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
        // L'UI affiche la carte de `target` UNIQUEMENT à `actor` via cette clé.
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
          return {'log': '🔮 Vision — ${target.name} (12 PV ou plus) subit 2 blessures', 'needsTarget': false};
        }
        return {'log': '🔮 Vision — ${target.name} ne subit aucune blessure', 'needsTarget': false};
      case 'vision_hp_11minus':
        if (target.character!.hp <= 11) {
          applyDamage(target, 1);
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
      return {'log': '🔮 Vision — ${target.name} n\'a pas d\'équipement, subit 1 blessure', 'needsTarget': false};
    }
    return {'log': '', 'needsTarget': false, 'needsTargetChoice': true,
      'punishActorUid': actor.uid, 'punishTargetUid': target.uid};
  }

  Map<String, dynamic> _vision(Player actor, Player target, Faction f, int dmg) {
    // Le Caméléon (Jason) : insensible aux cartes Vision, même non révélé —
    // aucune information ne doit jamais filtrer sur sa vraie faction.
    final targetEff = target.copiedEffect ?? target.character?.abilityEffect ?? '';
    if (targetEff == 'chameleon_passive') {
      return {'log': '🔮 Carte Vision — ${target.name} ne subit aucune blessure', 'needsTarget': false};
    }
    // Ne pas révéler la faction dans les logs publics
    if (target.character!.faction == f) {
      applyDamage(target, dmg);
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
    if (attacker.sainteTunique) dmg = max(0, dmg - 1);

    // Luc/Peintre passive +1 dmg
    final atkEff = attacker.copiedEffect ?? attacker.character?.abilityEffect ?? '';
    if (atkEff == 'ines_plus1_atk' && attacker.revealed) dmg += 1;
    // Théo Homard +1 dmg si révélé
    if ((attacker.copiedEffect ?? attacker.character?.abilityEffect ?? '') == 'revealed_plus1_dmg') dmg += 1;
    // Felipe Pompims dernier Hunter +2
    if (atkEff == 'last_hunter_buff' && attacker.bonusMaxHp > 0) dmg += 2;
    // Mathieu: 3ème attaque +3
    final mathieuCount = attackCount ?? 0;
    if ((attacker.copiedEffect ?? attacker.character?.abilityEffect ?? '') == 'third_attack_bonus' && mathieuCount % 3 == 2) dmg += 3;
    // Vache: -1 infligé
    if ((attacker.copiedEffect ?? attacker.character?.abilityEffect ?? '') == 'reduce_all_by1') dmg = max(0, dmg - 1);
    // Louise: si 0 dmg → 4, sinon +1
    if ((attacker.copiedEffect ?? attacker.character?.abilityEffect ?? '') == 'zero_wound_power') {
      if (dmg == 0) dmg = 4;
      else dmg += 1;
    }
    // Carla: si cible est un Hunter révélé → soigne au lieu de blesser (−1 dégât)
    final isCarla = (attacker.copiedEffect ?? attacker.character?.abilityEffect ?? '') == 'heal_hunter_on_attack';
    if (isCarla && attacker.revealed && target.character?.faction == Faction.hunter && target.revealed) {
      final healAmt = max(0, dmg - 1);
      if (healAmt > 0) applyHeal(target, healAmt);
      return {'log': '🕊 Carla soigne ${target.name} de $healAmt au lieu de blesser', 'actualDmg': 0};
    }
    // Carla: même contre non-Hunter, inflige 1 de moins
    if (isCarla && attacker.revealed) dmg = max(0, dmg - 1);
    // Fifi Été: +2 si pas attaqué le tour d'avant
    if ((attacker.copiedEffect ?? attacker.character?.abilityEffect ?? '') == 'no_attack_buff'
        && attacker.revealed && attacker.bonusMaxHp > 0) {
      dmg += 2; attacker.bonusMaxHp = 0; // consume le buff
    }

    // Protection cible
    if (target.invulnerable) return {'log': '🛡 ${target.name} est invulnérable — attaque bloquée'};
    if (target.fifiAutomneShield) {
      target.fifiAutomneShield = false;
      return {'log': "🍂 Fifi d'Automne annule l'attaque !"};
    }
    // Sainte tunique cible: -1 reçu
    if (target.sainteTunique) dmg = max(0, dmg - 1);
    // Vache cible: -1 reçu
    if ((target.copiedEffect ?? target.character?.abilityEffect ?? '') == 'reduce_all_by1') dmg = max(0, dmg - 1);
    // Inès passive: -1 reçu
    if ((target.copiedEffect ?? target.character?.abilityEffect ?? '') == 'ines_minus1_recv' && target.revealed) dmg = max(0, dmg - 1);
    // Shieldtarget (Vlad Princesse)
    // handled in controller

    // Fourrure de Chaussette : renvoie l'attaque sur l'attaquant lui-même
    if (target.equipment.any((e) => e.effect == 'mirror_damage') || target.mirrorDamage) {
      final reflected = applyDamage(attacker, dmg);
      if (!attacker.alive) attacker.killedByUid = target.uid;
      return {'log': '🪞 ${target.name} renvoie l\'attaque — ${attacker.name} subit $reflected dégâts', 'actualDmg': reflected};
    }

    final actual = applyDamage(target, dmg);
    if (!target.alive) target.killedByUid = attacker.uid;
    if (actual > 0 && attacker.epeeNinja) applyDamage(target, 2);
    String log = '⚔️ ${attacker.name} attaque ${target.name} — $actual dégâts';

    // Bazooka: AoE
    if (attacker.bazooka && dmg > 0) {
      final z = attacker.zoneIndex;
      final adj = kAdjacences[z];
      final splashed = all.where((p) =>
        p.alive && p.uid != attacker.uid && p.uid != target.uid &&
        (p.zoneIndex == z || adj.contains(p.zoneIndex))).toList();
      for (final p in splashed) { applyDamage(p, dmg); if (!p.alive) p.killedByUid = attacker.uid; }
      if (splashed.isNotEmpty) log += ' + 💥 Bazooka sur ${splashed.length} joueurs';
    }

    // Scott: contre-attaque (uniquement s'il survit à l'attaque)
    bool scottCountered = false;
    final tEff = target.copiedEffect ?? target.character?.abilityEffect ?? '';
    if (tEff == 'counter_attack_passive' && target.revealed && target.alive) {
      final cd4 = rollD4(); final cd6 = rollD6();
      final cDmg = (cd4 - cd6).abs();
      final cActual = applyDamage(attacker, cDmg);
      if (!attacker.alive) attacker.killedByUid = target.uid;
      log += ' | 🛡️ ${target.name} contre-attaque — D4($cd4) D6($cd6) → $cActual dégâts';
      scottCountered = true;
    }
    // Orion: vole équipement si 0 dégâts
    if (atkEff == 'zero_wound_steal' && actual == 0 && target.equipment.isNotEmpty) {
      final eq = target.equipment.removeAt(0);
      attacker.equipment.add(eq); _equipPassive(attacker, eq); recalcPassives(target);
      log += ' | 🐱 Orion vole "${eq.name}"';
    }
    // Slime passif SUR Slime: quand quelqu'un ATTAQUE Slime, l'attaquant perd un équipement
    final tgtEff2 = target.copiedEffect ?? target.character?.abilityEffect ?? '';
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
      final dTEff = target.copiedEffect ?? target.character?.abilityEffect ?? '';
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
      final jEff = target.copiedEffect ?? target.character?.abilityEffect ?? '';
      if (jEff == 'resurrect_once' && !target.revived) {
        target.wounds = 0; target.alive = true; target.revived = true;
        log += ' | ✝️ Jésus ressuscite !';
      }
    }
    // Raphaël Shadow mirror
    if ((attacker.copiedEffect ?? attacker.character?.abilityEffect ?? '') == 'mirror_damage' && actual > 0) {
      applyDamage(attacker, actual);
      log += ' | ⚔️ Raphaël subit $actual (miroir)';
    }
    // Rat d'Rouen: soigne de 1 si C'EST son attaque qui inflige
    if ((attacker.copiedEffect ?? attacker.character?.abilityEffect ?? '') == 'heal1_on_own_attack' && actual > 0) {
      applyHeal(attacker, 1);
    }
    // Jason neutre: +1 blessure sur toutes ses attaques
    if ((attacker.copiedEffect ?? attacker.character?.abilityEffect ?? '') == 'lie_vision_plus1' && attacker.revealed) {
      applyDamage(target, 1);
    }

    return {'log': log, 'actualDmg': actual, 'scottCountered': scottCountered};
  }

  // Compat: legacy string version
  Map<String, dynamic> resolveAttack(Player attacker, Player target, int baseDmg) {
    int dmg = baseDmg;
    if (attacker.lance && dmg > 0) dmg += 2;
    if (attacker.lanceLonginus && dmg > 0 &&
        attacker.character?.faction == Faction.hunter && attacker.revealed) dmg += 2;
    if (dmg > 0) dmg += attacker.equipment.where((e) => e.effect == 'dague_voleur').length;
    if (attacker.epeeNinja && dmg > 0) dmg += 2;
    // Louise : si 0 dmg → 4, sinon +1
    final atkEff = attacker.copiedEffect ?? attacker.character?.abilityEffect ?? '';
    if (atkEff == 'zero_wound_power') {
      if (dmg == 0) dmg = 4; else dmg += 1;
    }
    if (attacker.sainteTunique) dmg = max(0, dmg - 1);
    // Fourrure de Chaussette : renvoie l'attaque sur l'attaquant lui-même
    if (target.equipment.any((e) => e.effect == 'mirror_damage') || target.mirrorDamage) {
      final reflected = applyDamage(attacker, dmg);
      if (!attacker.alive) attacker.killedByUid = target.uid;
      return {'log': '🪞 ${target.name} renvoie l\'attaque — ${attacker.name} subit $reflected dégâts', 'scottCountered': false};
    }
    final actual = applyDamage(target, dmg);
    if (!target.alive) target.killedByUid = attacker.uid;
    // (epeeNinja already included in dmg above)
    String log = '⚔️ ${attacker.name} attaque ${target.name} — $actual dégâts';
    // Scott : contre-attaque (uniquement s'il survit à l'attaque)
    bool scottCountered = false;
    final tEff = target.copiedEffect ?? target.character?.abilityEffect ?? '';
    if (tEff == 'counter_attack_passive' && target.revealed && target.alive) {
      final cd4 = rollD4(); final cd6 = rollD6();
      final cDmg = (cd4 - cd6).abs();
      final cActual = applyDamage(attacker, cDmg);
      if (!attacker.alive) attacker.killedByUid = target.uid;
      log += ' | 🛡️ ${target.name} contre-attaque — D4($cd4) D6($cd6) → $cActual dégâts';
      scottCountered = true;
    }
    // Rat d'Rouen : soigne de 1 si C'EST son attaque qui inflige
    final atkEffRat = attacker.copiedEffect ?? attacker.character?.abilityEffect ?? '';
    if (atkEffRat == 'heal1_on_own_attack' && actual > 0) {
      applyHeal(attacker, 1);
      log += ' | 🐀 ${attacker.name} se soigne de 1';
    }
    return {'log': log, 'scottCountered': scottCountered};
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
    bool gameEnding = false, // appelé en fin de partie (survive, unrevealed, etc.)
    List<String>? teamAllyUids, // Dresseur: uids de l'équipe
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

      // Felipe tué — son tueur doit se révéler
      if (deadP.character!.id == 'felipe' && killerId != null) {
        try { players.firstWhere((p) => p.uid == killerId).revealed = true; } catch (_) {}
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
            // faction gagnante partage la victoire avec Tommy (même coup).
            final ids = <String>{p.uid};
            if (victim.character!.faction == Faction.hunter && hunters.isEmpty) {
              ids.addAll(shadows.map((s2) => s2.uid));
              return {'winnerIds': ids.toList(),
                'reason': '📋 ${p.name} élimine ${victim.name} (pouvoir copié) — les Shadows gagnent aussi !'};
            }
            if (victim.character!.faction == Faction.shadow && shadows.isEmpty) {
              ids.addAll(hunters.map((h2) => h2.uid));
              return {'winnerIds': ids.toList(),
                'reason': '📋 ${p.name} élimine ${victim.name} (pouvoir copié) — les Hunters gagnent aussi !'};
            }
            return {'winnerIds': [p.uid], 'reason': '📋 ${p.name} élimine ${victim.name}, dont il avait copié le pouvoir — Victoire !'};
          }
        } catch (_) {}
      }
    }

    // Christine — Felipe éliminé
    if (justDiedId != null) {
      try {
        final victim = players.firstWhere((p) => p.uid == justDiedId);
        if (victim.character!.id == 'felipe') {
          for (final p in alive) {
            if (p.character!.winEffect == 'kill_felipe_or_shadows') {
              return {'winnerIds': [p.uid], 'reason': '⚔️ Christine élimine Felipe — Victoire !'};
            }
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
            return {'winnerIds': [killer.uid], 'reason': '🥭 ${killer.name} élimine ${victim.name} (13+ PV) — Victoire !'};
          }
        }
      } catch (_) {}
    }

    // ── Victoires principales ───────────────────────────────────────────────

    // Tous les Shadows morts → Hunters + survive gagnent
    if (shadows.isEmpty) {
      final ids = <String>{
        ...hunters.map((p) => p.uid),
        ...alive.where((p) {
          final we = p.character!.winEffect;
          return we == 'survive' || we == 'kill_christine_or_hunters';
        }).map((p) => p.uid),
      }.toList();
      // Léo gagne aussi si tous les Hunters en vie (winEffect die_first_or_kill_hunters)
      for (final p in alive) {
        if (p.character!.winEffect == 'die_first_or_kill_hunters') ids.add(p.uid);
      }
      return {'winnerIds': ids, 'reason': 'Les Hunters éliminent tous les Shadows !'};
    }

    // Tous les Hunters morts → Shadows + survive gagnent
    if (hunters.isEmpty) {
      final ids = <String>{
        ...shadows.map((p) => p.uid),
        ...alive.where((p) {
          final we = p.character!.winEffect;
          return we == 'survive' || we == 'kill_felipe_or_shadows';
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
    if (gameEnding) {
      final winners = <String>[];
      for (final p in alive) {
        final we = p.character!.winEffect;
        switch (we) {
          case 'survive': winners.add(p.uid);
          case 'unrevealed_win': if (!p.revealed) winners.add(p.uid);
          case 'left_wins':
            final idx = players.indexOf(p);
            final left = players[(idx - 1 + players.length) % players.length];
            if (left.alive && winners.contains(left.uid)) winners.add(p.uid);
          case 'right_wins':
            final idx2 = players.indexOf(p);
            final right = players[(idx2 + 1) % players.length];
            if (right.alive && winners.contains(right.uid)) winners.add(p.uid);
          case 'two_kills_or_center':
            // terrainLayout id 1 = terrain 4-5
            // handled by zoneIndex check at game end
            break;
          case 'team_alive_win':
            if (teamAllyUids != null && teamAllyUids.every((uid) =>
              players.any((pp) => pp.uid == uid && pp.alive))) {
              for (final uid in teamAllyUids) winners.add(uid);
            }
          default: break;
        }
      }
      if (winners.isNotEmpty) {
        return {'winnerIds': winners.toSet().toList(), 'reason': 'Fin de partie — conditions de victoire !'};
      }
    }

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
          (p.copiedEffect ?? p.character?.abilityEffect ?? '') == 'gege_passive') {
        gege = p; break;
      }
    }
    if (gege == null || !target.alive) return (null, false);
    final r = rollAttack();
    final dealt = applyDamage(target, r['damage']!);
    if (!target.alive) target.killedByUid = gege.uid;
    return ('\u{1f47b} Gège attaque aussi \${target.name} — D4(\${r[\'d4\']}) D6(\${r[\'d6\']}) → \$dealt blessures', true);
  }

  String? applyGegePassive(Player attacker, Player target, List<Player> all) =>
      applyGegePassiveEx(attacker, target, all).$1;

  /// Résout le choix de la cible pour les cartes "Divination X ou Y" :
  /// `giveEquipment = true` → la cible donne un équipement (choisi par
  /// `equipmentIndex` si fourni, sinon le premier) à l'auteur de la carte.
  /// `giveEquipment = false` → la cible subit 1 blessure à la place.
  String resolvePunishChoice(Player actor, Player target, bool giveEquipment, {int? equipmentIndex}) {
    if (!giveEquipment || target.equipment.isEmpty) {
      applyDamage(target, 1);
      return '🔮 ${target.name} choisit de subir 1 blessure';
    }
    final idx = (equipmentIndex != null && equipmentIndex < target.equipment.length) ? equipmentIndex : 0;
    final e = target.equipment.removeAt(idx);
    actor.equipment.add(e); _equipPassive(actor, e);
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
  /// (ex: Baleine soigne les Hunters révélés). `abilityUsed` est réutilisé sur
  /// le mort comme marqueur "passif de mort déjà déclenché" pour éviter les
  /// déclenchements multiples si la fonction est appelée plusieurs fois.
  void applyDeathPassives(List<Player> all) {
    for (final p in all) {
      if (p.alive || p.abilityUsed) continue;
      final eff = p.copiedEffect ?? p.character?.abilityEffect ?? '';
      if (eff == 'death_heal_allies') {
        for (final ally in all.where((a) =>
            a.alive && a.character?.faction == Faction.hunter && a.revealed)) {
          applyHeal(ally, 2);
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
      p.abilityUsed = true; // marque ce mort comme "passif traité"
    }
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
        final card = drawCard(DeckType.tenebres);
        if (card.type == CardType.equipement) {
          killer.equipment.add(card); _equipPassive(killer, card);
          return ('🔮 ${killer.name} reçoit "${card.name}" (équipement Ténèbres)', false);
        }
        return ('🔮 ${killer.name} : carte Ténèbres "${card.name}" — non équipement, ignorée', false);
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

  /// Richard II : échange deux zones du plateau.
  /// Retourne le log. Seul Richard II active l'effet du terrain d'arrivée
  /// (géré côté controller après appel).
  String swapTerrainZones(int zone1, int zone2, List<Player> all,
      List<Terrain> layout, Player richard) {
    // Échange les deux tuiles dans le layout
    final tmp = layout[zone1];
    layout[zone1] = layout[zone2];
    layout[zone2] = tmp;
    // Les joueurs gardent leur zoneIndex — ils suivent la tuile physiquement
    // Mais zoneIndex = position dans la grille, pas la tuile.
    // Donc on échange l'index de TOUS les joueurs sur ces zones.
    for (final p in all) {
      if (p.zoneIndex == zone1) p.zoneIndex = zone2;
      else if (p.zoneIndex == zone2) p.zoneIndex = zone1;
    }
    final t1 = layout[zone1]; // nouvelle tuile en zone1 (anciennement zone2)
    final t2 = layout[zone2]; // nouvelle tuile en zone2 (anciennement zone1)
    return '👑 Richard II échange ${t2.name} ↔ ${t1.name} !';
  }

  void recalcPassives(Player p) {
    // Reset all equipment-based passives
    p.hache = false; p.sniper = false; p.bazooka = false;
    p.lance = false; p.lanceLonginus = false; p.dague = false; p.sainteTunique = false;
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
    final cfg = getRoleConfig(n);
    final rng = Random();

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
      if (p.poisonTurnsRemaining <= 0) p.poisonSourceUid = null;
    }

    final eff = p.copiedEffect ?? p.character?.abilityEffect ?? '';
    if (!p.revealed) return logs;

    // Fijacked: soigne 1 par équipement
    if (eff == 'heal_per_equip_eot' && p.equipment.isNotEmpty) {
      applyHeal(p, p.equipment.length);
      logs.add('🏺 Fijacked soigné de \${p.equipment.length}');
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
