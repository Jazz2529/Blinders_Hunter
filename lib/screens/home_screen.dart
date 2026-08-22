// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/game_provider.dart';
import '../services/display_settings.dart';
import '../services/persistence.dart';
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
                Text('Musique composée par le talentueux Dams.',
                  style: body(10, c: kTextSub).copyWith(letterSpacing: 2)),
                Text('Du fond du cœur, Merci pour tout',
                  style: body(11, c: kTextSub).copyWith(letterSpacing: 2)),
                Text('By Order of the Sporty Blinders',
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
              const SectionLabel('TON JETON'),
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
                      onTap: () => setState(() => _token = t.id),
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
                  label: '▶️  Reprendre la partie (${_resumable!.roomId})',
                  gold: true, onTap: _resume),
              ),
            ),
          ],
          BHButton(label: '🤖  Mode Solo', onTap: _goSolo),
          const SizedBox(height: 10),
          BHButton(label: '⚔️  Multijoueur', gold: true, onTap: _goMulti),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: BHButton(label: '📊 Stats', outlined: true,
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const StatsScreen())))),
            const SizedBox(width: 10),
            Expanded(child: BHButton(label: '📖 Règles', outlined: true,
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RulesScreen())))),
          ]),
          const SizedBox(height: 10),
          BHButton(label: '📚 Catalogue (personnages & cartes)', outlined: true,
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CardCatalogScreen()))),
          const SizedBox(height: 10),
          BHButton(label: '🛒 Boutique', outlined: true,
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ShopScreen()))),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cette partie n\'existe plus.')));
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
    if (code.isEmpty) { setState(() => _error = 'Entre un code de salle'); return; }
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
  Widget build(BuildContext ctx) {
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
            Text('MULTIJOUEUR', style: cinzel(16, c: kGold2, fw: FontWeight.w900)),
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
              BHButton(label: '➕ Créer une salle', gold: true, onTap: _create),
            const SizedBox(height: 10),
            BHButton(label: 'Rejoindre avec un code', outlined: true,
              onTap: () => setState(() { _joinMode = true; _error = null; })),
          ] else ...[
            Text('Entre le code à 5 lettres de la salle.',
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
              BHButton(label: '🔑 Rejoindre', gold: true, onTap: _join),
            const SizedBox(height: 10),
            BHButton(label: '← Retour', outlined: true,
              onTap: () => setState(() { _joinMode = false; _error = null; })),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: body(12, c: kRed), textAlign: TextAlign.center),
          ],
        ]),
      ),
    );
  }
}

// ─── Dialog Paramètres ────────────────────────────────────────────────────────
class SettingsDialog extends StatefulWidget {
  const SettingsDialog();
  @override State<SettingsDialog> createState() => SettingsDialogState();
}

class SettingsDialogState extends State<SettingsDialog> {
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
            Text('PARAMÈTRES', style: cinzel(16, c: kGold2, fw: FontWeight.w900)),
            const Spacer(),
            GestureDetector(onTap: () => Navigator.pop(ctx),
              child: const Icon(Icons.close, color: kTextSub)),
          ]),
          const SizedBox(height: 20),

          // Musique
          SectionLabel('MUSIQUE'),
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
                  Text(audio.musicEnabled ? 'Activée' : 'Désactivée',
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
          SectionLabel('EFFETS SONORES'),
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
                  Text(audio.sfxEnabled ? 'Activés' : 'Désactivés',
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
                Text('Tester les effets sonores', style: body(11, c: kTextSub)),
              ]),
            ),
          ),

          const SizedBox(height: 16),

          // Affichage (appareil, échelle, résolution)
          SectionLabel('AFFICHAGE'),
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
                  Text('Appareil, échelle & résolution', style: body(12, c: kText)),
                  Text(
                    'Mode : ${DisplaySettings.instance.deviceMode == 'auto' ? 'Auto' : DisplaySettings.instance.deviceMode == 'pc' ? 'PC' : 'Téléphone'} · ${DisplaySettings.instance.resolution.label}',
                    style: body(10, c: kTextDim)),
                ])),
                const Icon(Icons.chevron_right, color: kTextSub, size: 18),
              ]),
            ),
          ),

          const SizedBox(height: 16),
          // Réinitialisation de la progression
          SectionLabel('PROGRESSION'),
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
                  Text('Réinitialiser ma progression', style: body(12, c: kRed)),
                  Text('Or, cosmétiques, historique et statistiques', style: body(10, c: kTextDim)),
                ])),
              ]),
            ),
          ),

          const SizedBox(height: 16),
          // Version
          Text('Blinders Hunter — Mode Solo & Multijoueur',
            style: body(10, c: kTextDim), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  void _confirmReset(BuildContext ctx) {
    showDialog(context: ctx, builder: (dctx) => AlertDialog(
      backgroundColor: kBg2,
      title: Text('⚠️ Réinitialiser la progression ?', style: cinzel(15, c: kRed)),
      content: Text(
        'Cette action efface définitivement ton or, tes cosmétiques débloqués, '
        'ton historique de parties et tes statistiques par personnage. '
        'Cette action est irréversible.',
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
                const SnackBar(content: Text('Progression réinitialisée.')));
            }
          },
          child: Text('Réinitialiser', style: cinzel(12, c: kRed, fw: FontWeight.w900)),
        ),
      ],
    ));
  }
}
