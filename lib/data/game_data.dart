// lib/data/game_data.dart
// VERSION 24 PERSONNAGES — sélection de test

import '../models/models.dart';

// ─── 24 personnages sélectionnés ─────────────────────────────────────────────
const List<CharacterCard> kAllCharacters = [

  // ══════════ HUNTERS (20) ══════════

  CharacterCard(id:'albane', name:'Albane', faction:Faction.hunter, hp:14, icon:'🏃',
    ability:'Passif révélé: lance 2 fois les dés de déplacement et choisit le résultat',
    abilityEffect:'double_move_dice', abilityRepeatable:true,
    winCondition:'Tous les Shadows sont morts', winEffect:'hunters_win'),

  CharacterCard(id:'amelia', name:'Amélia', faction:Faction.hunter, hp:11, icon:'🌸',
    ability:'Unique: inflige 2 blessures à tous les Shadows révélés ET soigne de 2 tous les Hunters révélés.',
    abilityEffect:'ally_sacrifice_heal',
    winCondition:'Tous les Shadows sont morts', winEffect:'hunters_win'),

  CharacterCard(id:'artcade', name:"Art'Cade", faction:Faction.hunter, hp:12, icon:'🐉',
    ability:'Répétable: inflige 2 blessures à tous les joueurs sur la zone 6 (Chapelle Sacrée)',
    abilityEffect:'aoe_zone6', abilityRepeatable:true,
    winCondition:'Tous les Shadows sont morts', winEffect:'hunters_win'),

  CharacterCard(id:'augustin', name:'Augustin', faction:Faction.hunter, hp:13, icon:'🌾',
    ability:'Passif: si vous faites un 7 aux dés de déplacement, soignez 2 blessures',
    abilityEffect:'heal_on_same_terrain', abilityRepeatable:true,
    winCondition:'Tous les Shadows sont morts', winEffect:'hunters_win'),

  CharacterCard(id:'baleine', name:'Baleine', faction:Faction.hunter, hp:12, icon:'🐋',
    ability:'Passif: quand Baleine meurt, tous les Hunters révélés sont soignés de 2 blessures',
    abilityEffect:'death_heal_allies', abilityRepeatable:true,
    winCondition:'Tous les Shadows sont morts', winEffect:'hunters_win'),

  CharacterCard(id:'carla', name:'Carla', faction:Faction.hunter, hp:11, icon:'🎗️',
    ability:'Passif révélé: si vous attaquez un Hunter révélé, il est soigné du même montant au lieu d\'être blessé',
    abilityEffect:'heal_hunter_on_attack', abilityRepeatable:true,
    winCondition:'Tous les Shadows sont morts', winEffect:'hunters_win'),

  CharacterCard(id:'christine', name:'Christine', faction:Faction.hunter, hp:13, icon:'🗺️',
    ability:'Répétable: au lieu de vous déplacer normalement, choisissez directement un des 2 terrains adjacents et déplacez-vous-y',
    abilityEffect:'move_adjacent_choice', abilityRepeatable:true,
    winCondition:'Tous les Shadows sont morts', winEffect:'hunters_win'),

  CharacterCard(id:'clemence', name:'Clémence', faction:Faction.hunter, hp:12, icon:'🎨',
    ability:'Unique: à la révélation, choisissez 2 effets parmi 3 propositions pondérées — les 2 effets se combinent et s\'appliquent sur une cible de votre choix (ou automatiquement pour les effets de zone)',
    abilityEffect:'builder_power', abilityRepeatable:false,
    winCondition:'Tous les Shadows sont morts', winEffect:'hunters_win'),

  CharacterCard(id:'elaia', name:'Elaia', faction:Faction.hunter, hp:13, icon:'🔮',
    ability:'Répétable, au début du tour: regardez les 2 premières cartes d\'une pile de votre choix (Ténèbres/Lumière/Vision) et choisissez leur ordre de pioche',
    abilityEffect:'peek_reorder_deck', abilityRepeatable:true,
    winCondition:'Tous les Shadows sont morts', winEffect:'hunters_win'),

  CharacterCard(id:'elise', name:'Élise', faction:Faction.hunter, hp:12, icon:'⛪',
    ability:'Répétable: piochez une carte Lumière',
    abilityEffect:'draw_light', abilityRepeatable:true,
    winCondition:'Tous les Shadows sont morts', winEffect:'hunters_win'),

  CharacterCard(id:'felipe', name:'Felipe', faction:Faction.hunter, hp:11, icon:'🩸',
    ability:'Passif révélé: si vous subissez des dégâts létaux, vous survivez 1 tour de plus (insensible à toutes les blessures pendant ce sursis) — si vous éliminez un joueur durant ce tour, vous vous soignez de 2 blessures au lieu de mourir',
    abilityEffect:'felipe_passive', abilityRepeatable:true,
    winCondition:'Tous les Shadows sont morts', winEffect:'hunters_win'), 

  CharacterCard(id:'fijacked', name:'Fijacked', faction:Faction.hunter, hp:11, icon:'🏺',
    ability:'Passif révélé: au début de votre tour, soignez 1 blessure par équipement possédé',
    abilityEffect:'heal_per_equip_eot', abilityRepeatable:true,
    winCondition:'Tous les Shadows sont morts', winEffect:'hunters_win'),

  CharacterCard(id:'gege', name:'Gège le Fantôme', faction:Faction.hunter, hp:14, icon:'👻',
    ability:'Passif: ne peut pas attaquer, mais attaque automatiquement chaque fois qu\'un Hunter révélé attaque',
    abilityEffect:'gege_passive', abilityRepeatable:true,
    winCondition:'Tous les Shadows sont morts', winEffect:'hunters_win'),

  CharacterCard(id:'louna', name:'Louna', faction:Faction.hunter, hp:14, icon:'🐱',
    ability:'Unique: devenez insensible aux blessures pendant 1 tour entier',
    abilityEffect:'shield3',
    winCondition:'Tous les Shadows sont morts', winEffect:'hunters_win'),  

  CharacterCard(id:'marion', name:'Marion', faction:Faction.hunter, hp:13, icon:'🧝',
    ability:'Unique: placez un joueur exactement à 5 blessures (soigne ou blesse)',
    abilityEffect:'set_wounds5',
    winCondition:'Tous les Shadows sont morts', winEffect:'hunters_win'),

  CharacterCard(id:'oceane', name:'Océane', faction:Faction.hunter, hp:12, icon:'🌊',
    ability:'Unique: choisissez un joueur à exclure, lancez le D4, tous les autres joueurs se soignent du résultat',
    abilityEffect:'d4_heal_neighbors',
    winCondition:'Tous les Shadows sont morts', winEffect:'hunters_win'),

  CharacterCard(id:'raph_soleil', name:'Raph du Soleil Levant', faction:Faction.hunter, hp:12, icon:'🥷',
    ability:'Répétable: subissez 2 blessures pour soigner un joueur de votre choix de 3 blessures',
    abilityEffect:'damage2_then_heal3', abilityRepeatable:true,
    winCondition:'Tous les Shadows sont morts', winEffect:'hunters_win'),

  CharacterCard(id:'remi', name:'Rémi', faction:Faction.hunter, hp:12, icon:'🛠️',
    ability:'Unique: 3 effets sont tirés au hasard parmi 10 (7 communs, 3 légendaires) — choisissez-en 2 pour créer votre équipement personnalisé',
    abilityEffect:'craft_equipment_remi',
    winCondition:'Tous les Shadows sont morts', winEffect:'hunters_win'),

  CharacterCard(id:'richard2', name:'Richard II', faction:Faction.hunter, hp:13, icon:'👑',
    ability:'Répétable: choisissez 2 zones du plateau — elles échangent de place avec tous les joueurs dessus. Vous activez l\'effet du terrain sur lequel vous atterrissez. Vous ne pouvez pas vous déplacer ce tour.',
    abilityEffect:'swap_zones', abilityRepeatable:true,
    winCondition:'Tous les Shadows sont morts', winEffect:'hunters_win'),

  CharacterCard(id:'scott', name:'Scott', faction:Faction.hunter, hp:13, icon:'🛡️',
    ability:'Passif: si un joueur l\'attaque, il contre-attaque automatiquement (lance ses propres dés)',
    abilityEffect:'counter_attack_passive', abilityRepeatable:true,
    winCondition:'Tous les Shadows sont morts', winEffect:'hunters_win'),

    // ══════════ SHADOWS (20) ══════════

  CharacterCard(id:'agathe', name:'Agathe', faction:Faction.shadow, hp:9, icon:'🧛‍♀️',
    ability:'Répétable (max 5x): volez 1 PV MAX à un joueur au choix (vous +1 PV max, lui -1 PV max, définitivement)',
    abilityEffect:'steal_max_hp', abilityRepeatable:true,
    winCondition:'Tous les Hunters sont morts', winEffect:'shadows_win'),

  CharacterCard(id:'bibble', name:'Bibble', faction:Faction.shadow, hp:13, icon:'🧚',
    ability:'Passif révélé: les cartes Ténèbres vous soignent au lieu de vous blesser',
    abilityEffect:'tenebres_heal_instead', abilityRepeatable:true,
    winCondition:'Tous les Hunters sont morts', winEffect:'shadows_win'),

  CharacterCard(id:'damien', name:'Damien', faction:Faction.shadow, hp:12, icon:'🍸',
    ability:'Unique, au début du tour: choisissez un joueur et servez-lui soit un alcool fort (4 blessures instantanées) soit un poison (3 blessures au début de chacun de ses 2 prochains tours, 6 au total)',
    abilityEffect:'damien_serve', abilityRepeatable:false,
    winCondition:'Tous les Hunters sont morts', winEffect:'shadows_win'),

  CharacterCard(id:'emilien', name:'Emilien', faction:Faction.shadow, hp:12, icon:'🎲',
    ability:'Passif: lors d\'une attaque, vous pouvez relancer le D6 une seule fois par tour avant de valider les dégâts',
    abilityEffect:'reroll_d6_attack', abilityRepeatable:true,
    winCondition:'Tous les Hunters sont morts', winEffect:'shadows_win'),

  CharacterCard(id:'fifi_shadow', name:'Fifi', faction:Faction.shadow, hp:13, icon:'🍀',
    ability:'Unique: ce tour, tous vos dés sont au maximum (7 déplacement, 5 dégâts attaque)',
    abilityEffect:'choose_all_dice',
    winCondition:'Tous les Hunters sont morts', winEffect:'shadows_win'),

  CharacterCard(id:'hong_yi', name:'Hong Yi', faction:Faction.shadow, hp:8, icon:'⚡',
    ability:'Unique: choisissez un joueur — lui infligez 8 blessures, et infligez-vous 4 blessures',
    abilityEffect:'terrain_max_aoe',
    winCondition:'Tous les Hunters sont morts', winEffect:'shadows_win'),

  CharacterCard(id:'jeanne', name:'Jeanne', faction:Faction.shadow, hp:12, icon:'🔮',
    ability:'Unique: à la révélation, marque un joueur (visible de tous) et choisit secrètement une récompense — le joueur qui tue la cible marquée reçoit cette récompense, et Jeanne se soigne de 3',
    abilityEffect:'prophete_mark', abilityRepeatable:false,
    winCondition:'Tous les Hunters sont morts', winEffect:'shadows_win'),

  CharacterCard(id:'julien', name:'Julien', faction:Faction.shadow, hp:11, icon:'😈',
    ability:'Répétable: infligez 2 blessures à un joueur de votre choix, ou soignez-vous de 1 blessure',
    abilityEffect:'damage2_or_heal1', abilityRepeatable:true,
    winCondition:'Tous les Hunters sont morts', winEffect:'shadows_win'),

  CharacterCard(id:'bob', name:'Bob', faction:Faction.shadow, hp:5, icon:'⛓️',
    ability:'Passif: chaque fois que vous mourriez, vous revenez à la vie avec 1 PV MAX de moins (5 → 4 → 3…) — jusqu\'à ce que ce total atteigne 0, où vous mourez alors définitivement.',
    abilityEffect:'bob_resurrect', abilityRepeatable:true,
    winCondition:'Tous les Hunters sont morts', winEffect:'shadows_win'),

  CharacterCard(id:'luc', name:'Luc', faction:Faction.shadow, hp:11, icon:'🔥',
    ability:'Répétable: mettez le feu à un joueur de votre choix — pendant 2 tours, il perd 2 PV au début de son tour, mais ses attaques infligent 1 blessure de plus.',
    abilityEffect:'luc_ignite', abilityRepeatable:true,
    winCondition:'Tous les Hunters sont morts', winEffect:'shadows_win'),

  CharacterCard(id:'maxence', name:'Maxence', faction:Faction.shadow, hp:12, icon:'🩸',
    ability:'Passif révélé: chaque attaque vous inflige 1 blessure, mais lui inflige 2 dégâts de plus.',
    abilityEffect:'maxence_selfharm_boost', abilityRepeatable:true,
    winCondition:'Tous les Hunters sont morts', winEffect:'shadows_win'),

  CharacterCard(id:'tom', name:'Tom', faction:Faction.shadow, hp:14, icon:'💀',
    ability:'Passif: chaque fois que vous éliminez un Shadow, vous gagnez 2 PV MAX et +2 dégâts permanents à vos attaques.',
    abilityEffect:'tom_shadow_kill_boost', abilityRepeatable:true,
    winCondition:'Tous les Hunters sont morts', winEffect:'shadows_win'),

  CharacterCard(id:'louise', name:'Louise', faction:Faction.shadow, hp:10, icon:'💢',
    ability:'Passif: si votre attaque inflige 0 blessure → infligez 4. Sinon infligez 1 de plus',
    abilityEffect:'zero_wound_power', abilityRepeatable:true,
    winCondition:'Tous les Hunters sont morts', winEffect:'shadows_win'),

  CharacterCard(id:'marin', name:'Marin', faction:Faction.shadow, hp:10, icon:'🗡️',
    ability:'Répétable: infligez 3 blessures à un joueur de votre choix et donnez-lui votre dague (+1 dégât pour lui à ses attaques)',
    abilityEffect:'damage3_give_dague', abilityRepeatable:true,
    winCondition:'Tous les Hunters sont morts', winEffect:'shadows_win'),

  CharacterCard(id:'mathieu', name:'Mathieu', faction:Faction.shadow, hp:11, icon:'📊',
    ability:'Passif: à partir de sa 3ème attaque, toutes ses attaques infligent 2 blessures de plus (permanent)',
    abilityEffect:'third_attack_bonus', abilityRepeatable:true,
    winCondition:'Tous les Hunters sont morts', winEffect:'shadows_win'),

  CharacterCard(id:'monkey', name:'Monkey Raph', faction:Faction.shadow, hp:11, icon:'🐒',
    ability:'Répétable: piochez une carte Ténèbres visible de tous',
    abilityEffect:'draw_dark', abilityRepeatable:true,
    winCondition:'Tous les Hunters sont morts', winEffect:'shadows_win'),

  CharacterCard(id:'mr_casino', name:'Mr Casino', faction:Faction.shadow, hp:13, icon:'🎰',
    ability:'Répétable: pariez pair ou impair — si vous gagnez infligez 3 blessures, sinon subissez 2',
    abilityEffect:'casino_bet', abilityRepeatable:true,
    winCondition:'Tous les Hunters sont morts', winEffect:'shadows_win'),

  CharacterCard(id:'nils', name:'Nils', faction:Faction.shadow, hp:13, icon:'📦',
    ability:'Répétable: activez le stockage (vos attaques stockent les blessures au lieu d\'en infliger), puis redéclenchez pour tout déverser sur un joueur au choix',
    abilityEffect:'store_damage_nils', abilityRepeatable:true,
    winCondition:'Tous les Hunters sont morts', winEffect:'shadows_win'),

  CharacterCard(id:'ninja', name:'Ninja', faction:Faction.shadow, hp:12, icon:'🥷',
    ability:'Unique: rejoue autant de tours supplémentaires consécutifs qu\'il y a de joueurs morts au moment de l\'activation. Si personne n\'est mort, le pouvoir n\'a aucun effet.',
    abilityEffect:'bonus_turns', abilityRepeatable:false,
    winCondition:'Tous les Hunters sont morts', winEffect:'shadows_win'),

  CharacterCard(id:'peio', name:'Peio', faction:Faction.shadow, hp:14, icon:'🧌',
    ability:'Répétable: subissez 1 blessure pour réutiliser l\'effet du terrain où vous êtes',
    abilityEffect:'self1_trigger_terrain', abilityRepeatable:true,
    winCondition:'Tous les Hunters sont morts', winEffect:'shadows_win'),

  CharacterCard(id:'pirate', name:'Pirate', faction:Faction.shadow, hp:11, icon:'🏴‍☠️',
    ability:'Passif révélé: portée infinie — vous pouvez attaquer tout joueur sans restriction',
    abilityEffect:'infinite_range', abilityRepeatable:true,
    winCondition:'Tous les Hunters sont morts', winEffect:'shadows_win'),

  CharacterCard(id:'theo', name:'Theo', faction:Faction.shadow, hp:12, icon:'🗲',
    ability:'Passif révélé: si vous n\'avez pas attaqué au tour précédent, votre prochaine attaque infligera 2 blessures de plus',
    abilityEffect:'no_attack_buff', abilityRepeatable:true,
    winCondition:'Tous les Hunters sont morts', winEffect:'shadows_win'),

  CharacterCard(id:'travert', name:'Travert', faction:Faction.shadow, hp:12, icon:'🎲',
    ability:'Unique: choisissez un joueur et lancez le D6 — lui infligez le résultat en blessures',
    abilityEffect:'d6_global_attack',
    winCondition:'Tous les Hunters sont morts', winEffect:'shadows_win'),

  CharacterCard(id:'vlad', name:'Vlad', faction:Faction.shadow, hp:10, icon:'🦇',
    ability:'Répétable: attaquez avec le D4 un joueur à portée',
    abilityEffect:'d4_bonus_attack', abilityRepeatable:true,
    winCondition:'Tous les Hunters sont morts', winEffect:'shadows_win'),

  // ══════════ NEUTRES (8) ══════════

  CharacterCard(id:'cambou', name:'Cambou', faction:Faction.neutral, hp:14, icon:'🌙',
    ability:'Unique: passez votre tour pour soigner toutes vos blessures et ne plus subir de blessures jusqu\'au prochain tour',
    abilityEffect:'full_heal_shield_turn', abilityRepeatable:false,
    winCondition:'Être en vie à la fin de la partie', winEffect:'survive'),

  CharacterCard(id:'carapatte', name:'Carapatte', faction:Faction.neutral, hp:13, icon:'🐢',
    ability:'Unique: attaquez avec le D6 et soignez-vous d\'autant de blessures que vous infligez',
    abilityEffect:'d6_lifesteal',
    winCondition:'Être en vie à la fin de la partie', winEffect:'survive'),

  CharacterCard(id:'jason', name:'Jason', faction:Faction.neutral, hp:12, icon:'🦎',
    ability:'Passif: insensible aux cartes Vision. À sa révélation, choisit un Hunter et un Shadow en jeu, et affiche le reveal de l\'un des deux au choix.',
    abilityEffect:'chameleon_passive', abilityRepeatable:true,
    winCondition:'Être en vie à la fin de la partie', winEffect:'survive'),

  CharacterCard(id:'oscar', name:'Oscar', faction:Faction.neutral, hp:13, icon:'🧪',
    ability:'Répétable: une fois révélé, cumule 1 XP par blessure infligée en attaque. Au début de son tour, peut dépenser son XP au choix — 💧 Eau (3xp): vole un équipement au joueur de son choix — 🌿 Plante (2xp): se soigne de 2 blessures — 🔥 Feu (4xp): +2 dégâts à sa prochaine attaque ce tour',
    abilityEffect:'oscar_xp_spend', abilityRepeatable:true,
    winCondition:'Atteindre 13 XP cumulée', winEffect:'oscar_xp13'),

  CharacterCard(id:'fanny', name:'Fanny', faction:Faction.neutral, hp:12, icon:'🎭',
    ability:'Aucun pouvoir tant que vous n\'avez éliminé personne — si vous éliminez un joueur, vous volez sa carte ENTIÈRE (camp, pouvoir, condition de victoire). Vous devenez alors ce personnage.',
    abilityEffect:'fanny_none', abilityRepeatable:false,
    winCondition:'Aucune tant que vous n\'avez éliminé personne', winEffect:'fanny_none'),

  CharacterCard(id:'victor', name:'Victor', faction:Faction.neutral, hp:13, icon:'💘',
    ability:'Passif révélé: une fois révélé, chaque attaque augmente de 20% la barre de charme du joueur attaqué, et de 10% celle de tous les joueurs sur votre zone. À 100%, un joueur ne peut plus vous attaquer. Vous seul voyez ces barres.',
    abilityEffect:'victor_charm', abilityRepeatable:true,
    winCondition:'Avoir charmé 2 joueurs à 100%', winEffect:'victor_charm2'),

  CharacterCard(id:'maxime', name:'Maxime', faction:Faction.neutral, hp:11, icon:'🗡️',
    ability:'Passif: votre première attaque après vous être révélé inflige le double de blessures.',
    abilityEffect:'maxime_double_first', abilityRepeatable:true,
    winCondition:'Éliminer le premier joueur à vous avoir infligé des blessures cette partie',
    winEffect:'maxime_kill_first_attacker'),

  CharacterCard(id:'leo', name:'Léo', faction:Faction.neutral, hp:12, icon:'💀',
    ability:'Unique: lancez le D4 et infligez ce résultat à tout le monde (vous inclus)',
    abilityEffect:'d4_all', abilityRepeatable:false,
    winCondition:'Être le premier à mourir', winEffect:'die_first_or_kill_hunters'),

  CharacterCard(id:'mango', name:'Mango Loco', faction:Faction.neutral, hp:10, icon:'🥭',
    ability:'Passif : si le joueur attaqué a 13 PV ou plus, vous attaquez 2 fois (lancez les dés 2 fois, dégâts additionnés)',
    abilityEffect:'double_attack_if_tanky', abilityRepeatable:true,
    winCondition:'Éliminer un joueur avec 13 PV ou plus', winEffect:'kill_hp13plus'),

  CharacterCard(id:'rat_rouen', name:"Rat d'Rouen", faction:Faction.neutral, hp:10, icon:'🐀',
    ability:'Passif: vous vous soignez de 1 blessure chaque fois que l\'une de VOS attaques inflige des blessures',
    abilityEffect:'heal1_on_own_attack', abilityRepeatable:true,
    winCondition:'Être en vie à la fin de la partie', winEffect:'survive'),

  CharacterCard(id:'tommy', name:'Tommy', faction:Faction.neutral, hp:13, icon:'🎭',
    ability:'Unique, au début du tour: copiez le pouvoir d\'un joueur révélé de votre choix',
    abilityEffect:'copy_ability', abilityRepeatable:false,
    winCondition:'Éliminer la personne dont vous avez copié le pouvoir', winEffect:'kill_copied'),

  CharacterCard(id:'tristan', name:'Tristan', faction:Faction.neutral, hp:14, icon:'🔄',
    ability:'Répétable: échangez un de vos équipements avec un équipement d\'un autre joueur',
    abilityEffect:'swap_equipment', abilityRepeatable:true,
    winCondition:'Posséder 3 équipements de la même couleur (Lumière ou Ténèbres)',
    winEffect:'three_same_color_equip'),

  
];

// ─── Terrains ────────────────────────────────────────────────────────────────
const List<Terrain> kAllTerrains = [
  Terrain(num:'2-3', id:0, name:'Bibliothèque', effect:'vision',   desc:'Piochez une carte Vision',    icon:'🔮'),
  Terrain(num:'4-5', id:1, name:'Hall',  effect:'choice',   desc:'Piochez une carte de votre choix', icon:'🏪'),
  Terrain(num:'6',   id:2, name:'Salle de Bain',     effect:'lumiere',  desc:'Piochez une carte Lumière',   icon:'⛪'),
  Terrain(num:'8',   id:3, name:'Cuisine',       effect:'tenebres', desc:'Piochez une carte Ténèbres',  icon:'🔨'),
  Terrain(num:'9',   id:4, name:'Salon',            effect:'damage9',  desc:'Infligez 2 blessures au joueur de votre choix', icon:'🏹'),
  Terrain(num:'10',  id:5, name:'Chambre',       effect:'steal',    desc:'Volez une carte équipement',  icon:'🗼'),
];

// ─── Helpers ─────────────────────────────────────────────────────────────────
Map<String, int> getRoleConfig(int n) {
  if (n <= 4) return {'hunters': 2, 'shadows': 1, 'neutrals': 1};
  if (n == 5) return {'hunters': 2, 'shadows': 2, 'neutrals': 1};
  return {'hunters': 3, 'shadows': 3, 'neutrals': 1};
}

// ─── Adjacences terrain ───────────────────────────────────────────────────────
const List<List<int>> kAdjacences = [
  [1, 5], [0, 2], [1, 3], [2, 4], [3, 5], [4, 0],
];

// ─── Cartes Lumière ───────────────────────────────────────────────────────────
const List<GameCard> kLumiereCards = [
  GameCard(id:'L01',name:'Premier Secours',deck:DeckType.lumiere,type:CardType.utilisation,
    effect:'set_marker7_choice',text:'Placez le marqueur de blessure d\'un joueur de votre choix (vous compris) sur le 7'),
  GameCard(id:'L02',name:'Eau Bénite',deck:DeckType.lumiere,type:CardType.utilisation,
    effect:'heal_self_2',text:'Vous êtes soigné de 2 blessures'),
  GameCard(id:'L02b',name:'Eau Bénite',deck:DeckType.lumiere,type:CardType.utilisation,
    effect:'heal_self_2',text:'Vous êtes soigné de 2 blessures'),
  GameCard(id:'L04',name:'Avènement Suprême',deck:DeckType.lumiere,type:CardType.utilisation,
    effect:'hunter_reveal_heal',text:'Si vous êtes Hunter, révélez-vous (ou si déjà révélé) pour soigner toutes vos blessures'),
  GameCard(id:'L05',name:'Amulette',deck:DeckType.lumiere,type:CardType.equipement,
    effect:'tenebres_card_immune',text:'Aucune blessure des cartes Ténèbres Araignée Sanguinaire, Dynamite ou Chauve-souris Vampire'),
  GameCard(id:'L06',name:'Éclair Purificateur',deck:DeckType.lumiere,type:CardType.utilisation,
    effect:'aoe_all_except_self_2',text:'Chaque personnage à l\'exception de vous-même subit 2 blessures'),
  GameCard(id:'L08',name:'Toge Sainte',deck:DeckType.lumiere,type:CardType.equipement,
    effect:'sainte_tunique',text:'Vos attaques infligent 1 blessure de moins et les blessures reçues sont réduites de 1'),
  GameCard(id:'L09',name:'Broche de Chance',deck:DeckType.lumiere,type:CardType.equipement,
    effect:'terrain9_dmg_immune',text:'La Forêt Hantée (terrain 9) ne peut pas vous infliger de blessures (mais peut toujours vous soigner)'),
  GameCard(id:'L10',name:'Bénédiction',deck:DeckType.lumiere,type:CardType.utilisation,
    effect:'heal_other_d6',text:'Choisissez un joueur autre que vous — D6 — il se soigne d\'autant'),
  GameCard(id:'L11',name:'Boussole Mystique',deck:DeckType.lumiere,type:CardType.equipement,
    effect:'double_dice_choice',text:'Quand vous vous déplacez, lancez 2 fois les dés et choisissez le résultat'),
  GameCard(id:'L12',name:'Barre de Chocolat',deck:DeckType.lumiere,type:CardType.utilisation,
    effect:'low_hp_reveal_heal',text:'Si vous avez 11 PV ou moins et révélez (ou avez révélé) votre identité, soignez toutes vos blessures'),
  GameCard(id:'L13',name:'Lance de Longinus',deck:DeckType.lumiere,type:CardType.equipement,
    effect:'lance_longinus',text:'Si vous êtes un Hunter révélé, vos attaques infligent 2 blessures supplémentaires'),
  GameCard(id:'L15',name:'Miroir Divin',deck:DeckType.lumiere,type:CardType.utilisation,
    effect:'force_shadow_reveal',text:'Si vous êtes un Shadow, vous devez révéler votre identité (les autres joueurs ne sont pas affectés)'),
  GameCard(id:'L16',name:'Bucket de Poulet',deck:DeckType.lumiere,type:CardType.utilisation,
    effect:'heal_self_4',text:'Vous êtes soigné de 4 blessures'),
  GameCard(id:'L20',name:'Flamme des Arcades',deck:DeckType.lumiere,type:CardType.utilisation,
    effect:'flamme_arcades',text:'Si vous êtes sur le terrain 6, soignez-vous de 2 ; sinon subissez 1 blessure'),
];

// ─── Cartes Ténèbres ──────────────────────────────────────────────────────────
const List<GameCard> kTenebresCards = [
  GameCard(id:'T01',name:'Poupée Démoniaque',deck:DeckType.tenebres,type:CardType.utilisation,
    effect:'banane_demonique',text:'Désignez un joueur — D6 : 1 à 4 → il subit 3 blessures, 5 ou 6 → vous subissez 3 blessures'),
  GameCard(id:'T02',name:'Mitrailleuse Funeste',deck:DeckType.tenebres,type:CardType.equipement,
    effect:'bazooka',text:'Vos attaques touchent tous les joueurs à votre portée (un seul jet de dés)'),
  GameCard(id:'T03',name:'Rituel Diabolique',deck:DeckType.tenebres,type:CardType.utilisation,
    effect:'shadow_reveal_heal',text:'Si vous êtes Shadow, révélez-vous (ou si déjà révélé) pour soigner toutes vos blessures'),
  GameCard(id:'T04',name:'Dynamite',deck:DeckType.tenebres,type:CardType.utilisation,
    effect:'dynamite',text:'Lancez les 2 dés — 3 blessures à tous les joueurs (vous compris) dans la zone du résultat. Rien si le total est 7'),
  GameCard(id:'T05',name:'Dague du Voleur',deck:DeckType.tenebres,type:CardType.equipement,
    effect:'dague_voleur',text:'+1 blessure si votre attaque inflige des dégâts'),
  GameCard(id:'T05b',name:'Dague du Voleur',deck:DeckType.tenebres,type:CardType.equipement,
    effect:'dague_voleur',text:'+1 blessure si votre attaque inflige des dégâts'),
  GameCard(id:'T05c',name:'Dague du Voleur',deck:DeckType.tenebres,type:CardType.equipement,
    effect:'dague_voleur',text:'+1 blessure si votre attaque inflige des dégâts'),
  GameCard(id:'T06',name:'Sabre Hanté Masamune',deck:DeckType.tenebres,type:CardType.equipement,
    effect:'hache_berserker',text:'Vous êtes obligé d\'attaquer durant votre tour, avec le D4 uniquement (résultat brut)'),
  GameCard(id:'T07',name:'Révolver des Ténèbres',deck:DeckType.tenebres,type:CardType.equipement,
    effect:'revolver_tenebres',text:'Attaquez un joueur sur l\'un des 4 lieux hors de votre secteur — vous ne pouvez plus attaquer dans votre propre secteur'),
  GameCard(id:'T08',name:'Chauve-souris Vampire',deck:DeckType.tenebres,type:CardType.utilisation,
    effect:'vampirisation',text:'Infligez 2 blessures à un joueur de votre choix puis soignez-vous de 1'),
  GameCard(id:'T08b',name:'Chauve-souris Vampire',deck:DeckType.tenebres,type:CardType.utilisation,
    effect:'vampirisation',text:'Infligez 2 blessures à un joueur de votre choix puis soignez-vous de 1'),
  GameCard(id:'T08c',name:'Chauve-souris Vampire',deck:DeckType.tenebres,type:CardType.utilisation,
    effect:'vampirisation',text:'Infligez 2 blessures à un joueur de votre choix puis soignez-vous de 1'),
  GameCard(id:'T10',name:'Araignée Sanguinaire',deck:DeckType.tenebres,type:CardType.utilisation,
    effect:'veuve_noire',text:'Infligez 2 blessures à un joueur de votre choix puis subissez 2 blessures'),
  GameCard(id:'T11',name:'Peau de Banane',deck:DeckType.tenebres,type:CardType.utilisation,
    effect:'peau_banane',text:'Donnez une de vos cartes équipement à un autre joueur. Si vous n\'en avez aucune, subissez 1 blessure'),
  GameCard(id:'T12',name:'Succube Tentatrice',deck:DeckType.tenebres,type:CardType.utilisation,
    effect:'pince_attrape',text:'Volez la carte équipement du joueur de votre choix'),
  GameCard(id:'T12b',name:'Succube Tentatrice',deck:DeckType.tenebres,type:CardType.utilisation,
    effect:'pince_attrape',text:'Volez la carte équipement du joueur de votre choix'),
  GameCard(id:'T14',name:'Épée des Ninja',deck:DeckType.tenebres,type:CardType.equipement,
    effect:'epee_ninja',text:'Si votre attaque inflige des blessures, la victime subit 2 blessures supplémentaires'),
  GameCard(id:'T16',name:'Carapace Bleu',deck:DeckType.tenebres,type:CardType.utilisation,
    effect:'blue_shell',text:'Passez le marqueur de blessure d\'un joueur sur 5'),
  GameCard(id:'T19',name:'Sniper',deck:DeckType.tenebres,type:CardType.equipement,
    effect:'sniper',text:'Peut attaquer un joueur peu importe où il se trouve'),
];

// ─── Cartes Vision ────────────────────────────────────────────────────────────
const List<GameCard> kVisionCards = [
  GameCard(id:'V01',name:'Divination Shadow ×2',deck:DeckType.vision,type:CardType.utilisation,
    effect:'vision_shadow_2',text:'Je pense que tu es Shadow — si oui, subis 2 blessures'),
  GameCard(id:'V02',name:'Divination Hunter ×1',deck:DeckType.vision,type:CardType.utilisation,
    effect:'vision_hunter_1',text:'Je pense que tu es Hunter — si oui, subis 1 blessure'),
  GameCard(id:'V02b',name:'Divination Hunter ×1',deck:DeckType.vision,type:CardType.utilisation,
    effect:'vision_hunter_1',text:'Je pense que tu es Hunter — si oui, subis 1 blessure'),
  GameCard(id:'V04',name:'Divination Shadow ×1',deck:DeckType.vision,type:CardType.utilisation,
    effect:'vision_shadow_1',text:'Je pense que tu es Shadow — si oui, subis 1 blessure'),
  GameCard(id:'V05',name:'Intuition Shadow',deck:DeckType.vision,type:CardType.utilisation,
    effect:'vision_shadow_heal_or_dmg',text:'Je pense que tu es Shadow — si oui, soigne-toi de 1 (sinon, subis 1)'),
  GameCard(id:'V06',name:'Intuition Hunter',deck:DeckType.vision,type:CardType.utilisation,
    effect:'vision_hunter_heal_or_dmg',text:'Je pense que tu es Hunter — si oui, soigne-toi de 1 (sinon, subis 1)'),
  GameCard(id:'V07',name:'Intuition Neutre',deck:DeckType.vision,type:CardType.utilisation,
    effect:'vision_neutral_heal_or_dmg',text:'Choisissez un joueur — s\'il est Neutre, il se soigne de 1. Sinon il subit 1 blessure.'),
  GameCard(id:'V08',name:'Vision Suprême',deck:DeckType.vision,type:CardType.utilisation,
    effect:'vision_show_card',text:'Montre-moi secrètement ta carte personnage'),
  GameCard(id:'V09',name:'Divination Neutre ou Shadow',deck:DeckType.vision,type:CardType.utilisation,
    effect:'vision_punish_neutral_shadow',text:'Je pense que tu es Neutre ou Shadow — si c\'est le cas, donne-moi une carte équipement ou subis 1'),
  GameCard(id:'V09b',name:'Divination Neutre ou Shadow',deck:DeckType.vision,type:CardType.utilisation,
    effect:'vision_punish_neutral_shadow',text:'Je pense que tu es Neutre ou Shadow — si c\'est le cas, donne-moi une carte équipement ou subis 1'),
  GameCard(id:'V10',name:'Divination Neutre ou Hunter',deck:DeckType.vision,type:CardType.utilisation,
    effect:'vision_punish_neutral_hunter',text:'Je pense que tu es Neutre ou Hunter — si c\'est le cas, donne-moi une carte équipement ou subis 1'),
  GameCard(id:'V10b',name:'Divination Neutre ou Hunter',deck:DeckType.vision,type:CardType.utilisation,
    effect:'vision_punish_neutral_hunter',text:'Je pense que tu es Neutre ou Hunter — si c\'est le cas, donne-moi une carte équipement ou subis 1'),
  GameCard(id:'V11',name:'Divination Shadow ou Hunter',deck:DeckType.vision,type:CardType.utilisation,
    effect:'vision_punish_shadow_hunter',text:'Je pense que tu es Shadow ou Hunter — si c\'est le cas, donne-moi une carte équipement ou subis 1'),
  GameCard(id:'V11b',name:'Divination Shadow ou Hunter',deck:DeckType.vision,type:CardType.utilisation,
    effect:'vision_punish_shadow_hunter',text:'Je pense que tu es Shadow ou Hunter — si c\'est le cas, donne-moi une carte équipement ou subis 1'),
  GameCard(id:'V12',name:'Divination Vétéran',deck:DeckType.vision,type:CardType.utilisation,
    effect:'vision_hp_12plus',text:'Je pense que tu as 12 PV ou plus — si oui, subis 2 blessures'),
  GameCard(id:'V13',name:'Divination Novice',deck:DeckType.vision,type:CardType.utilisation,
    effect:'vision_hp_11minus',text:'Je pense que tu as 11 PV ou moins — si oui, subis 1 blessure'),
];

// ─── Helpers ──────────────────────────────────────────────────────────────────
GameCard? findCardById(String id) {
  for (final c in [...kLumiereCards, ...kTenebresCards, ...kVisionCards]) {
    if (c.id == id) return c;
  }
  return null;
}

List<GameCard> deckCards(DeckType deck) => switch (deck) {
  DeckType.lumiere  => kLumiereCards,
  DeckType.tenebres => kTenebresCards,
  DeckType.vision   => kVisionCards,
};

const List<String> kBotNames = ['Ombralys', 'Vexar', 'Kira', 'Drath'];
