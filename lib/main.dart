import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/game_provider.dart';
import 'screens/home_screen.dart';
import 'screens/multi_screens.dart';
import 'screens/solo_screen.dart';
import 'models/models.dart';
import 'widgets/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(
    ChangeNotifierProvider(
      create: (_) => GameProvider(firebaseEnabled: true)..init(),
      child: const BlindersHunterApp(),
    ),
  );
}

class BlindersHunterApp extends StatelessWidget {
  const BlindersHunterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blinders Hunter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: kBg0,
        colorScheme: const ColorScheme.dark(primary: kGold, surface: kBg2),
        fontFamily: 'CrimsonText',
        appBarTheme: const AppBarTheme(
          backgroundColor: kBg2, foregroundColor: kText, elevation: 0),
      ),
      home: const _RootWrapper(),
    );
  }
}

// ─── Wrapper racine — résolution + router ────────────────────────────────────
class _RootWrapper extends StatefulWidget {
  const _RootWrapper();
  @override State<_RootWrapper> createState() => _RootWrapperState();
}

class _RootWrapperState extends State<_RootWrapper> {
  // Résolutions disponibles (largeur × hauteur)
  static const _resolutions = [
    _Res('Mobile  (390×844)',  390, 844),
    _Res('Tablette (768×1024)', 768, 1024),
    _Res('PC petit (900×600)',  900, 600),
    _Res('PC moyen (1280×800)', 1280, 800),
    _Res('PC grand (1440×900)', 1440, 900),
    _Res('Plein écran',         0,   0),   // 0,0 = taille réelle
  ];

  int _resIdx = 5; // Plein écran par défaut

  @override
  Widget build(BuildContext context) {
    final res = _resolutions[_resIdx];
    final isFullscreen = res.w == 0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // ── Contenu centré avec taille simulée ──
        Center(
          child: isFullscreen
            ? _appContent(context)
            : SizedBox(
                width: res.w.toDouble(),
                height: res.h.toDouble(),
                child: ClipRect(child: _appContent(context)),
              ),
        ),

        // ── Sélecteur résolution (discret, coin haut droit) ──
        Positioned(
          top: 8, right: 8,
          child: _ResSelector(
            resolutions: _resolutions,
            currentIdx: _resIdx,
            onChanged: (i) => setState(() => _resIdx = i),
          ),
        ),
      ]),
    );
  }

  Widget _appContent(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (ctx, gp, _) {
        if (gp.gameResult != null) return _GameOverScreen(gp: gp);
        if (gp.roomStatus == 'playing') {
          if (gp.phase == GamePhase.roleReveal) return RoleRevealScreen();
          return GameScreen();
        }
        if (gp.roomId != null) return const LobbyScreen();
        return const HomeScreen();
      },
    );
  }
}

// ─── Sélecteur de résolution ─────────────────────────────────────────────────
class _ResSelector extends StatefulWidget {
  final List<_Res> resolutions;
  final int currentIdx;
  final void Function(int) onChanged;
  const _ResSelector({required this.resolutions, required this.currentIdx,
    required this.onChanged});
  @override State<_ResSelector> createState() => _ResSelectorState();
}

class _ResSelectorState extends State<_ResSelector> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      // Bouton toggle
      GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: kBg2.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: kBord2),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.aspect_ratio, size: 12, color: kGold),
            const SizedBox(width: 4),
            Text(
              widget.resolutions[widget.currentIdx].label.split(' ')[0],
              style: cinzel(9, c: kGold),
            ),
            const SizedBox(width: 2),
            Icon(_expanded ? Icons.expand_less : Icons.expand_more,
              size: 12, color: kTextSub),
          ]),
        ),
      ),
      // Dropdown
      if (_expanded)
        Container(
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: kBg2.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBord2),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: widget.resolutions.asMap().entries.map((e) {
              final selected = e.key == widget.currentIdx;
              return GestureDetector(
                onTap: () {
                  widget.onChanged(e.key);
                  setState(() => _expanded = false);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected ? kGold.withValues(alpha: 0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(e.value.label,
                    style: cinzel(9, c: selected ? kGold2 : kTextSub),
                    textAlign: TextAlign.right),
                ),
              );
            }).toList(),
          ),
        ),
    ]);
  }
}

class _Res {
  final String label;
  final int w, h;
  const _Res(this.label, this.w, this.h);
}

// ─── Game Over Screen ─────────────────────────────────────────────────────────
class _GameOverScreen extends StatelessWidget {
  final GameProvider gp;
  const _GameOverScreen({required this.gp});

  @override
  Widget build(BuildContext context) {
    final result = gp.gameResult!;
    final winnerIds = List<String>.from(result['winnerIds'] as List? ?? []);
    final winners = gp.players.values.where((p) => winnerIds.contains(p.uid)).toList();
    final iWon = winnerIds.contains(gp.myUid);
    return Scaffold(
      backgroundColor: kBg0,
      body: SafeArea(child: Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(iWon ? '🏆' : '💀', style: const TextStyle(fontSize: 72)),
          const SizedBox(height: 12),
          Text(iWon ? 'VICTOIRE !' : 'DÉFAITE',
            style: cinzel(32, c: iWon ? kGold2 : kRed, fw: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(result['reason'] as String? ?? '',
            textAlign: TextAlign.center, style: body(15, c: kTextSub)),
          const SizedBox(height: 24),
          ...winners.map((w) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(w.token, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text(w.name, style: body(16, fw: FontWeight.w600)),
            ]),
          )),
          const SizedBox(height: 32),
          BHButton(label: '↺ Menu principal', gold: true,
            onTap: () async {
              await gp.leaveRoomAndReset();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
              }
            }),
        ]),
      ))),
    );
  }
}
