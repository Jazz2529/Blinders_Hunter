// lib/data/characters_data.dart
// Mapping character id → image illustration

import '../services/persistence.dart';
import 'cosmetics_data.dart';

const Map<String, String> kRevealQuotes = {
  'albane': "[Your time ends now]",
  'amelia': "[Light ! Guide my hand]",
  'artcade': "[You wish to be struck by lightning ?]",
  'augustin': "[Who dares defile this ancient Lamb]",
  'fijacked': "[Break yourself upon my Body]",
  'scott': "[Arise !]",
  'louna': "[No more Nice it is]",
  'richard2': "[I've got magic like you've never seen before]",
  'clemence': "[Life's notes may change but the song is the same]",
  'marion': "[Get ready for your just Death-ert]",
  'oceane': "[It's time to even the scales]",
  'elaia': "[Welcome ! Care to hear your fortune ?]",
  'damien': "[Hum, I was not expecting a guest like you]",
  'tommy': "[My people will rise anew, whether you help us or not!]",
  'mango': "[Welcome to my Eternal Party !]",
  'raph_soleil': "[You are here for a Lesson ?]",
  'elise': "[There is strength in Harmony]",
  'baleine': "[Fill the skies with a cascade of sparkles !]",
  'gege': "[I cannot find eternal rest and neither will you]",
  'bibble': "[Mrglglrglglglglglglgl.. or whatever he said]",
  'jeanne': "[I've seen your future]",
  'ninja': "[Go with Honor, Friend]",
  'louise': "[Roll out the Red carpet !]",
  'mathieu': "[Evil will be purged !]",
  'mr_casino': "[This is a Performance you will never forget]",
  'monkey': "[The wild hunts begins]",
  'pirate': "[Fire the Cannons !]",
  'hong_yi': "[Victory or Death !]",
  'vlad': "[Your curiosity will be the end of You]",
  'travert': "[Time for a Remix !]",
  'fifi_shadow': "[For the Gnomes !]",
  'marin': "[Time to bring the Heat]",
  'peio': "[The earth itself is my ally !]",
  'julien': "[Do you smell something burning ?]",
  'cambou': "[Time may pass, but the dream is eternal]",
  'leo': "[It is too late you cannot stop Me]",
  'rat_rouen': "[I will cut you down to my Size]",
  'carapatte': "[Are you interrupting my Meal ?]",
  'tristan': "[You won't be taking my treasures]",
  'jason': "[Argh, You got me !]",
  'carla': "[You seem overburdened. Lucky I'm here]",
  'nils': "[I just love it when a plan comes together]",
  'emilien': "[Who the King ? I the King]",
  'agathe': "[My heart is one with the eternal forest]",
  'felipe': "[Your soul shall be Mine]",
  'theo': "[Let's show these fine folk some Badlands hospitality]",
  'remi': "[May have gone slightly overboard on the size]",
  'oscar': "[Alright little one, let's bring you to life !]",
  'victor': "[What adventure you're up to today ?]",
  'maxime': "[Aaah, This guy is toasted]",
  'fanny': "[Evil lurks in these holes]",
  'maxence': "[Rawrrrr, dinodaure]",
  'bob': "[See the world as I do]",
  'meg': "[Power takes many form]",
  'tom': "[The true Horde cannot be stopped]",
  'hailey': "[A Worthy opponent !]",
  'luc': "[By Fire be Purged]",
  'ines': "[True mages masters all magic]",
  'baptiste': "[Fine, I'll heal]",
  'christine': "[No one crosses the uncrowned]",
};

const Map<String, String> kCharacterImages = {
  '3pintes': 'assets/images/characters/3_pinte.png',
  '80ans': 'assets/images/characters/80ans.png',
  'agathe': 'assets/images/characters/agathe.png',
  'albane': 'assets/images/characters/albane.png',
  'amelia': 'assets/images/characters/amelia.png',
  'artcade': 'assets/images/characters/art_cade.png',
  'augustin': 'assets/images/characters/augustin.png',
  'baleine': 'assets/images/characters/baleine.png',
  'baptiste': 'assets/images/characters/baptiste.png',
  'baron_marion': 'assets/images/characters/baron_marion.png',
  'bibble': 'assets/images/characters/bibble.png',
  'burger': 'assets/images/characters/burger.png',
  'cambou': 'assets/images/characters/cambou.png',
  'captain_ricard': 'assets/images/characters/captain_ricard.png',
  'carapatte': 'assets/images/characters/carapatte.png',
  'carla': 'assets/images/characters/carla.png',
  'chaise_merguez': 'assets/images/characters/chaise_merguez.png',
  'chaussette': 'assets/images/characters/chaussette.png',
  'christine': 'assets/images/characters/christine.png',
  'christine_maman': 'assets/images/characters/christine_maman.png',
  'clemence': 'assets/images/characters/clemence.png',
  'commandante_marion': 'assets/images/characters/commandante_marion.png',
  'couronne': 'assets/images/characters/couronne.png',
  'cupidon': 'assets/images/characters/cupidon.png',
  'damien_homard': 'assets/images/characters/damien_homard.png',
  'demi_sel': 'assets/images/characters/demi_sel.png',
  'dresseur_oscar': 'assets/images/characters/dresseur_oscar.png',
  'elaia': 'assets/images/characters/elaia.png',
  'elise': 'assets/images/characters/elise.png',
  'emilien_ninja': 'assets/images/characters/emilien_ninja.png',
  'enceinte_liste': 'assets/images/characters/enceinte.png',
  'fanny': 'assets/images/characters/fanny.png',
  'felipe': 'assets/images/characters/felipe.png',
  'felipe_pompims': 'assets/images/characters/felipe_pompims.png',
  'fifi_automne': 'assets/images/characters/fifi_d_automne.png',
  'fifi_ete': 'assets/images/characters/fifi_ete.png',
  'fifi_hiver': 'assets/images/characters/fifi_hiver.png',
  'fifi_shadow': 'assets/images/characters/fifi.png',
  'fijacked': 'assets/images/characters/fijacked.png',
  'garde_carla': 'assets/images/characters/garde_carla.png',
  'gege': 'assets/images/characters/gege_le_fantome.png',
  'glads': 'assets/images/characters/glads.png',
  'hailey': 'assets/images/characters/hailey.png',
  'hong_yi': 'assets/images/characters/hong_yi.png',
  'ines': 'assets/images/characters/ines.png',
  'ines_artdent': 'assets/images/characters/ines_artdent.png',
  'ingenieur': 'assets/images/characters/ingenieur.png',
  'jason': 'assets/images/characters/jason.png',
  'jason_espion': 'assets/images/characters/jason_espion.png',
  'jazzon': 'assets/images/characters/jazzon.png',
  'jeanne': 'assets/images/characters/jeanne.png',
  'jesus': 'assets/images/characters/jesus.png',
  'joey': 'assets/images/characters/joey.png',
  'julien': 'assets/images/characters/julien.png',
  'bob': 'assets/images/characters/bob.png',
  'luc': 'assets/images/characters/luc.png',
  'lea_ogway': 'assets/images/characters/lea_ogway.png',
  'leo': 'assets/images/characters/leo.png',
  'louise': 'assets/images/characters/louise.png',
  'louna': 'assets/images/characters/louna.png',
  'mango_loco': 'assets/images/characters/mango_loco.png',
  'marin': 'assets/images/characters/marin.png',
  'marion': 'assets/images/characters/marion.png',
  'mathieu': 'assets/images/characters/mathieu.png',
  'maxence': 'assets/images/characters/maxence.png',
  'meg': 'assets/images/characters/meg.png',
  'tom': 'assets/images/characters/tom.png',
  'maxime': 'assets/images/characters/maxime.png',
  'victor': 'assets/images/characters/victor.png',
  'meiko': 'assets/images/characters/meiko.png',
  'mimic': 'assets/images/characters/mimic.png',
  'monkey': 'assets/images/characters/monkey_raph.png',
  'mr_casino': 'assets/images/characters/mr_casino.png',
  'nils': 'assets/images/characters/nils.png',
  'theo': 'assets/images/characters/theo.png',
  'emilien': 'assets/images/characters/emilien.png',
  'nina': 'assets/images/characters/nina.png',
  'ninja': 'assets/images/characters/ninja.png',
  'nuts': 'assets/images/characters/nuts.png',
  'oceane': 'assets/images/characters/oceane.png',
  'orion': 'assets/images/characters/orion.png',
  'oscar': 'assets/images/characters/oscar.png',
  'pas_un_blinders': 'assets/images/characters/pas_un_blinders.png',
  'peintre': 'assets/images/characters/peinture.png',
  'peio_mongolie': 'assets/images/characters/peio_de_mongolie.png',
  'peio': 'assets/images/characters/peio.png',
  'pirate': 'assets/images/characters/pirate.png',
  'pretresse_raph': 'assets/images/characters/pretresse_raph.png',
  'raph_soleil': 'assets/images/characters/raph_du_soleil_levant.png',
  'raphael_shadow': 'assets/images/characters/raphael.png',
  'rat_rouen': 'assets/images/characters/rat.png',
  'remi': 'assets/images/characters/remi.png',
  'remi_canada': 'assets/images/characters/remi_du_canada.png',
  'richard2': 'assets/images/characters/richard_ii.png',
  'roi_burger': 'assets/images/characters/roi_burger.png',
  'roi_clemence': 'assets/images/characters/roi_clem.png',
  'scott': 'assets/images/characters/scott.png',
  'slime': 'assets/images/characters/slime.png',
  'soubrette_marin': 'assets/images/characters/marin_soubrette.png',
  'theo_homard': 'assets/images/characters/theo_homard.png',
  'tommy': 'assets/images/characters/tommy.png',
  'damien': 'assets/images/characters/damien.png',
  'mango': 'assets/images/characters/mango.png',
  'travert': 'assets/images/characters/travert.png',
  'tristan': 'assets/images/characters/tristan.png',
  'vache': 'assets/images/characters/vache.png',
  'vlad_princesse': 'assets/images/characters/vlad_princesse.png',
  'vlad_soleil': 'assets/images/characters/vlad_du_soleil_levant.png',
  'vladimir': 'assets/images/characters/vladimir.png',
  'vlad':     'assets/images/characters/vlad.png',   // Vlad Shadow
  'voiture_clem': 'assets/images/characters/voiture_de_clem.png',
  'woods': 'assets/images/characters/woods.png',
  'zazou': 'assets/images/characters/zazou.png',
  'zombie_raph': 'assets/images/characters/zombie_raph.png',
};

// Mapping terrain effect → image PNG
const Map<String, String> kTerrainImages = {
  'vision':   'assets/images/terrains/terrain_23.png',
  'choice':   'assets/images/terrains/terrain_45.png',
  'lumiere':  'assets/images/terrains/terrain_6.png',
  'tenebres': 'assets/images/terrains/terrain_8.png',
  'damage9':  'assets/images/terrains/terrain_9.png',
  'steal':    'assets/images/terrains/terrain_10.png',
};

// Mapping card effect → image PNG
const Map<String, String> kCardImages = {
  // Ténèbres
  'hache_berserker':    'assets/images/cards/hache_berserker.png',
  'peau_banane':        'assets/images/cards/peau_banane.png',
  'pince_attrape':      'assets/images/cards/pince_attrape.png',
  'sniper':             'assets/images/cards/sniper.png',
  'trebuchet':          'assets/images/cards/trebuchet.png',
  'vampirisation':      'assets/images/cards/vampirisation.png',
  'veuve_noire':        'assets/images/cards/veuve_noire.png',
  'banane_demonique':   'assets/images/cards/banane_demonique.png',
  'bazooka':            'assets/images/cards/bazooka.png',
  'shadow_reveal_heal': 'assets/images/cards/black_sabbath.png',
  'blue_shell':         'assets/images/cards/blue_shell.png',
  'bombe':              'assets/images/cards/bombe.png',
  'dague_voleur':       'assets/images/cards/dague_voleur.png',
  'dynamite':           'assets/images/cards/dynamite.png',
  'revolver_tenebres':  'assets/images/cards/revolver_tenebres.png',
  'epee_ninja':         'assets/images/cards/epee_ninja.png',
  // Lumière
  'aoe_same_zone_2':     'assets/images/cards/aoe_same_zone_2.png',
  'lance_lumiere':       'assets/images/cards/lance_lumiere.png',
  'shield_next_turn':    'assets/images/cards/shield_next_turn.png',
  'sainte_tunique':      'assets/images/cards/sainte_tunique.png',
  'crucifix_argent':     'assets/images/cards/crucifix_argent.png',
  'tenebres_card_immune':'assets/images/cards/tenebres_card_immune.png',
  'heal_other_d6':       'assets/images/cards/heal_other_d6.png',
  'triple_dice_choice':  'assets/images/cards/triple_dice_choice.png',
  'set_marker7_choice':  'assets/images/cards/set_marker7_choice.png',
  'heal_self_2':         'assets/images/cards/heal_self_2.png',
  'extra_turn':          'assets/images/cards/extra_turn.png',
  'hunter_reveal_heal':  'assets/images/cards/hunter_reveal_heal.png',
  'terrain9_immune':     'assets/images/cards/terrain9_immune.png',
  'terrain4_heal_or_dmg':'assets/images/cards/terrain4_heal_or_dmg.png',
  'aoe_all_except_self_2':'assets/images/cards/aoe_all_except_self_2.png',
  'terrain9_dmg_immune': 'assets/images/cards/terrain9_dmg_immune.png',
  'double_dice_choice':  'assets/images/cards/double_dice_choice.png',
  'low_hp_reveal_heal':  'assets/images/cards/low_hp_reveal_heal.png',
  'lance_longinus':      'assets/images/cards/lance_longinus.png',
  'force_shadow_reveal': 'assets/images/cards/force_shadow_reveal.png',
  'heal_self_4':         'assets/images/cards/heal_self_4.png',
  'flamme_arcades':      'assets/images/cards/flamme_arcades.png',
  // Vision
  'vision_hunter_1':     'assets/images/cards/vision_hunter_1.png',
  'vision_hunter_2':     'assets/images/cards/vision_hunter_2.png',
  'vision_shadow_1':     'assets/images/cards/vision_shadow_1.png',
  'vision_shadow_2':     'assets/images/cards/vision_shadow_2.png',
  'vision_shadow_heal_or_dmg':    'assets/images/cards/vision_shadow_heal_or_dmg.png',
  'vision_hunter_heal_or_dmg':    'assets/images/cards/vision_hunter_heal_or_dmg.png',
  'vision_neutral_heal_or_dmg':   'assets/images/cards/vision_neutral_heal_or_dmg.png',
  'vision_show_card':             'assets/images/cards/vision_show_card.png',
  'vision_punish_neutral_shadow': 'assets/images/cards/vision_punish_neutral_shadow.png',
  'vision_punish_neutral_hunter': 'assets/images/cards/vision_punish_neutral_hunter.png',
  'vision_punish_shadow_hunter':  'assets/images/cards/vision_punish_shadow_hunter.png',
  'vision_hp_12plus':             'assets/images/cards/vision_hp_12plus.png',
  'vision_hp_11minus':            'assets/images/cards/vision_hp_11minus.png',
};

// Dos de carte Vision (visible par les autres)
const String kVisionOtherImage = 'assets/images/cards/vision_other.png';

String? characterImagePath(String id) => kCharacterImages[id];

/// Illustration effective d'un personnage — prend en compte le cosmétique
/// équipé (boutique) s'il y en a un, sinon retombe sur l'image de base.
/// À utiliser PARTOUT où un personnage est affiché en jeu, à la place d'un
/// appel direct à characterImagePath(), pour que les achats en boutique
/// soient réellement visibles.
String? effectiveCharacterImagePath(String id) {
  final equipped = Prefs.equippedCosmetics()['character:$id'];
  if (equipped != null) {
    final item = kCosmeticsCatalog.where((c) => c.id == equipped).firstOrNull;
    if (item != null) return item.imagePath;
  }
  return characterImagePath(id);
}

/// Résout l'illustration d'un skin PRÉCIS par son identifiant — sans jamais
/// regarder les préférences locales de CET appareil. Nécessaire pour
/// afficher le skin qu'un AUTRE joueur a équipé (synchronisé via
/// Player.equippedCharacterSkin), plutôt que la préférence locale du
/// joueur qui consulte sa fiche.
String? resolveSpecificSkinImagePath(String characterId, String? skinId) {
  if (skinId != null) {
    final item = kCosmeticsCatalog.where((c) => c.id == skinId).firstOrNull;
    if (item != null) return item.imagePath;
  }
  return characterImagePath(characterId);
}
String? terrainImagePath(String effect) => kTerrainImages[effect];

/// Illustration effective d'un terrain — prend en compte le cosmétique
/// équipé (boutique) s'il y en a un, sinon retombe sur l'image de base.
/// Si le réglage "skins aléatoires" est actif, utilise en priorité le skin
/// tiré au sort pour CETTE partie (voir Prefs.rollRandomTerrainSkinsForNewGame).
String? effectiveTerrainImagePath(String effect) {
  if (Prefs.randomTerrainSkins()) {
    final randomId = Prefs.sessionTerrainSkins()[effect];
    if (randomId != null) {
      final item = kCosmeticsCatalog.where((c) => c.id == randomId).firstOrNull;
      if (item != null) return item.imagePath;
    }
  }
  final equipped = Prefs.equippedCosmetics()['terrain:$effect'];
  if (equipped != null) {
    final item = kCosmeticsCatalog.where((c) => c.id == equipped).firstOrNull;
    if (item != null) return item.imagePath;
  }
  return terrainImagePath(effect);
}
String? cardImagePath(String effect) => kCardImages[effect];

/// Réplique personnalisée affichée (et jouée en audio) quand ce personnage
/// se révèle — visible/audible de tous les joueurs.
String revealQuoteFor(String characterId) =>
    kRevealQuotes[characterId] ?? '« ... »';

/// PLACEHOLDER : chemin du fichier audio de la réplique de révélation.
/// Remplace `assets/audio/reveal_<id>.mp3` par le vrai fichier une fois
/// enregistré — aucun changement de code nécessaire.
String revealVoicePath(String characterId) => 'assets/audio/reveal_$characterId.mp3';
String? anyCardImagePath(String effect) => kCardImages[effect];
