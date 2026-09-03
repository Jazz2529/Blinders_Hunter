// lib/screens/quest_screen.dart
// Quêtes — journalières (jouer chaque camp) et par personnage (paliers de
// victoires), accessible en tapant sur l'icône d'or de l'écran principal.

import 'package:flutter/material.dart';
import '../widgets/theme.dart';
import '../data/game_data.dart';
import '../models/models.dart';
import '../services/persistence.dart';
import '../services/i18n.dart';

const List<int> kCharQuestTiers = [1, 10, 50, 100];
int charQuestGold(int tier) => tier == 100 ? 100 : 30;

class QuestScreen extends StatefulWidget {
  const QuestScreen({super.key});
  @override State<QuestScreen> createState() => _QuestScreenState();
}

class _QuestScreenState extends State<QuestScreen> with SingleTickerProviderStateMixin {
  int gold = 0;
  late final AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    gold = Prefs.gold();
    // Pulsation douce et continue — attire l'œil sur les quêtes
    // journalières pas encore accomplies, sans être trop agressif visuellement.
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  void _claim(String questId, int reward) {
    Prefs.claimQuest(questId, reward);
    setState(() => gold = Prefs.gold());
  }

  @override
  Widget build(BuildContext ctx) => LanguageAware(builder: (ctx) {
    final en = AppLanguage.instance.isEnglish;

    // ── Quêtes journalières ──────────────────────────────────────────────
    final dailyFactions = [Faction.hunter, Faction.shadow, Faction.neutral];

    // ── Quêtes personnage : pour chacun des 60, ne retenir QUE le PROCHAIN
    // palier non réclamé (ou rien si les 4 sont déjà réclamés) — afficher
    // les 240 combinaisons d'un coup serait illisible. Les personnages avec
    // une quête RÉCLAMABLE MAINTENANT remontent en tête de liste.
    final charRows = <_CharQuestRow>[];
    for (final c in kAllCharacters) {
      final wins = Prefs.gamesWonWith(c.name);
      for (final tier in kCharQuestTiers) {
        final qid = Prefs.charQuestId(c.name, tier);
        if (Prefs.isQuestClaimed(qid)) continue; // déjà pris, palier suivant
        charRows.add(_CharQuestRow(
          character: c, tier: tier, wins: wins, questId: qid,
          claimable: wins >= tier,
        ));
        break; // un seul palier (le prochain) affiché par personnage
      }
    }
    charRows.sort((a, b) {
      if (a.claimable != b.claimable) return a.claimable ? -1 : 1;
      return b.wins.compareTo(a.wins); // les plus proches du palier d'abord
    });

    return Scaffold(
      backgroundColor: kBg0,
      appBar: AppBar(
        backgroundColor: kBg2, elevation: 0,
        title: Text(en ? '📜 Quests' : '📜 Quêtes', style: cinzel(16, c: kGold2)),
        actions: [
          Padding(padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text('$gold 🪙', style: cinzel(14, c: kGold, fw: FontWeight.w900)))),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(en ? 'DAILY' : 'JOURNALIÈRES', style: cinzel(11, c: kTextSub, ls: 2)),
        const SizedBox(height: 8),
        ...dailyFactions.map((f) => _dailyCard(f, en)),
        const SizedBox(height: 20),
        Text(en ? 'CHARACTERS' : 'PERSONNAGES', style: cinzel(11, c: kTextSub, ls: 2)),
        const SizedBox(height: 4),
        Text(en ? 'One reward per character shown at a time — claim it to reveal the next tier.'
                : 'Une récompense par personnage affichée à la fois — réclame-la pour révéler le palier suivant.',
          style: body(10, c: kTextDim)),
        const SizedBox(height: 8),
        ...charRows.map((r) => _charCard(r, en)),
        if (charRows.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text(en ? '🏆 All character quests completed!' : '🏆 Toutes les quêtes personnage sont terminées !',
              style: body(12, c: kTextSub), textAlign: TextAlign.center))),
      ]),
    );
  });

  String _factionLabel(Faction f, bool en) => switch (f) {
    Faction.hunter  => en ? '🔵 Play a game as Hunter'  : '🔵 Jouer une partie en tant que Hunter',
    Faction.shadow  => en ? '🔴 Play a game as Shadow'  : '🔴 Jouer une partie en tant que Shadow',
    Faction.neutral => en ? '🟡 Play a game as Neutral' : '🟡 Jouer une partie en tant que Neutre',
  };

  Widget _dailyCard(Faction f, bool en) {
    final factionKey = f.name;
    final done = Prefs.hasPlayedFactionToday(factionKey);
    final qid = Prefs.dailyQuestId(factionKey);
    final claimed = Prefs.isQuestClaimed(qid);
    const reward = 30;
    return _questContainer(
      title: _factionLabel(f, en),
      reward: reward,
      claimed: claimed,
      claimable: done && !claimed,
      progressLabel: done ? null : (en ? 'Not played today' : 'Pas encore joué aujourd\'hui'),
      onClaim: () => _claim(qid, reward),
      shine: !done,
    );
  }

  Widget _charCard(_CharQuestRow r, bool en) {
    final reward = charQuestGold(r.tier);
    final label = en
        ? '${r.tier} win${r.tier > 1 ? "s" : ""} with ${tr(r.character.name)}'
        : '${r.tier} victoire${r.tier > 1 ? "s" : ""} avec ${tr(r.character.name)}';
    return _questContainer(
      title: label,
      reward: reward,
      claimed: false,
      claimable: r.claimable,
      progressLabel: r.claimable ? null : '${r.wins} / ${r.tier}',
      onClaim: () => _claim(r.questId, reward),
    );
  }

  Widget _questContainer({
    required String title, required int reward, required bool claimed,
    required bool claimable, String? progressLabel, required VoidCallback onClaim,
    bool shine = false,
  }) {
    final container = AnimatedBuilder(
      animation: _glowCtrl,
      builder: (_, child) {
        // Pulsation UNIQUEMENT si shine est demandé — les autres quêtes
        // gardent leur apparence statique habituelle (claimable ou non).
        final glow = shine ? (0.35 + _glowCtrl.value * 0.55) : 0.0;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: claimable ? kGold.withValues(alpha: 0.08) : kBg2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: shine ? kGold.withValues(alpha: glow) : (claimable ? kGold.withValues(alpha: 0.6) : kBord2),
              width: shine ? 1.8 : 1,
            ),
            boxShadow: shine ? [
              BoxShadow(color: kGold.withValues(alpha: glow * 0.5), blurRadius: 10, spreadRadius: 1),
            ] : null,
          ),
          child: child,
        );
      },
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: body(12, c: kText)),
          if (progressLabel != null) ...[
            const SizedBox(height: 3),
            Text(progressLabel, style: body(10, c: kTextDim)),
          ],
        ])),
        const SizedBox(width: 10),
        if (claimable)
          GestureDetector(
            onTap: onClaim,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: kGold, borderRadius: BorderRadius.circular(20)),
              child: Text('+$reward 🪙', style: cinzel(11, c: kBg0, fw: FontWeight.w900)),
            ),
          )
        else
          Text('+$reward 🪙', style: cinzel(11, c: kTextDim)),
      ]),
    );
    return container;
  }
}

class _CharQuestRow {
  final CharacterCard character;
  final int tier;
  final int wins;
  final String questId;
  final bool claimable;
  _CharQuestRow({required this.character, required this.tier, required this.wins,
    required this.questId, required this.claimable});
}
