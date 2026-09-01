import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/game_provider.dart';
import 'services/display_settings.dart';
import 'services/persistence.dart';
import 'services/i18n.dart';
import 'services/audio_service.dart';
import 'screens/home_screen.dart';
import 'screens/multi_screens.dart';
import 'screens/solo_screen.dart';
import 'models/models.dart';
import 'widgets/theme.dart';
import 'widgets/token_widget.dart';
import 'data/characters_data.dart';

/// Autorise le glisser-défiler avec la souris (et le trackpad/stylet) en plus
/// du tactile. Sans ça, sur PC, les listes horizontales (jetons, résolutions
/// simulées, galeries...) ne répondent PAS au glisser à la souris — seul le
/// tactile est autorisé par défaut par Flutter.
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prefs.init();
  DisplaySettings.instance.load();
  AppLanguage.instance.load();
  // IMPORTANT : sans cet appel, init() (qui configure le mixage audio sur
  // mobile, et charge les préférences de volume partout) n'était jamais
  // exécutée.
  await audio.init();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  // Mode plein écran immersif : masque la barre de statut ET la barre de
  // navigation Android (boutons retour/accueil/récents) — un balayage
  // depuis le bord de l'écran les fait réapparaître temporairement avant
  // de se cacher à nouveau, comportement standard pour un jeu.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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
      scrollBehavior: AppScrollBehavior(),
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
    // Changer de langue doit se répercuter immédiatement dans TOUTE
    // l'application (écran de jeu en cours, catalogue, etc.), pas
    // seulement dans la boîte de dialogue des réglages elle-même — même
    // mécanisme que pour les réglages d'affichage.
    AppLanguage.instance.addListener(_onSettings);
  }

  @override
  void dispose() {
    DisplaySettings.instance.removeListener(_onSettings);
    AppLanguage.instance.removeListener(_onSettings);
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
          // playGameMusic()/playLobbyMusic() sont no-op si déjà en cours
          // (guard interne sur _currentMusic) — sûr à appeler à chaque
          // rebuild du Consumer sans faire redémarrer la piste en boucle.
          audio.playGameMusic();
          if (gp.phase == GamePhase.roleReveal) return RoleRevealScreen();
          return GameScreen();
        }
        if (gp.roomId != null) {
          audio.playLobbyMusic();
          return const LobbyScreen();
        }
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
class _GameOverScreen extends StatefulWidget {
  final GameProvider gp;
  const _GameOverScreen({required this.gp});
  @override State<_GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<_GameOverScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgAc;
  late AnimationController _contentAc;

  @override
  void initState() {
    super.initState();
    final result = widget.gp.gameResult!;
    final winnerIds = List<String>.from(result['winnerIds'] as List? ?? []);
    final iWon = winnerIds.contains(widget.gp.myUid);
    if (iWon) audio.playWin(); else audio.playLose();
    audio.fadeOutMusic();

    // Enregistrer la partie dans l'historique local (déjà fait ailleurs
    // via _recordMultiResult, cette partie ne fait que gérer l'animation).
    _bgAc = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _contentAc = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _bgAc.forward().then((_) => _contentAc.forward());
  }

  @override void dispose() { _bgAc.dispose(); _contentAc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final gp = widget.gp;
    final result = gp.gameResult!;
    final winnerIds = List<String>.from(result['winnerIds'] as List? ?? []);
    final allPlayers = gp.players.values.toList();
    final winners = allPlayers.where((p) => winnerIds.contains(p.uid)).toList();
    final losers = allPlayers.where((p) => !winnerIds.contains(p.uid)).toList();

    String winFaction = '';
    if (winners.isNotEmpty) {
      winFaction = winners.first.character?.faction.name ?? '';
    }
    final fc = factionColor(winFaction.isEmpty ? 'hunter' : winFaction);
    final fbg = factionBg(winFaction.isEmpty ? 'hunter' : winFaction);

    final factionLabel = switch (winFaction) {
      'hunter'  => ui('gameover_hunters'),
      'shadow'  => ui('gameover_shadows'),
      'neutral' => ui('gameover_neutrals'),
      _         => ui('gameover_players'),
    };
    final factionEmoji = switch (winFaction) {
      'hunter' => '🔵', 'shadow' => '🔴', 'neutral' => '🟡', _ => '⚔️',
    };

    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _bgAc, curve: Curves.easeIn),
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter, radius: 1.5,
              colors: [fc.withValues(alpha: 0.25), Colors.black],
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _contentAc, curve: Curves.easeIn),
              child: LayoutBuilder(builder: (bctx, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(children: [
                        const SizedBox(height: 24),

                // ── Titre victoire ───────────────────────────────
                Column(children: [
                  Text(factionEmoji, style: const TextStyle(fontSize: 64)),
                  const SizedBox(height: 8),
                  Text(factionLabel, style: cinzel(32, c: fc, fw: FontWeight.w900).copyWith(
                    shadows: [Shadow(color: fc.withValues(alpha: 0.8), blurRadius: 24)])),
                  const SizedBox(height: 4),
                  Text(ui('gameover_won'), style: cinzel(22, c: kGold2, fw: FontWeight.w700, ls: 4)),
                  const SizedBox(height: 8),
                  Text(tr(result['reason'] as String? ?? ''), style: body(13, c: kTextSub),
                    textAlign: TextAlign.center,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                ]),

                const SizedBox(height: 24),

                // ── Cartes des gagnants (centrées) ─────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10, runSpacing: 10,
                    children: winners.map((w) {
                      final c2 = w.character;
                      final imgPath = c2 != null ? effectiveCharacterImagePath(c2.id) : null;
                      final wFc = factionColor(c2?.faction.name ?? '');
                      final isDead = !w.alive;
                      return Container(
                        width: 120,
                        decoration: BoxDecoration(
                          color: kBg2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDead ? kTextDim : wFc, width: 2.5),
                          boxShadow: isDead ? null
                            : [BoxShadow(color: wFc.withValues(alpha: 0.4), blurRadius: 10)],
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                            child: SizedBox(
                              height: 130, width: double.infinity,
                              child: Stack(fit: StackFit.expand, children: [
                                ColorFiltered(
                                  colorFilter: isDead
                                    ? const ColorFilter.matrix(<double>[
                                        0.2126, 0.7152, 0.0722, 0, 0,
                                        0.2126, 0.7152, 0.0722, 0, 0,
                                        0.2126, 0.7152, 0.0722, 0, 0,
                                        0, 0, 0, 1, 0,
                                      ])
                                    : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                                  child: imgPath != null
                                    ? Image.asset(imgPath, fit: BoxFit.cover,
                                        cacheHeight: 520,
                                        errorBuilder: (_, __, ___) => Container(color: fbg,
                                          child: Center(child: Text(c2?.icon ?? '?',
                                            style: const TextStyle(fontSize: 40)))))
                                    : Container(color: fbg, child: Center(
                                        child: Text(c2?.icon ?? '?', style: const TextStyle(fontSize: 40)))),
                                ),
                                if (isDead) ...[
                                  Container(color: Colors.black.withValues(alpha: 0.45)),
                                  const Center(child: Text('🪦', style: TextStyle(fontSize: 36))),
                                ],
                              ]),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(7),
                            child: Column(children: [
                              Text(c2 != null ? tr(c2.name) : w.name,
                                style: cinzel(11, c: isDead ? kTextDim : wFc, fw: FontWeight.w700),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 3),
                              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                TokenWidget(tokenId: w.token, size: 16),
                                const SizedBox(width: 4),
                                Flexible(child: Text(w.name,
                                  style: body(9, c: kTextSub),
                                  overflow: TextOverflow.ellipsis)),
                              ]),
                            ]),
                          ),
                        ]),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Perdants ─────────────────────────────────────
                if (losers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(children: [
                      Text(ui('gameover_eliminated'), style: cinzel(10, c: kTextDim, ls: 3)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8, runSpacing: 6, alignment: WrapAlignment.center,
                        children: losers.map((p) => Row(mainAxisSize: MainAxisSize.min, children: [
                          TokenWidget(tokenId: p.token, size: 22, isDead: true),
                          const SizedBox(width: 4),
                          Text(p.name, style: body(11, c: kTextDim)),
                        ])).toList(),
                      ),
                    ]),
                  ),

                const SizedBox(height: 24),

                // ── Boutons ───────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  child: Column(children: [
                    if (gp.myUid == gp.hostId) ...[
                      GestureDetector(
                        onTap: () { audio.stopWinLoseJingle(); gp.restartGame(); },
                        child: Container(
                          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: fc.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: fc, width: 2)),
                          child: Text(ui('gameover_replay'), textAlign: TextAlign.center,
                            style: cinzel(16, c: fc, fw: FontWeight.w700))),
                      ),
                      const SizedBox(height: 8),
                    ] else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(ui('gameover_replay_desc'),
                          style: body(11, c: kTextDim), textAlign: TextAlign.center),
                      ),
                    GestureDetector(
                      onTap: () async {
                        audio.stopWinLoseJingle();
                        await gp.leaveRoomAndReset();
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
                        }
                      },
                      child: Container(
                        width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: kBord2)),
                        child: Text(ui('gameover_main_menu'), textAlign: TextAlign.center,
                          style: cinzel(14, c: kTextSub))),
                    ),
                  ]),
                ),
                      ]),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
