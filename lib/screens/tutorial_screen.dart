// lib/screens/tutorial_screen.dart
// Tutoriel interactif — mécaniques du jeu Blinders Hunter

import 'package:flutter/material.dart';
import '../widgets/theme.dart';
import '../widgets/token_widget.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});
  @override State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen>
{
  int _page = 0;
  static const _totalPages = 10;

  @override
  void initState() { super.initState(); }

  void _next() {
    if (_page >= _totalPages - 1) { Navigator.pop(context); return; }
    setState(() => _page++);
  }

  void _prev() {
    if (_page <= 0) return;
    setState(() => _page--);
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      backgroundColor: kBg0,
      body: SafeArea(child: Column(children: [

        // ── Header ───────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(color: kBg2,
            border: Border(bottom: BorderSide(color: kBord))),
          child: Row(children: [
            GestureDetector(onTap: () => Navigator.pop(ctx),
              child: const Icon(Icons.close, color: kTextSub, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text('TUTORIEL', style: cinzel(10, c: kTextSub, ls: 3)),
              Text(_pageTitles[_page], style: cinzel(14, c: kGold2, fw: FontWeight.w900)),
            ])),
            Text('${_page + 1} / $_totalPages', style: body(12, c: kTextSub)),
          ]),
        ),

        // ── Barre de progression ─────────────────────────────────
        LinearProgressIndicator(
          value: (_page + 1) / _totalPages,
          backgroundColor: kBg3,
          valueColor: const AlwaysStoppedAnimation(kGold),
          minHeight: 3,
        ),

        // ── Contenu ──────────────────────────────────────────────
        Expanded(child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: SingleChildScrollView(
            key: ValueKey(_page),
            padding: const EdgeInsets.all(20),
            child: _buildPage(_page),
          ),
        )),

        // ── Navigation ───────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(color: kBg2,
            border: Border(top: BorderSide(color: kBord))),
          child: Row(children: [
            if (_page > 0)
              Expanded(child: BHButton(
                label: '← Précédent',
                outlined: true,
                onTap: _prev,
              ))
            else
              const Expanded(child: SizedBox()),
            const SizedBox(width: 12),
            Expanded(child: BHButton(
              label: _page == _totalPages - 1 ? '✅ Terminer' : 'Suivant →',
              gold: true,
              onTap: _next,
            )),
          ]),
        ),
      ])),
    );
  }

  // ── Titres des pages ─────────────────────────────────────────────────────
  static const _pageTitles = [
    'Bienvenue',
    'Les Factions',
    'Le Plateau',
    'Structure d\'un Tour',
    'Le Déplacement',
    'Les Terrains',
    'Les Cartes',
    'L\'Attaque',
    'Les Pouvoirs',
    'La Victoire',
  ];

  // ── Contenu par page ─────────────────────────────────────────────────────
  Widget _buildPage(int page) {
    switch (page) {
      case 0: return _page0();
      case 1: return _page1();
      case 2: return _page2();
      case 3: return _page3();
      case 4: return _page4();
      case 5: return _page5();
      case 6: return _page6();
      case 7: return _page7();
      case 8: return _page8();
      case 9: return _page9();
      default: return const SizedBox.shrink();
    }
  }

  // ── PAGE 0 : Bienvenue ───────────────────────────────────────────────────
  Widget _page0() => Column(children: [
    const SizedBox(height: 12),
    Text('⚔️', style: const TextStyle(fontSize: 72)),
    const SizedBox(height: 16),
    Text('BLINDERS HUNTER', style: cinzel(26, c: kGold, fw: FontWeight.w900, ls: 4),
      textAlign: TextAlign.center),
    const SizedBox(height: 8),
    Text('Jeu de rôles cachés · 4 à 7 joueurs',
      style: body(14, c: kTextSub), textAlign: TextAlign.center),
    const SizedBox(height: 24),
    _card('''Blinders Hunter est un jeu de déduction sociale où chaque joueur reçoit un rôle secret.

Ton objectif : identifier les membres de l'équipe adverse et les éliminer avant qu'ils ne t'éliminent.

Personne ne sait qui est qui — sauf toi (et encore, pas toujours).'''),
    const SizedBox(height: 16),
    _infoRow('🎭', 'Rôle secret assigné au début de la partie'),
    _infoRow('🗡', 'Blessures = points de vie perdus'),
    _infoRow('🏆', 'Chaque faction a sa condition de victoire'),
    _infoRow('👁', 'Se révéler = montrer son rôle à tous'),
  ]);

  // ── PAGE 1 : Factions ────────────────────────────────────────────────────
  Widget _page1() => Column(children: [
    _sectionTitle('3 FACTIONS SECRÈTES'),
    const SizedBox(height: 16),

    _factionCard(
      color: kHunter,
      icon: '🔵',
      name: 'HUNTERS',
      count: '2-3 joueurs',
      desc: 'Les chasseurs de l\'ombre. Leur mission : éliminer tous les Shadows.',
      win: 'Tous les Shadows sont éliminés',
      tip: 'Les Hunters ont intérêt à se révéler ensemble pour coordonner leurs attaques.',
    ),
    const SizedBox(height: 12),

    _factionCard(
      color: kShadow,
      icon: '🔴',
      name: 'SHADOWS',
      count: '2-3 joueurs',
      desc: 'Les créatures des ténèbres. Leur mission : éliminer tous les Hunters.',
      win: 'Tous les Hunters sont éliminés',
      tip: 'Les Shadows peuvent se cacher longtemps et frapper au bon moment.',
    ),
    const SizedBox(height: 12),

    _factionCard(
      color: kGold,
      icon: '🟡',
      name: 'NEUTRES',
      count: '1 joueur',
      desc: 'Jouent seuls, avec leurs propres règles de victoire.',
      win: 'Dépend du personnage (survivre, mourir en premier…)',
      tip: 'Les Neutres peuvent changer le destin de la partie à tout moment.',
    ),

    const SizedBox(height: 16),
    _warningBox('🔒 Les rôles sont SECRETS — personne ne sait qui est Hunter, Shadow ou Neutre au début !'),
  ]);

  // ── PAGE 2 : Le Plateau ──────────────────────────────────────────────────
  Widget _page2() => Column(children: [
    _sectionTitle('LE PLATEAU DE JEU'),
    const SizedBox(height: 12),
    _card('Le plateau est un hexagone composé de 6 zones. Chaque zone est associée à un terrain avec un effet spécial.'),
    const SizedBox(height: 16),

    // Représentation ASCII du plateau
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBg3, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBord2)),
      child: Column(children: [
        Text('Représentation du plateau', style: body(11, c: kTextSub)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _hexZone('🔮', '2-3'),
          const SizedBox(width: 8),
          _hexZone('🏪', '4-5'),
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _hexZone('🗼', '10'),
          const SizedBox(width: 24),
          _hexZone('⛪', '6'),
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _hexZone('🏹', '9'),
          const SizedBox(width: 8),
          _hexZone('🔨', '8'),
        ]),
      ]),
    ),

    const SizedBox(height: 16),
    _infoRow('📍', 'Les joueurs commencent sur des zones différentes'),
    _infoRow('🚶', 'On se déplace en lançant 2 dés (D4 + D6)'),
    _infoRow('🗺️', 'Les zones voisines sont accessibles (+1 déplacement)'),
  ]);

  // ── PAGE 3 : Structure d'un Tour ─────────────────────────────────────────
  Widget _page3() => Column(children: [
    _sectionTitle('STRUCTURE D\'UN TOUR'),
    const SizedBox(height: 12),
    _card('Chaque joueur réalise les actions dans cet ordre précis. Tu peux ignorer certaines étapes, mais jamais les sauter dans le désordre.'),
    const SizedBox(height: 20),

    _turnStep('1', '⚡ CAPACITÉ', kGold,
      'Active ton pouvoir spécial (si disponible) ou passe cette étape.',
      optional: true),
    _turnArrow(),
    _turnStep('2', '🚶 DÉPLACEMENT', kHunter,
      'Lance les dés D4+D6 et déplace-toi sur la zone correspondante.',
      optional: false),
    _turnArrow(),
    _turnStep('3', '🗺️ EFFET TERRAIN', Colors.teal,
      'La zone où tu arrives peut te forcer à piocher une carte.',
      optional: true),
    _turnArrow(),
    _turnStep('4', '🃏 CARTE', Colors.purple,
      'Si tu as pioché une carte, applique son effet maintenant.',
      optional: true),
    _turnArrow(),
    _turnStep('5', '⚔️ ATTAQUE', kRed,
      'Attaque un joueur adjacent (optionnel). Lance D4+D6 — le résultat = les blessures infligées.',
      optional: true),

    const SizedBox(height: 16),
    _warningBox('💡 Le tour se termine automatiquement après l\'attaque ou quand tu cliques "Terminer le tour".'),
  ]);

  // ── PAGE 4 : Le Déplacement ──────────────────────────────────────────────
  Widget _page4() => Column(children: [
    _sectionTitle('LE DÉPLACEMENT'),
    const SizedBox(height: 12),
    _card('Pour te déplacer, tu lances deux dés : un D4 (1-4) et un D6 (1-6). La somme détermine ta destination.'),
    const SizedBox(height: 16),

    _diceTable(),

    const SizedBox(height: 16),
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kGold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGold.withValues(alpha: 0.4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🌟', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text('LE 7 — CASE SPÉCIALE', style: cinzel(12, c: kGold, fw: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        Text('Si tu fais 7, tu peux choisir librement n\'importe quelle zone du plateau ! C\'est la seule valeur qui te donne cette liberté.',
          style: body(13)),
      ]),
    ),
    const SizedBox(height: 12),
    _infoRow('🎲', 'Certains personnages lancent 2 fois et choisissent (Albane)'),
    _infoRow('📍', 'Tu peux aussi "Rester sur place" sans te déplacer'),
  ]);

  // ── PAGE 5 : Les Terrains ────────────────────────────────────────────────
  Widget _page5() => Column(children: [
    _sectionTitle('LES TERRAINS'),
    const SizedBox(height: 12),
    _card('Chaque zone a un terrain avec un effet qui se déclenche quand tu t\'y arrêtes. Tu peux toujours choisir d\'ignorer l\'effet.'),
    const SizedBox(height: 16),

    _terrainRow('🔮', '2-3', 'Bosquet du Sorcier', 'Pioche une carte Vision pour tester l\'identité d\'un joueur'),
    _terrainRow('🏪', '4-5', 'Marché des Ombres', 'Choisis librement le type de carte à piocher (Lumière, Ténèbres ou Vision)'),
    _terrainRow('⛪', '6',   'Chapelle Sacrée', 'Pioche une carte Lumière (effets positifs, soins, protections)'),
    _terrainRow('🔨', '8',   'Forge Maudite', 'Pioche une carte Ténèbres (effets offensifs, équipements puissants)'),
    _terrainRow('🏹', '9',   'Clairière', 'Inflige 2 blessures au joueur de ton choix sans lancer les dés'),
    _terrainRow('🗼', '10',  'Tour du Voleur', 'Vole une carte équipement à n\'importe quel joueur'),
  ]);

  // ── PAGE 6 : Les Cartes ──────────────────────────────────────────────────
  Widget _page6() => Column(children: [
    _sectionTitle('LES 3 TYPES DE CARTES'),
    const SizedBox(height: 12),

    _cardTypeBlock(
      color: kHunter,
      icon: '🔵',
      name: 'Cartes Lumière',
      desc: 'Effets généralement positifs : soins, protections, buffs. '
            'Obtenues à la Chapelle Sacrée (zone 6) ou au Marché.',
      examples: ['💉 Trousse de Soin — soigne un joueur (D6)', '🛡 Plaid Divin — immunité aux attaques 1 tour', '⚔️ Lance de Lumière — +2 dégâts (équipement)'],
    ),
    const SizedBox(height: 12),

    _cardTypeBlock(
      color: kRed,
      icon: '🔴',
      name: 'Cartes Ténèbres',
      desc: 'Effets offensifs ou ambivalents : dégâts, vols, équipements puissants. '
            'Obtenues à la Forge Maudite (zone 8) ou au Marché.',
      examples: ['💣 Bombe — D4+D6 → dégâts sur toute une zone', '🍌 Banane Démoniaque — D6 : si ≤4 cible subit 3, sinon toi', '💥 Bazooka — tes attaques touchent tous les joueurs à portée (équipement)'],
    ),
    const SizedBox(height: 12),

    _cardTypeBlock(
      color: Colors.purple,
      icon: '🔮',
      name: 'Cartes Vision',
      desc: 'Permettent de deviner la faction d\'un joueur. '
            'Si tu as raison, il subit des blessures. Obtenues au Bosquet.',
      examples: ['❓ Vision Shadow ×2 — si Shadow, subit 2 blessures', '❓ Vision Hunter ×1 — si Hunter, subit 1 blessure'],
    ),

    const SizedBox(height: 16),
    _warningBox('⚙️ Certaines cartes sont des ÉQUIPEMENTS — elles restent actives toute la partie !'),
  ]);

  // ── PAGE 7 : L'Attaque ───────────────────────────────────────────────────
  Widget _page7() => Column(children: [
    _sectionTitle('L\'ATTAQUE'),
    const SizedBox(height: 12),
    _card('Après t\'être déplacé, tu peux attaquer un joueur adjacent (sur ta zone ou une zone voisine). L\'attaque est optionnelle — une seule par tour.'),
    const SizedBox(height: 20),

    // Déroulé de l'attaque
    Container(
      padding: const EdgeInsets.all(14),
      decoration: surfaceDecor(),
      child: Column(children: [
        Text('Déroulé d\'une attaque', style: cinzel(12, c: kGold)),
        const SizedBox(height: 12),
        _atkStep('1', 'Choisit une cible à portée', kTextSub),
        const SizedBox(height: 6),
        _atkStep('2', 'Lance D4 + D6', kGold),
        const SizedBox(height: 6),
        _atkStep('3', 'La somme = blessures infligées (après modificateurs)', kRed),
        const SizedBox(height: 6),
        _atkStep('4', 'Si blessures ≥ PV max → le joueur est éliminé', Colors.grey),
      ]),
    ),

    const SizedBox(height: 16),
    _infoRow('🛡', 'Certains équipements réduisent les dégâts reçus (Sainte Tunique)'),
    _infoRow('💥', 'Certains équipements augmentent les dégâts infligés (Lance de Lumière)'),
    _infoRow('🏴‍☠️', 'Le Pirate peut attaquer n\'importe quel joueur (portée infinie)'),
    _infoRow('💥', 'Le Bazooka touche TOUS les joueurs à portée en une attaque'),
    const SizedBox(height: 12),
    _warningBox('💀 Un joueur éliminé reste sur le plateau — ses équipements peuvent encore être volés !'),
  ]);

  // ── PAGE 8 : Les Pouvoirs ────────────────────────────────────────────────
  Widget _page8() => Column(children: [
    _sectionTitle('LES POUVOIRS'),
    const SizedBox(height: 12),
    _card('Chaque personnage possède une capacité unique activable en début de tour. Certains pouvoirs sont répétables chaque tour, d\'autres ne peuvent être utilisés qu\'une seule fois.'),
    const SizedBox(height: 20),

    // Exemple avec Mr Casino
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kGold, width: 2),
        boxShadow: [BoxShadow(color: kGold.withValues(alpha: 0.2), blurRadius: 12)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: kShadow.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: kShadow)),
            child: Text('🔴 SHADOW', style: cinzel(9, c: kRed))),
          const Spacer(),
          Text('🔄 RÉPÉTABLE', style: cinzel(9, c: kGold2)),
        ]),
        const SizedBox(height: 10),
        Text('🎰 MR CASINO', style: cinzel(18, c: kGold, fw: FontWeight.w900)),
        const Divider(color: kBord, height: 16),
        Text('Comment ça marche :', style: cinzel(10, c: kTextSub, ls: 1)),
        const SizedBox(height: 8),
        _atkStep('1', 'Choisis PAIR ou IMPAIR', kGold),
        const SizedBox(height: 4),
        _atkStep('2', 'Un dé D6 s\'anime et roule...', kGold),
        const SizedBox(height: 4),
        _atkStep('3', 'Gagné → tu infliges 3 blessures au joueur de ton choix', kGreen),
        const SizedBox(height: 4),
        _atkStep('4', 'Perdu → tu subis 2 blessures', kRed),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: kGold.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8)),
          child: Text(
            '💡 Stratégie : utiliser Casino quand tu es à bas PV est risqué. '
            'Mais c\'est la seule façon d\'infliger des dégâts hors de portée normale.',
            style: body(12, c: kTextSub)),
        ),
      ]),
    ),

    const SizedBox(height: 16),
    _card('Chaque personnage a son propre style :\n'
      '• Pouvoirs offensifs (Travert D6, Hong Yi inflige 9 et meurt)\n'
      '• Pouvoirs défensifs (Louna — immunité 1 tour, Cambou — soin total)\n'
      '• Pouvoirs passifs auto (Art\'Cade — flammes zone 6 chaque tour)\n'
      '• Pouvoirs uniques à impact fort (Léo — gagne en mourant en premier)'),
  ]);

  // ── PAGE 9 : La Victoire ─────────────────────────────────────────────────
  Widget _page9() => Column(children: [
    _sectionTitle('CONDITIONS DE VICTOIRE'),
    const SizedBox(height: 12),
    _card('La partie se termine dès qu\'une faction remplit sa condition. Tout le monde se révèle et les gagnants s\'affichent.'),
    const SizedBox(height: 20),

    _winCard(kHunter, '🔵 HUNTERS GAGNENT',
      'Quand tous les Shadows sont éliminés.',
      '→ Coordonnez-vous, révélez-vous et éliminez les Shadows méthodiquement.'),
    const SizedBox(height: 12),
    _winCard(kRed, '🔴 SHADOWS GAGNENT',
      'Quand tous les Hunters sont éliminés.',
      '→ Restez cachés longtemps, utilisez les cartes Ténèbres, frappez au bon moment.'),
    const SizedBox(height: 12),
    _winCard(kGold, '🟡 NEUTRES GAGNENT',
      'Condition propre à chaque personnage.',
      '→ Léo : mourir en premier. Cambou : survivre jusqu\'à la fin. Rat d\'Rouen : survivre.'),

    const SizedBox(height: 20),
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kGold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kGold.withValues(alpha: 0.4))),
      child: Column(children: [
        Text('🏆 TU ES PRÊT !', style: cinzel(18, c: kGold2, fw: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(
          'Tu connais maintenant toutes les mécaniques de base.\n'
          'Lance une partie Solo pour t\'entraîner, ou rejoins tes amis en Multijoueur !',
          style: body(13, c: kTextSub), textAlign: TextAlign.center),
      ]),
    ),
  ]);

  // ── Widgets helper ────────────────────────────────────────────────────────

  Widget _sectionTitle(String t) => Text(t,
    style: cinzel(16, c: kGold2, fw: FontWeight.w900, ls: 2),
    textAlign: TextAlign.center);

  Widget _card(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: surfaceDecor(),
    child: Text(text, style: body(13), textAlign: TextAlign.left));

  Widget _infoRow(String icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(icon, style: const TextStyle(fontSize: 16)),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: body(12, c: kTextSub))),
    ]));

  Widget _warningBox(String text) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: kGold.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: kGold.withValues(alpha: 0.3))),
    child: Text(text, style: body(12, c: kGold2), textAlign: TextAlign.center));

  Widget _factionCard({required Color color, required String icon,
      required String name, required String count, required String desc,
      required String win, required String tip}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.4))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('$icon $name', style: cinzel(14, c: color, fw: FontWeight.w900)),
        const Spacer(),
        Text(count, style: body(11, c: kTextSub)),
      ]),
      const SizedBox(height: 6),
      Text(desc, style: body(12)),
      const SizedBox(height: 8),
      Row(children: [
        const Text('🏆', style: TextStyle(fontSize: 13)),
        const SizedBox(width: 6),
        Expanded(child: Text(win, style: body(11, c: color))),
      ]),
      const SizedBox(height: 4),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('💡', style: TextStyle(fontSize: 13)),
        const SizedBox(width: 6),
        Expanded(child: Text(tip, style: body(11, c: kTextDim))),
      ]),
    ]));

  Widget _hexZone(String icon, String num) => Container(
    width: 80, height: 70,
    decoration: BoxDecoration(
      color: kBg2, borderRadius: BorderRadius.circular(8),
      border: Border.all(color: kBord2)),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(icon, style: const TextStyle(fontSize: 20)),
      Text(num, style: cinzel(10, c: kGold)),
    ]));

  Widget _diceTable() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: kBg3, borderRadius: BorderRadius.circular(10)),
    child: Column(children: [
      Text('Résultat → Zone', style: cinzel(11, c: kTextSub)),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final entry in {'2':'0', '3':'1', '4':'2', '5':'3',
            '6':'4', '7':'LIBRE 🌟', '8':'5', '9':'0',
            '10':'1', '11':'2', '12':'3'}.entries)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: entry.key == '7' ? kGold.withValues(alpha: 0.15) : kBg2,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: entry.key == '7' ? kGold : kBord2)),
            child: Text('${entry.key} → ${entry.value}',
              style: cinzel(10, c: entry.key == '7' ? kGold2 : kText))),
      ]),
    ]));

  Widget _terrainRow(String icon, String num, String name, String desc) =>
    Padding(padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(color: kBg3, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBord2)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            Text(num, style: cinzel(9, c: kGold)),
          ])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: cinzel(12, c: kText, fw: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(desc, style: body(11, c: kTextSub)),
        ])),
      ]));

  Widget _cardTypeBlock({required Color color, required String icon,
      required String name, required String desc, required List<String> examples}) =>
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$icon $name', style: cinzel(13, c: color, fw: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(desc, style: body(12)),
        const SizedBox(height: 8),
        ...examples.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text('• $e', style: body(11, c: kTextSub)))),
      ]));

  Widget _turnStep(String num, String label, Color color, String desc,
      {required bool optional}) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.35))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle),
        child: Center(child: Text(num, style: cinzel(12, c: color, fw: FontWeight.w900)))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(label, style: cinzel(12, c: color, fw: FontWeight.w700)),
          if (optional) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: kBg3, borderRadius: BorderRadius.circular(4)),
              child: Text('optionnel', style: body(9, c: kTextDim))),
          ],
        ]),
        const SizedBox(height: 3),
        Text(desc, style: body(11, c: kTextSub)),
      ])),
    ]));

  Widget _turnArrow() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 3, horizontal: 18),
    child: Icon(Icons.keyboard_arrow_down, color: kBord2, size: 20));

  Widget _atkStep(String num, String text, Color color) => Row(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(
      width: 20, height: 20, margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
      child: Center(child: Text(num, style: cinzel(9, c: color, fw: FontWeight.w900)))),
    const SizedBox(width: 8),
    Expanded(child: Text(text, style: body(12))),
  ]);

  Widget _winCard(Color color, String title, String cond, String tip) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.4))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: cinzel(13, c: color, fw: FontWeight.w900)),
      const SizedBox(height: 6),
      Text(cond, style: body(12, c: kText)),
      const SizedBox(height: 4),
      Text(tip, style: body(11, c: kTextDim)),
    ]));
}
