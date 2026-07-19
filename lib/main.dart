import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/game_provider.dart';
import 'services/display_settings.dart';
import 'services/persistence.dart';
import 'screens/home_screen.dart';
import 'screens/multi_screens.dart';
import 'screens/solo_screen.dart';
import 'models/models.dart';
import 'widgets/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prefs.init();
  DisplaySettings.instance.load();
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

// ─── Wrapper racine — affichage (mode, échelle, résolution) + router ────────
class _RootWrapper extends StatefulWidget {
  const _RootWrapper();
  @override State<_RootWrapper> createState() => _RootWrapperState();
}

class _RootWrapperState extends State<_RootWrapper> {
  @override
  void initState() {
    super.initState();
    DisplaySettings.instance.addListener(_onSettings);
  }

  @override
  void dispose() {
    DisplaySettings.instance.removeListener(_onSettings);
    super.dispose();
  }

  void _onSettings() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final ds = DisplaySettings.instance;
    final res = ds.resolution;
    final isFullscreen = res.w == 0;
    final mq = MediaQuery.of(context);

    // Taille effective vue par le jeu (simulée ou réelle)
    final simSize = isFullscreen
        ? mq.size
        : Size(res.w.toDouble(), res.h.toDouble());

    // MediaQuery override : le contenu voit la taille simulée ET l'échelle UI.
    final content = MediaQuery(
      data: mq.copyWith(
        size: simSize,
        textScaler: TextScaler.linear(ds.uiScale),
      ),
      child: _appContent(context),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Center(
          child: isFullscreen
              ? content
              : Container(
                  width: simSize.width,
                  height: simSize.height,
                  decoration: BoxDecoration(
                    border: Border.all(color: kBord2, width: 1),
                  ),
                  child: ClipRect(child: content),
                ),
        ),
        // Badge discret : mode + résolution actuels (coin haut droit)
        Positioned(
          top: 6, right: 6,
          child: _DisplayBadge(ds: ds),
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

// ─── Badge d'affichage — ouvre les réglages au tap ───────────────────────────
class _DisplayBadge extends StatelessWidget {
  final DisplaySettings ds;
  const _DisplayBadge({required this.ds});

  @override
  Widget build(BuildContext context) {
    final modeIcon = ds.deviceMode == 'phone'
        ? Icons.smartphone
        : ds.deviceMode == 'pc' ? Icons.desktop_windows : Icons.autorenew;
    return GestureDetector(
      onTap: () => showDisplaySettingsSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: kBg2.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: kBord2),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(modeIcon, size: 12, color: kGold),
          const SizedBox(width: 4),
          Text(ds.resolution.label.split(' ')[0], style: cinzel(9, c: kGold)),
        ]),
      ),
    );
  }
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
          if (gp.myUid == gp.hostId) ...[
            BHButton(label: '🔄 Rejouer avec les mêmes joueurs', gold: true,
              onTap: () => gp.restartGame()),
            const SizedBox(height: 8),
          ] else
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('L\'hôte peut relancer une partie avec les mêmes joueurs.',
                style: body(11, c: kTextDim), textAlign: TextAlign.center),
            ),
          BHButton(label: '↺ Menu principal',
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
