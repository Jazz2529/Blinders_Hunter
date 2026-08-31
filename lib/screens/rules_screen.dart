import 'package:flutter/material.dart';
import '../widgets/theme.dart';
import '../data/game_data.dart';
import '../services/i18n.dart';

/// ─── Écran des règles — consultable partout via le bouton ❓ ────────────────
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext ctx) => LanguageAware(builder: (ctx) {
    final en = AppLanguage.instance.isEnglish;
    return Scaffold(
      backgroundColor: kBg0,
      appBar: AppBar(
        backgroundColor: kBg2, elevation: 0,
        title: Text(en ? '📖 Game rules' : '📖 Règles du jeu', style: cinzel(16, c: kGold2)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: en ? _buildEn() : _buildFr(),
      ),
    );
  });

  List<Widget> _buildFr() => [
    _section('🎯 OBJECTIF', [
      _p('Chaque joueur incarne secrètement un personnage appartenant à une faction :'),
      _bullet('🔵 Hunters', 'gagnent quand tous les Shadows sont morts.'),
      _bullet('🔴 Shadows', 'gagnent quand tous les Hunters sont morts.'),
      _bullet('🟡 Neutres', 'ont chacun leur propre condition de victoire.'),
      _p("Ton identité reste cachée jusqu'à ce que tu la révèles — ou qu'une carte Vision la découvre. Révéler son identité débloque sa capacité spéciale."),
    ]),
    _section("🔄 DÉROULEMENT D'UN TOUR", [
      _bullet('1. Capacité', 'si tu es révélé, tu peux utiliser ta capacité (ou passer).'),
      _bullet('2. Déplacement', 'lance D4 + D6. La somme (2-10) désigne ta zone de destination. Un 7 te laisse choisir ta zone.'),
      _bullet('3. Effet du terrain', "applique (ou ignore) l'effet de la zone où tu atterris."),
      _bullet('4. Attaque', 'attaque un joueur à portée (ta zone + zones adjacentes). Dégâts = |D4 − D6|.'),
      _p("La partie continue jusqu'à ce qu'une faction remplisse sa condition de victoire."),
    ]),
    _section('🗺 LES TERRAINS', [
      for (final t in kAllTerrains)
        _bullet('${t.icon} ${t.num} — ${t.name}', t.desc),
      _p("Les zones adjacentes à la tienne sont les seules à portée d'attaque (sauf effets spéciaux comme le Sniper ou Pirate)."),
    ]),
    _section('🃏 LES CARTES', [
      _bullet('🔮 Vision', 'joue-la sur un adversaire pour sonder secrètement son identité.'),
      _bullet('✨ Lumière', 'soins, équipements bénéfiques et protections.'),
      _bullet('💀 Ténèbres', 'dégâts, malédictions et équipements offensifs.'),
      _p("Une carte piochée doit être appliquée — impossible de l'ignorer."),
    ]),
    _section('⚔️ COMBAT', [
      _bullet('Dégâts', '|D4 − D6| : de 0 (égalité) à 5 (écart max).'),
      _bullet('Portée', 'ta zone + les zones adjacentes.'),
      _bullet('Équipements', 'dagues, bazooka, sniper et autres modifient tes attaques.'),
      _bullet('Blessures', 'quand tes blessures atteignent tes PV max, tu es éliminé.'),
    ]),
    _section('💡 ASTUCES', [
      _p("• Rester caché protège ton identité mais bloque ta capacité."),
      _p('• Observe qui attaque qui : les alliances se devinent vite.'),
      _p('• Les Neutres sèment le doute — méfie-toi des comportements étranges.'),
      _p("• Certaines capacités se déclenchent à la mort : tuer n'est pas toujours gagnant."),
    ]),
    const SizedBox(height: 24),
  ];

  List<Widget> _buildEn() => [
    _section('🎯 OBJECTIVE', [
      _p('Each player secretly plays a character belonging to a faction:'),
      _bullet('🔵 Hunters', 'win when all Shadows are dead.'),
      _bullet('🔴 Shadows', 'win when all Hunters are dead.'),
      _bullet('🟡 Neutrals', 'each have their own win condition.'),
      _p("Your identity stays hidden until you reveal it — or a Vision card exposes it. Revealing your identity unlocks your special ability."),
    ]),
    _section('🔄 HOW A TURN WORKS', [
      _bullet('1. Ability', 'if revealed, you may use your ability (or skip it).'),
      _bullet('2. Movement', 'roll D4 + D6. The sum (2-10) points to your destination zone. A 7 lets you choose your zone.'),
      _bullet('3. Zone effect', 'apply (or ignore) the effect of the zone you land on.'),
      _bullet('4. Attack', 'attack a player in range (your zone + adjacent zones). Damage = |D4 − D6|.'),
      _p('The game continues until a faction fulfills its win condition.'),
    ]),
    _section('🗺 THE ZONES', [
      for (final t in kAllTerrains)
        _bullet('${t.icon} ${t.num} — ${tr(t.name)}', tr(t.desc)),
      _p('Zones adjacent to yours are the only ones within attack range (except special effects like Sniper or Pirate).'),
    ]),
    _section('🃏 THE CARDS', [
      _bullet('🔮 Vision', 'play it on an opponent to secretly probe their identity.'),
      _bullet('✨ Light', 'healing, beneficial equipment, and protections.'),
      _bullet('💀 Dark', 'damage, curses, and offensive equipment.'),
      _p("A drawn card must be applied — it cannot be ignored."),
    ]),
    _section('⚔️ COMBAT', [
      _bullet('Damage', '|D4 − D6|: from 0 (tie) to 5 (max gap).'),
      _bullet('Range', 'your zone + adjacent zones.'),
      _bullet('Equipment', 'daggers, bazooka, sniper and others modify your attacks.'),
      _bullet('Wounds', 'when your wounds reach your max HP, you are eliminated.'),
    ]),
    _section('💡 TIPS', [
      _p('• Staying hidden protects your identity but blocks your ability.'),
      _p('• Watch who attacks whom: alliances are quickly guessed.'),
      _p('• Neutrals sow doubt — beware of strange behavior.'),
      _p("• Some abilities trigger on death: killing isn't always a win."),
    ]),
    const SizedBox(height: 24),
  ];

  Widget _section(String title, List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: kBg2, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: kBord2)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: cinzel(13, c: kGold2, fw: FontWeight.w900)),
      const SizedBox(height: 10),
      ...children,
    ]),
  );

  Widget _p(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: body(12, c: kTextSub)));

  Widget _bullet(String label, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: RichText(text: TextSpan(children: [
      TextSpan(text: '$label — ',
        style: body(12, c: kGold, fw: FontWeight.w700)),
      TextSpan(text: text, style: body(12, c: kTextSub)),
    ])),
  );
}
