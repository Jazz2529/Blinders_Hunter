// lib/services/engine_abilities.dart
// Pouvoirs complets de tous les personnages

import 'dart:math';
import '../models/models.dart';
import '../data/game_data.dart';

mixin AbilityEngine {
  Random get rng;
  int rollD4();
  int rollD6();
  int applyDamage(Player p, int n, {bool isTenebresCard = false, bool ignoreShield = false});
  void applyHeal(Player p, int n);
  int terrainLayoutIdx(List<Terrain> layout, int id);

  // ─── Dispatch principal ──────────────────────────────────────────────────────
  Map<String, dynamic> applyAbilityFull(
    Player actor, List<Player> all, List<Terrain> layout, {Player? target}) {
    actor.abilityUsed = true;
    final eff = actor.copiedEffect ?? actor.character!.abilityEffect;
    return _dispatch(eff, actor, all, layout, target: target);
  }

  Map<String, dynamic> _dispatch(String eff, Player actor, List<Player> all,
    List<Terrain> layout, {Player? target}) {
    final alive = all.where((p) => p.alive).toList();

    switch (eff) {

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // HUNTERS
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      case 'ally_share_equip': // Agathe — à la révélation
        // Partage passif : géré dans resolveAttackFull
        // Signalement au controller via special
        return {'log': '😇 Agathe révèle — ses équipements sont partagés avec les Hunters révélés',
                'special': 'agathe_share'};

      case 'double_move_dice': // Albane — passif révélé, 2 lancers au choix
        // Géré dans solo_controller (hasDoubleMove = true chaque tour)
        return {'log': '⏳ Albane peut choisir parmi 2 lancers de dés ce tour',
                'special': 'double_move'};

      case 'ally_sacrifice_heal': // Amélia — unique
        final revealedHunters = alive.where((p) =>
          p.character!.faction == Faction.hunter && p.revealed).toList();
        if (revealedHunters.isEmpty)
          return {'log': 'Amélia — aucun Hunter révélé'};
        final n = revealedHunters.length;
        for (final h in revealedHunters) applyDamage(h, 1);
        for (final h in revealedHunters) applyHeal(h, n * 2 ~/ revealedHunters.length + 1);
        return {'log': '🌸 Amélia : $n Hunters subissent 1 et se soignent de ${n*2~/revealedHunters.length+1}'};

      case 'aoe_zone6': // Artcade — passif début de tour, répétable
        final idx = terrainLayoutIdx(layout, 2);
        int count = 0;
        for (final p in alive) {
          if (p.uid != actor.uid && p.zoneIndex == idx) { applyDamage(p, 2); count++; }
        }
        return {'log': '🐉 Artcade inflige 2 dégâts à $count joueurs sur la zone 6'};

      case 'sacrifice_heal_dead': // Captain Ricard — unique, cible requise
        if (target == null) return {'needsTarget': true};
        // S'inflige des blessures pour soigner la cible
        final sacrifice = min(5, actor.character!.hp - actor.wounds - 1);
        if (sacrifice <= 0) return {'log': 'Captain Ricard — trop peu de PV'};
        applyDamage(actor, sacrifice);
        applyHeal(target, sacrifice);
        return {'log': '🍾 Captain Ricard sacrifie $sacrifice PV → soigne ${target.name} de $sacrifice'};

      case 'heal_hunter_on_attack': // Carla — passif dans resolveAttack
        return {'log': '🕊 Carla révèle — attaques sur Hunters les soignent (−1 dégât)','special':'carla_passive'};

      case 'force_reveal_damage1': // Elaia — unique, cible requise
        if (target == null) return {'needsTarget': true};
        target.revealed = true;
        applyDamage(target, 1);
        return {'log': '🔮 Elaia force ${target.name} à se révéler et lui inflige 1'};

      case 'use_discarded_lumiere': // Elise — passif début de tour
        return {'log': '⛪ Elise utilise la dernière carte Lumière', 'special': 'use_last_lumiere'};

      case 'ines_passive': // Inès — passive choisie à la révélation
      case 'alternate_buff':
        // Le choix est stocké dans player.copiedEffect par le controller
        return {'log': '🔄 Inès choisit son buff', 'special': 'ines_choose'};

      case 'shield3': // Louna — unique, insensible 1 tour complet
        actor.shield = true; actor.shieldCharges = 99; // 99 = dure jusqu'au prochain tour
        return {'log': '🐱 Louna est insensible aux blessures ce tour'};

      case 'set_wounds5': // Marion — unique, cible requise
        if (target == null) return {'needsTarget': true};
        target.wounds = 5; // force exactement à 5 (soigne si >5, blesse si <5)
        return {'log': '🧝 Marion place ${target.name} exactement à 5 blessures'};

      case 'd4_heal_neighbors': // Océane — unique
        final d = rollD4();
        // Trouver joueur avant/après dans l'ordre
        final order = alive.map((p) => p.uid).toList();
        final myIdx = order.indexOf(actor.uid);
        final before = alive[(myIdx - 1 + alive.length) % alive.length];
        final after  = alive[(myIdx + 1) % alive.length];
        applyHeal(actor, d); applyHeal(before, d); applyHeal(after, d);
        final names = {actor.name, before.name, after.name}.join(', ');
        return {'log': '🌊 Océane soigne $names de $d (D4)'};

      case 'allied_invulnerable': // Rémi — passif, géré dans applyDamage
        return {'log': '🛡️ Rémi révèle — Hunters sur même terrain invulnérables', 'special': 'remi_passive'};

      case 'swap_terrains': // Richard II — début de tour, choix terrain
        if (target == null) return {'needsTarget': true, 'special': 'richard_swap'};
        // Échange les effets : les joueurs restent, les terrains changent
        final myZ = actor.zoneIndex;
        final theirZ = target.zoneIndex;
        // On échange les terrains dans le layout
        final tmp = layout[myZ];
        layout[myZ] = layout[theirZ];
        layout[theirZ] = tmp;
        return {'log': '🔀 Richard II échange les terrains $myZ et $theirZ', 'special': 'trigger_terrain'};

      case 'auto_counterattack': // Scott — passif dans resolveAttack
        return {'log': '🐺 Scott révèle — contre-attaque automatique', 'special': 'scott_passive'};

      case 'team_attack': // Gège — passif, ne peut pas attaquer seul
        return {'log': '👻 Gège révèle — additionne ses dés aux attaques alliées', 'special': 'gege_passive'};

      case 'choose_passive': // Luc — à la révélation, choix parmi 3
        return {'log': '🎭 Luc choisit sa forme passive', 'special': 'luc_choose'};

      case 'heal_on_same_terrain': // Augustin — passif sur résultat 7
        // Géré dans humanMove quand sum == 7
        return {'log': '🌾 Augustin — se soigne de 2 sur un 7'};

      case 'copy_hunter_ability': // Baptiste — à la révélation
        final unused = kAllCharacters.where((c) =>
          c.faction == Faction.hunter &&
          !all.any((p) => p.character?.id == c.id)).toList();
        if (unused.isEmpty) return {'log': 'Baptiste — aucun Hunter non joué'};
        final copied = unused[rng.nextInt(unused.length)];
        actor.copiedEffect = copied.abilityEffect;
        actor.abilityUsed = false; // reset pour pouvoir l'utiliser
        return {'log': '📖 Baptiste reçoit le pouvoir de ${copied.name} : ${copied.ability}'};

      case 'pay2_give_passive': // Peintre — début de tour, s'inflige 2 pour choisir passif
        applyDamage(actor, 2);
        return {'log': '🖌️ Peintre subit 2 pour choisir une capacité passive', 'special': 'luc_choose'};

      case 'heal_per_equip_eot': // Fijacked — passif début de tour révélé
        final n = actor.equipment.length;
        if (n > 0) applyHeal(actor, n);
        return {'log': '🏺 Fijacked soigné de $n (${n} équipements)'};

      case 'link_two_players': // Cupidon — unique, lie 2 joueurs 1 tour
        if (target == null) return {'needsTarget': true};
        return {'log': '💘 Cupidon lie ${actor.name} et ${target.name} pour 1 tour',
                'special': 'cupidon_link:${target.uid}'};

      case 'damage2_then_heal3': // Raph du Soleil Levant — répétable
        if (target == null) return {'needsTarget': true};
        applyDamage(actor, 2); applyHeal(target, 3);
        return {'log': '🥷 Raph subit 2 → soigne ${target.name} de 3'};

      case 'last_hunter_buff': // Felipe Pompims — passif révélé
        actor.bonusMaxHp += 3; applyHeal(actor, 3);
        return {'log': '💪 Felipe Pompims dernier Hunter — +3 PV, +2 dégâts', 'special': 'felipe_buff'};

      case 'lumiere_copy': // Mère Christine — passif dans resolveCard
        return {'log': '✨ Mère Christine révèle — copie effets Lumière sur allié', 'special': 'christine_passive'};

      case 'death_heal_allies': // Baleine — passif à la mort
        return {'log': '🐋 Baleine révèle — soignera les Hunters de 3 à sa mort', 'special': 'baleine_passive'};

      case 'no_attack_buff': // Fifi Été — passif (géré dans resolveAttack)
        return {'log': '🌻 Fifi Été révèle — +2 si pas attaqué le tour d\'avant', 'special': 'fifi_ete_passive'};

      case 'force_d4_move': // Fifi Hiver — unique, gèle un joueur
        if (target == null) return {'needsTarget': true};
        target.frozen = true;
        return {'log': '❄️ Fifi Hiver gèle ${target.name} — ne peut pas se déplacer 1 tour'};

      case 'heal2_same_hunter': // Hailey — passif début de tour
        final sameTerrain = alive.any((p) =>
          p.uid != actor.uid && p.character!.faction == Faction.hunter &&
          p.revealed && p.zoneIndex == actor.zoneIndex);
        if (sameTerrain) { applyHeal(actor, 2); return {'log': '🏡 Hailey soigné de 2 (Hunter voisin)'}; }
        return {'log': 'Hailey — pas de Hunter révélé sur la même zone'};

      case 'same_zone_damage2': // Burger — répétable début de tour
        if (target == null) return {'needsTarget': true};
        final hasHunterHere = alive.any((p) =>
          p.uid != actor.uid && p.character!.faction == Faction.hunter &&
          p.revealed && p.zoneIndex == actor.zoneIndex);
        if (!hasHunterHere) return {'log': 'Burger — pas de Hunter révélé sur ce terrain'};
        applyDamage(target, 2);
        return {'log': '🍔 Burger inflige 2 à ${target.name}'};

      case 'swap_position': // Voiture de Clem — répétable, au lieu du déplacement
        if (target == null) return {'needsTarget': true};
        final tmp = actor.zoneIndex;
        actor.zoneIndex = target.zoneIndex;
        target.zoneIndex = tmp;
        return {'log': '🚗 Voiture échange de place avec ${target.name}', 'special': 'skip_move'};

      case 'discard_all_equip': // Soubrette Marin — unique
        for (final p in alive) { p.equipment.clear(); }
        return {'log': '🧹 Soubrette Marin — tous les équipements défaussés'};

      case 'intercept_attack': // Vlad Princesse — début de tour, protège 1 joueur
        if (target == null) return {'needsTarget': true};
        return {'log': '👸 Vlad Princesse protège ${target.name} (−1 dégât/attaque)',
                'special': 'vlad_shield:${target.uid}'};

      case 'double_vision_damage': // Jason Espion — répétable, donne 1 carte Vision
        return {'log': '🕵️ Jason Espion obtient 1 carte Vision (dégâts doublés)', 'special': 'jason_vision'};

      case 'fetch_lumiere': // Prêtresse Raph — unique, choisit dans toutes les cartes Lumière
        return {'log': '🙏 Prêtresse Raph choisit une carte Lumière', 'special': 'fetch_lumiere'};

      case 'move_player_or_cancel_equip': // Commandante Marion — répétable, choix
        if (target == null) return {'needsTarget': true, 'special': 'commandante_choose'};
        return {'log': '🎯 Commandante Marion déplace ${target.name}', 'special': 'commandante_move:${target.uid}'};

      case 'draw_on_hit_dual_target': // Mango Loco — passif
        return {'log': '🥭 Mango Loco révèle — pioche sur hit, peut cibler 2', 'special': 'mango_passive'};

      case 'stay_retrigger_terrain': // Demi-Sel — répétable, au lieu du déplacement
        return {'log': '🧂 Demi-Sel reste sur place → réactive le terrain', 'special': 'demi_sel_stay'};

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // SHADOWS
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      case 'draw_dark': // Monkey Raph — répétable début de tour
        return {'log': '🐒 Monkey Raph pioche une carte Ténèbres', 'special': 'draw_dark'};

      case 'damage2_or_heal1': // Julien — répétable début de tour
        if (target != null) { applyDamage(target, 2); return {'log': '🍳 Julien inflige 2 à ${target.name}'}; }
        applyHeal(actor, 1);
        return {'log': '🍳 Julien se soigne de 1', 'needsOptionalTarget': true};

      case 'steal_equip_choice': // Nils — répétable début de tour
        if (target == null) return {'needsTarget': true};
        if (target.equipment.isEmpty) return {'log': '${target.name} n\'a pas d\'équipement'};
        final stolen = target.equipment.removeAt(rng.nextInt(target.equipment.length));
        actor.equipment.add(stolen);
        return {'log': '⚡ Nils vole "${stolen.name}" à ${target.name}'};

      case 'd4_bonus_attack': // Vladimir — répétable début de tour
        if (target == null) return {'needsTarget': true};
        final dv = rollD4(); applyDamage(target, dv);
        return {'log': '💨 Vladimir attaque ${target.name} avec D4(\$dv)'};

      case 'trade_item_damage3': // Marin — répétable
        if (target == null) return {'needsTarget': true};
        if (actor.equipment.isEmpty) return {'log': 'Marin n\'a pas d\'équipement à donner'};
        final item = actor.equipment.removeAt(0); target.equipment.add(item);
        applyDamage(target, 3);
        return {'log': '💰 Marin donne "${item.name}" à ${target.name} et inflige 3'};

      case 'terrain_max_aoe': // Hong Yi — unique, se sacrifie
        // Inflige 8 à tous les joueurs à portée puis meurt
        final adj = kAdjacences[actor.zoneIndex];
        final targets = alive.where((p) =>
          p.uid != actor.uid && (p.zoneIndex == actor.zoneIndex || adj.contains(p.zoneIndex))).toList();
        for (final p in targets) applyDamage(p, 8);
        // Hong Yi meurt
        actor.wounds = (actor.character!.hp + actor.bonusMaxHp).toInt();
        return {'log': '⚡ Hong Yi se sacrifie — inflige 8 à ${targets.length} joueurs à portée'};

      case 'self1_trigger_terrain': // Peio — répétable
        applyDamage(actor, 1);
        return {'log': '🧌 Peio subit 1 → réactive l\'effet du terrain', 'special': 'trigger_terrain'};

      case 'zero_wound_power': // Louise — passif dans resolveAttack
        return {'log': '💢 Louise — passif : 0 dégâts → inflige 4, sinon +1', 'special': 'louise_passive'};

      case 'reduce_all_by1': // Vache — passif dans resolveAttack
        return {'log': '🐄 Vache — passif : attaques −1, dégâts reçus −1', 'special': 'vache_passive'};

      case 'infinite_range': // Pirate — passif répétable
        actor.infiniteRange = true;
        return {'log': '🏴‍☠️ Pirate peut attaquer tous les joueurs sans restriction'};

      case 'd6_global_attack': // Travert — unique
        if (target == null) return {'needsTarget': true};
        final dt = rollD6(); applyDamage(target, dt);
        return {'log': '🎲 Travert lance D6(\$dt) sur ${target.name}'};

      case 'gather_attack_redistribute': // Glads — unique
        if (target == null) return {'needsTarget': true};
        // Ramasse tous les équipements, attaque, redistribue
        final allEquip = <GameCard>[];
        for (final p in alive) { allEquip.addAll(p.equipment); p.equipment.clear(); }
        final totalDmg = allEquip.length * 2;
        applyDamage(target, totalDmg);
        // Redistribue aléatoirement
        allEquip.shuffle(rng);
        for (int i = 0; i < allEquip.length; i++) alive[i % alive.length].equipment.add(allEquip[i]);
        return {'log': '💥 Glads ramasse ${allEquip.length} équipements → inflige \$totalDmg à ${target.name} → redistribue'};

      case 'extra_turn_per_death': // Ninja — unique
        final deaths = all.where((p) => !p.alive).length;
        return {'log': '🥷 Ninja rejoue \$deaths tours (\$deaths morts)', 'special': 'ninja_extra:\$deaths'};

      case 'zero_wound_steal': // Orion — passif dans resolveAttack
        return {'log': '🐱 Orion — passif : vole un équipement si attaque = 0', 'special': 'orion_passive'};

      case 'mirror_damage': // Raphaël Shadow — unique, attaques multiples
        return {'log': '⚔️ Raphaël peut attaquer autant de fois que voulu (subit autant)', 'special': 'raph_multi_atk'};

      case 'choose_all_dice': // Fifi Shadow — unique, tour parfait
        return {'log': '🍀 Fifi — ce tour tous les dés sont au maximum (7 dépl, 5 atk)', 'special': 'fifi_golden'};

      case 'trade_banana_for_equip': // Jazzon — répétable
        if (target == null) return {'needsTarget': true};
        if (target.equipment.isEmpty) return {'log': '${target.name} n\'a pas d\'équipement'};
        final ej = target.equipment.removeAt(0); actor.equipment.add(ej);
        return {'log': '🎵 Jazzon vole "${ej.name}" à ${target.name}'};

      case 'third_attack_bonus': // Mathieu — passif dans resolveAttack
        return {'log': '📊 Mathieu — passif : 3ème attaque +3 dégâts', 'special': 'mathieu_passive'};

      case 'counter_roll_cancel': // Maxime — passif dans resolveAttack
        return {'log': '🤼 Maxime — passif : lancé de dés pour annuler les blessures', 'special': 'maxime_passive'};

      case 'reveal_all_characters': // Maxence — unique
        for (final p in alive) p.revealed = true;
        return {'log': '🔍 Maxence — tous les joueurs révèlent leur rôle !'};

      case 'two_items_damage2': // 3ème Pinte — répétable
        if (actor.equipment.length < 2) return {'log': '🍺 3ème Pinte n\'a pas 2 objets'};
        if (target == null) return {'needsTarget': true};
        applyDamage(target, 2);
        return {'log': '🍺 3ème Pinte inflige 2 à ${target.name} (2 objets)'};

      case 'move_between_players': // Nina — unique, tour bonus après ce tour
        return {'log': '😤 Nina joue un tour bonus après ce tour', 'special': 'nina_bonus_turn'};

      case 'trap_terrain_no_ability': // Peio de Mongolie — répétable
        return {'log': '🏕️ Peio Mongolie piège ce terrain (capacité bloquée)', 'special': 'trap:ability_block'};

      case 'undo_last_turn': // Zazou — unique
        return {'log': '⏮️ Zazou annule le dernier tour', 'special': 'zazou_undo'};

      case 'resurrect_once': // Jesus — passif à la mort
        if (actor.revived) return {'log': 'Jésus a déjà ressuscité'};
        actor.wounds = 0; actor.revived = true; actor.alive = true;
        return {'log': '✝️ Jésus ressuscite !'};

      case 'trap_terrain_2dmg': // Damien Homard — répétable
        return {'log': '🦞 Damien piège ce terrain (2 dégâts prochain joueur)', 'special': 'trap:2'};

      case 'cancel_swap_attack': // Fifi d'Automne — unique, annule attaque reçue
        return {'log': '🍂 Fifi d\'Automne peut annuler la prochaine attaque reçue', 'special': 'fifi_automne_shield'};

      case 'trap_terrain_freeze': // Emilien Ninja — répétable
        return {'log': '🥷 Emilien Ninja piège ce terrain (gel prochain joueur)', 'special': 'trap:freeze'};

      case 'create_minion': // Vlad du Soleil Levant — unique
        applyDamage(actor, 4);
        return {'log': '🌅 Vlad du Soleil Levant subit 4 → crée un mini de 3 PV'};

      case 'poison_player': // Ingénieur — unique
        if (target == null) return {'needsTarget': true};
        target.poisoned = true;
        return {'log': '🔧 Ingénieur empoisonne ${target.name} (−1 PV/tour)'};

      case 'tenebres_heal_instead': // Bibble — passif dans resolveCard
        return {'log': '🧚 Bibble — passif : les Ténèbres le soignent', 'special': 'bibble_passive'};

      case 'death_bomb_4dmg': // Enceinte de Liste — passif à la mort
        if (target == null) return {'needsTarget': true};
        return {'log': '🔊 Enceinte infligera 4 à ${target.name} à sa mort', 'special': 'death_bomb:${target.uid}:4'};

      case 'block_healing': // Rémi du Canada — passif dans resolveAttack
        return {'log': '🍁 Rémi Canada — passif : cible ne peut plus se soigner 1 tour', 'special': 'remi_canada_passive'};

      case 'force_ability_use': // Roi Clémence — unique
        if (target == null) return {'needsTarget': true};
        return {'log': '👑 Roi Clémence force ${target.name} à utiliser sa capacité', 'special': 'force_ability:${target.uid}'};

      case 'block_terrain_entry': // Garde Carla — passif
        return {'log': '🚫 Garde Carla — passif : personne ne peut entrer sur ce terrain', 'special': 'garde_carla_passive'};

      case 'recover_all_discarded': // Baron Marion — unique
        return {'log': '♟ Baron Marion récupère tous les équipements défaussés', 'special': 'recover_discarded'};

      case 'vision_then_4dmg': // Jeanne Baba — passif à la réception d'une carte Vision
        if (target == null) return {'needsTarget': true};
        applyDamage(target, 4);
        return {'log': '👁️ Jeanne Baba inflige 4 à ${target.name} (vision reçue)'};

      case 'revealed_plus1_dmg': // Théo Homard — passif permanent
        actor.revealed = true;
        return {'log': '🦐 Théo Homard commence révélé (+1 dégât, pas de carte Vision)', 'special': 'theo_passive'};

      case 'control_player': // Zombie Raph — unique
        if (target == null) return {'needsTarget': true};
        return {'log': '🧟 Zombie Raph contrôle ${target.name} pendant 1 tour', 'special': 'control:${target.uid}'};

      case 'casino_bet': // Mr Casino — répétable
        if (target == null) return {'needsTarget': true};
        final dc = rollD6();
        final betOdd = rng.nextBool(); // pari pair ou impair
        final isOdd = dc % 2 == 1;
        final win = betOdd == isOdd;
        if (win) { applyDamage(target, dc * 2); return {'log': '🎰 Mr Casino gagne ! D6(\$dc) → ${target.name} subit ${dc*2}'}; }
        applyDamage(actor, 1);
        return {'log': '🎰 Mr Casino perd ! D6(\$dc) → subit 1 blessure'};

      case 'mimic_equip_steal': // Mimic — passif dans resolveCard
        return {'log': '🃏 Mimic — passif : se révèle pour voler les équipements pioché', 'special': 'mimic_passive'};

      case 'attack_discard_equip': // Slime — passif dans resolveAttack
        return {'log': '🟢 Slime — passif : défausse 1 équipement à chaque hit', 'special': 'slime_passive'};

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // NEUTRES
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      case 'suppress_ability': // Felipe — unique, + tueur doit se révéler (géré dans checkWin)
        if (target == null) return {'needsTarget': true};
        target.abilityBlocked = true;
        return {'log': '💃 Felipe supprime la capacité de ${target.name}'};

      case 'freeze_all_movement': // 80 Ans + Léa Ogway — unique
        for (final p in alive) { if (p.uid != actor.uid) p.frozen = true; }
        return {'log': '💺 ${actor.name} — personne ne peut se déplacer ce tour'};

      case 'reflect_attack_zone': // Chaussette — unique, renvoie l'attaque reçue
        return {'log': '🐈 Chaussette peut renvoyer la prochaine attaque', 'special': 'chaussette_reflect'};

      case 'steal_win_condition': // Fanny — passif déclenché dans checkWin
        return {'log': '🎭 Fanny — vole la carte de la victime automatiquement'};

      case 'force_attack': // Woods — unique, force un joueur à en attaquer un autre
        if (target == null) return {'needsTarget': true};
        return {'log': '🌲 ${actor.name} force ${target.name} à attaquer', 'special': 'force_attack:${target.uid}'};

      case 'use_other_equip': // Joey — répétable
        if (target == null) return {'needsTarget': true};
        if (target.equipment.isEmpty) return {'log': '${target.name} n\'a pas d\'équipement'};
        final eq = target.equipment[rng.nextInt(target.equipment.length)];
        return {'log': '👜 Joey utilise "${eq.name}" de ${target.name}', 'special': 'use_equip:${eq.effect}'};

      case 'heal1_on_own_attack': // Rat d'Rouen — passif dans resolveAttack
        return {'log': '🐀 Rat d\'Rouen — soigné de 1 sur chaque hit', 'special': 'rat_passive'};

      case 'reshuffle_characters': // Connard — unique, à la 1ère révélation
        return {'log': '🤡 Connard — personnages redistribués !', 'special': 'reshuffle_all'};

      case 'pull_and_d4_aoe': // Nuts — unique
        if (target == null) return {'needsTarget': true};
        final adj = kAdjacences[actor.zoneIndex];
        for (final p in alive) {
          if (p.uid != actor.uid && (p.zoneIndex == actor.zoneIndex || adj.contains(p.zoneIndex)))
            p.zoneIndex = target.zoneIndex;
        }
        final dn = rollD4();
        for (final p in alive.where((p) => p.uid != actor.uid && p.zoneIndex == target.zoneIndex))
          applyDamage(p, dn);
        return {'log': '🐕 Nuts rassemble les joueurs et attaque D4($dn)'};

      case 'recruit_unrevealed': // Dresseur Oscar — unique
        if (target == null) return {'needsTarget': true};
        target.revealed = true;
        return {'log': '🎓 ${actor.name} recrute ${target.name} comme allié !', 'special': 'recruit_ally'};

      case 'd4_all': // Léo — répétable début de tour
        final dl = rollD4();
        for (final p in alive) { if (p.uid != actor.uid) applyDamage(p, dl); }
        return {'log': '💀 Léo lance D4($dl) — tous subissent $dl'};

      case 'use_dead_ability': // Tommy — répétable, une fois par mort
        final deadPlayers = all.where((p) => !p.alive && p.character != null).toList();
        if (deadPlayers.isEmpty) return {'log': 'Tommy — personne n\'est mort'};
        final chosen = deadPlayers[rng.nextInt(deadPlayers.length)];
        actor.copiedEffect = chosen.character!.abilityEffect;
        actor.abilityUsed = false;
        return {'log': '🎪 Tommy copie le pouvoir de ${chosen.name} (mort)'};

      case 'full_heal_shield_turn': // Cambou — répétable, passe le tour
        actor.wounds = 0; actor.shield = true; actor.shieldCharges = 99;
        return {'log': '🌙 Cambou passe son tour — soigné et protégé', 'special': 'skip_turn'};

      case 'copy_and_must_kill': // Oscar — répétable
        if (target == null) return {'needsTarget': true};
        actor.copiedEffect = target.character!.abilityEffect;
        actor.abilityUsed = false;
        return {'log': '📋 Oscar copie ${target.name} (${target.character!.ability})'};

      case 'lie_vision_plus1': // Jason — passif permanent
        return {'log': '🕶️ Jason peut mentir aux cartes Vision (+1 dégât)', 'special': 'jason_passive'};

      case 'd6_lifesteal': // Carapatte — unique
        if (target == null) return {'needsTarget': true};
        final dc2 = rollD6(); final dealt = applyDamage(target, dc2);
        applyHeal(actor, dealt);
        return {'log': '🐢 Carapatte inflige $dealt à ${target.name} et se soigne de $dealt'};

      case 'freeze_and_force_attack': // Léa Ogway — unique
        for (final p in alive) { if (p.uid != actor.uid) p.frozen = true; }
        return {'log': '🐢 Léa Ogway gèle tous et force les attaques', 'special': 'lea_force_attack'};

      case 'full_heal': // Meiko — unique (pas répétable)
        actor.wounds = 0;
        return {'log': '🏊 Meiko se soigne de toutes ses blessures'};

      case 'return_start_terrain': // Chaise de l'Enfer — répétable fin de tour
        actor.zoneIndex = actor.startZone;
        return {'log': "🪑 Chaise de l'Enfer retourne sur son terrain de départ", 'special': 'trigger_terrain'};

      case 'teleport_center_draw_all': // Couronne — répétable au lieu du déplacement
        final zone45 = terrainLayoutIdx(layout, 1); // terrain 4-5
        actor.zoneIndex = zone45;
        return {'log': '👑 Couronne va sur le terrain 4-5 et pioche une carte de chaque pile', 'special': 'draw_all_decks'};

      case 'd4_attack_only': // Christine — passif répétable
        return {'log': '⚔️ Christine utilise le D4 pour attaquer', 'special': 'christine_d4'};

      case 'recover_one_equip': // Roi Burger — répétable
        return {'log': '👑 Roi Burger récupère un équipement dans la défausse', 'special': 'recover_one_equip'};



      default:
        return {'log': '⚡ ${actor.name} utilise sa capacité ($eff)'};
    }
  }

  // ─── Passifs début de tour ───────────────────────────────────────────────────
  List<String> applyStartOfTurnPassives(Player p, List<Player> all,
      List<Terrain> layout, {GameCard? lastLumiereCard}) {
    final logs = <String>[];
    final alive = all.where((a) => a.alive).toList();
    final eff = p.copiedEffect ?? p.character?.abilityEffect ?? '';

    // Dégel automatique
    p.frozen = false; p.cannotHeal = false; p.invulnerable = false;

    // Poison (Ingénieur)
    if (p.poisoned && p.alive) { applyDamage(p, 1); logs.add('☠️ ${p.name} subit 1 (poison)'); }

    // Artcade — AoE zone 6 chaque tour
    if (eff == 'aoe_zone6' && p.revealed) {
      final idx = terrainLayoutIdx(layout, 2);
      int count = 0;
      for (final o in alive) { if (o.uid != p.uid && o.zoneIndex == idx) { applyDamage(o, 2); count++; } }
      if (count > 0) logs.add('🐉 Artcade — 2 dégâts sur $count joueurs zone 6');
    }

    // Fijacked — soigne par équipement
    if (eff == 'heal_per_equip_eot' && p.revealed) {
      final n = p.equipment.length;
      if (n > 0) { applyHeal(p, n); logs.add('🏺 Fijacked soigné de $n'); }
    }

    // Hailey — même zone Hunter révélé
    if (eff == 'heal2_same_hunter' && p.revealed) {
      final hasAlly = alive.any((o) => o.uid != p.uid &&
        o.character!.faction == Faction.hunter && o.revealed && o.zoneIndex == p.zoneIndex);
      if (hasAlly) { applyHeal(p, 2); logs.add('🏡 Hailey soigné de 2'); }
    }

    // Felipe Pompims — dernier Hunter buff
    if (eff == 'last_hunter_buff' && p.revealed) {
      final huntersAlive = alive.where((o) => o.character!.faction == Faction.hunter).length;
      if (huntersAlive == 1) { applyHeal(p, 3); logs.add('💪 Felipe Pompims — dernier Hunter, soigné de 3'); }
    }

    // Meiko — full heal début de tour
    if (eff == 'full_heal' && p.revealed) { p.wounds = 0; logs.add('🏊 ${p.name} soigné complètement'); }

    // Théo Homard — doit rester révélé
    if (eff == 'revealed_plus1_dmg') p.revealed = true;

    // Elise — utilise la dernière carte Lumière
    if (eff == 'use_discarded_lumiere' && p.revealed && lastLumiereCard != null) {
      logs.add('⛪ Elise utilise à nouveau "${lastLumiereCard.name}"');
    }

    // Rémi — invulnérabilité alliés sur même zone
    if (eff == 'allied_invulnerable' && p.revealed) {
      for (final o in alive) {
        if (o.uid != p.uid && o.character!.faction == Faction.hunter &&
            o.revealed && o.zoneIndex == p.zoneIndex) {
          o.invulnerable = true;
        }
      }
    }

    return logs;
  }

  // ─── Passifs dans resolveAttack ──────────────────────────────────────────────
  /// Appliquer avant/après chaque attaque
  void applyAttackPassives(Player attacker, Player target, int dmg, List<Player> all) {
    // Scott — contre-attaque
    final targetEff = target.copiedEffect ?? target.character?.abilityEffect ?? '';
    if (targetEff == 'auto_counterattack' && target.revealed && dmg > 0) {
      final d4 = rollD4(); final d6 = rollD6();
      final cDmg = (d4 - d6).abs();
      if (cDmg > 0) applyDamage(attacker, cDmg);
    }

    // Baleine — soigne les Hunters révélés à sa mort
    if (!target.alive) {
      final tEff = target.copiedEffect ?? target.character?.abilityEffect ?? '';
      if (tEff == 'death_heal_allies' && target.character!.faction == Faction.hunter) {
        for (final p in all.where((p) => p.alive &&
          p.character!.faction == Faction.hunter && p.revealed)) {
          applyHeal(p, 3);
        }
      }
    }

    // Slime — défausse équipement à chaque hit
    final atkEff = attacker.copiedEffect ?? attacker.character?.abilityEffect ?? '';
    if (atkEff == 'attack_discard_equip' && dmg > 0 && target.equipment.isNotEmpty) {
      target.equipment.removeAt(0);
    }

    // Rat d'Rouen — se soigne de 1 sur toute attaque
    for (final p in all.where((p) => p.alive)) {
      final pEff = p.copiedEffect ?? p.character?.abilityEffect ?? '';
      if (pEff == 'heal1_on_any_attack') applyHeal(p, 1);
    }
  }
}
