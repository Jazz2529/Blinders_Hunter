// lib/screens/multi_screens.dart
// Lobby + Role Reveal + Game Screen multijoueur

import 'dart:async';
import 'dart:math' show Random, cos, sin;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/game_provider.dart';
import '../services/display_settings.dart';
import 'rules_screen.dart';
import '../widgets/card_viewer.dart';
import '../models/models.dart';
import '../widgets/theme.dart';
import '../widgets/shine_effect.dart';
import '../services/persistence.dart';
import '../services/i18n.dart';
import '../widgets/token_widget.dart';
import '../widgets/player_status_widget.dart';
import '../widgets/reveal_screen.dart';
import '../widgets/terrain_widget.dart';
import '../widgets/ability_animations.dart';
import '../data/tokens_data.dart';
import '../data/characters_data.dart';
import '../data/interactions_data.dart';
import '../data/game_data.dart';
import '../services/audio_service.dart';
import '../services/engine.dart';
import 'home_screen.dart' show SettingsDialog;

// ─────────────────────────────────────────────
// LOBBY
// ─────────────────────────────────────────────
class LobbyScreen extends StatelessWidget {
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext ctx) => Consumer<GameProvider>(
    builder:(_, gp, __) {
      final n = gp.players.length;
      final allReady = gp.players.values.isNotEmpty && gp.players.values.every((p) => p.isReady);
      final canStart = n >= 4 && allReady;
      String startLabel;
      final en = AppLanguage.instance.isEnglish;
      if (n < 4) {
        startLabel = en ? '⏳ Waiting for players ($n/4 minimum)' : '⏳ En attente de joueurs ($n/4 minimum)';
      } else if (!allReady) {
        final notReady = gp.players.values.where((p) => !p.isReady).length;
        startLabel = en ? '⏳ Waiting — $notReady player(s) not ready' : '⏳ En attente — $notReady joueur(s) pas prêt(s)';
      } else {
        startLabel = en ? '⚔  Start game ($n players)' : '⚔  Lancer la partie ($n joueurs)';
      }
      return Scaffold(
        backgroundColor:kBg0,
        appBar:AppBar(
          backgroundColor:kBg2, elevation:0,
          title:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(ui('lobby_title'),style:cinzel(16,c:kGold2)),
            GestureDetector(
              onTap:(){
                Clipboard.setData(ClipboardData(text:gp.roomId??''));
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content:Text(ui('lobby_code_copied')),backgroundColor:const Color(0xFF1C1309)));
              },
              child:Text('Code : ${gp.roomId??"—"}  📋',style:body(12,c:kTextSub).copyWith(letterSpacing:3)),
            ),
          ]),
          actions:[
            IconButton(
              icon: const Icon(Icons.exit_to_app, color: kTextSub),
              tooltip: ui('lobby_leave_room'),
              onPressed: () async {
                await gp.leaveRoomAndReset();
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: kGold),
              onPressed: () => showDialog(context: ctx, builder: (_) => const SettingsDialog()),
            ),
          ],
        ),
        body:Column(children:[
          Expanded(child:ListView(padding:const EdgeInsets.all(14),children:[
            SectionLabel(ui('lobby_players')),
            ...gp.players.values.map((p)=>_PlayerTile(p:p,isMe:p.uid==gp.myUid,
              canRemove: gp.isHost, onRemove: () => gp.guardedAction(() => gp.removeBot(p.uid)),
              onKick: () => _confirmKickPlayer(ctx, gp, p))),
            const SizedBox(height:16),
            SectionLabel(ui('lobby_your_token')),
            const SizedBox(height:10),
            SizedBox(height:56, child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: availableTokens().length,
              itemBuilder: (_, i) {
                final t = availableTokens()[i];
                final usedByOther = gp.players.values
                    .any((p) => p.uid != gp.myUid && p.token == t.id);
                final sel = t.id == gp.me?.token;
                return GestureDetector(
                  onTap: usedByOther ? null : () => gp.guardedAction(() => gp.changeToken(t.id)),
                  child: Opacity(
                    opacity: usedByOther ? 0.25 : 1.0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: EdgeInsets.all(sel ? 2.5 : 0),
                      decoration: BoxDecoration(shape: BoxShape.circle,
                        border: sel ? Border.all(color: kGold, width: 2.5) : null,
                        boxShadow: sel ? [BoxShadow(color: kGold.withValues(alpha: 0.4), blurRadius: 8)] : null),
                      child: TokenWidget(tokenId: t.id, size: 44),
                    ),
                  ),
                );
              },
            )),
            if (gp.isHost) ...[
              const SizedBox(height: 16),
              SectionLabel(ui('char_pool_section')),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.push(ctx, MaterialPageRoute(
                  builder: (_) => const CharacterPoolScreen())),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: kBg3, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kBord2)),
                  child: Row(children: [
                    const Icon(Icons.groups, color: kGold, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      (gp.enabledCharacterIds == null || gp.enabledCharacterIds!.isEmpty)
                          ? ui('char_pool_all')
                          : ui('char_pool_n').replaceAll('{n}', '${gp.enabledCharacterIds!.length}'),
                      style: body(12, c: kText))),
                    const Icon(Icons.chevron_right, color: kTextSub, size: 18),
                  ]),
                ),
              ),
            ],
          ])),
          Container(color:kBg2,padding:const EdgeInsets.all(14),child:Column(children:[
            if (gp.isHost)
              BHButton(
                label: startLabel,
                onTap: canStart ? gp.startGame : null,
                gold: canStart,
              ),
            if (gp.isHost && n < 7) ...[
              const SizedBox(height: 8),
              BHButton(
                label: ui('lobby_add_bot'),
                outlined: true,
                onTap: () => gp.guardedAction(() => gp.addBot()),
              ),
            ],
            const SizedBox(height:8),
            BHButton(
              label:gp.me?.isReady==true?ui('lobby_ready_cancel'):ui('lobby_mark_ready'),
              onTap: () => gp.guardedAction(() => gp.setReady(!(gp.me?.isReady??false))),
              outlined:true,
            ),
          ])),
        ]),
      );
    },
  );
}

class _PlayerTile extends StatelessWidget {
  final Player p; final bool isMe; final bool canRemove; final VoidCallback? onRemove;
  final VoidCallback? onKick;
  const _PlayerTile({required this.p, required this.isMe,
    this.canRemove = false, this.onRemove, this.onKick});

  @override
  Widget build(BuildContext ctx) => Container(
    margin:const EdgeInsets.only(bottom:8),
    padding:const EdgeInsets.all(12),
    decoration:surfaceDecor(border:isMe?kGold:kBord2),
    child:Row(children:[
      TokenWidget(tokenId: p.token, size: 36),
      const SizedBox(width:12),
      Expanded(child:Row(children:[
        if (p.isBot) const Padding(
          padding: EdgeInsets.only(right: 4),
          child: Text('🤖', style: TextStyle(fontSize: 14))),
        Flexible(child: Text(p.name,style:body(15,fw:FontWeight.w600))),
      ])),
      if(p.isReady) Container(
        padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),
        decoration:BoxDecoration(color:kGreen.withOpacity(0.15),
          borderRadius:BorderRadius.circular(20),border:Border.all(color:kGreen)),
        child:Text(ui('lobby_ready_badge'),style:cinzel(11,c:kGreen)),
      ),
      if (canRemove && p.isBot) ...[
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onRemove,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: kRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.close, color: kRed, size: 16)),
        ),
      ],
      // Expulser un joueur HUMAIN — réservé à l'hôte, jamais pour
      // soi-même (même bouton/style que le retrait d'un bot ci-dessus,
      // juste réservé aux humains).
      if (canRemove && !p.isBot && !isMe) ...[
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onKick,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: kRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.person_remove, color: kRed, size: 16)),
        ),
      ],
    ]),
  );
}

// ─────────────────────────────────────────────
// ROLE REVEAL
// ─────────────────────────────────────────────
class RoleRevealScreen extends StatefulWidget {
  const RoleRevealScreen({super.key});
  @override State<RoleRevealScreen> createState() => _RoleRevealState();
}

class _RoleRevealState extends State<RoleRevealScreen> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext ctx) => Consumer<GameProvider>(
    builder:(_, gp, __) {
      final me = gp.me; final c = me?.character;
      if (c == null) return const Scaffold(
        backgroundColor:kBg0,
        body:Center(child:CircularProgressIndicator(color:kGold)));
      final fc = factionColor(c.faction.name);
      return Scaffold(
        backgroundColor:kBg0,
        body:SafeArea(child:Center(child:SingleChildScrollView(
          padding:const EdgeInsets.all(24),
          child:Column(children:[
            Text(ui('secret_card'),style:cinzel(11,c:kTextSub.withOpacity(0.6),ls:3)),
            Text(me!.name,style:cinzel(20,c:kGold2)),
            const SizedBox(height:20),
            Builder(builder: (_) {
              final imgPath = effectiveCharacterImagePath(c.id);
              if (imgPath == null) {
                return Container(
                  width:100,height:100,
                  decoration:BoxDecoration(shape:BoxShape.circle,
                    border:Border.all(color:fc,width:3),
                    gradient:RadialGradient(colors:[fc.withOpacity(0.2),kBg2])),
                  child:Center(child:Text(c.icon,style:const TextStyle(fontSize:48))),
                );
              }
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(height: 240,
                  child: AspectRatio(aspectRatio: 2/3,
                    child: SmoothAssetImage(imgPath, fit: BoxFit.cover,
                      cacheWidth: 320, cacheHeight: 480,
                      placeholderColor: fc.withOpacity(0.15),
                      placeholderIcon: c.icon,
                      errorBuilder: (_, __, ___) => Container(
                        width: 100, height: 100,
                        color: fc.withOpacity(0.15),
                        child: Center(child: Text(c.icon,
                          style: const TextStyle(fontSize: 48))))))),
              );
            }),
            const SizedBox(height:12),
            Text(tr(c.name),style:cinzel(22,c:kGold2,fw:FontWeight.w900)),
            const SizedBox(height:6),
            FactionBadge(c.faction.name),
            const SizedBox(height:6),
            Text("${c.hp} ${ui('hp_suffix')}",style:cinzel(16,c:kGold)),
            const SizedBox(height:14),
            _InfoBox(icon:'⚡',label:ui('ability_unique'),text:tr(c.ability)),
            const SizedBox(height:8),
            _InfoBox(icon:'🏆',label:ui('win_condition_upper'),text:tr(c.winCondition)),
            const SizedBox(height:20),
            Text(ui('dont_show_screen'),
              style:body(12,c:kTextDim).copyWith(fontStyle:FontStyle.italic)),
            const SizedBox(height:24),
            if (!_confirmed)
              BHButton(label:ui('confirm_role_seen'), gold:true, onTap: () => gp.guardedAction(() async {
                setState(() => _confirmed = true);
                await gp.confirmRoleReveal();
              }))
            else
              Column(children:[
                const SizedBox(
                  width:28, height:28,
                  child: CircularProgressIndicator(color: kGold, strokeWidth: 2.5)),
                const SizedBox(height:10),
                Text(ui('waiting_other_players').replaceAll('{n}', '${gp.roleConfirms}/${gp.players.length}'),
                  style: body(12, c: kTextSub)),
              ]),
          ]),
        ))),
      );
    },
  );
}

/// Rémi : une ligne sélectionnable dans le sélecteur d'effets (multi).
class _RemiChoiceRowMulti extends StatelessWidget {
  final String label;
  final bool selected, legendary;
  final VoidCallback onTap;
  const _RemiChoiceRowMulti({required this.label, required this.selected,
    required this.onTap, this.legendary = false});

  @override
  Widget build(BuildContext ctx) {
    final accent = legendary ? kGold : kGold2;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.15) : kBg3,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? accent : kBord2, width: selected ? 2 : 1),
        ),
        child: Row(children: [
          Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18, color: selected ? accent : kTextDim),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: body(12, c: selected ? kText : kTextSub))),
        ]),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String icon,label,text;
  const _InfoBox({required this.icon,required this.label,required this.text});

  @override
  Widget build(BuildContext ctx) => Container(
    width:double.infinity,padding:const EdgeInsets.all(12),
    decoration:surfaceDecor(),
    child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(icon,style:const TextStyle(fontSize:16)),const SizedBox(width:8),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(label,style:cinzel(9,c:kTextSub,ls:1)),const SizedBox(height:2),
        Text(text,style:body(13)),
      ])),
    ]),
  );
}

// ─────────────────────────────────────────────
// GAME SCREEN (multi)
// ─────────────────────────────────────────────
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Garde-fou pour éviter d'ouvrir le même dialogue plusieurs fois lors des
  // re-renders répétés (polling REST) tant que l'état pending reste actif.
  static String? _shownPunishFor;
  static String? _shownRevealFor;
  static String? _shownPublicRevealFor;

  @override
  void dispose() {
    // Filet de sécurité garanti : dispose() se déclenche TOUJOURS quand cet
    // écran est retiré, peu importe comment (bouton retour, geste système,
    // navigation programmatique...) — contrairement à PopScope qui peut ne
    // pas se déclencher dans tous les cas selon le contexte de navigation.
    audio.stopAllSfx();
    audio.stopMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) => PopScope(
    canPop: false,
    onPopInvoked: (didPop) async {
      if (didPop) return;
      final confirmed = await showDialog<bool>(
        context: ctx,
        builder: (dctx) => AlertDialog(
          backgroundColor: kBg2,
          title: Text(ui('quit_game_title'), style: cinzel(16, c: kGold2)),
          content: Text(ui('quit_game_content'),
            style: body(13)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx, false),
              child: Text(ui('btn_cancel'), style: cinzel(12, c: kTextSub))),
            TextButton(onPressed: () => Navigator.pop(dctx, true),
              child: Text(ui('btn_quit'), style: cinzel(12, c: kRed))),
          ],
        ),
      );
      if (confirmed == true && ctx.mounted) Navigator.of(ctx).pop();
    },
    child: Consumer<GameProvider>(
    builder:(_, gp, __) {
      final isMyTurn = gp.isMyTurn;
      final gs = gp.gameState;
      final playerData = gp.playerList.where((p) => p.alive).map((p) => {
        'zoneIndex': p.zoneIndex,
        'tokenId': p.token,
        'alive': p.alive,
        'revealed': p.revealed,
        'faction': p.disguiseFactionOverride ?? p.character?.faction.name ?? '',
      }).toList();

      // Divination X ou Y : si JE suis la cible en attente, propose le choix.
      // IMPORTANT : la clé inclut l'horodatage de CET événement précis, pas
      // seulement l'UID de la cible — sinon, si le MÊME joueur était visé
      // deux fois par des cartes Vision rapprochées, le sondage réseau
      // pouvait ne jamais observer l'état "nettoyé" intermédiaire entre les
      // deux, et la seconde punition ne déclenchait alors jamais son
      // dialogue (c'était très probablement la cause du bug rapporté).
      final punishTargetUidRaw = gs?.pendingPunishTargetUid;
      final punishTs = gs?.pendingPunishTimestamp ?? 0;
      final punishKey = punishTargetUidRaw != null ? '${punishTargetUidRaw}_$punishTs' : null;
      if (punishTargetUidRaw == gp.myUid && gs?.pendingPunishActorUid != null &&
          _shownPunishFor != punishKey) {
        _shownPunishFor = punishKey;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (ctx.mounted) _showPunishChoiceDialog(ctx, gp);
        });
      } else if (punishKey == null) {
        _shownPunishFor = null;
      }
      // Vision Suprême : si la révélation m'est destinée, l'afficher.
      final revealKey = gs?.privateRevealTargetUid;
      if (gs?.privateRevealForUid == gp.myUid && revealKey != null &&
          _shownRevealFor != revealKey) {
        _shownRevealFor = revealKey;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (ctx.mounted) _showPrivateRevealDialog(ctx, gp);
        });
      } else if (revealKey == null) {
        _shownRevealFor = null;
      }

      final overlay = gs?.abilityOverlay;
      final diceResult = gs?.abilityDiceResult;
      final lastDice = gs?.lastDiceResult;
      final lastLabel = gs?.lastDiceLabel;
      final lastCardId = gs?.lastDrawnCardId;
      final lastCard = lastCardId != null ? findCardById(lastCardId) : null;
      final cardTs = gs?.lastDrawnCardTimestamp ?? 0;
      final cardAge = DateTime.now().millisecondsSinceEpoch - cardTs;
      final baseScaffold = Scaffold(
        backgroundColor:kBg0,
        appBar:AppBar(
          backgroundColor:kBg2,elevation:0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: ui('leave_game_tooltip'),
            onPressed: () => _confirmLeaveGame(ctx, gp),
          ),
          title:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(isMyTurn?ui('your_turn_simple'):ui('turn_of_waiting').replaceAll('{name}', gp.currentPlayer?.name??"—"),
              style:cinzel(15,c:isMyTurn?kGold2:kTextSub)),
            Builder(builder: (_) {
              final ts = gs?.turnStartedAt;
              String suffix = '';
              if (ts != null && gp.roomStatus == 'playing') {
                final left = ((GameProvider.turnTimeoutMs -
                    (DateTime.now().millisecondsSinceEpoch - ts)) / 1000).ceil();
                if (left <= 45 && left > 0) suffix = '  ·  ⏰ ${left}s';
              }
              return Text('${_phaseLabel(gp.phase)}$suffix',
                style: body(11, c: suffix.isEmpty ? kTextSub : kRed));
            }),
          ]),
          actions:[
            IconButton(
              icon: const Icon(Icons.settings, color: kGold),
              onPressed: () => showDialog(context: ctx, builder: (_) => const SettingsDialog()),
            ),
            IconButton(
              icon:const Text('📜',style:TextStyle(fontSize:20)),
              onPressed:()=>_showLog(ctx,gp),
            ),
          ],
        ),
        body: LayoutBuilder(builder: (bctx, constraints) {
          final screenH = constraints.maxHeight;
          final screenW = constraints.maxWidth;
          final isMobile = DisplaySettings.instance.isMobileFor(screenW);
          final boardH = isMobile
              ? (screenH * 0.36).clamp(130.0, 280.0)
              : (screenH * 0.28).clamp(160.0, 260.0);

          // Plateau (commun PC / mobile)
          Widget boardWidget() {
            final g = gs!;
            return SizedBox(
            height: boardH,
            child: Padding(
              padding: EdgeInsets.fromLTRB(isMobile ? 4 : 8, isMobile ? 3 : 6, isMobile ? 4 : 8, 0),
              child: Column(children: [
                Expanded(child: LayoutBuilder(builder: (lctx, bc) {
                  final zone6idx = g.terrainLayout.indexWhere((t) => t.effect == 'lumiere');
                  final idx = zone6idx < 0 ? 4 : zone6idx;
                  const gap = 4.0; const cols = 3; const rows = 2;
                  final tileW = (bc.maxWidth  - gap * (cols - 1)) / cols;
                  final tileH = (bc.maxHeight - gap * (rows - 1)) / rows;
                  final col = idx % cols; final row = idx ~/ cols;
                  final tx = col * (tileW + gap); final ty = row * (tileH + gap);
                  return Stack(children: [
                    GameBoard(
                      terrainLayout: g.terrainLayout,
                      players: playerData,
                      humanZoneIndex: gp.me?.zoneIndex ?? 0,
                      showAdjacent: true,
                    ),
                    if (overlay == 'artcade_flames')
                      Positioned(left: tx, top: ty, width: tileW, height: tileH,
                        child: ArtcadeFlameOverlay(onDone: () => gp.clearAbilityOverlay())),
                  ]);
                })),
                if (!isMobile) ...[
                  const SizedBox(height: 2),
                  const AdjacencyLegend(),
                ],
              ]),
            ),
          );
          }

          // ── LAYOUT TÉLÉPHONE : même ordre que le solo — classement des
          // joueurs (trié par blessures) au-dessus du plateau, puis le
          // plateau, puis les actions, puis un journal TOUJOURS visible en
          // bas (avant : liste non triée sous le plateau, journal caché
          // derrière un bouton 📜 à ouvrir manuellement). ──
          if (isMobile) {
            final sortedPlayers = List<Player>.from(gp.playerList);
            sortedPlayers.sort((a, b) {
              if (!a.alive && b.alive) return 1;
              if (a.alive && !b.alive) return -1;
              return a.wounds.compareTo(b.wounds);
            });
            return Column(children: [
              SizedBox(
                height: (screenH * 0.18).clamp(123.0, 153.0),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  children: sortedPlayers.map((p) => _MultiPlayerStatus(p: p, gp: gp)).toList(),
                ),
              ),
              if (gs != null) boardWidget(),
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    color: kBg2,
                    child: isMyTurn ? _ActionPanel(gp: gp) : _WaitPanel(gp: gp),
                  ),
                ),
              ),
              _MultiLogStrip(gp: gp),
            ]);
          }

          // ── LAYOUT PC/tablette : disposition CÔTE À CÔTE plutôt qu'un
          // simple empilement vertical identique au mobile — sur un écran
          // large, empiler verticalement gâchait tout l'espace horizontal
          // disponible sur les côtés, ET le journal persistant n'était
          // même pas affiché (seulement présent côté mobile). Colonne de
          // gauche : classement des joueurs + plateau + journal, plus
          // grande puisqu'elle profite de toute la largeur. Colonne de
          // droite, largeur fixe : le panneau d'action, sur toute la
          // hauteur de l'écran (plus besoin de le restreindre en hauteur
          // puisqu'il ne partage plus l'espace vertical avec le plateau).
          final actionPanelWidth = (screenW * 0.32).clamp(340.0, 420.0);
          return Row(children: [
            Expanded(
              child: Column(children: [
                SizedBox(
                  height: (screenH * 0.19).clamp(118.0, 148.0),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    children: gp.playerList.map((p) => _MultiPlayerStatus(p: p, gp: gp)).toList(),
                  ),
                ),
                if (gs != null) boardWidget(),
                Expanded(child: _MultiLogPanel(gp: gp)),
              ]),
            ),
            Container(width: 1, color: kBord2),
            SizedBox(
              width: actionPanelWidth,
              child: SingleChildScrollView(
                child: Container(
                  color: kBg2,
                  child: isMyTurn ? _ActionPanel(gp: gp) : _WaitPanel(gp: gp),
                ),
              ),
            ),
          ]);}),
      );

      final turnBanner = TurnBanner(
        key: ValueKey('turn_${gs?.currentPlayerId ?? ''}'),
        show: isMyTurn && gp.roomStatus == 'playing');
      // Alerte "corde qui brûle" — visible seulement dans les 10 dernières
      // secondes du minuteur de tour, pour tous les joueurs (pas juste soi).
      int ropeSecondsLeft = 0;
      final tsRope = gs?.turnStartedAt;
      if (tsRope != null && gp.roomStatus == 'playing') {
        ropeSecondsLeft = ((GameProvider.turnTimeoutMs -
            (DateTime.now().millisecondsSinceEpoch - tsRope)) / 1000).ceil();
      }
      final scottInGame = gp.players.values.any((p) => p.alive && p.character?.id == 'scott');
      final burningRope = BurningRopeTimer(secondsLeft: ropeSecondsLeft, scottInGame: scottInGame);
      // Révélation — animation plein écran PARTAGÉE avec le solo (jetons,
      // interactions entre personnages, etc.), visible de TOUS les
      // joueurs dès que N'IMPORTE QUI se révèle — avant : une simple
      // bannière de citation textuelle, bien moins riche.
      final revealQuoteUid = gs?.publicRevealUid;
      final revealTs = gs?.publicRevealTimestamp ?? 0;
      final publicRevealKey = revealQuoteUid != null ? '${revealQuoteUid}_$revealTs' : null;
      // Fenêtre de fraîcheur de 9s (l'animation dure désormais ~6s en
      // interne, allongée pour bien laisser le temps de voir l'image et
      // d'entendre la réplique, notamment pour les révélations de bots qui
      // s'enchaînent vite avec d'autres actions de leur tour) — évite
      // qu'un client qui vient de se connecter ou de se reconnecter ne
      // rejoue une révélation déjà ancienne.
      final revealFresh = revealQuoteUid != null &&
          (DateTime.now().millisecondsSinceEpoch - revealTs) < 9000;
      final revealingPlayer = revealQuoteUid != null ? gp.players[revealQuoteUid] : null;
      // IMPORTANT : si ce joueur n'est pas encore dans le cache local à cet
      // instant précis (ex: mise à jour reçue via un cycle de sondage
      // différent), on ne tente PAS d'afficher l'animation plutôt que de
      // forcer un déballage nul qui plante silencieusement — c'était très
      // probablement la cause de "je n'ai pas l'animation des autres
      // joueurs" : l'échec était invisible (pas de crash visible), juste
      // l'animation qui ne s'affichait jamais.
      final showPublicReveal = revealFresh && publicRevealKey != null &&
          revealingPlayer != null &&
          _shownPublicRevealFor != publicRevealKey;
      if (showPublicReveal) _shownPublicRevealFor = publicRevealKey;
      final revealFullScreen = showPublicReveal
          ? RevealFullScreen(
              key: ValueKey('reveal_$publicRevealKey'),
              player: revealingPlayer,
              allPlayers: gp.players.values.toList(),
              onDone: () {})
          : const SizedBox.shrink();
      if (overlay == null && diceResult == null && lastDice == null && lastCard == null) {
        return Stack(children: [baseScaffold, turnBanner, burningRope, revealFullScreen]);
      }

      void clearOverlay() => gp.clearAbilityOverlay();
      final diceAge = lastDice != null
          ? DateTime.now().millisecondsSinceEpoch - (gs?.lastDiceTimestamp ?? 0)
          : 9999;

      return Stack(children: [
        baseScaffold,
        if (diceResult != null)
          AbilityDiceRoll(result: diceResult, onDone: clearOverlay),
        // Résultat des dés visible de tous (déplacement, attaque, cartes)
        if (lastDice != null && diceAge < 4000)
          _LastDiceBanner(
            result: lastDice,
            label: lastLabel ?? '🎲',
            timestamp: gs?.lastDiceTimestamp ?? 0,
          ),
        // Carte piochée par un bot : affichée dans le panneau d'action/
        // attente (voir _WaitPanel), au MÊME EMPLACEMENT qu'en solo — plus
        // ici en bannière flottante, un endroit différent du solo.
        if (overlay == 'oceane_notes')        OceaneNotesOverlay(onDone: clearOverlay),
        if (overlay == 'raph_petals')         RaphPetalsOverlay(onDone: clearOverlay),
        if (overlay == 'monkey_demon_eyes')   MonkeyDemonEyesOverlay(onDone: clearOverlay),
        if (overlay == 'gege_ghost')          _GegeGhostOverlay(onDone: clearOverlay),
        if (overlay == 'richard2_swap')       _RichardSwapOverlay(onDone: clearOverlay),

        if (overlay == 'scott_counter')       _ScottCounterOverlay(
          key: ValueKey('scott_${gs?.scottCounterDice?['d4']}_${gs?.scottCounterDice?['d6']}_${gs?.scottCounterDice?['dmg']}_${gs?.lastDiceTimestamp}'),
          dice: gs?.scottCounterDice, onDone: clearOverlay),
        if (overlay == 'mathieu_bullet')      _MathieuBulletOverlay(onDone: clearOverlay),
        if (overlay == 'hongyi_dumbbell')     HongYiDumbbellOverlay(onDone: clearOverlay),
        if (overlay == 'vlad_mountain')       VladMountainOverlay(onDone: clearOverlay),
        if (overlay == 'travert_shockwave')   TravertShockwaveOverlay(onDone: clearOverlay),
        if (overlay == 'leo_flames_all')      LeoFlamesAllOverlay(onDone: clearOverlay),
        if (overlay == 'cambou_sheep')        CambouSheepOverlay(onDone: clearOverlay),
        if (overlay == 'carapatte_food')      CarapatteFoodOverlay(onDone: clearOverlay),
        if (overlay == 'augustin_wheat')      AugustinWheatOverlay(onDone: clearOverlay),
        if (overlay == 'fijacked_city')       FijackedCityOverlay(onDone: clearOverlay),
        if (overlay == 'louna_shield')        LounaShieldOverlay(onDone: clearOverlay),
        if (overlay == 'marion_plants')       MarionPlantsOverlay(onDone: clearOverlay),
        if (overlay == 'amelia_light')        AmeliaLightOverlay(onDone: clearOverlay),
        if (overlay == 'albane_clock')        AlbaneClockOverlay(onDone: clearOverlay),
        if (overlay == 'baleine_heal')        BaleineHealOverlay(onDone: clearOverlay),
        if (overlay == 'christine_map')       ChristineMapOverlay(onDone: clearOverlay),
        if (overlay == 'clemence_forge')      ClemenceForgeOverlay(onDone: clearOverlay),
        if (overlay == 'elaia_vision')        ElaiaVisionOverlay(onDone: clearOverlay),
        if (overlay == 'elise_light')         EliseLightOverlay(onDone: clearOverlay),
        if (overlay == 'baptiste_revive')     BaptisteReviveOverlay(onDone: clearOverlay),
        if (overlay == 'hailey_copy')         HaileyCopyOverlay(onDone: clearOverlay),
        if (overlay == 'remi_craft')          RemiCraftOverlay(onDone: clearOverlay),
        if (overlay == 'ines_lock')           InesLockOverlay(onDone: clearOverlay),
        if (overlay == 'meg_offense')         MegFormOverlay(isOffense: true, onDone: clearOverlay),
        if (overlay == 'meg_defense')         MegFormOverlay(isOffense: false, onDone: clearOverlay),
        if (overlay == 'agathe_drain')        AgatheDrainOverlay(onDone: clearOverlay),
        if (overlay == 'damien_alcohol')      DamienServeOverlay(isPoison: false, onDone: clearOverlay),
        if (overlay == 'damien_poison')       DamienServeOverlay(isPoison: true, onDone: clearOverlay),
        if (overlay == 'fifi_golden')         FifiGoldenOverlay(onDone: clearOverlay),
        if (overlay == 'jeanne_mark')         JeanneMarkOverlay(onDone: clearOverlay),
        if (overlay == 'julien_attack')       JulienOverlay(isAttack: true, onDone: clearOverlay),
        if (overlay == 'julien_heal')         JulienOverlay(isAttack: false, onDone: clearOverlay),
        if (overlay == 'luc_ignite')          LucIgniteOverlay(onDone: clearOverlay),
        if (overlay == 'marin_dagger')        MarinDaggerOverlay(onDone: clearOverlay),
        if (overlay == 'casino_win')          CasinoResultOverlay(isWin: true, onDone: clearOverlay),
        if (overlay == 'casino_lose')         CasinoResultOverlay(isWin: false, onDone: clearOverlay),
        if (overlay == 'nils_release')        NilsReleaseOverlay(onDone: clearOverlay),
        if (overlay == 'ninja_shadow')         NinjaShadowOverlay(onDone: clearOverlay),
        if (overlay == 'peio_terrain')         PeioTerrainOverlay(onDone: clearOverlay),
        if (overlay == 'oscar_water')          OscarElementOverlay(element: 'water', onDone: clearOverlay),
        if (overlay == 'oscar_plant')          OscarElementOverlay(element: 'plant', onDone: clearOverlay),
        if (overlay == 'oscar_fire')           OscarElementOverlay(element: 'fire', onDone: clearOverlay),
        if (overlay == 'tommy_copy')            TommyCopyOverlay(onDone: clearOverlay),
        if (overlay == 'tristan_swap')          TristanSwapOverlay(onDone: clearOverlay),
        if (overlay == 'jeanne_reward')
          JeanneRewardOverlay(
            bannerText: gp.gameState?.jeanneRewardBanner ?? '',
            onDone: clearOverlay),
        if (overlay == 'maxence_drunk')        MaxenceDrunkOverlay(onDone: clearOverlay),
        turnBanner,
        burningRope,
        revealFullScreen,
      ]);
    },
  ));

  void _showPunishChoiceDialog(BuildContext ctx, GameProvider gp) {
    final me = gp.me;
    final hasEquip = me != null && me.equipment.isNotEmpty;
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dctx) => AlertDialog(
        backgroundColor: kBg2,
        title: Text(ui('vision_targets_you'), style: cinzel(15, c: kGold2)),
        content: Text(
          hasEquip
            ? ui('give_equip_or_dmg')
            : "Tu n'as aucun équipement — tu vas subir 1 blessure.",
          style: body(13, c: kTextSub)),
        actions: [
          if (hasEquip)
            TextButton(
              onPressed: () { Navigator.pop(dctx); gp.guardedAction(() => gp.resolvePunishChoice(true)); },
              child: Text(ui('btn_give_equip'), style: cinzel(12, c: kGold)),
            ),
          TextButton(
            onPressed: () { Navigator.pop(dctx); gp.guardedAction(() => gp.resolvePunishChoice(false)); },
            child: Text('🩸 Subir 1 blessure', style: cinzel(12, c: kRed)),
          ),
        ],
      ),
    );
  }

  void _showPrivateRevealDialog(BuildContext ctx, GameProvider gp) {
    final target = gp.players[gp.gameState?.privateRevealTargetUid];
    final c = target?.character;
    if (target == null || c == null) { gp.dismissPrivateReveal(); return; }
    final fc = factionColor(c.faction.name);
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dctx) => Dialog(
        backgroundColor: kBg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(ui('supreme_vision_title'), style: cinzel(13, c: kGold)),
            const SizedBox(height: 6),
            Text(target.name, style: cinzel(13, c: kTextSub)),
            const SizedBox(height: 8),
            Container(
              width:90,height:90,
              decoration:BoxDecoration(shape:BoxShape.circle,
                border:Border.all(color:fc,width:3),
                gradient:RadialGradient(colors:[fc.withOpacity(0.2),kBg2])),
              child:Center(child:Text(c.icon,style:const TextStyle(fontSize:42))),
            ),
            const SizedBox(height:10),
            Text(c.name,style:cinzel(20,c:kGold2,fw:FontWeight.w900)),
            const SizedBox(height:6),
            FactionBadge(c.faction.name),
            const SizedBox(height:16),
            BHButton(label:'Fermer',outlined:true,onTap:() {
              Navigator.pop(dctx);
              gp.dismissPrivateReveal();
            }),
          ]),
        ),
      ),
    );
  }

  String _phaseLabel(GamePhase p) {
    switch (p) {
      case GamePhase.ability:     return ui('phase_ability');
      case GamePhase.move:        return ui('phase_move');
      case GamePhase.zoneEffect:  return ui('phase_zone_effect');
      case GamePhase.cardDrawn:   return ui('phase_card_drawn');
      case GamePhase.cardChoice:  return ui('phase_market_choice');
      case GamePhase.chooseTarget:return ui('phase_choose_target');
      case GamePhase.attack:      return ui('phase_attack');
      default: return p.name;
    }
  }

  void _showDiceRef(BuildContext ctx) {
    showDialog(context: ctx, builder: (_) => Dialog(
      backgroundColor: kBg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ui('dice_reference_title'), style: cinzel(14, c: kGold, fw: FontWeight.w900)),
          const SizedBox(height: 16),
          Text(ui('movement_upper'), style: cinzel(11, c: kGold2)),
          const SizedBox(height: 6),
          ...List.generate(4, (d4) => Row(children: [
            ...List.generate(6, (d6) {
              final sum = (d4+1) + (d6+1);
              return Container(width: 36, height: 32, margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: kBg3, borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: kGold.withValues(alpha: 0.3))),
                child: Center(child: Text('$sum', style: body(11, c: kGold2))));
            }),
          ])),
          const SizedBox(height: 6),
          Text(ui('move_formula'), style: body(10, c: kTextSub)),
          const Divider(height: 20, color: Colors.white12),
          Text(ui('atk_formula'), style: cinzel(11, c: kRed)),
          const SizedBox(height: 6),
          Wrap(spacing: 4, runSpacing: 4, children: [
            for (int d4 = 1; d4 <= 4; d4++)
              for (int d6 = 1; d6 <= 6; d6++)
                Container(width: 32, height: 28,
                  decoration: BoxDecoration(color: kBg3, borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: kRed.withValues(alpha: 0.4))),
                  child: Center(child: Text('${(d4-d6).abs()}', style: body(10, c: kRed)))),
          ]),
          const SizedBox(height: 6),
          Text(ui('attack_formula2'), style: body(10, c: kTextSub)),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text(ui('btn_close2'), style: body(13, c: kGold)))),
        ]),
      ),
    ));
  }

  void _showLog(BuildContext ctx, GameProvider gp) {
    showModalBottomSheet(context:ctx,backgroundColor:kBg2,
      isScrollControlled: true,
      builder:(_) => DraggableScrollableSheet(
        initialChildSize: 0.6, minChildSize: 0.3, maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollCtrl) => Column(children: [
          const SizedBox(height: 10),
          Text(ui('log_title'), style: cinzel(13, c: kGold)),
          const SizedBox(height: 4),
          // Logs privés (cartes Vision etc.)
          if (gp.privateLog.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2D1B4E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF9B59B6), width: 1)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ui('secret_info_visible_only_you'),
                    style: body(10, c: const Color(0xFF9B59B6))),
                  const SizedBox(height: 4),
                  ...gp.privateLog.reversed.map((m) =>
                    Text(resolveLog(m), style: body(11, c: const Color(0xFFCE93D8)))),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Expanded(child: ListView.builder(
            controller: scrollCtrl,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            reverse: true,
            itemCount: gp.log.length,
            itemBuilder: (_, i) {
              final entry = gp.log[gp.log.length - 1 - i];
              final sep = entry.indexOf('||');
              final cls = sep >= 0 ? entry.substring(0, sep) : '';
              final msg = sep >= 0 ? entry.substring(sep + 2) : entry;
              Color c = kTextSub;
              if (cls == 'important') c = kGold;
              if (cls == 'death') c = kRed;
              if (cls == 'player') c = kGold2;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(resolveLog(msg), style: body(12, c: c)),
              );
            },
          )),
        ]),
      ),
    );
  }
}

/// Affiche la liste d'équipements d'un joueur donné (public, visible même
/// si le joueur n'est pas révélé — l'équipement est une information publique).
/// Remplace les tooltips (inadaptés au tactile — nécessitent un appui long
/// peu découvrable) par un vrai bouton tapable, important pour le mobile.
void _showEquipmentFor(BuildContext ctx, Player p) {
  final items = p.equipment;
  final isNils = (p.copiedEffect ?? p.character?.abilityEffect) == 'store_damage_nils';
  showDialog(context: ctx, builder: (_) => Dialog(
    backgroundColor: kBg2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Container(
      constraints: const BoxConstraints(maxWidth: 380, maxHeight: 520),
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const Text('🎒', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(child: Text(ui('equipments_of').replaceAll('{name}', p.name.toUpperCase()),
            style: cinzel(13, c: kGold2, fw: FontWeight.w900),
            overflow: TextOverflow.ellipsis)),
        ]),
        if (isNils && p.revealed) ...[
          const SizedBox(height: 12),
          // Compteur visible de tous UNE FOIS RÉVÉLÉ seulement — avant ça,
          // ça révélerait indirectement son identité (Nils) à tout le
          // monde, ce qui n'est pas normal.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: kRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kRed.withValues(alpha: 0.5)),
            ),
            child: Text(ui('stored_damage').replaceAll('{n}', '${p.storedDamage}'),
              style: cinzel(13, c: kRed, fw: FontWeight.w800),
              textAlign: TextAlign.center),
          ),
        ],
        const SizedBox(height: 14),
        if (items.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(ui('no_equipment_for_player'),
              style: body(12, c: kTextSub), textAlign: TextAlign.center))
        else
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final eq = items[i];
                final dc = deckColor(eq.deck.name);
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kBg3, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: dc.withValues(alpha: 0.5))),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(deckIcon(eq.deck.name), style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tr(eq.name), style: cinzel(12, c: kGold2, fw: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(eq.text.split('\n').map(tr).join('\n'), style: body(11, c: kTextSub)),
                    ])),
                  ]),
                );
              },
            ),
          ),
        const SizedBox(height: 14),
        BHButton(label: 'Fermer', outlined: true, onTap: () => Navigator.pop(ctx)),
      ]),
    ),
  ));
}

/// Affiche la fiche d'un joueur (vraie carte, mystère, ou déguisement de
/// Jason) puis son équipement — logique PARTAGÉE utilisée par tous les
/// widgets de liste de joueurs (PlayerStatusCard inclus), pour garantir un
/// comportement identique peu importe où l'on touche un joueur.
/// Confirmation avant de quitter une partie EN COURS — le joueur est
/// remplacé par un bot qui continue à sa place (personnage/PV/équipement
/// conservés), la partie n'est pas bloquée pour les autres.
/// Confirmation avant d'expulser un joueur — réservé à l'hôte, dans le
/// lobby uniquement (avant le lancement de la partie).
Future<void> _confirmKickPlayer(BuildContext ctx, GameProvider gp, Player p) async {
  final confirmed = await showDialog<bool>(context: ctx, builder: (dctx) => AlertDialog(
    backgroundColor: kBg2,
    title: Text(ui('kick_title').replaceAll('{name}', p.name), style: cinzel(15, c: kGold)),
    content: Text(ui('kick_content').replaceAll('{name}', p.name),
      style: body(13)),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dctx, false),
        child: Text(ui('btn_cancel'), style: cinzel(12, c: kTextSub)),
      ),
      TextButton(
        onPressed: () => Navigator.pop(dctx, true),
        child: Text(ui('btn_kick'), style: cinzel(12, c: kRed, fw: FontWeight.w900)),
      ),
    ],
  ));
  if (confirmed == true) {
    await gp.guardedAction(() => gp.kickPlayer(p.uid));
  }
}

Future<void> _confirmLeaveGame(BuildContext ctx, GameProvider gp) async {
  final confirmed = await showDialog<bool>(context: ctx, builder: (dctx) => AlertDialog(
    backgroundColor: kBg2,
    title: Text(ui('quit_game_title'), style: cinzel(15, c: kGold)),
    content: Text(
      ui('bot_takes_over_desc') + ' ' +
      ui('cannot_return_warning'),
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
  if (confirmed == true) {
    await gp.leaveGameAsBot();
  }
}

Future<void> showMultiPlayerCard(BuildContext ctx, Player p, GameProvider gp) async {
  final c = p.character;
  final isMe = p.uid == gp.myUid;
  // Vision Suprême : connaissance privée permanente — le joueur qui a
  // découvert secrètement cette identité peut la reconsulter à tout
  // moment ensuite, comme s'il était révélé, mais seulement pour lui.
  final knowsPrivately = gp.myUid != null && p.privatelyKnownBy.contains(gp.myUid);
  // Maxence : ivresse — si LE JOUEUR QUI REGARDE (gp.me) est ivre, la
  // carte affichée pour un AUTRE joueur est celle "hallucinée", qui prend
  // le pas sur tout le reste (révélation, mystère, déguisement de Jason).
  final drunkVision = DrunkVision.forViewer(gp.me);
  final drunkChar = (!isMe && drunkVision != null) ? drunkVision.cardFor(p.uid) : null;
  // Un joueur MORT révèle toujours son vrai rôle en cliquant sur son
  // jeton — même s'il n'avait jamais été révélé de son vivant. Pour
  // SOI-MÊME : toujours la vraie carte, peu importe la révélation —
  // sinon on voyait une fiche "mystère" en cliquant sur son propre jeton.
  if (drunkChar == null && ((!isMe && !p.revealed && p.alive && !knowsPrivately) || c == null)) {
    await showMysteryCardDialog(ctx, p);
  } else {
    // Jason (Caméléon) : afficher la carte du personnage IMITÉ tant qu'il
    // est VIVANT — mort, il révèle sa vraie identité comme tout le monde
    // (convention "les cartes se retournent à la mort"). Pour SOI-MÊME :
    // toujours sa vraie carte, jamais le déguisement.
    final hasDisguise = !isMe && p.alive && p.disguiseNameOverride != null;
    final disguisedCharId = p.disguiseCharIdOverride;
    final disguisedChar = disguisedCharId != null
        ? kAllCharacters.where((ch) => ch.id == disguisedCharId).firstOrNull
        : null;
    final shown = drunkChar ?? ((hasDisguise && disguisedChar != null) ? disguisedChar : c!);
    final maximeTarget = (isMe && shown.id == 'maxime' && p.maximeFirstAttackerUid != null)
        ? gp.players[p.maximeFirstAttackerUid]
        : null;
    await showFullCardDialog(ctx, shown, hpOverride: shown.hp + p.maxHpModifier,
      oscarXpOverride: drunkChar == null && shown.id == 'oscar' ? p.oscarXp : null,
      maximeTargetName: (isMe && shown.id == 'maxime')
        ? (maximeTarget?.name ?? ui('nobody_yet')) : null,
      megFormOverride: drunkChar == null && shown.abilityEffect == 'meg_shapeshift' ? p.megForm : null,
      mathieuAttackCount: drunkChar == null && (p.copiedEffect ?? shown.abilityEffect) == 'third_attack_bonus' ? p.attackCount : null,
      skinOverride: drunkChar == null ? p.equippedCharacterSkin : null,
      winsOverride: drunkChar == null ? p.shineWins : null,
      copiedAbilityText: (drunkChar == null && p.copiedEffect != null)
          ? tr(characterAbilityForEffect(p.copiedEffect) ?? '') : null);
  }
  final isNils = (p.copiedEffect ?? p.character?.abilityEffect) == 'store_damage_nils';
  if (drunkChar == null && (p.equipment.isNotEmpty || isNils) && ctx.mounted) {
    _showEquipmentFor(ctx, p);
  }
}

/// Adaptateur : calcule les paramètres de PlayerStatusCard (le widget
/// PARTAGÉ avec le solo) à partir du GameProvider — utilisé partout où un
/// joueur doit s'afficher en multijoueur (PC comme mobile), pour un rendu
/// visuel identique au solo.
class _MultiPlayerStatus extends StatelessWidget {
  final Player p; final GameProvider gp;
  const _MultiPlayerStatus({required this.p, required this.gp});
  @override
  Widget build(BuildContext ctx) {
    final drunkVision = DrunkVision.forViewer(gp.me);
    // Victor : cœur affiché UNIQUEMENT si CE joueur est charmé à 100% ET
    // que la personne qui regarde l'écran est Victor lui-même.
    final victorMe = gp.me?.character?.id == 'victor' ? gp.me : null;
    final maxed = victorMe != null && (victorMe.charmLevels[p.uid] ?? 0) >= 100;
    return PlayerStatusCard(
      player: p,
      isCurrent: p.uid == gp.gameState?.currentPlayerId,
      isMe: p.uid == gp.myUid,
      isMarked: gp.gameState?.markedPlayerUid == p.uid,
      victorCharmMaxed: maxed,
      drunkVision: drunkVision,
      onTap: (target) => showMultiPlayerCard(ctx, target, gp),
    );
  }
}


class _WaitPanel extends StatelessWidget {
  final GameProvider gp;
  const _WaitPanel({required this.gp});

  @override
  Widget build(BuildContext ctx) {
    final gs = gp.gameState;
    final mover = gp.currentPlayer;
    final punishTargetUid = gs?.pendingPunishTargetUid;
    final bonusLeft = gs?.bonusTurnsRemaining ?? 0;
    final pta = gs?.pendingTargetAction;

    // ── Texte de statut + contenu spécifique selon la situation ──────────
    // Même principe que _BotPanel en solo : jeton + texte + barre de
    // progression TOUJOURS visibles, puis un contenu qui varie selon ce
    // qui se passe réellement (carte piochée, terrain d'arrivée, tour
    // bonus de Ninja, choix de zones de Richard II, ou à défaut le
    // dernier message du journal) — pour un ressenti identique au solo,
    // que ce soit un bot OU un autre joueur humain qui joue.
    String statusText;
    Widget? extraContent;

    if (punishTargetUid != null && punishTargetUid != gp.myUid) {
      final target = gp.players[punishTargetUid];
      statusText = ui('waiting_for_player').replaceAll('{name}', target?.name ?? '\u2014');
      extraContent = Text(
        ui('must_give_or_take1'),
        style: body(11, c: kTextSub), textAlign: TextAlign.center);
    } else if (gs?.lastDrawnCardId != null &&
        (DateTime.now().millisecondsSinceEpoch - (gs?.lastDrawnCardTimestamp ?? 0)) < 4000) {
      // Carte piochée par un BOT : même emplacement que pour un joueur
      // humain (voir le cas GamePhase.cardDrawn juste en dessous) — avant,
      // ça s'affichait dans une bannière flottante en haut de l'écran, un
      // endroit différent de celui du solo. Champ dédié (lastDrawnCardId),
      // indépendant de la phase de jeu par sécurité (voir _LastCardBanner
      // dans les overlays, retiré ci-dessous au profit de cet emplacement
      // unique et cohérent).
      final card = findCardById(gs!.lastDrawnCardId!);
      statusText = '${mover?.name ?? "?"} pioche :';
      extraContent = card != null ? _CardWidget(card: card) : null;
    } else if (gs?.phase == GamePhase.cardDrawn) {
      // Carte piochée : tout le monde voit la carte tirée (image + effet),
      // exactement comme en solo — SAUF Vision, qui reste secrète (seul
      // celui qui pioche la connaît, comme le veut la règle du jeu).
      final cardId = gs?.pendingAction;
      final card = cardId != null ? findCardById(cardId) : null;
      if (card != null && card.deck != DeckType.vision) {
        statusText = '${mover?.name ?? "?"} pioche :';
        extraContent = _CardWidget(card: card);
      } else {
        statusText = '${mover?.name ?? "?"} pioche une carte Vision (secrète)';
        extraContent = const Text('🔮', style: TextStyle(fontSize: 36));
      }
    } else if (gs?.phase == GamePhase.zoneEffect) {
      // Terrain d'arrivée : tout le monde voit CE terrain — exactement
      // comme en solo, où le plateau et le terrain courant sont toujours
      // visibles pour tous.
      final zoneIdx = gs?.richardActivateZone ?? mover?.zoneIndex;
      final layout = gs?.terrainLayout;
      final terrain = (zoneIdx != null && layout != null && zoneIdx >= 0 && zoneIdx < layout.length)
          ? layout[zoneIdx] : null;
      statusText = '${mover?.name ?? "?"} arrive sur :';
      extraContent = terrain == null ? null : Column(mainAxisSize: MainAxisSize.min, children: [
        Text(terrain.icon, style: const TextStyle(fontSize: 36)),
        const SizedBox(height: 2),
        Text(terrain.name, style: cinzel(13, c: kGold2)),
        Text(terrain.keyword, style: body(11, c: kTextSub)),
      ]);
    } else if (bonusLeft > 0) {
      statusText = '${mover?.name ?? "Ninja"} rejoue !';
      extraContent = Text('$bonusLeft tour(s) bonus restant(s)', style: body(12, c: kTextSub));
    } else if (pta == 'swap_zone_pick1' || pta == 'swap_zone_pick2') {
      statusText = '${mover?.name ?? "Richard II"} choisit des zones\u2026';
      extraContent = Text(ui('terrains_will_swap'),
        style: body(11, c: kTextSub), textAlign: TextAlign.center);
    } else {
      // Repli générique : le DERNIER message du journal (décrit toujours
      // ce qui vient concrètement de se passer) plutôt que le nom brut,
      // illisible, de la phase (ex: "ability").
      statusText = ui('bot_thinking').replaceAll('{name}', mover?.name ?? "\u2014");
      String? lastMsg;
      if (gp.log.isNotEmpty) {
        final raw = gp.log.last;
        final sep = raw.indexOf('||');
        lastMsg = sep >= 0 ? resolveLog(raw.substring(sep + 2)) : resolveLog(raw);
      }
      extraContent = lastMsg == null ? null : Text(lastMsg,
        style: body(12, c: kTextSub), textAlign: TextAlign.center,
        maxLines: 2, overflow: TextOverflow.ellipsis);
    }

    // IMPORTANT : c'est le SPECTATEUR (gp.me, cet appareil) qui doit être
    // ivre pour que tout ceci s'applique — pas le joueur qui joue
    // actuellement. Un joueur ivre ne doit pouvoir se fier à AUCUNE
    // information affichée (qui joue, quelle action, quel jeton) : tout est
    // remplacé par du contenu confus/aléatoire, y compris quand ce n'est
    // PAS son tour. Les autres joueurs (non ivres) continuent de tout voir
    // normalement.
    final drunkVision = DrunkVision.forViewer(gp.me);
    if (drunkVision != null) {
      statusText = ui('someone_is_playing');
      extraContent = null;
    }
    final displayToken = mover == null ? '🔵' : (drunkVision?.tokenFor(mover.uid) ?? mover.token);

    // ── Structure commune, identique à _BotPanel (solo) ──────────────────
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 10),
      TokenWidget(tokenId: displayToken, size: 48),
      const SizedBox(height: 4),
      Text(statusText, style: cinzel(13, c: kTextSub), textAlign: TextAlign.center),
      const SizedBox(height: 12),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: LinearProgressIndicator(backgroundColor: kBord2, color: kGold, minHeight: 4),
      ),
      if (extraContent != null) ...[
        const SizedBox(height: 10),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: extraContent),
      ],
    ]);
  }
}
class _ActionPanel extends StatefulWidget {
  final GameProvider gp;
  const _ActionPanel({required this.gp});
  @override State<_ActionPanel> createState()=>_ActionPanelState();
}

class _ActionPanelState extends State<_ActionPanel> {
  int? _atkD4,_atkD6,_atkDmg;
  bool _emilienRerolledThisTurn = false; // suivi local — évite tout souci de sync réseau pour ce simple garde-fou d'interface
  int? _atkD4b,_atkD6b; // Mango Loco : 2ème lancer si cible costaude (13+ PV)
  int? _d4, _d6, _sum;
  int? _d4b, _d6b, _sum2; // Boussole Mystique : 2e lancer optionnel
  bool _boussoleDecided = false;
  bool _busy = false;
  bool _casinoActive = false; // état local pour Mr Casino — évite le délai Firebase
  String? _atkTargetId;
  bool _showingSwapTargets = false;

  GameProvider get gp => widget.gp;

  @override
  void initState() {
    super.initState();
    // Récupère un jet de dés DÉJÀ lancé mais pas encore confirmé (stocké
    // sur GameProvider, pas dans cet état local) — sans ça, n'importe quel
    // changement ailleurs dans l'appli qui reconstruit ce widget (ex:
    // modifier l'échelle d'affichage) faisait perdre le jet et permettait
    // de relancer les dés gratuitement.
    _d4 = gp.pendingMoveD4; _d6 = gp.pendingMoveD6; _sum = gp.pendingMoveSum;
    _d4b = gp.pendingMoveD4b; _d6b = gp.pendingMoveD6b; _sum2 = gp.pendingMoveSum2;
  }

  /// Exécute une action async en empêchant les doubles-clics (anti-spam).
  /// Délègue désormais au garde CENTRALISÉ de GameProvider (guardedAction)
  /// — une seule source de vérité, partagée avec tous les autres boutons
  /// qui appellent gp.xxx() directement ailleurs dans ce fichier.
  Future<void> _act(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() => _busy = true);
    try { await gp.guardedAction(fn); } finally { if (mounted) setState(() => _busy = false); }
  }

  void _showJasonDisguiseChoice(BuildContext ctx) {
    final hunters = gp.playerList
        .where((p) => p.character?.faction == Faction.hunter && p.character != null)
        .map((p) => p.character!)
        .toList();
    final shadows = gp.playerList
        .where((p) => p.character?.faction == Faction.shadow && p.character != null)
        .map((p) => p.character!)
        .toList();
    if (hunters.isEmpty || shadows.isEmpty) {
      // Cas extrême : pas assez de variété en jeu, révélation normale
      gp.guardedAction(() => gp.revealSelf());
      return;
    }
    final hunterPick = hunters[Random().nextInt(hunters.length)];
    final shadowPick = shadows[Random().nextInt(shadows.length)];
    showDialog(context: ctx, builder: (dctx) => AlertDialog(
      backgroundColor: kBg2,
      title: Text(ui('jason_choose_disguise'), style: cinzel(15, c: kGold2)),
      content: Text(ui('jason_disguise_desc'),
        style: body(12, c: kTextSub)),
      actions: [
        TextButton(
          onPressed: () { Navigator.pop(dctx); gp.guardedAction(() => gp.revealAsDisguise(hunterPick)); },
          child: Text('${hunterPick.icon} ${hunterPick.name} (Hunter)', style: cinzel(12, c: kGold)),
        ),
        TextButton(
          onPressed: () { Navigator.pop(dctx); gp.guardedAction(() => gp.revealAsDisguise(shadowPick)); },
          child: Text('${shadowPick.icon} ${shadowPick.name} (Shadow)', style: cinzel(12, c: kRed)),
        ),
      ],
    ));
  }

  /// Rémi : propose 3 effets tirés au hasard parmi les 10 disponibles
  /// (légendaires nettement plus rares), et il en choisit exactement 2
  /// parmi CES 3 (pas parmi tous les 10). Identique au sélecteur solo.
  void _showRemiCraftDialog(BuildContext ctx) {
    final offered = remiDraw3();
    final selected = <String>{};
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx2, setDialogState) => Dialog(
          backgroundColor: kBg2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460, maxHeight: 480),
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Text('🛠️', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(child: Text('CHOISISSEZ 2 EFFETS PARMI CES 3 (${selected.length}/2)',
                  style: cinzel(13, c: kGold2, fw: FontWeight.w900))),
              ]),
              const SizedBox(height: 4),
              Text(ui('equip_permanent_warning'),
                style: body(11, c: kTextSub)),
              const SizedBox(height: 12),
              ...offered.map((key) => _RemiChoiceRowMulti(
                label: kRemiAllChoices[key]!,
                legendary: kRemiLegendaryChoices.containsKey(key),
                selected: selected.contains(key),
                onTap: () => setDialogState(() {
                  if (selected.contains(key)) {
                    selected.remove(key);
                  } else if (selected.length < 2) {
                    selected.add(key);
                  }
                }),
              )),
              const SizedBox(height: 14),
              BHButton(
                label: ui('btn_craft_n_of_2').replaceAll('{n}', '${selected.length}'),
                danger: true,
                onTap: selected.length == 2 ? () {
                  final list = selected.toList();
                  Navigator.pop(dctx2);
                  gp.guardedAction(() => gp.remiCraftEquipment(list[0], list[1]));
                } : null,
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _showJulienChoice(BuildContext ctx) {
    showDialog(context: ctx, builder: (dctx) => AlertDialog(
      backgroundColor: kBg2,
      title: Text(ui('julien_title'), style: cinzel(16, c: kGold2)),
      content: Text(ui('julien_choice'),
        style: body(13)),
      actions: [
        TextButton(
          onPressed: () => gp.guardedAction(() async {
            Navigator.pop(dctx);
            await gp.requestTarget('damage2_or_heal1');
          }),
          child: Text('⚔️ Attaquer', style: cinzel(12, c: kRed)),
        ),
        TextButton(
          onPressed: () => gp.guardedAction(() async {
            Navigator.pop(dctx);
            await gp.useAbility();
          }),
          child: Text('💚 Se soigner', style: cinzel(12, c: kGreen)),
        ),
      ],
    ));
  }



  @override
  Widget build(BuildContext ctx) {
    // Seconde couche de protection anti-spam : pendant qu'une action est en
    // cours (gp.actionBusy), TOUS les boutons de ce panneau sont
    // visuellement et interactivement désactivés d'un coup — impossible de
    // déclencher un second appui, même très rapide, avant que le premier
    // ne soit terminé.
    final busy = gp.actionBusy;
    return AbsorbPointer(
      absorbing: busy,
      child: Opacity(
        opacity: busy ? 0.55 : 1.0,
        child: Padding(
          padding:const EdgeInsets.all(14),
          child:Column(mainAxisSize:MainAxisSize.min,children:[
            Text(_phaseLabel(),style:cinzel(11,c:kGold,ls:2)),
            const SizedBox(height:10),
            ..._buildActions(ctx),
          ]),
        ),
      ),
    );
  }

  String _phaseLabel() => switch(gp.phase.name){
    'ability'=>ui('phase_ability'),'move'=>ui('phase_move'),'zoneEffect'=>ui('phase_zone_effect'),
    'cardChoice'=>ui('phase_card_choice'),'cardDrawn'=>ui('phase_card_drawn'),
    'chooseTarget'=>ui('phase_choose_target'),'attack'=>ui('phase_attack'),_=>gp.phase.name};

  List<Widget> _buildActions(BuildContext ctx) {
    final me = gp.me;
    // ── Butin : récupérer l'équipement d'un joueur qu'on vient d'éliminer ──
    // (file d'attente — plusieurs morts simultanées, ex: bazooka, passent
    // une par une sans que la 2ème n'écrase la 1ère)
    final lootKillerUid = gp.gameState?.lootKillerUid;
    final lootQueue = gp.gameState?.lootDeadQueue ?? const [];
    if (lootKillerUid != null && lootQueue.isNotEmpty) {
      final dead = gp.players[lootQueue.first];
      if (dead != null && dead.equipment.isNotEmpty) {
        if (lootKillerUid == gp.myUid) {
          return [_LootChoicePanel(gp: gp, dead: dead)];
        }
        final killerName = gp.players[lootKillerUid]?.name ?? '?';
        return [Text('🎒 $killerName choisit un butin sur ${dead.name}…',
          style: body(13, c: const Color(0xFFB8860B)))];
      } else if (lootKillerUid == gp.myUid) {
        // plus rien à récupérer pour ce mort — passer au suivant silencieusement
        gp.guardedAction(() => gp.lootSkip());
      }
    }
    switch (gp.phase) {
      case GamePhase.ability:
        // Mr Casino : widget de pari — vérifie état local ET Firebase
        if (_casinoActive || gp.gameState?.pendingTargetAction == 'casino_bet') {
          if (gp.isMyTurn) return [_MultiCasinoWidget(gp: gp, onDone: () => setState(() => _casinoActive = false))];
          return [Text('🎰 ${gp.currentPlayer?.name ?? "Mr Casino"} fait son pari…',
            style: body(13, c: kGold))];
        }
        // Fifi : sélecteur de dés
        if (gp.gameState?.pendingTargetAction == 'fifi_dice_picker') {
          if (gp.isMyTurn) return [_MultiFifiDiceWidget(gp: gp)];
          return [Text('🍀 ${gp.currentPlayer?.name ?? "Fifi"} choisit ses dés…',
            style: body(13, c: kGreen))];
        }
        // Clémence : afficher le sélecteur de pouvoir si le builder est actif
        final builderStep = gp.gameState?.builderStep ?? 0;
        if (builderStep > 0 && builderStep < 3 && gp.isMyTurn) {
          return [_ClemenceBuilderPanel(gp: gp,
            step: builderStep,
            offered: gp.gameState?.builderOffered ?? [],
            chosen: gp.gameState?.builderEffect1)];
        }
        // Jeanne étape 2 : choisir la récompense secrète (visible seulement de Jeanne)
        final jeanneRewards = gp.gameState?.builderOffered ?? [];
        final markedUid = gp.gameState?.markedPlayerUid;
        if (markedUid != null && jeanneRewards.isNotEmpty && gp.isMyTurn) {
          return [_JeanneRewardPanel(gp: gp, rewards: jeanneRewards)];
        }
        // Elaia étape 1 : choisir la pile à regarder
        final elaiaStep = gp.gameState?.elaiaStep ?? 0;
        if (elaiaStep == 1) {
          if (gp.isMyTurn) return [_ElaiaDeckChoicePanel(gp: gp)];
          return [Text('🔮 ${gp.currentPlayer?.name ?? "Elaia"} regarde une pile…',
            style: body(13, c: const Color(0xFF9370DB)))];
        }
        // Elaia étape 2 : choisir l'ordre des 2 cartes regardées
        if (elaiaStep == 2 && gp.gameState?.elaiaCard1Id != null && gp.gameState?.elaiaCard2Id != null) {
          if (gp.isMyTurn) return [_ElaiaOrderPanel(gp: gp,
            card1: findCardById(gp.gameState!.elaiaCard1Id!)!,
            card2: findCardById(gp.gameState!.elaiaCard2Id!)!)];
          return [Text('🔮 ${gp.currentPlayer?.name ?? "Elaia"} organise une pile…',
            style: body(13, c: const Color(0xFF9370DB)))];
        }
        // Damien : cible choisie — choisir alcool fort ou poison
        final damienTargetUid = gp.gameState?.damienTargetUid;
        if (damienTargetUid != null) {
          final damienTarget = gp.players[damienTargetUid];
          if (gp.isMyTurn && damienTarget != null) {
            return [_DamienChoicePanel(gp: gp, target: damienTarget)];
          }
          return [Text('🍸 ${gp.currentPlayer?.name ?? "Damien"} choisit quoi servir…',
            style: body(13, c: kRed))];
        }
        return [
          // Bandeaux d'état persistants (visibles de tous)
          if (gp.gameState?.fifiGoldenTurn == true)
            _StatusBanner(ui('fifi_golden_turn'), kGreen),
          if ((gp.gameState?.bonusTurnsRemaining ?? 0) > 0)
            _StatusBanner('🥷 ${gp.gameState!.bonusTurnsRemaining} tour(s) bonus restant(s)', kGold),
          if (gp.gameState?.markedPlayerUid != null && gp.gameState?.markedPlayerUid != '__clear__')
            _StatusBanner(
              '🔮 Joueur marqué : ${gp.players[gp.gameState!.markedPlayerUid!]?.name ?? "?"}',
              kRed),
          if(me?.revealed==false)
            BHButton(label:ui('btn_reveal'),onTap:() => gp.guardedAction(() async {
              if (me?.character?.abilityEffect == 'chameleon_passive') {
                _showJasonDisguiseChoice(ctx);
                return;
              }
              await gp.revealSelf();
              if (ctx.mounted && gp.me?.character != null) {
                showFullCardDialog(ctx, gp.me!.character!,
                  hpOverride: gp.me!.character!.hp + gp.me!.maxHpModifier,
                  oscarXpOverride: gp.me!.character!.id == 'oscar' ? gp.me!.oscarXp : null,
                  megFormOverride: gp.me!.character!.abilityEffect == 'meg_shapeshift' ? gp.me!.megForm : null,
                  mathieuAttackCount: (gp.me!.copiedEffect ?? gp.me!.character!.abilityEffect) == 'third_attack_bonus' ? gp.me!.attackCount : null,
                  skinOverride: gp.me!.equippedCharacterSkin,
                  winsOverride: gp.me!.shineWins,
                  copiedAbilityText: gp.me!.copiedEffect != null
                      ? tr(characterAbilityForEffect(gp.me!.copiedEffect) ?? '') : null);
              }
            })),
          if ((me?.copiedEffect ?? me?.character?.abilityEffect) == 'double_move_dice' && me?.revealed == true)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kBg3, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kGold.withValues(alpha: 0.4))),
              child: Text(ui('albane_auto_power'),
                style: body(11, c: kGold2), textAlign: TextAlign.center),
            ),
          if(me?.revealed==true) ...[
            if(me?.abilityUsed==false && !const {
              'heal_on_same_terrain', 'heal_per_equip_eot', 'counter_attack_passive', 'no_attack_buff',
              'death_heal_allies', 'gege_passive', 'tenebres_heal_instead',
              'zero_wound_power', 'third_attack_bonus', 'infinite_range',
              'chameleon_passive', 'heal1_on_own_attack', 'builder_power', 'prophete_mark',
              'double_attack_if_tanky', 'heal_hunter_on_attack', 'reroll_d6_attack', 'felipe_passive',
              'double_move_dice', 'fanny_none', 'victor_charm', 'maxime_double_first', 'bob_resurrect', 'maxence_selfharm_boost', 'tom_shadow_kill_boost',
            }.contains(me?.copiedEffect ?? me?.character?.abilityEffect) &&
              !((me?.copiedEffect ?? me?.character?.abilityEffect) == 'store_damage_nils' && (me?.storedDamage ?? 0) < 1) &&
              me?.abilityLockedByUid == null)
              BHButton(
                label: (me?.copiedEffect ?? me?.character?.abilityEffect) == 'store_damage_nils'
                  ? ui('btn_unleash_stored').replaceAll('{n}', '${me?.storedDamage ?? 0}')
                  : (me?.copiedEffect ?? me?.character?.abilityEffect) == 'craft_equipment_remi'
                    ? ui('btn_craft_equip')
                    : ui('btn_use_ability'),
                onTap: (me?.copiedEffect ?? me?.character?.abilityEffect) == 'damage2_or_heal1'
                  ? () => _showJulienChoice(ctx)
                  : (me?.copiedEffect ?? me?.character?.abilityEffect) == 'craft_equipment_remi'
                    ? () => _showRemiCraftDialog(ctx)
                    : (me?.copiedEffect ?? me?.character?.abilityEffect) == 'casino_bet'
                      ? () => gp.guardedAction(() async {
                          setState(() => _casinoActive = true);
                          await gp.useAbility();
                        })
                      : (me?.copiedEffect ?? me?.character?.abilityEffect) == 'hailey_copy_hunter'
                        ? () => gp.guardedAction(() => gp.haileyOpenChoice())
                        : () => _act(gp.useAbility)),
            if ((me?.copiedEffect ?? me?.character?.abilityEffect) == 'meg_shapeshift' && me?.megForm != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: (me?.megForm == 'offense' ? kRed : kGreen).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: (me?.megForm == 'offense' ? kRed : kGreen).withValues(alpha: 0.5))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(me?.megForm == 'offense' ? '⚔️' : '🛡️', style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      me?.megForm == 'offense'
                          ? ui('form_offensive')
                          : ui('form_defensive'),
                      style: cinzel(11, c: me?.megForm == 'offense' ? kRed : kGreen)),
                  ]),
                ),
              ),
            // Mathieu : nombre d'attaques effectuées — dès la 3ème, le bonus
            // de +2 dégâts devient permanent.
            if ((me?.copiedEffect ?? me?.character?.abilityEffect) == 'third_attack_bonus')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: ((me?.attackCount ?? 0) >= 3 ? kGold : kTextSub).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: ((me?.attackCount ?? 0) >= 3 ? kGold : kTextSub).withValues(alpha: 0.5))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    ...List.generate(3, (i) => Padding(
                      padding: const EdgeInsets.only(right: 3),
                      child: Icon(
                        (me?.attackCount ?? 0) > i ? Icons.circle : Icons.circle_outlined,
                        size: 12,
                        color: (me?.attackCount ?? 0) >= 3 ? kGold : kTextSub),
                    )),
                    const SizedBox(width: 6),
                    Text(
                      (me?.attackCount ?? 0) >= 3
                          ? ui('bonus_2dmg_active').replaceAll('{n}', '${me?.attackCount}')
                          : 'Attaques : ${me?.attackCount ?? 0}/3',
                      style: cinzel(11, c: (me?.attackCount ?? 0) >= 3 ? kGold : kTextSub)),
                  ]),
                ),
              ),
          ],
          BHButton(label:ui('skip_to_move'),onTap:()=>_act(gp.skipAbility),outlined:true),
        ];
      case GamePhase.move:
        if (_showingSwapTargets) {
          final others = gp.players.values.where((p) => p.alive && p.uid != gp.myUid).toList();
          return [
            Text(ui('swap_with_who'), style: cinzel(11, c: kGold)),
            const SizedBox(height: 6),
            if (others.isEmpty) Text(ui('no_other_player_alive'), style: body(13, c: kTextSub)),
            ...others.map((t) => BHButton(
              label: '${t.token} ${t.name}',
              // Pas de remise à zéro locale ici — la section disparaît de
              // toute façon dès que la phase change réellement (même
              // principe que pour le déplacement/l'attaque).
              onTap: () => _act(() => gp.swapPosition(t)),
            )),
            BHButton(label: 'Annuler', outlined: true,
              onTap: () => setState(() => _showingSwapTargets = false)),
          ];
        }
        final hasPortail = gp.me?.equipment.any((e) => e.effect == 'swap_position_equip') ?? false;
        final hasBoussole = gp.me?.equipment.any((e) => e.effect == 'double_dice_choice') ?? false;
        final hasAlbane = ((gp.me?.copiedEffect ?? gp.me?.character?.abilityEffect) == 'double_move_dice')
            && (gp.me?.revealed == true) && (gp.me?.abilityUsed == false);
        final hasDoubleRoll = hasBoussole || hasAlbane;
        if (_sum == null) {
          return [
            if (hasPortail)
              BHButton(label: ui('btn_swap_place'), outlined: true,
                onTap: () => setState(() { _showingSwapTargets = true; })),
            // Albane/Boussole : lancer les deux d'un coup
            if (hasDoubleRoll)
              BHButton(
                label: hasAlbane ? ui('albane_roll2_best') : ui('compass_roll2_best'),
                gold: true,
                onTap: () {
                  final r1 = GameEngine.instance.rollMove();
                  final r2 = GameEngine.instance.rollMove();
                  setState(() {
                    _d4 = r1['d4'] as int; _d6 = r1['d6'] as int; _sum = r1['sum'] as int;
                    _d4b = r2['d4'] as int; _d6b = r2['d6'] as int; _sum2 = r2['sum'] as int;
                  });
                  gp.pendingMoveD4 = _d4; gp.pendingMoveD6 = _d6; gp.pendingMoveSum = _sum;
                  gp.pendingMoveD4b = _d4b; gp.pendingMoveD6b = _d6b; gp.pendingMoveSum2 = _sum2;
                })
            else
              BHButton(label: ui('btn_roll_dice2'), onTap: _rollDice, gold: true),
          ];
        }
        // Albane/Boussole : afficher les deux résultats pour choisir —
        // empilés verticalement (pas côte à côte) pour éviter tout
        // débordement sur écran étroit.
        if (hasDoubleRoll && _sum2 != null && !_boussoleDecided) {
          return [
            Text('LANCER 1', style: cinzel(11, c: kTextDim, ls: 2)),
            const SizedBox(height: 4),
            _DiceWidget(d4: _d4!, d6: _d6!, sum: _sum!, isAttack: false),
            const SizedBox(height: 10),
            Text('LANCER 2', style: cinzel(11, c: kTextDim, ls: 2)),
            const SizedBox(height: 4),
            _DiceWidget(d4: _d4b!, d6: _d6b!, sum: _sum2!, isAttack: false),
            const SizedBox(height: 8),
            BHButton(label: '✅ Choisir lancer 1 ($_sum)', gold: true,
              onTap: () {
                if (hasAlbane) gp.guardedAction(() => gp.markAlbaneUsed());
                setState(() { _sum2 = null; _d4b = null; _d6b = null; _boussoleDecided = true; });
                gp.pendingMoveSum2 = null; gp.pendingMoveD4b = null; gp.pendingMoveD6b = null;
              }),
            BHButton(label: '✅ Choisir lancer 2 ($_sum2)', gold: true,
              onTap: () {
                if (hasAlbane) gp.guardedAction(() => gp.markAlbaneUsed());
                setState(() {
                  _d4 = _d4b; _d6 = _d6b; _sum = _sum2;
                  _sum2 = null; _d4b = null; _d6b = null; _boussoleDecided = true;
                });
                gp.pendingMoveD4 = _d4; gp.pendingMoveD6 = _d6; gp.pendingMoveSum = _sum;
                gp.pendingMoveSum2 = null; gp.pendingMoveD4b = null; gp.pendingMoveD6b = null;
              }),
          ];
        }
        return [
          _DiceWidget(d4: _d4!, d6: _d6!, sum: _sum!, isAttack: false),
          const SizedBox(height: 10),
          if (_sum == 7) ..._buildZoneChoices() else _buildAutoMove(),
        ];
      case GamePhase.zoneEffect:
        return [
          BHButton(label:ui('btn_apply_terrain'),
            onTap:()=>_act(() => gp.applyTerrainEffect(zoneOverride: gp.gameState?.richardActivateZone))),
          BHButton(label:ui('skip_to_attack'),onTap:()=>_act(gp.skipTerrainEffect),outlined:true),
        ];
      case GamePhase.cardChoice:
        return [
          BHButton(label:ui('deck_light'),   onTap:()=>_act(()=>gp.drawCard(DeckType.lumiere))),
          BHButton(label:ui('deck_dark'),  onTap:()=>_act(()=>gp.drawCard(DeckType.tenebres))),
          BHButton(label:ui('deck_vision'),    onTap:()=>_act(()=>gp.drawCard(DeckType.vision))),
        ];
      case GamePhase.cardDrawn:
        final cardId = gp.gameState?.pendingAction;
        final card = cardId != null ? findCardById(cardId) : null;
        return [
          if (card != null) _CardWidget(card: card),
          const SizedBox(height: 10),
          BHButton(label:ui('btn_apply_card'),onTap:()=>_act(gp.applyCard), gold: true),
          // Pas de bouton "Ignorer" — une carte piochée doit être appliquée
        ];
      case GamePhase.chooseTarget:
        final pta = gp.gameState?.pendingTargetAction;
        // Oscar : afficher l'écran de choix (Eau/Plante/Feu) — seulement au
        // joueur concerné, les autres attendent.
        if (pta == 'oscar_choice') {
          if (gp.isMyTurn) return [_MultiOscarChoiceWidget(gp: gp)];
          return [Text('🧪 ${gp.currentPlayer?.name ?? "Oscar"} choisit comment dépenser son XP…',
            style: cinzel(13, c: kGold))];
        }
        // Meg : afficher l'écran de choix (Offensive/Défensive) — seulement
        // au joueur concerné, les autres attendent.
        if (pta == 'meg_choice') {
          if (gp.isMyTurn) return [_MultiMegChoiceWidget(gp: gp)];
          return [Text('🐺 ${gp.currentPlayer?.name ?? "Meg"} choisit sa forme…',
            style: cinzel(13, c: kGold))];
        }
        // Christine : afficher les zones adjacentes proposées — seulement
        // au joueur concerné, les autres attendent.
        if (pta == 'christine_zone_choice') {
          if (gp.isMyTurn) return [_MultiChristineZoneWidget(gp: gp)];
          return [Text('🗺️ ${gp.currentPlayer?.name ?? "Christine"} choisit sa zone…',
            style: cinzel(13, c: kGold))];
        }
        // Hailey : afficher les 3 Hunters proposés — seulement au joueur
        // concerné, les autres attendent.
        if (pta == 'hailey_choice') {
          if (gp.isMyTurn) return [_MultiHaileyChoiceWidget(gp: gp)];
          return [Text('📖 ${gp.currentPlayer?.name ?? "Hailey"} choisit un pouvoir à copier…',
            style: cinzel(13, c: kGold))];
        }
        // Baptiste : afficher le sélecteur de montant à sacrifier —
        // seulement au joueur concerné, les autres attendent.
        if (pta == 'baptiste_amount') {
          if (gp.isMyTurn) return [_MultiBaptisteAmountWidget(gp: gp)];
          return [Text('✝️ ${gp.currentPlayer?.name ?? "Baptiste"} choisit son sacrifice…',
            style: cinzel(13, c: kGold))];
        }
        // Tristan étape 2 : choisir SON équipement à donner.
        if (pta == 'tristan_give_choice') {
          if (gp.isMyTurn) return [_MultiTristanGiveWidget(gp: gp)];
          return [Text(ui('tristan_choosing_give').replaceAll('{name}', gp.currentPlayer?.name ?? 'Tristan'),
            style: cinzel(13, c: kGold))];
        }
        // Tristan étape 3 : choisir l'équipement à recevoir chez la cible.
        if (pta == 'tristan_receive_choice') {
          if (gp.isMyTurn) return [_MultiTristanReceiveWidget(gp: gp)];
          return [Text(ui('tristan_choosing_receive').replaceAll('{name}', gp.currentPlayer?.name ?? 'Tristan'),
            style: cinzel(13, c: kGold))];
        }
        // Mr Casino : afficher le widget de pari (seulement à Mr Casino)
        if (pta == 'casino_bet') {
          if (gp.isMyTurn) return [_MultiCasinoWidget(gp: gp)];
          return [Text('🎰 ${gp.currentPlayer?.name ?? "Mr Casino"} fait son pari…',
            style: cinzel(13, c: kGold))];
        }
        // Corne des Woods — étape 2 : filtrer aux joueurs à portée du joueur forcé
        List<Player> all;
        if (pta == 'corne_des_woods_victim') {
          final forcedUid = gp.gameState?.forcedAttackerUid;
          final forced = forcedUid != null ? gp.players[forcedUid] : null;
          all = forced != null ? gp.attackTargetsFor(forced) : [];
        } else if (pta == 'ability_vlad_adjacent') {
          // Vlad : seulement les joueurs adjacents
          all = gp.attackTargets;
          if (all.isEmpty) {
            return [
              Text(ui('vlad_no_adjacent2'),
                style: body(13, c: kTextSub), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              BHButton(label: '← Retour', outlined: true,
                onTap: () => _act(gp.backToAbility)),
            ];
          } // attackTargets already filters by adjacency
        } else if (pta == 'clemence_target' || pta == 'terrain_damage9' || pta == 'set_marker7_choice' || pta == 'set_wounds7' || pta == 'vampirisation' || pta == 'damage2_then_heal3') {
          // Clémence, Terrain 9, Premier Secours ("vous compris"), Marion,
          // la Chauve-souris Vampire et Raph du Soleil Levant ("un joueur
          // de votre choix", sans exclusion explicite dans le texte de la
          // capacité — il doit pouvoir se soigner lui-même) peuvent se
          // cibler eux-mêmes.
          all = gp.players.values.where((p) => p.alive).toList();
        } else if (pta == 'copy_ability') {
          // Tommy : seulement les joueurs révélés au pouvoir copiable
          all = gp.players.values.where((p) => p.alive && p.uid != gp.myUid &&
              p.revealed && p.character != null &&
              !GameEngine.uncopyableAbilities.contains(p.character!.abilityEffect)).toList();
        } else if (pta == 'baptiste_target') {
          // Baptiste : ne peut cibler QUE des joueurs morts, pour les ramener à la vie
          all = gp.players.values.where((p) => !p.alive).toList();
        } else {
          all = gp.players.values.where((p)=>p.alive&&p.uid!=gp.myUid).toList();
        }
        String title = ui('choose_target');
        if (pta == 'terrain_damage9') title = ui('title_terrain_damage9');
        if (pta == 'baptiste_target') title = ui('title_baptiste_target');
        if (pta == 'terrain_steal')   title = ui('title_terrain_steal');
        if (pta == 'set_wounds7')     title = ui('title_set_wounds7');
        if (pta == 'damage2_then_heal3') title = ui('title_damage2_then_heal3');
        if (pta == 'ally_sacrifice_heal') title = ui('title_ally_sacrifice_heal');
        if (pta == 'terrain_max_aoe') title = ui('title_terrain_max_aoe');
        if (pta == 'store_damage_nils') title = ui('title_store_damage_nils');
        if (pta == 'steal_max_hp') title = ui('title_steal_max_hp');
        if (pta == 'd6_lifesteal')    title = ui('title_d6_lifesteal');
        if (pta == 'd6_global_attack') title = ui('title_d6_global_attack');
        if (pta == 'd4_bonus_attack') title = ui('title_d4_bonus_attack');
        if (pta == 'swap_equipment') title = ui('title_swap_equipment');
        if (pta == 'damage2_or_heal1') title = ui('title_damage2_or_heal1');
        if (pta == 'vision_shadow_heal_or_dmg') title = ui('title_vision_shadow_heal_or_dmg');
        if (pta == 'vision_hunter_heal_or_dmg') title = ui('title_vision_hunter_heal_or_dmg');
        if (pta == 'vision_neutral_heal_or_dmg') title = ui('title_vision_neutral_heal_or_dmg');
        if (pta == 'vision_show_card') title = ui('title_vision_show_card');
        if (pta == 'vision_punish_neutral_shadow') title = ui('title_vision_punish');
        if (pta == 'vision_punish_neutral_hunter') title = ui('title_vision_punish');
        if (pta == 'vision_punish_shadow_hunter') title = ui('title_vision_punish');
        if (pta == 'vision_hp_12plus') title = ui('title_vision_hp_12plus');
        if (pta == 'vision_hp_11minus') title = ui('title_vision_hp_11minus');
        if (pta == 'damage3_give_dague') title = ui('title_damage3_give_dague');
        if (pta == 'damien_serve') title = ui('title_damien_serve');
        if (pta == 'copy_ability') title = ui('title_copy_ability');
        if (pta == 'd4_heal_neighbors') title = ui('title_d4_heal_neighbors');
        if (pta == 'heal_other_d4') title = ui('title_heal_other_d4');
        if (pta == 'creation_marin') title = ui('title_creation_marin');
        if (pta == 'oscar_water_target') title = ui('title_oscar_water_target');
        if (pta == 'corne_des_woods') title = ui('title_corne_des_woods');
        if (pta == 'corne_des_woods_victim') title = ui('title_corne_des_woods_victim');
        if (pta == 'clemence_target') title = ui('title_clemence_target');
        if (pta == 'jeanne_mark_target') title = ui('title_jeanne_mark_target');
        if (pta == 'casino_win') title = ui('title_casino_win');
        if (pta == 'ability_vlad_adjacent') title = ui('title_ability_vlad_adjacent');
        if (pta == 'equip_choice') title = ui('title_equip_choice');
        // Richard II : afficher les zones du plateau
        if ((pta == 'swap_zone_pick1' || pta == 'swap_zone_pick2') && gp.isMyTurn) {
          final myZoneIdx = gp.me?.zoneIndex ?? 0;
          final layout = gp.gameState?.terrainLayout ?? [];
          return [
            Text(ui('title_richard2_zone'),
              style: cinzel(12, c: kGold)), const SizedBox(height: 8),
            ...layout.asMap().entries.where((e) => e.key != myZoneIdx).map((entry) {
              final idx = entry.key; final terrain = entry.value;
              final dv = DrunkVision.forViewer(gp.me);
              final here = gp.players.values.where((p) => p.alive && p.zoneIndex == idx)
                  .map((p) => dv?.tokenFor(p.uid) ?? p.token).join(' ');
              return Padding(padding: const EdgeInsets.only(bottom: 6),
                child: BHButton(
                  label: 'Zone ${idx+1} — ${terrain.icon} ${terrain.name}'
                    '${here.isNotEmpty ? "  ($here)" : ""}',
                  onTap: () => _act(() => gp.chooseSwapZone(idx)),
                ));
            }),
          ];
        }
        // equip_choice : afficher une liste d'équipements plutôt que de joueurs
        if (pta == 'equip_choice') {
          final encoded = gp.gameState?.forcedAttackerUid ?? '';
          final parts = encoded.split('|');
          if (parts.length == 3) {
            final mode = parts[0]; final actorUid = parts[1]; final targetUid = parts[2];
            final src = mode == 'steal'
                ? gp.players[targetUid]
                : gp.players[actorUid];
            final equipList = src?.equipment ?? [];
            return [
              Text(mode == 'steal' ? ui('choose_equip_to_steal') : ui('choose_equip_to_give'),
                style: cinzel(11, c: kGold)),
              const SizedBox(height: 6),
              if (equipList.isEmpty)
                Text(ui('no_equipment_available'), style: body(12, c: kTextSub))
              else ...equipList.asMap().entries.map((entry) => BHButton(
                label: entry.value.name,
                onTap: () => _act(() => gp.resolveEquipChoiceMulti(mode, actorUid, targetUid, entry.key)),
              )),
            ];
          }
        }
        // terrain_steal_item (Tour du Voleur, terrain 10) : laisser choisir
        // PRÉCISÉMENT quel objet voler chez la cible déjà choisie, au lieu
        // d'un tirage aléatoire.
        if (pta == 'terrain_steal_item') {
          final stealTargetUid = gp.gameState?.stealTargetUid;
          final src = stealTargetUid != null ? gp.players[stealTargetUid] : null;
          final equipList = src?.equipment ?? [];
          final dv = DrunkVision.forViewer(gp.me);
          final srcLabel = (dv != null && src != null) ? tr(dv.cardFor(src.uid).name) : (src?.name ?? '?');
          return [
            Text('🗼 Quel objet de $srcLabel voulez-vous voler ?',
              style: cinzel(11, c: kGold)),
            const SizedBox(height: 6),
            if (equipList.isEmpty)
              Text(ui('no_equipment_available'), style: body(12, c: kTextSub))
            else ...equipList.asMap().entries.map((entry) => BHButton(
              label: dv != null ? ui('mystery_item').replaceAll('{n}', '${entry.key + 1}') : entry.value.name,
              onTap: () => _act(() => gp.resolveStealItem(entry.key)),
            )),
          ];
        }
        return [
          Text(title, style: cinzel(11, c: kGold)),
          const SizedBox(height: 6),
          if (all.isEmpty) Text(ui('no_valid_target'), style: body(13, c: kTextSub)),
          ...all.map((t) {
            // IMPORTANT : enveloppé dans _act() (verrou anti-double-clic) —
            // sans ça, un clic rapide/répété pouvait déclencher 2 appels
            // concurrents basés sur le même instantané Firebase pas encore
            // synchronisé, le 2ème écrasant le 1er (dégâts qui semblaient
            // "annulés"/soignés après une attaque de Vlad par exemple).
            Future<void> onTap() async {
              if (pta == 'terrain_damage9' || pta == 'terrain_steal') {
                await gp.applyTerrainTarget(t);
              } else if (pta == 'corne_des_woods_victim') {
                await gp.resolveCorneVictim(t);
              } else if (pta == 'ability_vlad_adjacent') {
                await gp.useAbility(target: t);
              } else if (pta == 'terrain_max_aoe') {
                await gp.hongYiApplyAbility(t);
              } else if (pta == 'oscar_water_target') {
                await gp.oscarChoice('water', target: t);
              } else if (pta == 'baptiste_target') {
                await gp.baptisteChooseTarget(t);
              } else if (pta == 'store_damage_nils') {
                await gp.useAbility(target: t);
              } else if (pta == 'steal_max_hp') {
                await gp.useAbility(target: t);
              } else if (pta == 'jeanne_mark_target') {
                await gp.jeanneChooseTarget(t);
              } else if (pta == 'casino_win') {
                await gp.casinoApplyDamage(t);
              } else if (pta == 'damien_serve') {
                await gp.damienChooseTarget(t);
              } else if (pta == 'clemence_target') {
                await gp.clemenceApplyToTarget(t);
              } else if (pta == 'ability_tristan') {
                await gp.tristanChooseTarget(t);
              } else if (pta != null && pta.startsWith('vision_') ||
                  pta == 'banane_demonique' || pta == 'vampirisation' ||
                  pta == 'blue_shell' || pta == 'veuve_noire' ||
                  pta == 'peau_banane' || pta == 'pince_attrape' ||
                  pta == 'trebuchet' || pta == 'set_marker7_choice' ||
                  pta == 'heal_other_d6' || pta == 'heal_other_d4' ||
                  pta == 'creation_marin' || pta == 'corne_des_woods') {
                await gp.applyCard(target: t);
              } else {
                // Pouvoirs nécessitant une cible (set_wounds7, damage2_then_heal3, etc.)
                await gp.useAbility(target: t);
              }
            }
            final dv = DrunkVision.forViewer(gp.me);
            final label = dv != null
                ? '${tr(dv.cardFor(t.uid).name)} (${dv.tokenFor(t.uid)})  ?🩸'
                : '${t.name} (${t.token})  ${t.wounds}🩸';
            return BHButton(
              label: label,
              onTap: () => _act(onTap),
            );
          }),
        ];
      case GamePhase.attack:
        final targets = gp.attackTargets;
        final alreadyAttacked = gp.gameState?.hasAttacked == true;
        final hasHache = gp.me?.hache == true && gp.me?.equipment.any((e) => e.effect == 'hache_berserker') == true;
        final mustAttackNow = hasHache && !alreadyAttacked && targets.isNotEmpty;
        final hasBazooka = gp.me?.bazooka == true ||
            (gp.me != null && remiActiveChoices(gp.me!).contains('remi_aoe'));
        // Mathieu : afficher le compteur d'attaques
        final isMathieu = (gp.me?.copiedEffect ?? gp.me?.character?.abilityEffect) == 'third_attack_bonus';
        final mathieuCount = gp.me?.attackCount ?? 0;
        return [
          if (isMathieu && !alreadyAttacked)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: kBg3, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: mathieuCount >= 2 ? kRed : kGold.withValues(alpha: 0.4))),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('⚔️ Attaques ce tour : ', style: body(11, c: kTextSub)),
                ...List.generate(3, (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Icon(
                    i < mathieuCount ? Icons.circle : Icons.circle_outlined,
                    size: 14,
                    color: mathieuCount >= 2 && i == 2 ? kRed : kGold),
                )),
                if (mathieuCount >= 2)
                  Text('  ⚡ +1 dmg!', style: body(11, c: kRed, fw: FontWeight.bold)),
              ]),
            ),
          if (alreadyAttacked)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: surfaceDecor(),
              child: Text(ui('already_attacked_this_turn'),
                style: body(12, c: kTextSub), textAlign: TextAlign.center),
            )
          else if(targets.isEmpty) Text(ui('no_target_in_range'),style:body(13,c:kTextSub)),
          if(!alreadyAttacked && _atkDmg==null) ...[
            // Bazooka/Mitraillette : un seul bouton pour tous
            if (hasBazooka) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: kRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8), border: Border.all(color: kRed.withValues(alpha: 0.4))),
                child: Text('💥 Frappe TOUS les joueurs accessibles !',
                  style: body(12, c: kRed), textAlign: TextAlign.center),
              ),
              if (targets.isNotEmpty)
                BHButton(
                  label: '💥 Attaquer tout le monde (${targets.length} cibles)',
                  danger: true,
                  onTap: () => _startAttack(targets.first.uid), // targetId utilisé seulement pour déclencher, bazooka gère tous
                ),
            ] else ...[
              ...targets.map((t) {
                final dv = DrunkVision.forViewer(gp.me);
                final label = dv != null
                    ? "Attaquer ${tr(dv.cardFor(t.uid).name)} (${dv.tokenFor(t.uid)})"
                    : 'Attaquer ${t.name} (${t.token})';
                return BHButton(
                  label: label,
                  danger:true,
                  onTap:()=>_startAttack(t.uid),
                );
              }),
            ],
          ] else if (!alreadyAttacked) ...[
            Container(
              margin:const EdgeInsets.only(bottom:8),
              padding:const EdgeInsets.all(12),
              decoration:BoxDecoration(color:kShadow.withOpacity(0.1),
                borderRadius:BorderRadius.circular(10),border:Border.all(color:kShadow)),
              child:Column(children:[
                Text(ui('dmg_suffix').replaceAll('{n}', '$_atkDmg'),style:cinzel(28,c:kRed,fw:FontWeight.w900)),
                if (_atkD4b != null)
                  Text(ui('strong_target_double').replaceAll('{d4}','${_atkD4}').replaceAll('{d6}','${_atkD6}').replaceAll('{d4b}','${_atkD4b}').replaceAll('{d6b}','${_atkD6b}').replaceAll('{n}','$_atkDmg'),
                    style:body(11,c:kGold2), textAlign: TextAlign.center)
                else if (!hasBazooka)
                  Text('|d4($_atkD4) − d6($_atkD6)| = $_atkDmg',style:body(12,c:kTextSub))
                else
                  Text('💥 Bazooka — tous les joueurs accessibles',style:body(12,c:kRed)),
              ]),
            ),
            BHButton(label:ui('btn_confirm_short'),danger:true,
              onTap:()=>_act(_confirmAttack)),
            // Emilien : passif — une SEULE relance du D6 par tour. Non
            // disponible pour le bazooka ni le double-lancer de Mango.
            if (gp.me?.revealed == true && _atkD4b == null && !hasBazooka && !_emilienRerolledThisTurn &&
                (gp.me?.copiedEffect ?? gp.me?.character?.abilityEffect) == 'reroll_d6_attack') ...[
              const SizedBox(height: 8),
              BHButton(
                label: '🎲 Relancer le D6 (1 fois par tour)',
                outlined: true,
                onTap: () {
                  audio.playDice();
                  final newD6 = GameEngine.instance.rollD6();
                  setState(() {
                    _atkD6 = newD6;
                    _atkDmg = (_atkD4! - newD6).abs();
                    _emilienRerolledThisTurn = true;
                  });
                }),
            ],
          ],
          if (mustAttackNow)
            Container(
              margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: kRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8), border: Border.all(color: kRed.withValues(alpha: 0.5))),
              child: Text('🪓 Tu DOIS attaquer avant de terminer le tour !', style: body(11, c: kRed)),
            )
          // Une attaque en attente de confirmation (dés déjà lancés) DOIT
          // être résolue — impossible de terminer le tour pour la contourner.
          // IMPORTANT : on vérifie aussi `!alreadyAttacked` — sinon, comme
          // _atkDmg n'est plus remis à zéro immédiatement après confirmation
          // (pour éviter un autre bug où l'interface "revenait en arrière"
          // pendant le court délai réseau), cet avertissement restait
          // bloqué indéfiniment après une attaque pourtant déjà validée,
          // sans aucun bouton pour continuer.
          else if (_atkDmg != null && !alreadyAttacked)
            Container(
              margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: kRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8), border: Border.all(color: kRed.withValues(alpha: 0.5))),
              child: Text('⚔️ Tu dois confirmer ton attaque avant de terminer le tour !', style: body(11, c: kRed)),
            )
          else
            BHButton(label:ui('btn_end_turn2'), onTap: () => _act(gp.endTurn), outlined:true),
        ];
      default: return [];
    }
  }

  void _rollDice() {
    audio.playDice();
    if (gp.gameState?.fifiGoldenTurn == true) {
      final move = gp.gameState?.fifiMoveResult ?? 7;
      // Décompose la somme en D4+D6 cohérents
      final d4 = (move / 2).ceil().clamp(1, 4).toInt();
      final d6 = (move - d4).clamp(1, 6).toInt();
      setState(() { _d4 = d4; _d6 = d6; _sum = move; });
    } else {
      final r = GameEngine.instance.rollMove();
      setState(() { _d4 = r['d4']; _d6 = r['d6']; _sum = r['sum']; });
    }
    gp.pendingMoveD4 = _d4; gp.pendingMoveD6 = _d6; gp.pendingMoveSum = _sum;
  }

  void _resetDice() => setState(() {
    _d4 = _d6 = _sum = null;
    _d4b = _d6b = _sum2 = null;
    _boussoleDecided = false;
  });

  List<Widget> _buildZoneChoices() => List.generate(6, (i) {
    if (i == gp.me?.zoneIndex) return const SizedBox.shrink();
    final t = gp.gameState!.terrainLayout[i];
    return BHButton(
      label: '${t.icon} ${t.num} — ${tr(t.name)}',
      onTap: () => _act(() => gp.moveTo(i, diceSum: _sum!, d4: _d4!, d6: _d6!)),
    );
  });

  Widget _buildAutoMove() {
    const m = {2: 0, 3: 0, 4: 1, 5: 1, 6: 2, 8: 3, 9: 4, 10: 5};
    final tid = m[_sum];
    final layout = gp.gameState!.terrainLayout;
    int idx = tid != null ? layout.indexWhere((t) => t.id == tid) : -1;
    if (idx == -1 || idx == gp.me?.zoneIndex) idx = ((gp.me?.zoneIndex ?? 0) + 1) % 6;
    final t = layout[idx];
    return BHButton(
      label: '→ ${t.icon} ${tr(t.name)}  (${tr(t.keyword)})',
      onTap: () => _act(() => gp.moveTo(idx, diceSum: _sum!, d4: _d4!, d6: _d6!)),
    );
  }

  void _startAttack(String targetId) {
    final hasHache = gp.me?.hache == true &&
        (gp.me?.equipment.any((e) => e.effect == 'hache_berserker') ?? false);
    final eff = gp.me?.copiedEffect ?? gp.me?.character?.abilityEffect;
    final target = gp.players[targetId];
    // Rémi : équipement personnalisé — si le choix D4/D6 uniquement est
    // actif, on ne lance QUE ce dé (pas les deux), et les dégâts sont son
    // résultat brut directement.
    final remiChoicesMe = gp.me != null ? remiActiveChoices(gp.me!) : const <String>{};
    if (remiChoicesMe.contains('remi_d4only')) {
      final d4 = GameEngine.instance.rollD4();
      setState(() { _atkD4 = d4; _atkD6 = null; _atkDmg = d4; _atkTargetId = targetId; });
      return;
    }
    if (remiChoicesMe.contains('remi_d6only')) {
      final d6 = GameEngine.instance.rollD6();
      setState(() { _atkD4 = null; _atkD6 = d6; _atkDmg = d6; _atkTargetId = targetId; });
      return;
    }
    if (gp.gameState?.fifiGoldenTurn == true) {
      final atk = gp.gameState?.fifiAtkResult ?? 5;
      final d4 = (atk / 2).ceil().clamp(0, 4).toInt();
      final d6 = (atk - d4).clamp(0, 6).toInt();
      setState(() { _atkD4 = d4; _atkD6 = d6; _atkDmg = atk; _atkTargetId = targetId; });
    } else if (hasHache && eff == 'double_attack_if_tanky' && target?.character != null && target!.revealed && target.character!.hp >= 13) {
      // 🥭 Mango Loco + Sabre Hanté Masamune : cible costaude → double
      // lancer même en D4 forcé, dégâts additionnés (même règle que pour
      // une attaque normale — le Sabre ne doit pas faire perdre ce passif).
      final r1 = GameEngine.instance.rollHacheAttack();
      final r2 = GameEngine.instance.rollHacheAttack();
      setState(() {
        _atkD4 = r1['d4']!; _atkD6 = 0;
        _atkD4b = r2['d4']!; _atkD6b = 0;
        _atkDmg = r1['damage']! + r2['damage']!;
        _atkTargetId = targetId;
      });
    } else if (hasHache) {
      // Sabre Hanté : D4 seulement
      final r = GameEngine.instance.rollHacheAttack();
      setState(() { _atkD4 = r['d4']!; _atkD6 = 0; _atkDmg = r['damage']; _atkTargetId = targetId; });
    } else if (eff == 'double_attack_if_tanky' && target?.character != null && target!.revealed && target.character!.hp >= 13) {
      // 🥭 Mango Loco : cible costaude (13+ PV) → double lancer, dégâts additionnés
      final r1 = GameEngine.instance.rollAttack();
      final r2 = GameEngine.instance.rollAttack();
      setState(() {
        _atkD4 = r1['d4']!; _atkD6 = r1['d6']!;
        _atkD4b = r2['d4']!; _atkD6b = r2['d6']!;
        _atkDmg = r1['damage']! + r2['damage']!;
        _atkTargetId = targetId;
      });
    } else {
      // Attaque normale : D4 + D6
      final r = GameEngine.instance.rollAttack();
      setState(() {
        _atkD4 = r['d4']!;
        _atkD6 = r['d6']!;
        _atkDmg = r['damage']!;
        _atkTargetId = targetId;
      });
    }
  }

  Future<void> _confirmAttack() async {
    if(_atkTargetId==null||_atkDmg==null) return;
    // IMPORTANT : pas de remise à zéro locale ici après l'écriture — la
    // section d'attaque disparaît de toute façon dès que la phase change
    // réellement (case GamePhase.attack). Effacer l'état local tout de
    // suite créait une fenêtre où l'interface retombait brièvement sur
    // "lancer les dés" avant que le sondage réseau ne rattrape le
    // changement de phase (même bug que pour le déplacement).
    await gp.attackPlayer(_atkTargetId!, _atkDmg!, d4: _atkD4 ?? 0, d6: _atkD6 ?? 0);
  }
}

/// Dés animés (roll → révélation), identique au solo
class _DiceWidget extends StatefulWidget {
  final int d4, d6, sum;
  final bool isAttack;
  const _DiceWidget({required this.d4, required this.d6, required this.sum, required this.isAttack});
  @override State<_DiceWidget> createState() => _DiceWidgetState();
}

class _DiceWidgetState extends State<_DiceWidget>
    with TickerProviderStateMixin {
  late AnimationController _rollAc;
  late AnimationController _revealAc;
  late Animation<double> _rollD4x, _rollD4y;
  late Animation<double> _rollD6x, _rollD6y;
  late Animation<double> _rollRotD4, _rollRotD6;
  late Animation<double> _revealScale, _revealFade;
  bool _showResult = false;

  @override
  void initState() {
    super.initState();
    _rollAc = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 500));
    _rollD4x = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: -60, end: 30), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 30, end: -15), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: -15, end: 0),  weight: 30),
    ]).animate(CurvedAnimation(parent: _rollAc, curve: Curves.easeInOut));
    _rollD4y = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: -30, end: 20), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 20, end: -10), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: -10, end: 0),  weight: 30),
    ]).animate(CurvedAnimation(parent: _rollAc, curve: Curves.easeIn));
    _rollD6x = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 60, end: -25), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: -25, end: 15), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 15, end: 0),   weight: 30),
    ]).animate(CurvedAnimation(parent: _rollAc, curve: Curves.easeInOut));
    _rollD6y = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 20, end: -30), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: -30, end: 15), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 15, end: 0),   weight: 30),
    ]).animate(CurvedAnimation(parent: _rollAc, curve: Curves.easeIn));
    _rollRotD4 = Tween<double>(begin: -2.0, end: 0)
        .animate(CurvedAnimation(parent: _rollAc, curve: Curves.easeOut));
    _rollRotD6 = Tween<double>(begin: 2.0, end: 0)
        .animate(CurvedAnimation(parent: _rollAc, curve: Curves.easeOut));

    _revealAc = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 350));
    _revealScale = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _revealAc, curve: Curves.easeOutBack));
    _revealFade = CurvedAnimation(parent: _revealAc, curve: Curves.easeOut);

    _rollAc.forward().then((_) {
      if (mounted) setState(() => _showResult = true);
      _revealAc.forward();
    });
  }

  @override void dispose() {
    _rollAc.dispose(); _revealAc.dispose(); super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(height: 70,
        child: LayoutBuilder(builder: (lctx, constraints) {
          // Les décalages d'animation (initialement en pixels fixes ±60) sont
          // mis à l'échelle selon la largeur réellement disponible — sans
          // ça, deux dés côte à côte (Albane/Boussole, écran étroit) se
          // faisaient déborder/couper par une animation prévue pour un dé
          // seul en pleine largeur.
          final scale = (constraints.maxWidth / 260).clamp(0.35, 1.0);
          return AnimatedBuilder(
            animation: _rollAc,
            builder: (_, __) => Stack(alignment: Alignment.center, children: [
              Transform.translate(
                offset: Offset(_rollD4x.value * scale, _rollD4y.value),
                child: Transform.rotate(angle: _rollRotD4.value,
                  child: _RollingDie(
                    value: widget.d4, label: 'd4',
                    color: widget.isAttack ? kRed : kGold,
                    rolling: !_showResult,
                  )),
              ),
              Transform.translate(
                offset: Offset((_rollD6x.value + 60) * scale, _rollD6y.value),
                child: Transform.rotate(angle: _rollRotD6.value,
                  child: _RollingDie(
                    value: widget.d6, label: 'd6',
                    color: widget.isAttack ? kRed : kGold,
                    rolling: !_showResult,
                  )),
              ),
            ]),
          );
        }),
      ),
      if (_showResult)
        AnimatedBuilder(
          animation: _revealAc,
          builder: (_, child) => FadeTransition(
            opacity: _revealFade,
            child: Transform.scale(scale: _revealScale.value, child: child),
          ),
          child: _buildContent(),
        ),
    ]);
  }

  Widget _buildContent() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: widget.isAttack ? kShadow.withValues(alpha: 0.1) : kGold.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: widget.isAttack
        ? kShadow.withValues(alpha: 0.6) : kGold.withValues(alpha: 0.4)),
    ),
    child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _Face(value: widget.d4, label: 'd4'),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(widget.isAttack ? '−' : '+', style: cinzel(20, c: kTextDim))),
        _Face(value: widget.d6, label: 'd6'),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('=', style: cinzel(20, c: kTextDim))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: (widget.isAttack ? kRed : kGold).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: widget.isAttack ? kRed : kGold),
          ),
          child: Text('${widget.sum}',
            style: cinzel(28, c: widget.isAttack ? kRed : kGold2, fw: FontWeight.w900)),
        ),
      ]),
      const SizedBox(height: 6),
      Text(widget.isAttack
        ? ui('attack_formula3').replaceAll('{d4}', '${widget.d4}').replaceAll('{d6}', '${widget.d6}').replaceAll('{sum}', '${widget.sum}')
        : ui('move_formula3').replaceAll('{d4}', '${widget.d4}').replaceAll('{d6}', '${widget.d6}').replaceAll('{sum}', '${widget.sum}'),
        style: body(11, c: kTextSub)),
      if (!widget.isAttack && widget.sum == 7)
        Padding(padding: const EdgeInsets.only(top: 4),
          child: Text(ui('choose_destination'), style: cinzel(11, c: kGold))),
    ]),
  );
}

class _Face extends StatelessWidget {
  final int value; final String label;
  const _Face({required this.value, required this.label});
  @override
  Widget build(BuildContext ctx) => Container(
    width: 48, height: 48,
    decoration: BoxDecoration(
      color: kBg3, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: kBord2, width: 1.5)),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('$value', style: cinzel(20, c: kGold2, fw: FontWeight.w900)),
      Text(label, style: body(8, c: kTextDim)),
    ]),
  );
}

/// Dé animé — affiche des valeurs aléatoires qui défilent pendant le roll
class _RollingDie extends StatefulWidget {
  final int value;
  final String label;
  final Color color;
  final bool rolling;
  const _RollingDie({required this.value, required this.label,
    required this.color, required this.rolling});
  @override State<_RollingDie> createState() => _RollingDieState();
}

class _RollingDieState extends State<_RollingDie> {
  int _display = 1;
  late final Stream<int> _stream;

  @override
  void initState() {
    super.initState();
    _stream = Stream.periodic(const Duration(milliseconds: 60), (i) => i);
    _stream.listen((i) {
      if (mounted && widget.rolling) {
        setState(() => _display = (i % 6) + 1);
      }
    });
  }

  @override
  Widget build(BuildContext ctx) {
    final shown = widget.rolling ? _display : widget.value;
    return Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        color: kBg3,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.rolling ? kBord2 : widget.color,
          width: widget.rolling ? 1.5 : 2.5),
        boxShadow: widget.rolling ? null : [
          BoxShadow(color: widget.color.withValues(alpha: 0.4), blurRadius: 8)
        ],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('$shown',
          style: cinzel(22,
            c: widget.rolling ? kTextDim : widget.color,
            fw: FontWeight.w900)),
        Text(widget.label, style: body(8, c: kTextDim)),
      ]),
    );
  }
}

/// Carte piochée affichée avec illustration (identique au solo)
class _CardWidget extends StatelessWidget {
  final GameCard card;
  const _CardWidget({required this.card});

  @override
  Widget build(BuildContext ctx) {
    final dc = deckColor(card.deck.name);
    final imgPath = anyCardImagePath(card.effect);

    return EntranceScale(child: Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: dc.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dc.withValues(alpha: 0.6)),
        boxShadow: [BoxShadow(color: dc.withValues(alpha: 0.15), blurRadius: 10)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (imgPath != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 240,
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: Image.asset(imgPath, fit: BoxFit.contain,
                      cacheWidth: 320, cacheHeight: 480,
                      errorBuilder: (_, __, ___) => Container(
                        height: 80, color: dc.withValues(alpha: 0.1),
                        child: Center(child: Text(deckIcon(card.deck.name),
                          style: const TextStyle(fontSize: 40))))),
                  ),
                ),
              ),
            ),
          )
        else
          Container(
            height: 80, width: double.infinity,
            decoration: BoxDecoration(
              color: dc.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Center(child: Text(deckIcon(card.deck.name),
              style: const TextStyle(fontSize: 40))),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(deckLabel(card.deck.name), style: cinzel(9, c: dc, ls: 1)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: dc.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  card.type == CardType.equipement ? ui('card_type_equipment') : ui('card_type_single_use'),
                  style: body(9, c: dc)),
              ),
            ]),
            const SizedBox(height: 6),
            Text(tr(card.name), style: cinzel(15, c: kGold2, fw: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(tr(card.text), style: body(12)),
          ]),
        ),
      ]),
    ));
  }
}

// ═══════════════════════════════════════════════════════════
// CLÉMENCE — Pouvoir Constructeur (multijoueur)
// ═══════════════════════════════════════════════════════════
class _ClemenceBuilderPanel extends StatelessWidget {
  final GameProvider gp;
  final int step;
  final List<String> offered;
  final String? chosen;
  const _ClemenceBuilderPanel({
    required this.gp, required this.step,
    required this.offered, this.chosen});

  @override
  Widget build(BuildContext ctx) {
    final eg = GameEngine.instance;
    const purple = Color(0xFF9B59B6);
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0A2E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: purple, width: 2.5),
        boxShadow: [BoxShadow(color: purple.withValues(alpha: 0.35), blurRadius: 18)],
      ),
      child: Column(children: [
        Text(ui('clemence_title'), style: cinzel(18, c: purple, fw: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(step == 1
          ? ui('choice_1_of_2')
          : ui('choice_2_of_2'),
          style: body(11, c: kTextSub), textAlign: TextAlign.center),
        if (step == 2 && chosen != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: purple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8)),
            child: Text('✅ Effet 1 : ${eg.builderEffectLabel(chosen!)}',
              style: body(11, c: purple)),
          ),
        ],
        const SizedBox(height: 16),
        ...offered.map((eff) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: BHButton(
            label: eg.builderEffectLabel(eff),
            onTap: () => gp.guardedAction(() => gp.clemenceChooseEffect(eff)),
          ),
        )),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// JEANNE — Sélection récompense secrète (multijoueur)
// ═══════════════════════════════════════════════════════════
class _JeanneRewardPanel extends StatelessWidget {
  final GameProvider gp;
  final List<String> rewards;
  const _JeanneRewardPanel({required this.gp, required this.rewards});

  @override
  Widget build(BuildContext ctx) {
    final eg = GameEngine.instance;
    const ruby = Color(0xFFAA1144);
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0A2E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ruby, width: 2.5),
        boxShadow: [BoxShadow(color: ruby.withValues(alpha: 0.35), blurRadius: 18)],
      ),
      child: Column(children: [
        Text('🔮 JEANNE', style: cinzel(18, c: ruby, fw: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(ui('choose_killer_reward'),
          style: body(11, c: kTextSub), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ...rewards.map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: BHButton(
            label: eg.jeanneRewardLabel(r),
            onTap: () => gp.guardedAction(() => gp.jeanneChooseReward(r)),
          ),
        )),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ELAIA — Étape 1 : choisir la pile à regarder (multijoueur)
// ═══════════════════════════════════════════════════════════
class _ElaiaDeckChoicePanel extends StatelessWidget {
  final GameProvider gp;
  const _ElaiaDeckChoicePanel({required this.gp});

  @override
  Widget build(BuildContext ctx) {
    const purple = Color(0xFF6A3FA0);
    final decks = [
      ('tenebres', ui('deck_dark2')),
      ('lumiere',  ui('deck_light2')),
      ('vision',   '🔮 Vision'),
    ];
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kBg2, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: purple, width: 2.5),
        boxShadow: [BoxShadow(color: purple.withValues(alpha: 0.35), blurRadius: 18)],
      ),
      child: Column(children: [
        Text('🔮 ELAIA — PRESCIENCE', style: cinzel(16, c: purple, fw: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(ui('which_pile_to_peek'),
          style: body(11, c: kTextSub), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ...decks.map((d) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: BHButton(label: d.$2, onTap: () => gp.guardedAction(() => gp.elaiaChooseDeck(d.$1))),
        )),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ELAIA — Étape 2 : choisir l'ordre des 2 cartes regardées (multijoueur)
// ═══════════════════════════════════════════════════════════
class _ElaiaOrderPanel extends StatelessWidget {
  final GameProvider gp;
  final GameCard card1, card2;
  const _ElaiaOrderPanel({required this.gp, required this.card1, required this.card2});

  @override
  Widget build(BuildContext ctx) {
    const purple = Color(0xFF6A3FA0);
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kBg2, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: purple, width: 2.5),
        boxShadow: [BoxShadow(color: purple.withValues(alpha: 0.35), blurRadius: 18)],
      ),
      child: Column(children: [
        Text('🔮 ELAIA — ORDRE DE PIOCHE', style: cinzel(14, c: purple, fw: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(ui('choose_first_draw'),
          style: body(11, c: kTextSub), textAlign: TextAlign.center),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _cardPreview(card1)),
          const SizedBox(width: 8),
          Expanded(child: _cardPreview(card2)),
        ]),
        const SizedBox(height: 14),
        BHButton(label: '1️⃣ ${card1.name}  →  2️⃣ ${card2.name}', gold: true,
          onTap: () => gp.guardedAction(() => gp.elaiaConfirmOrder(card1.id, card2.id))),
        const SizedBox(height: 8),
        BHButton(label: '1️⃣ ${card2.name}  →  2️⃣ ${card1.name}', gold: true,
          onTap: () => gp.guardedAction(() => gp.elaiaConfirmOrder(card2.id, card1.id))),
      ]),
    );
  }

  Widget _cardPreview(GameCard c) {
    final dc = deckColor(c.deck.name);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kBg3, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dc.withValues(alpha: 0.6))),
      child: Column(children: [
        Text(deckIcon(c.deck.name), style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 6),
        Text(c.name, style: cinzel(11, c: kGold2, fw: FontWeight.w700),
          textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(c.text, style: body(9, c: kTextSub),
          textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// DAMIEN — Choix alcool fort / poison (multijoueur)
// ═══════════════════════════════════════════════════════════
class _DamienChoicePanel extends StatelessWidget {
  final GameProvider gp;
  final Player target;
  const _DamienChoicePanel({required this.gp, required this.target});

  @override
  Widget build(BuildContext ctx) {
    const wine = Color(0xFF8B0032);
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kBg2, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: wine, width: 2.5),
        boxShadow: [BoxShadow(color: wine.withValues(alpha: 0.35), blurRadius: 18)],
      ),
      child: Column(children: [
        Text('🍸 DAMIEN', style: cinzel(18, c: wine, fw: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(ui('damien_serve_who').replaceAll('{target}', target.name),
          style: body(12, c: kTextSub), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        BHButton(label: ui('btn_strong_liquor'),
          onTap: () => gp.guardedAction(() => gp.damienServeAlcohol())),
        const SizedBox(height: 8),
        BHButton(label: ui('btn_poison'),
          onTap: () => gp.guardedAction(() => gp.damienServePoison())),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// BUTIN — récupérer un équipement d'un joueur éliminé (multijoueur)
// ═══════════════════════════════════════════════════════════
class _LootChoicePanel extends StatelessWidget {
  final GameProvider gp;
  final Player dead;
  const _LootChoicePanel({required this.gp, required this.dead});

  @override
  Widget build(BuildContext ctx) {
    const gold = Color(0xFFB8860B);
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kBg2, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: gold, width: 2.5),
        boxShadow: [BoxShadow(color: gold.withValues(alpha: 0.35), blurRadius: 18)],
      ),
      child: Column(children: [
        Text('🎒 BUTIN', style: cinzel(18, c: gold, fw: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(ui('target_eliminated_loot').replaceAll('{name}', dead.name),
          style: body(12, c: kTextSub), textAlign: TextAlign.center),
        const SizedBox(height: 14),
        ...dead.equipment.asMap().entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: BHButton(label: '📦 ${e.value.name}',
            onTap: () => gp.guardedAction(() => gp.lootChooseItem(e.key))),
        )),
        const SizedBox(height: 6),
        BHButton(label: ui('no_take'), outlined: true, onTap: () => gp.guardedAction(() => gp.lootSkip())),
      ]),
    );
  }
}

// ─── Bannière dés (visible des non-joueurs) ───────────────────────────────────
// ─── Réplique de révélation — visible/audible de tous ────────────────────────
class _RevealQuoteBanner extends StatefulWidget {
  final Player? player;
  final List<Player>? allPlayers; // pour détecter les interactions entre personnages
  const _RevealQuoteBanner({super.key, required this.player, this.allPlayers});
  @override State<_RevealQuoteBanner> createState() => _RevealQuoteBannerState();
}

class _RevealQuoteBannerState extends State<_RevealQuoteBanner> {
  CharInteraction? _interaction;

  @override
  void initState() {
    super.initState();
    // La clé unique (uid + timestamp) garantit que ce initState — donc la
    // lecture du son — ne se déclenche qu'UNE FOIS par révélation, jamais
    // ré-exécuté sur les reconstructions ultérieures du même événement.
    // Jason déguisé : sonne comme le personnage imité. Une fois démasqué
    // (disguiseCharIdOverride==null), sonne comme lui-même.
    final c = widget.player?.character;
    if (c != null) {
      final voiceId = widget.player!.disguiseCharIdOverride ?? c.id;
      audio.playRevealVoice(voiceId);
      // Interaction entre personnages : réplique complémentaire si un autre
      // joueur déjà révélé matche une interaction connue.
      if (widget.allPlayers != null) {
        final otherRevealed = widget.allPlayers!
            .where((p) => p.uid != widget.player!.uid && p.alive && p.revealed && p.character != null)
            .map((p) => p.character!.id).toSet();
        final it = findRevealInteraction(voiceId, otherRevealed);
        if (it != null) {
          _interaction = it;
          Future.delayed(const Duration(milliseconds: 1600), () {
            if (mounted) audio.playInteractionVoice(it.key);
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext ctx) {
    final p = widget.player;
    final c = p?.character;
    if (p == null || c == null) return const SizedBox.shrink();
    // Jason (Caméléon) : affiche le déguisement (Hunter/Shadow imité), pas
    // sa vraie identité, tant qu'il n'a pas été démasqué — même logique que
    // le solo, sans quoi son mécanisme unique serait visuellement ignoré.
    final displayChar = p.disguiseCharIdOverride != null
        ? kAllCharacters.where((ch) => ch.id == p.disguiseCharIdOverride).firstOrNull ?? c
        : c;
    final quoteId = p.disguiseCharIdOverride ?? c.id;
    final fc = factionColor(displayChar.faction.name);
    final fb = factionBg(displayChar.faction.name);
    final imgPath = effectiveCharacterImagePath(displayChar.id);
    final fLabel = displayChar.faction.name == 'hunter' ? ui('faction_hunter')
        : displayChar.faction.name == 'shadow' ? ui('faction_shadow') : ui('faction_neutral');

    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: Colors.black87,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: kBg2,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: fc, width: 3),
                boxShadow: [
                  BoxShadow(color: fc.withValues(alpha: 0.7), blurRadius: 50),
                  BoxShadow(color: fc.withValues(alpha: 0.3), blurRadius: 100),
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(height: 260,
                      child: AspectRatio(aspectRatio: 2 / 3,
                        child: ShineOverlay(
                          tier: shineTierFor(p?.shineWins ?? Prefs.gamesWonWith(displayChar.name)),
                          child: imgPath != null
                            ? Image.asset(imgPath, fit: BoxFit.cover,
                                cacheWidth: 700, cacheHeight: 1050,
                                errorBuilder: (_, __, ___) => Container(color: fb,
                                  child: Center(child: Text(displayChar.icon,
                                    style: const TextStyle(fontSize: 64)))))
                            : Container(color: fb,
                                child: Center(child: Text(displayChar.icon,
                                  style: const TextStyle(fontSize: 64)))),
                        ))))),
                Padding(padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    Text(ui('has_revealed').replaceAll('{name}', p.name),
                      style: cinzel(20, c: fc, fw: FontWeight.w900),
                      textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: fc.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: fc, width: 1.5)),
                      child: Text(fLabel, style: cinzel(13, c: fc, fw: FontWeight.w700))),
                    const SizedBox(height: 8),
                    Text(ui('he_is').replaceAll('{char}', tr(displayChar.name)),
                      style: cinzel(15, c: kGold2, fw: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: kBg3, borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: fc.withValues(alpha: 0.4))),
                      child: Text('« ${revealQuoteFor(quoteId)} »',
                        style: body(12, c: kTextSub, fw: FontWeight.w600),
                        textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    if (_interaction != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: kGold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kGold.withValues(alpha: 0.5))),
                        child: Text('💬 ${_interaction!.text}',
                          style: body(12, c: kGold2, fw: FontWeight.w600),
                          textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _LastDiceBanner extends StatefulWidget {
  final Map<String, int> result;
  final String label;
  final int timestamp;
  const _LastDiceBanner({required this.result, required this.label, required this.timestamp});
  @override State<_LastDiceBanner> createState() => _LastDiceBannerState();
}
class _LastDiceBannerState extends State<_LastDiceBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _opacity;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _opacity = CurvedAnimation(parent: _ac, curve: Curves.easeIn);
    _ac.forward();
    // Auto-dismiss après 3 secondes
    final remaining = 3000 - (DateTime.now().millisecondsSinceEpoch - widget.timestamp);
    final delay = remaining.clamp(500, 3000);
    _timer = Timer(Duration(milliseconds: delay), () {
      if (mounted) _ac.reverse();
    });
  }

  @override void dispose() { _timer?.cancel(); _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    final d4 = widget.result['d4'] ?? 0;
    final d6 = widget.result['d6'] ?? 0;
    final sum = widget.result['sum'] ?? 0;
    return Positioned(
      top: 56, left: 0, right: 0,
      child: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: kBg2.withValues(alpha: 0.97),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: kGold, width: 2),
              boxShadow: [BoxShadow(color: kGold.withValues(alpha: 0.3), blurRadius: 12)],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(widget.label, style: cinzel(12, c: kGold)),
              const SizedBox(height: 6),
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (d4 > 0) ...[
                  _DieFace(value: d4, sides: 4),
                  const SizedBox(width: 10),
                  Text('−', style: cinzel(18, c: kTextSub)),
                  const SizedBox(width: 10),
                ],
                _DieFace(value: d6, sides: 6),
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: kGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kGold)),
                  child: Text('= $sum', style: cinzel(22, c: kGold2, fw: FontWeight.w900)),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

// Bannière de carte piochée par un bot — sur le même modèle que
// _LastDiceBanner ci-dessus : totalement indépendante de GamePhase, pas de
// risque pour la machine à états du tour du bot.
class _LastCardBanner extends StatefulWidget {
  final GameCard card;
  final int timestamp;
  const _LastCardBanner({required this.card, required this.timestamp});
  @override State<_LastCardBanner> createState() => _LastCardBannerState();
}
class _LastCardBannerState extends State<_LastCardBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _opacity;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _opacity = CurvedAnimation(parent: _ac, curve: Curves.easeIn);
    _ac.forward();
    // Auto-dismiss après 4 secondes (le temps de bien voir la carte)
    final remaining = 4000 - (DateTime.now().millisecondsSinceEpoch - widget.timestamp);
    final delay = remaining.clamp(500, 4000);
    _timer = Timer(Duration(milliseconds: delay), () {
      if (mounted) _ac.reverse();
    });
  }

  @override void dispose() { _timer?.cancel(); _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    return Positioned(
      top: 56, left: 0, right: 0,
      child: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: kBg2.withValues(alpha: 0.97),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: kGold, width: 2),
              boxShadow: [BoxShadow(color: kGold.withValues(alpha: 0.3), blurRadius: 12)],
            ),
            child: _CardWidget(card: widget.card),
          ),
        ),
      ),
    );
  }
}

class _DieFace extends StatelessWidget {
  final int value, sides;
  const _DieFace({required this.value, required this.sides});
  @override
  Widget build(BuildContext ctx) => Container(
    width: 42, height: 42,
    decoration: BoxDecoration(
      color: kBg1, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: sides == 4 ? kHunter : kShadow, width: 2.5),
      boxShadow: [BoxShadow(color: (sides == 4 ? kHunter : kShadow).withValues(alpha: 0.3), blurRadius: 6)],
    ),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('$value', style: cinzel(17, c: kGold2, fw: FontWeight.w900)),
      Text('D$sides', style: body(8, c: kTextSub)),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════
// MR CASINO — Pari pair/impair (multijoueur)
// ═══════════════════════════════════════════════════════════
// ─── Bandeau d'état persistant (tour parfait, tours bonus, marquage...) ──────
class _StatusBanner extends StatelessWidget {
  final String message;
  final Color color;
  const _StatusBanner(this.message, this.color);

  @override
  Widget build(BuildContext ctx) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(message, style: body(11, c: color)),
  );
}

// ─── Oscar : écran de choix Eau/Plante/Feu (multijoueur) ─────────────────
// ─── Baptiste : sélection du montant à sacrifier (multijoueur) ──────────
class _MultiBaptisteAmountWidget extends StatefulWidget {
  final GameProvider gp;
  const _MultiBaptisteAmountWidget({required this.gp});
  @override State<_MultiBaptisteAmountWidget> createState() => _MultiBaptisteAmountWidgetState();
}

class _MultiBaptisteAmountWidgetState extends State<_MultiBaptisteAmountWidget> {
  int? _amount;

  int get _maxAmount {
    final me = widget.gp.me;
    if (me?.character == null) return 1;
    final maxHp = me!.character!.hp + me.maxHpModifier;
    return (maxHp - me.wounds).clamp(1, 999);
  }

  @override
  Widget build(BuildContext ctx) {
    final maxAmount = _maxAmount;
    _amount ??= maxAmount;
    if (_amount! > maxAmount) _amount = maxAmount;
    final me = widget.gp.me;
    final maxHp = (me?.character?.hp ?? 0) + (me?.maxHpModifier ?? 0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: surfaceDecor(),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('✝️ Baptiste — Sacrifice', style: cinzel(15, c: kGold2), textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text('Tes PV restants : $maxAmount / $maxHp',
          style: body(12, c: kTextSub), textAlign: TextAlign.center),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
            icon: const Icon(Icons.remove_circle, color: kRed),
            onPressed: _amount! > 1 ? () => setState(() => _amount = _amount! - 1) : null,
          ),
          Container(
            width: 70, alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: kBg3, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kGold, width: 2)),
            child: Text('${_amount!}', style: cinzel(22, c: kGold2, fw: FontWeight.w900)),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, color: kGreen),
            onPressed: _amount! < maxAmount ? () => setState(() => _amount = _amount! + 1) : null,
          ),
        ]),
        const SizedBox(height: 6),
        Text('Le joueur reviendra avec ${_amount!} blessure${_amount! > 1 ? "s" : ""}\nde moins que son maximum de vie',
          style: body(11, c: kTextDim), textAlign: TextAlign.center),
        const SizedBox(height: 14),
        BHButton(label: ui('confirm_sacrifice'), danger: true,
          onTap: () => widget.gp.guardedAction(() => widget.gp.baptisteConfirmAmount(_amount!))),
      ]),
    );
  }
}

class _MultiHaileyChoiceWidget extends StatelessWidget {
  final GameProvider gp;
  const _MultiHaileyChoiceWidget({required this.gp});

  @override
  Widget build(BuildContext ctx) {
    final offeredIds = gp.gameState?.haileyOffered ?? const [];
    final offered = offeredIds
        .map((id) => kAllCharacters.where((c) => c.id == id).firstOrNull)
        .whereType<CharacterCard>()
        .toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: surfaceDecor(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(ui('hailey_copy_title'), style: cinzel(15, c: kGold2), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(ui('hailey_final_choice'),
          style: body(12, c: kTextSub), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        if (offered.isEmpty)
          Padding(padding: const EdgeInsets.all(20),
            child: Text(ui('no_hunter_to_copy'),
              style: body(12, c: kTextDim), textAlign: TextAlign.center)),
        ...offered.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => gp.guardedAction(() => gp.haileyChoice(c.id)),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kBg3, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kGold.withValues(alpha: 0.5))),
              child: Row(children: [
                Text(c.icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr(c.name), style: cinzel(13, c: kGold2, fw: FontWeight.w700)),
                  // IMPORTANT : certaines capacités ont une description
                  // longue — sans limite, ça pouvait faire déborder ce
                  // conteneur (overflow) selon le Hunter proposé.
                  Text(tr(c.ability), style: body(11, c: kTextSub),
                    maxLines: 3, overflow: TextOverflow.ellipsis),
                ])),
              ]),
            ),
          ),
        )),
      ]),
    );
  }
}

class _MultiChristineZoneWidget extends StatelessWidget {
  final GameProvider gp;
  const _MultiChristineZoneWidget({required this.gp});

  @override
  Widget build(BuildContext ctx) {
    final myZoneIdx = gp.me?.zoneIndex ?? 0;
    final adj = kAdjacences[myZoneIdx];
    final layout = gp.gameState?.terrainLayout ?? const [];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: surfaceDecor(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('🗺️ Christine — Choisissez votre prochain terrain', style: cinzel(15, c: kGold2), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        ...adj.map((idx) {
          final terrain = idx < layout.length ? layout[idx] : null;
          final dv = DrunkVision.forViewer(gp.me);
          final playersHere = (gp.gameState?.playerOrder ?? const [])
              .map((uid) => gp.players[uid])
              .where((p) => p != null && p.alive && p.zoneIndex == idx)
              .map((p) => dv?.tokenFor(p!.uid) ?? p!.token).join(' ');
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: BHButton(
              label: 'Zone ${idx + 1} — ${terrain?.icon ?? ""} ${terrain?.name ?? ""}${playersHere.isNotEmpty ? "  ($playersHere)" : ""}',
              onTap: () => gp.guardedAction(() => gp.christineChooseZone(idx)),
            ),
          );
        }),
      ]),
    );
  }
}

class _MultiTristanGiveWidget extends StatelessWidget {
  final GameProvider gp;
  const _MultiTristanGiveWidget({required this.gp});

  @override
  Widget build(BuildContext ctx) {
    final me = gp.me;
    final equipment = me?.equipment ?? const [];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: surfaceDecor(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(ui('tristan_which_give'), style: cinzel(15, c: kGold2), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        ...equipment.asMap().entries.map((entry) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: BHButton(
            label: entry.value.name,
            onTap: () => gp.guardedAction(() => gp.tristanChooseGive(entry.key)),
          ),
        )),
      ]),
    );
  }
}

class _MultiTristanReceiveWidget extends StatelessWidget {
  final GameProvider gp;
  const _MultiTristanReceiveWidget({required this.gp});

  @override
  Widget build(BuildContext ctx) {
    final targetUid = gp.gameState?.tristanTargetUid;
    final target = targetUid != null ? gp.players[targetUid] : null;
    final equipment = target?.equipment ?? const [];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: surfaceDecor(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(ui('tristan_which_receive').replaceAll('{target}', target?.name ?? '?'),
          style: cinzel(15, c: kGold2), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        ...equipment.asMap().entries.map((entry) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: BHButton(
            label: entry.value.name,
            onTap: () => gp.guardedAction(() => gp.tristanChooseReceive(entry.key)),
          ),
        )),
      ]),
    );
  }
}

class _MultiMegChoiceWidget extends StatelessWidget {
  final GameProvider gp;
  const _MultiMegChoiceWidget({required this.gp});

  @override
  Widget build(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: surfaceDecor(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(ui('meg_choose_form_title'), style: cinzel(15, c: kGold2), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(ui('meg_form_auto_alternate'),
          style: body(12, c: kTextSub), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        BHButton(label: ui('btn_form_offensive'), gold: true,
          onTap: () => gp.guardedAction(() => gp.megChooseForm('offense'))),
        const SizedBox(height: 8),
        BHButton(label: ui('btn_form_defensive'), outlined: true,
          onTap: () => gp.guardedAction(() => gp.megChooseForm('defense'))),
      ]),
    );
  }
}

class _MultiOscarChoiceWidget extends StatelessWidget {
  final GameProvider gp;
  const _MultiOscarChoiceWidget({required this.gp});

  @override
  Widget build(BuildContext ctx) {
    final xp = gp.me?.oscarXp ?? 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: surfaceDecor(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(ui('oscar_spend_xp_title'), style: cinzel(15, c: kGold2), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text('XP actuelle : $xp', style: body(13, c: kGold), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        _MultiOscarOption(icon: '💧', label: 'Eau', cost: 3, xp: xp,
          desc: ui('steal_equip_choice'),
          onTap: () => gp.guardedAction(() => gp.oscarChoice('water'))),
        const SizedBox(height: 8),
        _MultiOscarOption(icon: '🌿', label: 'Plante', cost: 2, xp: xp,
          desc: ui('heals_2_wounds'),
          onTap: () => gp.guardedAction(() => gp.oscarChoice('plant'))),
        const SizedBox(height: 8),
        _MultiOscarOption(icon: '🔥', label: 'Feu', cost: 4, xp: xp,
          desc: ui('oscar_fire_desc'),
          onTap: () => gp.guardedAction(() => gp.oscarChoice('fire'))),
        const SizedBox(height: 10),
        BHButton(label: ui('no_spend'), outlined: true,
          onTap: () => gp.guardedAction(() => gp.fb.setPhase(gp.roomId!, GamePhase.move, clearPending: true))),
      ]),
    );
  }
}

class _MultiOscarOption extends StatelessWidget {
  final String icon, label, desc;
  final int cost, xp;
  final VoidCallback onTap;
  const _MultiOscarOption({required this.icon, required this.label, required this.cost,
    required this.xp, required this.desc, required this.onTap});

  @override
  Widget build(BuildContext ctx) {
    final affordable = xp >= cost;
    return GestureDetector(
      onTap: affordable ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: affordable ? kBg3 : kBg2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: affordable ? kGold.withValues(alpha: 0.5) : kBord)),
        child: Row(children: [
          Text(icon, style: TextStyle(fontSize: 22, color: affordable ? null : kTextDim)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$label — ${cost}xp',
                style: cinzel(13, c: affordable ? kGold2 : kTextDim, fw: FontWeight.w700)),
              Text(desc, style: body(11, c: affordable ? kTextSub : kTextDim)),
            ]),
          ),
          if (!affordable) const Icon(Icons.lock, size: 16, color: kTextDim),
        ]),
      ),
    );
  }
}

class _MultiCasinoWidget extends StatefulWidget {
  final GameProvider gp;
  final VoidCallback? onDone;
  const _MultiCasinoWidget({required this.gp, this.onDone});
  @override State<_MultiCasinoWidget> createState() => _MultiCasinoWidgetState();
}
class _MultiCasinoWidgetState extends State<_MultiCasinoWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  bool? _bet;      // true = Impair, false = Pair
  int? _result;
  bool? _won;
  bool _rolling = false;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  }
  @override void dispose() { _ac.dispose(); super.dispose(); }

  void _roll(bool betOdd) {
    if (_rolling) return;
    setState(() { _bet = betOdd; _result = null; _won = null; _rolling = true; });
    _ac.forward(from: 0).then((_) {
      final d = GameEngine.instance.rollD6();
      setState(() { _result = d; _won = betOdd == (d % 2 == 1); _rolling = false; });
    });
  }

  @override
  Widget build(BuildContext ctx) {
    const gold = Color(0xFFD4AF37);
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: gold, width: 2),
      ),
      child: Column(children: [
        Text('🎰 MR CASINO', style: cinzel(18, c: gold, fw: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(ui('bet_odd_even'), style: body(12, c: kTextSub)),
        const SizedBox(height: 16),
        if (_result == null) ...[
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: BHButton(label: ui('btn_even'), onTap: () => _roll(false)))),
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: BHButton(label: ui('btn_odd'), onTap: () => _roll(true)))),
          ]),
        ] else ...[
          Text(ui('casino_result').replaceAll('{n}', '$_result').replaceAll('{parity}', (_result! % 2 == 0) ? '(${ui('even_simple')})' : '(${ui('odd_simple')})'),
            style: cinzel(20, c: _won! ? Colors.greenAccent : kRed,
              fw: FontWeight.w900)),
          const SizedBox(height: 8),
          if (_won!)
            Text(ui('won_choose_target'), style: body(12, c: Colors.greenAccent))
          else
            Text(ui('lost_take2'), style: body(12, c: kRed)),
          const SizedBox(height: 12),
          BHButton(
            label: _won! ? ui('btn_choose_target_short') : ui('btn_take2_short'),
            gold: _won!,
            danger: !_won!,
            onTap: () {
              if (_won!) {
                widget.onDone?.call();
                widget.gp.guardedAction(() => widget.gp.casinoWin());
              } else {
                widget.onDone?.call();
                widget.gp.guardedAction(() => widget.gp.casinoLose());
              }
            },
          ),
        ],
      ]),
    );
  }
}

// ─── Gège Fantôme overlay ─────────────────────────────────────────────────────
class _GegeGhostOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const _GegeGhostOverlay({required this.onDone});
  @override State<_GegeGhostOverlay> createState() => _GegeGhostOverlayState();
}
class _GegeGhostOverlayState extends State<_GegeGhostOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _opacity;
  late Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 25),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 25),
    ]).animate(_ac);
    _slide = Tween(begin: 0.0, end: -60.0).animate(
      CurvedAnimation(parent: _ac, curve: Curves.easeOut));
    _ac.forward().then((_) => widget.onDone());
  }
  @override void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) => AnimatedBuilder(
    animation: _ac,
    builder: (_, __) => Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Transform.translate(
            offset: Offset(0, _slide.value),
            child: Opacity(
              opacity: _opacity.value,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('👻', style: TextStyle(fontSize: 72)),
                const SizedBox(height: 8),
                Text(ui('gege_attacks'),
                  style: TextStyle(fontSize: 18, color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black, blurRadius: 8)])),
              ]),
            ),
          ),
        ),
      ),
    ),
  );
}


// ═══════════════════════════════════════════════════════════
// RICHARD II — Animation d'échange de terrains
// ═══════════════════════════════════════════════════════════
class _RichardSwapOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const _RichardSwapOverlay({required this.onDone});
  @override State<_RichardSwapOverlay> createState() => _RichardSwapOverlayState();
}
class _RichardSwapOverlayState extends State<_RichardSwapOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _ac.forward().then((_) { if (mounted) widget.onDone(); });
  }
  @override void dispose() { _ac.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext ctx) {
    const purple = Color(0xFF9B59B6);
    return AnimatedBuilder(
      animation: _ac,
      builder: (_, __) {
        final t = _ac.value;
        final opacity = (t < 0.1 ? t * 10 : t > 0.85 ? (1 - t) / 0.15 : 1.0).clamp(0.0, 1.0);
        final offset1 = Offset(lerpDouble(-80, 80, t)!, 0);
        final offset2 = Offset(lerpDouble(80, -80, t)!, 0);
        final particles = List.generate(12, (i) {
          final angle = (i / 12) * 6.28 + t * 3.14;
          final r = 80 + 40 * t;
          return Offset(cos(angle) * r, sin(angle) * r * 0.5);
        });
        return Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: CustomPaint(
                painter: _SwapPainter(offset1, offset2, particles, purple, t),
                child: Center(
                  child: Text('👑', style: TextStyle(
                    fontSize: 48 + 20 * sin(t * 3.14),
                    shadows: [Shadow(color: purple.withValues(alpha: 0.8), blurRadius: 20)],
                  )),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SwapPainter extends CustomPainter {
  final Offset o1, o2;
  final List<Offset> particles;
  final Color color;
  final double t;
  _SwapPainter(this.o1, this.o2, this.particles, this.color, this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;
    paint.color = color.withValues(alpha: 0.5);
    final rect1 = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center + o1, width: 60, height: 60), const Radius.circular(10));
    canvas.drawRRect(rect1, paint);
    final rect2 = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center + o2, width: 60, height: 60), const Radius.circular(10));
    canvas.drawRRect(rect2, paint);
    paint.color = color.withValues(alpha: 0.6 * (1 - t));
    for (final p in particles) { canvas.drawCircle(center + p, 4, paint); }
  }
  @override bool shouldRepaint(_SwapPainter old) => true;
}

// ═══════════════════════════════════════════════════════════
// MATHIEU — Animation point qui fonce sur l'écran (3e attaque)
// ═══════════════════════════════════════════════════════════
class _MathieuBulletOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const _MathieuBulletOverlay({required this.onDone});
  @override State<_MathieuBulletOverlay> createState() => _MathieuBulletOverlayState();
}
class _MathieuBulletOverlayState extends State<_MathieuBulletOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scale = Tween(begin: 0.05, end: 4.0).animate(
      CurvedAnimation(parent: _ac, curve: Curves.easeIn));
    _opacity = TweenSequence([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_ac);
    _ac.forward().then((_) { if (mounted) widget.onDone(); });
  }
  @override void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) => AnimatedBuilder(
    animation: _ac,
    builder: (_, __) => Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: _opacity.value,
          child: Center(
            child: Transform.scale(
              scale: _scale.value,
              child: Container(
                width: 60, height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFCC0000),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0x88FF0000), blurRadius: 30, spreadRadius: 10)],
                ),
                child: const Center(child: Text('⚔️', style: TextStyle(fontSize: 28))),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════
// SCOTT — Animation contre-attaque
// ═══════════════════════════════════════════════════════════
class _ScottCounterOverlay extends StatefulWidget {
  final VoidCallback onDone;
  final Map<String, int>? dice;
  const _ScottCounterOverlay({super.key, required this.onDone, this.dice});
  @override State<_ScottCounterOverlay> createState() => _ScottCounterOverlayState();
}
class _ScottCounterOverlayState extends State<_ScottCounterOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _opacity;
  late Animation<double> _scale;
  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_ac);
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.3, end: 1.2), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _ac, curve: Curves.elasticOut));
    _ac.forward().then((_) { if (mounted) widget.onDone(); });
  }
  @override void dispose() { _ac.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext ctx) => AnimatedBuilder(
    animation: _ac,
    builder: (_, __) => Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: _opacity.value,
          child: Center(
            child: Transform.scale(
              scale: _scale.value,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('🛡️', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 8),
                Text(ui('counter_attack_bang'), style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900, color: Colors.orange,
                  shadows: [Shadow(color: Colors.black, blurRadius: 8)])),
                if (widget.dice != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: kBg1.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      ui('dice_result_dmg').replaceAll('{d4}', '${widget.dice!['d4']}').replaceAll('{d6}', '${widget.dice!['d6']}').replaceAll('{dmg}', '${widget.dice!['dmg']}'),
                      style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
    ),
  );
}

// ─── PlayerChip : version compacte pour mobile horizontal ────────────────────
// Journal persistant, toujours visible en bas de l'écran mobile — sur le
// même modèle que _LogStrip en solo (avant : caché derrière un bouton 📜,
// il fallait l'ouvrir manuellement pour voir ce qui venait de se passer).
class _MultiLogStrip extends StatelessWidget {
  final GameProvider gp;
  const _MultiLogStrip({required this.gp});
  @override
  Widget build(BuildContext ctx) {
    // IMPORTANT : tant qu'un joueur est ivre (Maxence), le journal est
    // entièrement masqué — sinon les messages passés/récents pourraient
    // laisser deviner qui a été visé ou comment il se comporte.
    final viewerDrunk = (gp.me?.drunkTurnsRemaining ?? 0) > 0;
    if (viewerDrunk) {
      return Container(
        color: kBg1,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(ui('log_hidden_drunk'), style: body(11, c: kTextDim),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      );
    }
    final logs = gp.log.reversed.take(2).toList();
    return Container(
      color: kBg1,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: logs.map((entry) {
          final sep = entry.indexOf('||');
          final cls = sep >= 0 ? entry.substring(0, sep) : '';
          final msg = sep >= 0 ? entry.substring(sep + 2) : entry;
          return Text(resolveLog(msg),
            style: TextStyle(fontSize: 11, color: switch (cls) {
              'death' => kRed, 'important' => kGold,
              'player' => kGreen, _ => kTextSub,
            }),
            maxLines: 1, overflow: TextOverflow.ellipsis);
        }).toList()),
    );
  }
}

// ─── Journal PC : version spacieuse avec défilement, affichant beaucoup
// plus d'entrées que la version compacte mobile — profite de l'espace
// vertical disponible dans la colonne de gauche du nouveau layout PC. ───
class _MultiLogPanel extends StatelessWidget {
  final GameProvider gp;
  const _MultiLogPanel({required this.gp});
  @override
  Widget build(BuildContext ctx) {
    final viewerDrunk = (gp.me?.drunkTurnsRemaining ?? 0) > 0;
    if (viewerDrunk) {
      return Container(
        color: kBg1,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ui('log_title2'), style: cinzel(11, c: kGold2, fw: FontWeight.w700, ls: 1)),
          const SizedBox(height: 8),
          Text(ui('log_hidden_drunk'), style: body(11, c: kTextDim)),
        ]),
      );
    }
    final logs = gp.log.reversed.toList();
    return Container(
      color: kBg1,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(ui('log_title2'), style: cinzel(11, c: kGold2, fw: FontWeight.w700, ls: 1)),
        const SizedBox(height: 4),
        Expanded(
          child: ListView.builder(
            reverse: false,
            itemCount: logs.length,
            itemBuilder: (lctx, i) {
              final entry = logs[i];
              final sep = entry.indexOf('||');
              final cls = sep >= 0 ? entry.substring(0, sep) : '';
              final msg = sep >= 0 ? entry.substring(sep + 2) : entry;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(resolveLog(msg),
                  style: TextStyle(fontSize: 12, color: switch (cls) {
                    'death' => kRed, 'important' => kGold,
                    'player' => kGreen, _ => kTextSub,
                  })),
              );
            },
          ),
        ),
      ]),
    );
  }
}


// ═══════════════════════════════════════════════════════════
// FIFI — Sélecteur de dés (multijoueur)
// ═══════════════════════════════════════════════════════════
class _MultiFifiDiceWidget extends StatefulWidget {
  final GameProvider gp;
  const _MultiFifiDiceWidget({required this.gp});
  @override State<_MultiFifiDiceWidget> createState() => _MultiFifiDiceWidgetState();
}
class _MultiFifiDiceWidgetState extends State<_MultiFifiDiceWidget> {
  int _move = 7;
  int _atk  = 5;

  @override
  Widget build(BuildContext ctx) {
    const green = Color(0xFF4CAF50);
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kBg2, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: green, width: 2.5),
        boxShadow: [BoxShadow(color: green.withValues(alpha: 0.3), blurRadius: 14)],
      ),
      child: Column(children: [
        Text('🍀 FIFI', style: cinzel(20, c: green, fw: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(ui('choose_values_this_turn'),
          style: body(12, c: kTextSub), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        // Déplacement
        Text(ui('movement_label').replaceAll('{n}', '$_move'), style: cinzel(13, c: kGold2)),
        Slider(
          value: _move.toDouble(), min: 2, max: 10,
          divisions: 8, label: '$_move',
          activeColor: kGold2,
          onChanged: (v) => setState(() => _move = v.toInt()),
        ),
        const SizedBox(height: 12),
        // Attaque
        Text(ui('attack_dmg_label').replaceAll('{n}', '$_atk'), style: cinzel(13, c: kRed)),
        Slider(
          value: _atk.toDouble(), min: 0, max: 5,
          divisions: 5, label: '$_atk',
          activeColor: kRed,
          onChanged: (v) => setState(() => _atk = v.toInt()),
        ),
        const SizedBox(height: 20),
        BHButton(
          label: ui('btn_confirm_move_atk').replaceAll('{move}', '$_move').replaceAll('{atk}', '$_atk'),
          gold: true,
          onTap: () => widget.gp.guardedAction(() => widget.gp.fifiConfirmChoices(_move, _atk)),
        ),
      ]),
    );
  }
}

// ─── Sélection du pool de personnages (hôte uniquement) ────────────────────
class CharacterPoolScreen extends StatefulWidget {
  const CharacterPoolScreen({super.key});
  @override
  State<CharacterPoolScreen> createState() => _CharacterPoolScreenState();
}

class _CharacterPoolScreenState extends State<CharacterPoolScreen> {
  Set<String>? _selected; // null tant que le chargement initial n'est pas fait
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final gp = context.read<GameProvider>();
    await gp.fetchEnabledCharacters();
    final current = gp.enabledCharacterIds;
    setState(() {
      // Liste vide/absente côté serveur = tous activés par défaut.
      _selected = (current == null || current.isEmpty)
          ? kAllCharacters.map((c) => c.id).toSet()
          : current.toSet();
      _loading = false;
    });
  }

  void _toggle(String id) => setState(() {
    if (_selected!.contains(id)) { _selected!.remove(id); } else { _selected!.add(id); }
  });

  void _selectAll() => setState(() => _selected = kAllCharacters.map((c) => c.id).toSet());
  void _selectNone() => setState(() => _selected = {});

  Future<void> _save() async {
    final gp = context.read<GameProvider>();
    // Liste vide ou tous sélectionnés → on envoie une liste vide (= "tous",
    // comportement par défaut) plutôt qu'une énumération complète inutile.
    final all = kAllCharacters.map((c) => c.id).toSet();
    final toSave = (_selected!.isEmpty || _selected!.length == all.length)
        ? <String>[] : _selected!.toList();
    await gp.updateEnabledCharacters(toSave);
    if (mounted) Navigator.pop(context);
  }

  Widget _buildFactionSection(Faction faction, String label) {
    final chars = kAllCharacters.where((c) => c.faction == faction).toList();
    final fc = factionColor(faction.name);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(label, style: cinzel(12, c: fc, ls: 1)),
      ),
      ...chars.map((c) {
        final sel = _selected!.contains(c.id);
        return GestureDetector(
          onTap: () => _toggle(c.id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? fc.withValues(alpha: 0.10) : kBg3,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: sel ? fc.withValues(alpha: 0.5) : kBord2),
            ),
            child: Row(children: [
              Icon(sel ? Icons.check_box : Icons.check_box_outline_blank,
                color: sel ? fc : kTextDim, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(tr(c.name),
                style: body(13, c: sel ? kText : kTextDim))),
            ]),
          ),
        );
      }),
    ]);
  }

  @override
  Widget build(BuildContext ctx) {
    if (_loading || _selected == null) {
      return Scaffold(backgroundColor: kBg0,
        appBar: AppBar(backgroundColor: kBg2, elevation: 0,
          title: Text(ui('char_pool_title'), style: cinzel(16, c: kGold2))),
        body: const Center(child: CircularProgressIndicator(color: kGold)));
    }
    return Scaffold(
      backgroundColor: kBg0,
      appBar: AppBar(backgroundColor: kBg2, elevation: 0,
        title: Text(ui('char_pool_title'), style: cinzel(16, c: kGold2))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(child: Text(
              ui('char_pool_selected_count').replaceAll('{n}', '${_selected!.length}').replaceAll('{total}', '${kAllCharacters.length}'),
              style: body(12, c: kTextSub))),
            TextButton(onPressed: _selectAll, child: Text(ui('btn_select_all'), style: body(11, c: kGold))),
            TextButton(onPressed: _selectNone, child: Text(ui('btn_select_none'), style: body(11, c: kTextSub))),
          ]),
        ),
        Expanded(child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          children: [
            _buildFactionSection(Faction.hunter, ui('faction_hunter')),
            _buildFactionSection(Faction.shadow, ui('faction_shadow')),
            _buildFactionSection(Faction.neutral, ui('faction_neutral')),
            const SizedBox(height: 14),
          ],
        )),
        Container(color: kBg2, padding: const EdgeInsets.all(14),
          child: BHButton(
            label: ui('btn_save_selection'),
            onTap: _selected!.length < 4 ? null : _save,
            gold: _selected!.length >= 4,
          )),
        if (_selected!.length < 4)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(ui('char_pool_min_warning'), style: body(10, c: kRed)),
          ),
      ]),
    );
  }
}
