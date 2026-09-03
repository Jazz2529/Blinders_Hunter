import 'package:flutter/material.dart';
import '../widgets/theme.dart';
import '../services/persistence.dart';
import '../services/i18n.dart';

/// ─── Statistiques & historique des parties ──────────────────────────────────
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext ctx) => LanguageAware(builder: (ctx) {
    final en = AppLanguage.instance.isEnglish;
    final h = Prefs.history();
    final total = h.length;
    final wins = h.where((g) => g['win'] == true).length;
    final winrate = total == 0 ? 0 : (wins * 100 / total).round();
    final solo = h.where((g) => g['mode'] == 'solo').toList();
    final multi = h.where((g) => g['mode'] == 'multi').toList();

    // Stats par personnage : {char: [parties, victoires]}
    final byChar = <String, List<int>>{};
    for (final g in h) {
      final c = g['character'] as String? ?? '?';
      byChar.putIfAbsent(c, () => [0, 0]);
      byChar[c]![0]++;
      if (g['win'] == true) byChar[c]![1]++;
    }
    final charEntries = byChar.entries.toList()
      ..sort((a, b) => b.value[0].compareTo(a.value[0]));

    return Scaffold(
      backgroundColor: kBg0,
      appBar: AppBar(
        backgroundColor: kBg2, elevation: 0,
        title: Text(en ? '📊 Stats' : '📊 Statistiques', style: cinzel(16, c: kGold2)),
      ),
      body: total == 0
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('🎲', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(en ? 'No game recorded' : 'Aucune partie enregistrée', style: cinzel(14, c: kTextSub)),
              const SizedBox(height: 6),
              Text(en ? 'Play a game to see your stats here!' :
                  'Joue une partie pour voir tes stats ici !',
                  style: body(12, c: kTextDim)),
            ]))
          : ListView(padding: const EdgeInsets.all(16), children: [
              // ── Résumé global ──
              Row(children: [
                _statCard(en ? 'Games' : 'Parties', '$total', kGold),
                const SizedBox(width: 8),
                _statCard(en ? 'Wins' : 'Victoires', '$wins', kGreen),
                const SizedBox(width: 8),
                _statCard('Winrate', '$winrate%',
                    winrate >= 50 ? kGreen : kRed),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _statCard(en ? 'Solo' : 'Solo', '${solo.length}', kGold2),
                const SizedBox(width: 8),
                _statCard(en ? 'Multi' : 'Multi', '${multi.length}', kGold2),
              ]),
              const SizedBox(height: 8),
              Row(children: [_statCard(en ? 'Play time' : 'Temps de jeu', _formatPlaytime(Prefs.totalPlaytimeSeconds(), en), kGold)]),
              const SizedBox(height: 18),

              // ── Par personnage ──
              Text(en ? 'BY CHARACTER' : 'PAR PERSONNAGE', style: cinzel(11, c: kTextSub, ls: 2)),
              const SizedBox(height: 8),
              ...charEntries.take(12).map((e) {
                final games = e.value[0];
                final w = e.value[1];
                final wr = (w * 100 / games).round();
                return Container(
                  margin: const EdgeInsets.only(bottom: 5),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: kBg2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kBord2)),
                  child: Row(children: [
                    Expanded(child: Text(tr(e.key), style: body(12, c: kText))),
                    Text(en ? '$games g.' : '$games p.', style: body(11, c: kTextDim)),
                    const SizedBox(width: 10),
                    SizedBox(width: 44, child: Text(en ? '$w win' : '$w vic.',
                        style: body(11, c: kGreen),
                        textAlign: TextAlign.right)),
                    const SizedBox(width: 10),
                    SizedBox(width: 40, child: Text('$wr%',
                        style: body(11,
                            c: wr >= 50 ? kGreen : kRed,
                            fw: FontWeight.w700),
                        textAlign: TextAlign.right)),
                  ]),
                );
              }),
              const SizedBox(height: 18),

              // ── Historique récent ──
              Text(en ? 'RECENT GAMES' : 'DERNIÈRES PARTIES', style: cinzel(11, c: kTextSub, ls: 2)),
              const SizedBox(height: 8),
              ...h.take(25).map((g) {
                final win = g['win'] == true;
                final date = DateTime.fromMillisecondsSinceEpoch(
                    g['date'] as int? ?? 0);
                final dateStr =
                    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} '
                    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                return Container(
                  margin: const EdgeInsets.only(bottom: 5),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: kBg2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: win
                              ? kGreen.withValues(alpha: 0.35)
                              : kBord2)),
                  child: Row(children: [
                    Text(win ? '🏆' : '💀',
                        style: const TextStyle(fontSize: 15)),
                    const SizedBox(width: 8),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr(g['character'] as String? ?? '?'),
                              style: body(12, c: kText, fw: FontWeight.w600)),
                          Text(
                              '${g['mode'] == 'solo' ? 'Solo' : 'Multi'} · ${tr(factionLabel(g['faction'] as String? ?? ''))}',
                              style: body(10, c: kTextDim)),
                        ])),
                    Text(dateStr, style: body(10, c: kTextDim)),
                  ]),
                );
              }),
              const SizedBox(height: 24),
            ]),
    );
  });

  String _formatPlaytime(int totalSeconds, bool en) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) return en ? '${hours}h ${minutes}m' : '${hours}h ${minutes}min';
    return en ? '${minutes}m' : '${minutes}min';
  }

  Widget _statCard(String label, String value, Color c) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          color: kBg2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.withValues(alpha: 0.4))),
      child: Column(children: [
        Text(value, style: cinzel(18, c: c, fw: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: body(10, c: kTextDim)),
      ]),
    ),
  );
}
