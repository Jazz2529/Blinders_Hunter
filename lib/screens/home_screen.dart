// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/game_provider.dart';
import '../services/firebase_service.dart';
import '../services/display_settings.dart';
import '../services/persistence.dart';
import '../services/i18n.dart';
import 'rules_screen.dart';
import 'stats_screen.dart';
import 'gallery_screen.dart';
import 'shop_screen.dart';
import '../services/audio_service.dart';
import '../widgets/theme.dart';
import '../widgets/token_widget.dart';
import '../data/tokens_data.dart';
import 'solo_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  String _token = 'vlad';
  late AnimationController _ac;
  late Animation<double> _fade, _y;

  ({String roomId, String uid})? _resumable;

  @override
  void initState() {
    super.initState();
    // Pseudo et jeton mémorisés d'une connexion à l'autre.
    final savedName = Prefs.playerName();
    if (savedName != null && savedName.isNotEmpty) _nameCtrl.text = savedName;
    final savedToken = Prefs.playerToken();
    if (savedToken != null && savedToken.isNotEmpty) _token = savedToken;
    _checkResumable();
    _ac = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1000));
    _fade = CurvedAnimation(parent: _ac,
        curve: const Interval(0, 0.7, curve: Curves.easeOut));
    _y = Tween(begin: 28.0, end: 0.0).animate(
        CurvedAnimation(parent: _ac, curve: Curves.easeOut));
    _ac.forward();
    audio.playLobbyMusic();
  }

  @override
  void dispose() { _ac.dispose(); _nameCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      backgroundColor: kBg0,
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        child: Column(children: [
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            GestureDetector(
              onTap: () => Navigator.push(ctx,
                MaterialPageRoute(builder: (_) => const ShopScreen())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: kBg2, borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kGold.withValues(alpha: 0.5))),
                child: Text('${Prefs.gold()} 🪙', style: cinzel(13, c: kGold, fw: FontWeight.w900)),
              ),
            ),
            GestureDetector(
              onTap: () => _showSettings(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kBg2, shape: BoxShape.circle,
                  border: Border.all(color: kBord2)),
                child: const Icon(Icons.settings, color: kGold, size: 20),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // Logo animé
          AnimatedBuilder(animation: _ac, builder: (_, __) => FadeTransition(
            opacity: _fade,
            child: Transform.translate(offset: Offset(0, _y.value),
              child: Column(children: [
                Text('BLINDERS', style: cinzel(34, c: kGold, fw: FontWeight.w900, ls: 6)
                    .copyWith(shadows: const [Shadow(color: Color(0xFFD4A017), blurRadius: 18)])),
                Text('HUNTER', style: cinzel(26, c: kGold2, fw: FontWeight.w900, ls: 10)),
                const SizedBox(height: 6),
                Text(ui('music_credit'),
                  style: body(10, c: kTextSub).copyWith(letterSpacing: 2)),
                Text(ui('thanks_heart'),
                  style: body(11, c: kTextSub).copyWith(letterSpacing: 2)),
                Text(ui('order_sporty_blinders'),
                  style: body(11, c: kTextSub).copyWith(letterSpacing: 2)),
              ]),
            ),
          )),

          const SizedBox(height: 32),

          // Config joueur
          Container(padding: const EdgeInsets.all(16), decoration: surfaceDecor(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionLabel('TON NOM'),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                style: body(14),
                onChanged: (v) => Prefs.setPlayerName(v.trim()),
                decoration: InputDecoration(
                  hintText: 'Joueur', hintStyle: body(13, c: kTextDim),
                  filled: true, fillColor: kBg3,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kBord2)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kBord2)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kGold)),
                ),
              ),
              const SizedBox(height: 16),
              SectionLabel(ui('lobby_your_token')),
              const SizedBox(height: 10),
              SizedBox(height: 56, child: Stack(children: [
                ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  itemCount: availableTokens().length,
                  itemBuilder: (_, i) {
                    final t = availableTokens()[i];
                    final sel = t.id == _token;
                    return GestureDetector(
                      onTap: () => setState(() { _token = t.id; Prefs.setPlayerToken(t.id); }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 8),
                        padding: EdgeInsets.all(sel ? 2.5 : 0),
                        decoration: BoxDecoration(shape: BoxShape.circle,
                          border: sel ? Border.all(color: kGold, width: 2.5) : null,
                          boxShadow: sel ? [BoxShadow(color: kGold.withValues(alpha: 0.4), blurRadius: 8)] : null),
                        child: TokenWidget(tokenId: t.id, size: 44),
                      ),
                    );
                  },
                ),
                // Indication visuelle qu'on peut faire défiler horizontalement
                Positioned(right: 0, top: 0, bottom: 0,
                  child: IgnorePointer(child: Container(
                    width: 28,
                    decoration: BoxDecoration(gradient: LinearGradient(
                      begin: Alignment.centerLeft, end: Alignment.centerRight,
                      colors: [kBg1.withValues(alpha: 0.0), kBg1.withValues(alpha: 0.85)])),
                  )),
                ),
                Positioned(right: 2, top: 0, bottom: 0,
                  child: IgnorePointer(child: Center(
                    child: Icon(Icons.chevron_right, color: kGold.withValues(alpha: 0.7), size: 20)))),
              ])),
              const SizedBox(height: 6),
              Center(child: Text(
                availableTokens().firstWhere((t) => t.id == _token, orElse: () => kAllTokens.first).name,
                style: body(11, c: kTextSub))),
            ])),

          const SizedBox(height: 16),
          if (_resumable != null) ...[
            PulseGlow(
              active: true,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                child: BHButton(
                  label: ui('resume_game').replaceAll('{room}', _resumable!.roomId),
                  gold: true, onTap: _resume),
              ),
            ),
          ],
          BHButton(label: ui('menu_solo'), onTap: _goSolo),
          const SizedBox(height: 10),
          BHButton(label: ui('menu_multi'), gold: true, onTap: _goMulti),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: BHButton(label: ui('menu_stats'), outlined: true,
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const StatsScreen())))),
            const SizedBox(width: 10),
            Expanded(child: BHButton(label: ui('menu_rules'), outlined: true,
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RulesScreen())))),
          ]),
          const SizedBox(height: 10),
          BHButton(label: ui('menu_catalog'), outlined: true,
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CardCatalogScreen()))),
          const SizedBox(height: 10),
          BHButton(label: ui('menu_shop'), outlined: true,
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ShopScreen()))),
          const SizedBox(height: 10),
          BHButton(label: ui('menu_quit'), outlined: true,
            onTap: () => _confirmQuit(context)),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _newIdentity,
            child: Text('🔄 Nouvelle identité (test multi-fenêtres)',
              style: body(11, c: kTextDim)),
          ),
        ]),
      )),
    );
  }

  Future<void> _checkResumable() async {
    final saved = Prefs.savedRoom();
    if (saved == null) return;
    final gp = context.read<GameProvider>();
    final status = await gp.fb.fetchRoomStatus(saved.roomId);
    if (!mounted) return;
    if (status == null || status == 'finished') {
      Prefs.clearRoom();
      return;
    }
    setState(() => _resumable = saved);
  }

  Future<void> _resume() async {
    final r = _resumable;
    if (r == null) return;
    final gp = context.read<GameProvider>();
    final ok = await gp.resumeRoom(r.roomId, r.uid);
    if (!ok && mounted) {
      setState(() => _resumable = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ui('game_not_exist'))));
    }
    // Si ok, le routeur racine bascule automatiquement (roomStatus).
  }

  void _showSettings(BuildContext ctx) {
    showDialog(context: ctx, builder: (_) => const SettingsDialog());
  }

  void _goSolo() {
    final name = _nameCtrl.text.trim().isEmpty ? 'Joueur' : _nameCtrl.text.trim();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SoloSetupScreen(playerName: name, playerTokenId: _token)));
  }

  void _goMulti() {
    final name = _nameCtrl.text.trim().isEmpty ? 'Joueur' : _nameCtrl.text.trim();
    showDialog(context: context, builder: (_) =>
      _MultiplayerDialog(playerName: name, token: _token));
  }

  Future<void> _newIdentity() async {
    final gp = context.read<GameProvider>();
    await gp.newIdentity();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nouvelle identité générée — tu peux rejoindre une salle comme un autre joueur.'),
        backgroundColor: Color(0xFF1C1309)));
    }
  }

  Future<void> _confirmQuit(BuildContext ctx) async {
    final confirmed = await showDialog<bool>(context: ctx, builder: (dctx) => AlertDialog(
      backgroundColor: kBg2,
      title: Text(ui('quit_app_title'), style: cinzel(15, c: kGold)),
      content: Text(ui('current_game_lost'),
        style: body(13)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dctx, false),
          child: Text('Annuler', style: cinzel(12, c: kTextSub)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dctx, true),
          child: Text('Quitter', style: cinzel(12, c: kRed, fw: FontWeight.w900)),
        ),
      ],
    ));
    // SystemNavigator.pop() est l'API recommandée cross-platform : ferme
    // proprement sur Android, et sur iOS se contente de minimiser
    // l'application (Apple déconseille la fermeture forcée par le code —
    // ce comportement reste conforme à leurs directives).
    if (confirmed == true) {
      await SystemNavigator.pop();
    }
  }
}

// ─── Dialog Multijoueur — Créer / Rejoindre une salle ────────────────────────
class _MultiplayerDialog extends StatefulWidget {
  final String playerName, token;
  const _MultiplayerDialog({required this.playerName, required this.token});
  @override State<_MultiplayerDialog> createState() => _MultiplayerDialogState();
}

class _MultiplayerDialogState extends State<_MultiplayerDialog> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _joinMode = false;

  @override
  void dispose() { _codeCtrl.dispose(); super.dispose(); }

  Future<void> _create() async {
    setState(() { _loading = true; _error = null; });
    final gp = context.read<GameProvider>();
    try {
      await gp.createRoom(widget.playerName, widget.token);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _error = 'Erreur : $e'; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) { setState(() => _error = ui('enter_room_code')); return; }
    setState(() { _loading = true; _error = null; });
    final gp = context.read<GameProvider>();
    try {
      await gp.joinRoom(code, widget.playerName, widget.token);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext ctx) => LanguageAware(builder: (ctx) {
    return Dialog(
      backgroundColor: kBg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Icon(Icons.groups, color: kGold, size: 22),
            const SizedBox(width: 10),
            Text(ui('multiplayer_title'), style: cinzel(16, c: kGold2, fw: FontWeight.w900)),
            const Spacer(),
            GestureDetector(onTap: () => Navigator.pop(ctx),
              child: const Icon(Icons.close, color: kTextSub)),
          ]),
          const SizedBox(height: 20),
          if (!_joinMode) ...[
            Text('Crée une salle et partage le code à 5 lettres avec tes amis.',
              style: body(12, c: kTextSub), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (_loading)
              const CircularProgressIndicator(color: kGold)
            else
              BHButton(label: ui('btn_create_room'), gold: true, onTap: _create),
            const SizedBox(height: 10),
            BHButton(label: ui('btn_join_with_code'), outlined: true,
              onTap: () => setState(() { _joinMode = true; _error = null; })),
          ] else ...[
            Text(ui('multi_enter_code'),
              style: body(12, c: kTextSub), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextField(
              controller: _codeCtrl,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              style: cinzel(20, c: kGold2, ls: 4),
              maxLength: 5,
              decoration: InputDecoration(
                counterText: '',
                filled: true, fillColor: kBg3,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: kBord2)),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const CircularProgressIndicator(color: kGold)
            else
              BHButton(label: ui('btn_join'), gold: true, onTap: _join),
            const SizedBox(height: 10),
            BHButton(label: ui('btn_back'), outlined: true,
              onTap: () => setState(() { _joinMode = false; _error = null; })),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: body(12, c: kRed), textAlign: TextAlign.center),
          ],
        ]),
      ),
    );
  });
}

// ─── Dialog Paramètres ────────────────────────────────────────────────────────
class SettingsDialog extends StatefulWidget {
  const SettingsDialog();
  @override State<SettingsDialog> createState() => SettingsDialogState();
}

class SettingsDialogState extends State<SettingsDialog> {
  bool _busy = false;

  @override
  Widget build(BuildContext ctx) {
    return Dialog(
      backgroundColor: kBg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Row(children: [
            const Icon(Icons.settings, color: kGold, size: 22),
            const SizedBox(width: 10),
            Text(ui('settings_title'), style: cinzel(16, c: kGold2, fw: FontWeight.w900)),
            const Spacer(),
            GestureDetector(onTap: () => Navigator.pop(ctx),
              child: const Icon(Icons.close, color: kTextSub)),
          ]),
          const SizedBox(height: 20),

          // Musique
          SectionLabel(ui('settings_music')),
          const SizedBox(height: 10),
          Row(children: [
            GestureDetector(
              onTap: () { audio.toggleMusic(); setState(() {}); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: audio.musicEnabled
                      ? kGold.withValues(alpha: 0.12) : kBg3,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: audio.musicEnabled ? kGold : kBord2)),
                child: Row(children: [
                  Icon(audio.musicEnabled ? Icons.music_note : Icons.music_off,
                    color: audio.musicEnabled ? kGold : kTextDim, size: 16),
                  const SizedBox(width: 6),
                  Text(audio.musicEnabled ? (AppLanguage.instance.isEnglish ? ui('settings_enabled') : 'Activée') : (AppLanguage.instance.isEnglish ? ui('settings_disabled') : 'Désactivée'),
                    style: cinzel(10, c: audio.musicEnabled ? kGold : kTextDim)),
                ])),
            ),
            const SizedBox(width: 12),
            Expanded(child: Slider(
              value: audio.musicVolume,
              min: 0, max: 1,
              activeColor: kGold,
              inactiveColor: kBord2,
              onChanged: (v) { audio.setMusicVolume(v); setState(() {}); },
            )),
            Text('${(audio.musicVolume * 100).round()}%',
              style: body(11, c: kTextSub)),
          ]),

          const SizedBox(height: 16),

          // Effets sonores
          SectionLabel(ui('settings_sfx')),
          const SizedBox(height: 10),
          Row(children: [
            GestureDetector(
              onTap: () { audio.toggleSfx(); setState(() {}); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: audio.sfxEnabled
                      ? kGold.withValues(alpha: 0.12) : kBg3,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: audio.sfxEnabled ? kGold : kBord2)),
                child: Row(children: [
                  Icon(audio.sfxEnabled ? Icons.volume_up : Icons.volume_off,
                    color: audio.sfxEnabled ? kGold : kTextDim, size: 16),
                  const SizedBox(width: 6),
                  Text(audio.sfxEnabled ? (AppLanguage.instance.isEnglish ? ui('settings_enabled') : 'Activés') : (AppLanguage.instance.isEnglish ? ui('settings_disabled') : 'Désactivés'),
                    style: cinzel(10, c: audio.sfxEnabled ? kGold : kTextDim)),
                ])),
            ),
            const SizedBox(width: 12),
            Expanded(child: Slider(
              value: audio.sfxVolume,
              min: 0, max: 1,
              activeColor: kGold,
              inactiveColor: kBord2,
              onChanged: (v) { audio.setSfxVolume(v); setState(() {}); },
            )),
            Text('${(audio.sfxVolume * 100).round()}%',
              style: body(11, c: kTextSub)),
          ]),

          const SizedBox(height: 8),
          // Preview SFX
          GestureDetector(
            onTap: () => audio.playDice(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.play_circle_outline, color: kTextSub, size: 14),
                const SizedBox(width: 6),
                Text(ui('test_sfx'), style: body(11, c: kTextSub)),
              ]),
            ),
          ),

          const SizedBox(height: 16),

          // Langue de l'interface et du contenu de jeu
          SectionLabel(ui('settings_language')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () { AppLanguage.instance.setLanguage('fr'); setState(() {}); },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !AppLanguage.instance.isEnglish
                      ? kGold.withValues(alpha: 0.12) : kBg3,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: !AppLanguage.instance.isEnglish ? kGold : kBord2)),
                child: Text('🇫🇷 Français', textAlign: TextAlign.center,
                  style: cinzel(11, c: !AppLanguage.instance.isEnglish ? kGold : kTextDim)),
              ),
            )),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(
              onTap: () { AppLanguage.instance.setLanguage('en'); setState(() {}); },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppLanguage.instance.isEnglish
                      ? kGold.withValues(alpha: 0.12) : kBg3,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppLanguage.instance.isEnglish ? kGold : kBord2)),
                child: Text('🇬🇧 English', textAlign: TextAlign.center,
                  style: cinzel(11, c: AppLanguage.instance.isEnglish ? kGold : kTextDim)),
              ),
            )),
          ]),
          Padding(padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Traduit les personnages, cartes et terrains. Certains éléments '
              'd\'interface restent en français pour le moment.',
              style: body(10, c: kTextDim))),

          const SizedBox(height: 16),

          // Affichage (appareil, échelle, résolution)
          SectionLabel(ui('settings_display')),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              final navCtx = Navigator.of(ctx).context;
              Navigator.pop(ctx);
              showDisplaySettingsSheet(navCtx);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: kBg3,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBord2),
              ),
              child: Row(children: [
                Icon(
                  DisplaySettings.instance.deviceMode == 'phone'
                      ? Icons.smartphone
                      : DisplaySettings.instance.deviceMode == 'pc'
                          ? Icons.desktop_windows
                          : Icons.devices,
                  color: kGold, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ui('device_scale_resolution'), style: body(12, c: kText)),
                  Text(
                    ui('device_mode_label').replaceAll('{mode}', DisplaySettings.instance.deviceMode == 'auto' ? 'Auto' : DisplaySettings.instance.deviceMode == 'pc' ? 'PC' : ui('phone_label')).replaceAll('{res}', DisplaySettings.instance.resolution.label),
                    style: body(10, c: kTextDim)),
                ])),
                const Icon(Icons.chevron_right, color: kTextSub, size: 18),
              ]),
            ),
          ),

          const SizedBox(height: 16),
          // Compte — retrouver sa progression (or + cosmétiques) sur un
          // autre appareil/navigateur (ex : la version web du jeu).
          SectionLabel(ui('account_upper')),
          const SizedBox(height: 10),
          if (Prefs.accountCode() == null) ...[
            GestureDetector(
              onTap: _busy ? null : () => _createAccount(ctx),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: kGold.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kGold.withValues(alpha: 0.6)),
                ),
                child: Row(children: [
                  const Icon(Icons.person_add_alt, color: kGold, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(ui('btn_create_account'), style: body(12, c: kGold)),
                    Text(ui('create_account_desc'), style: body(10, c: kTextDim)),
                  ])),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _busy ? null : () => _linkAccount(ctx),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: kBg3,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kBord2),
                ),
                child: Row(children: [
                  const Icon(Icons.login, color: kText, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(ui('btn_have_code'), style: body(12, c: kText))),
                ]),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: kGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kGreen.withValues(alpha: 0.5)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.check_circle, color: kGreen, size: 16),
                  const SizedBox(width: 6),
                  Text(ui('account_linked'), style: body(11, c: kGreen)),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: SelectableText(Prefs.accountCode()!,
                    style: cinzel(15, c: kGold2, fw: FontWeight.w900))),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: Prefs.accountCode()!));
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(ui('code_copied')), backgroundColor: const Color(0xFF1C1309)));
                    },
                    child: const Icon(Icons.copy, color: kTextSub, size: 16)),
                ]),
                const SizedBox(height: 4),
                Text(ui('remember_this_code'), style: body(9, c: kTextDim)),
              ]),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _busy ? null : () => setState(() => Prefs.setAccountCode(null)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: kBg3, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kBord2)),
                child: Center(child: Text(ui('btn_unlink_account'), style: body(11, c: kTextSub))),
              ),
            ),
          ],

          const SizedBox(height: 16),
          // Réinitialisation de la progression
          SectionLabel(ui('progression_upper')),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _confirmReset(ctx),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: kRed.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kRed.withValues(alpha: 0.6)),
              ),
              child: Row(children: [
                const Icon(Icons.restart_alt, color: kRed, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ui('reset_my_progress'), style: body(12, c: kRed)),
                  Text(ui('gold_cosmetics_history'), style: body(10, c: kTextDim)),
                ])),
              ]),
            ),
          ),

          const SizedBox(height: 16),
          // Version
          Text(ui('app_subtitle'),
            style: body(10, c: kTextDim), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  /// Crée un nouveau compte : génère un code unique, y envoie la
  /// progression actuelle de cet appareil, et lie ce code localement.
  Future<void> _createAccount(BuildContext ctx) async {
    setState(() => _busy = true);
    try {
      final fb = FirebaseService.instance;
      final code = await fb.generateAccountCode();
      await fb.pushAccountData(code, Prefs.exportProgressionForAccount());
      Prefs.setAccountCode(code);
      if (ctx.mounted) {
        setState(() {});
        showDialog(context: ctx, builder: (dctx) => AlertDialog(
          backgroundColor: kBg2,
          title: Text(ui('account_created_title'), style: cinzel(15, c: kGold2)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ui('remember_this_code'), style: body(12)),
            const SizedBox(height: 10),
            Center(child: SelectableText(code, style: cinzel(20, c: kGold2, fw: FontWeight.w900))),
          ]),
          actions: [
            TextButton(onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(dctx);
            }, child: Text(ui('btn_copy_and_close'), style: cinzel(12, c: kGold))),
          ],
        ));
      }
    } catch (e) {
      if (ctx.mounted) {
        // Détail technique inclus (pas seulement le message générique) —
        // aide à diagnostiquer (ex: règles de sécurité Firebase qui
        // bloquent le chemin 'accounts/...', absent avant cette
        // fonctionnalité et donc pas forcément déjà autorisé).
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('${ui('account_error')}\n$e'),
            backgroundColor: kRed, duration: const Duration(seconds: 6)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Lie un compte EXISTANT via son code — écrase la progression locale
  /// actuelle avec celle sauvegardée sous ce code.
  Future<void> _linkAccount(BuildContext ctx) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(context: ctx, builder: (dctx) => AlertDialog(
      backgroundColor: kBg2,
      title: Text(ui('btn_have_code'), style: cinzel(15, c: kGold2)),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        style: cinzel(16, c: kGold2),
        decoration: InputDecoration(hintText: 'ABCD-1234-EFGH',
          hintStyle: body(13, c: kTextDim)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dctx),
          child: Text(ui('btn_cancel'), style: cinzel(12, c: kTextSub))),
        TextButton(onPressed: () => Navigator.pop(dctx, controller.text.trim().toUpperCase()),
          child: Text(ui('btn_confirm'), style: cinzel(12, c: kGold))),
      ],
    ));
    if (code == null || code.isEmpty) return;
    setState(() => _busy = true);
    try {
      final fb = FirebaseService.instance;
      final data = await fb.pullAccountData(code);
      if (data == null) {
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text(ui('account_code_not_found')), backgroundColor: kRed));
        }
        return;
      }
      await Prefs.importProgressionFromAccount(data);
      Prefs.setAccountCode(code);
      if (mounted) setState(() {});
    } catch (e) {
      if (ctx.mounted) {
        // Détail technique inclus (pas seulement le message générique) —
        // aide à diagnostiquer (ex: règles de sécurité Firebase qui
        // bloquent le chemin 'accounts/...', absent avant cette
        // fonctionnalité et donc pas forcément déjà autorisé).
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('${ui('account_error')}\n$e'),
            backgroundColor: kRed, duration: const Duration(seconds: 6)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _confirmReset(BuildContext ctx) {
    showDialog(context: ctx, builder: (dctx) => AlertDialog(
      backgroundColor: kBg2,
      title: Text('⚠️ Réinitialiser la progression ?', style: cinzel(15, c: kRed)),
      content: Text(
        'Cette action efface définitivement ton or, tes cosmétiques débloqués, '
        'ton historique de parties et tes statistiques par personnage. '
        "${ui('action_irreversible')}",
        style: body(13)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dctx),
          child: Text('Annuler', style: cinzel(12, c: kTextSub)),
        ),
        TextButton(
          onPressed: () async {
            await Prefs.resetProgress();
            if (dctx.mounted) Navigator.pop(dctx);
            if (ctx.mounted) {
              setState(() {});
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text(ui('progress_reset_done'))));
            }
          },
          child: Text(ui('reset_btn'), style: cinzel(12, c: kRed, fw: FontWeight.w900)),
        ),
      ],
    ));
  }
}
