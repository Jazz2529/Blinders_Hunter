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
import '../models/models.dart';
import '../widgets/theme.dart';
import '../widgets/token_widget.dart';
import '../widgets/terrain_widget.dart';
import '../widgets/ability_animations.dart';
import '../data/tokens_data.dart';
import '../data/characters_data.dart';
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
      if (n < 4) {
        startLabel = '⏳ En attente de joueurs ($n/4 minimum)';
      } else if (!allReady) {
        final notReady = gp.players.values.where((p) => !p.isReady).length;
        startLabel = '⏳ En attente — $notReady joueur(s) pas prêt(s)';
      } else {
        startLabel = '⚔  Lancer la partie ($n joueurs)';
      }
      return Scaffold(
        backgroundColor:kBg0,
        appBar:AppBar(
          backgroundColor:kBg2, elevation:0,
          title:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Lobby',style:cinzel(16,c:kGold2)),
            GestureDetector(
              onTap:(){
                Clipboard.setData(ClipboardData(text:gp.roomId??''));
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content:Text('Code copié !'),backgroundColor:Color(0xFF1C1309)));
              },
              child:Text('Code : ${gp.roomId??"—"}  📋',style:body(12,c:kTextSub).copyWith(letterSpacing:3)),
            ),
          ]),
          actions:[
            IconButton(
              icon: const Icon(Icons.exit_to_app, color: kTextSub),
              tooltip: 'Quitter la salle',
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
            const SectionLabel('JOUEURS'),
            ...gp.players.values.map((p)=>_PlayerTile(p:p,isMe:p.uid==gp.myUid)),
            const SizedBox(height:16),
            const SectionLabel('TON JETON'),
            const SizedBox(height:10),
            SizedBox(height:56, child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: kAllTokens.length,
              itemBuilder: (_, i) {
                final t = kAllTokens[i];
                final usedByOther = gp.players.values
                    .any((p) => p.uid != gp.myUid && p.token == t.id);
                final sel = t.id == gp.me?.token;
                return GestureDetector(
                  onTap: usedByOther ? null : () => gp.changeToken(t.id),
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
          ])),
          Container(color:kBg2,padding:const EdgeInsets.all(14),child:Column(children:[
            if (gp.isHost)
              BHButton(
                label: startLabel,
                onTap: canStart ? gp.startGame : null,
                gold: canStart,
              ),
            const SizedBox(height:8),
            BHButton(
              label:gp.me?.isReady==true?'✓ Prêt — annuler ?':'Se marquer prêt',
              onTap:()=>gp.setReady(!(gp.me?.isReady??false)),
              outlined:true,
            ),
          ])),
        ]),
      );
    },
  );
}

class _PlayerTile extends StatelessWidget {
  final Player p; final bool isMe;
  const _PlayerTile({required this.p,required this.isMe});

  @override
  Widget build(BuildContext ctx) => Container(
    margin:const EdgeInsets.only(bottom:8),
    padding:const EdgeInsets.all(12),
    decoration:surfaceDecor(border:isMe?kGold:kBord2),
    child:Row(children:[
      TokenWidget(tokenId: p.token, size: 36),
      const SizedBox(width:12),
      Expanded(child:Text(p.name,style:body(15,fw:FontWeight.w600))),
      if(p.isReady) Container(
        padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),
        decoration:BoxDecoration(color:kGreen.withOpacity(0.15),
          borderRadius:BorderRadius.circular(20),border:Border.all(color:kGreen)),
        child:Text('Prêt',style:cinzel(11,c:kGreen)),
      ),
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
            Text('Carte Secrète',style:cinzel(11,c:kTextSub.withOpacity(0.6),ls:3)),
            Text(me!.name,style:cinzel(20,c:kGold2)),
            const SizedBox(height:20),
            Container(
              width:100,height:100,
              decoration:BoxDecoration(shape:BoxShape.circle,
                border:Border.all(color:fc,width:3),
                gradient:RadialGradient(colors:[fc.withOpacity(0.2),kBg2])),
              child:Center(child:Text(c.icon,style:const TextStyle(fontSize:48))),
            ),
            const SizedBox(height:12),
            Text(c.name,style:cinzel(22,c:kGold2,fw:FontWeight.w900)),
            const SizedBox(height:6),
            FactionBadge(c.faction.name),
            const SizedBox(height:6),
            Text('${c.hp} PV',style:cinzel(16,c:kGold)),
            const SizedBox(height:14),
            _InfoBox(icon:'⚡',label:'CAPACITÉ UNIQUE',text:c.ability),
            const SizedBox(height:8),
            _InfoBox(icon:'🏆',label:'CONDITION DE VICTOIRE',text:c.winCondition),
            const SizedBox(height:20),
            Text('⚠️ Ne montre pas ton écran !',
              style:body(12,c:kTextDim).copyWith(fontStyle:FontStyle.italic)),
            const SizedBox(height:24),
            if (!_confirmed)
              BHButton(label:'✅ J\'ai vu mon rôle — Continuer', gold:true, onTap: () async {
                setState(() => _confirmed = true);
                await gp.confirmRoleReveal();
              })
            else
              Column(children:[
                const SizedBox(
                  width:28, height:28,
                  child: CircularProgressIndicator(color: kGold, strokeWidth: 2.5)),
                const SizedBox(height:10),
                Text('En attente des autres joueurs (${gp.roleConfirms}/${gp.players.length})...',
                  style: body(12, c: kTextSub)),
              ]),
          ]),
        ))),
      );
    },
  );
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
class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  // Garde-fou pour éviter d'ouvrir le même dialogue plusieurs fois lors des
  // re-renders répétés (polling REST) tant que l'état pending reste actif.
  static String? _shownPunishFor;
  static String? _shownRevealFor;

  @override
  Widget build(BuildContext ctx) => Consumer<GameProvider>(
    builder:(_, gp, __) {
      final isMyTurn = gp.isMyTurn;
      final gs = gp.gameState;
      final playerData = gp.playerList.where((p) => p.alive).map((p) => {
        'zoneIndex': p.zoneIndex,
        'tokenId': p.token,
        'alive': p.alive,
        'revealed': p.revealed,
        'faction': p.character?.faction.name ?? '',
      }).toList();

      // Divination X ou Y : si JE suis la cible en attente, propose le choix.
      final punishKey = gs?.pendingPunishTargetUid;
      if (punishKey == gp.myUid && gs?.pendingPunishActorUid != null &&
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
      final baseScaffold = Scaffold(
        backgroundColor:kBg0,
        appBar:AppBar(
          backgroundColor:kBg2,elevation:0,
          title:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(isMyTurn?'⚔️ Ton tour':'⌛ Tour de ${gp.currentPlayer?.name??"—"}',
              style:cinzel(15,c:isMyTurn?kGold2:kTextSub)),
            Text(_phaseLabel(gp.phase),style:body(11,c:kTextSub)),
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
              ? (screenH * 0.22).clamp(120.0, 190.0)
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

          // ── LAYOUT TÉLÉPHONE : plateau compact, joueurs en ligne, action max ──
          if (isMobile) {
            return Column(children: [
              if (gs != null) boardWidget(),
              SizedBox(
                height: 62,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  children: gp.playerList.map((p) => _PlayerChip(p: p, gp: gp)).toList(),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    color: kBg2,
                    child: isMyTurn ? _ActionPanel(gp: gp) : _WaitPanel(gp: gp),
                  ),
                ),
              ),
            ]);
          }

          // ── LAYOUT PC : inchangé ──
          return Column(children:[
          if (gs != null) boardWidget(),
          Expanded(child: screenW > 600
            ? GridView.count(
                crossAxisCount: 2, childAspectRatio: 4.5,
                padding: const EdgeInsets.all(8), mainAxisSpacing: 4, crossAxisSpacing: 4,
                children: gp.playerList.map((p) => _PlayerRow(p: p, gp: gp)).toList(),
              )
            : ListView(
                padding: const EdgeInsets.all(8),
                children: gp.playerList.map((p) => _PlayerRow(p: p, gp: gp)).toList(),
              )),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: screenH * 0.45),
            child: SingleChildScrollView(
              child: Container(
                color: kBg2,
                child: isMyTurn ? _ActionPanel(gp: gp) : _WaitPanel(gp: gp),
              ),
            ),
          ),
        ]);}),
      );

      if (overlay == null && diceResult == null && lastDice == null) return baseScaffold;

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
        if (overlay == 'oceane_notes')        OceaneNotesOverlay(onDone: clearOverlay),
        if (overlay == 'raph_petals')         RaphPetalsOverlay(onDone: clearOverlay),
        if (overlay == 'monkey_demon_eyes')   MonkeyDemonEyesOverlay(onDone: clearOverlay),
        if (overlay == 'gege_ghost')          _GegeGhostOverlay(onDone: clearOverlay),
        if (overlay == 'richard2_swap')       _RichardSwapOverlay(onDone: clearOverlay),
        if (overlay == 'scott_counter')         _ScottCounterOverlay(onDone: clearOverlay),
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
      ]);
    },
  );

  void _showPunishChoiceDialog(BuildContext ctx, GameProvider gp) {
    final me = gp.me;
    final hasEquip = me != null && me.equipment.isNotEmpty;
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dctx) => AlertDialog(
        backgroundColor: kBg2,
        title: Text('🔮 Une Vision te vise', style: cinzel(15, c: kGold2)),
        content: Text(
          hasEquip
            ? 'Donne une carte équipement, ou subis 1 blessure.'
            : "Tu n'as aucun équipement — tu vas subir 1 blessure.",
          style: body(13, c: kTextSub)),
        actions: [
          if (hasEquip)
            TextButton(
              onPressed: () { Navigator.pop(dctx); gp.resolvePunishChoice(true); },
              child: Text('⚔️ Donner un équipement', style: cinzel(12, c: kGold)),
            ),
          TextButton(
            onPressed: () { Navigator.pop(dctx); gp.resolvePunishChoice(false); },
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
            Text('🔮 Vision Suprême', style: cinzel(13, c: kGold)),
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
      case GamePhase.ability:     return '⚡ Capacité';
      case GamePhase.move:        return '🚶 Déplacement';
      case GamePhase.zoneEffect:  return '🗺️ Effet de terrain';
      case GamePhase.cardDrawn:   return '🃏 Carte piochée';
      case GamePhase.cardChoice:  return '🏪 Choix du Marché';
      case GamePhase.chooseTarget:return '🎯 Choix de cible';
      case GamePhase.attack:      return '⚔️ Attaque';
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
          Text('🎲 RÉFÉRENCE DES DÉS', style: cinzel(14, c: kGold, fw: FontWeight.w900)),
          const SizedBox(height: 16),
          Text('DÉPLACEMENT (D4 − D6)', style: cinzel(11, c: kGold2)),
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
          Text('D4 : 1-4  ×  D6 : 1-6  → somme 2-10', style: body(10, c: kTextSub)),
          const Divider(height: 20, color: Colors.white12),
          Text('ATTAQUE |D4 − D6|', style: cinzel(11, c: kRed)),
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
          Text('D4 : 1-4  ×  D6 : 1-6  → |D4−D6| = 0-5', style: body(10, c: kTextSub)),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('Fermer', style: body(13, c: kGold)))),
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
          Text('📜 JOURNAL', style: cinzel(13, c: kGold)),
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
                  Text('🔒 Infos secrètes (visibles seulement par toi)',
                    style: body(10, c: const Color(0xFF9B59B6))),
                  const SizedBox(height: 4),
                  ...gp.privateLog.reversed.map((m) =>
                    Text(m, style: body(11, c: const Color(0xFFCE93D8)))),
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
                child: Text(msg, style: body(12, c: c)),
              );
            },
          )),
        ]),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final Player p; final GameProvider gp;
  const _PlayerRow({required this.p,required this.gp});

  void _showCard(BuildContext ctx) {
    final c = p.character;
    if (c == null) return;
    final isMe = p.uid == gp.myUid;
    final hasDisguise = !isMe && p.disguiseNameOverride != null;
    // Trouver le personnage imité pour afficher sa vraie carte
    final disguisedCharId = p.disguiseCharIdOverride;
    final disguisedChar = disguisedCharId != null
        ? kAllCharacters.where((ch) => ch.id == disguisedCharId).firstOrNull
        : null;
    final displayName = hasDisguise ? p.disguiseNameOverride! : c.name;
    final displayIcon = hasDisguise ? (p.disguiseIconOverride ?? c.icon) : c.icon;
    final fc = hasDisguise
        ? factionColor(p.disguiseFactionOverride ?? 'neutral')
        : factionColor(c.faction.name);
    // HP apparent = HP du personnage imité (si disponible), sinon HP réel
    final displayHp = disguisedChar?.hp ?? c.hp;
    final displayAbility = disguisedChar?.ability ?? c.ability;
    final displayWin = disguisedChar?.winCondition ?? c.winCondition;
    showDialog(context: ctx, builder: (_) => Dialog(
      backgroundColor: kBg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(p.name, style: cinzel(13, c: kTextSub)),
          const SizedBox(height: 8),
          Container(
            width:90,height:90,
            decoration:BoxDecoration(shape:BoxShape.circle,
              border:Border.all(color:fc,width:3),
              gradient:RadialGradient(colors:[fc.withOpacity(0.2),kBg2])),
            child:Center(child:Text(displayIcon,style:const TextStyle(fontSize:42))),
          ),
          const SizedBox(height:10),
          Text(displayName,style:cinzel(20,c:kGold2,fw:FontWeight.w900)),
          const SizedBox(height:6),
          FactionBadge(hasDisguise ? (p.disguiseFactionOverride ?? c.faction.name) : c.faction.name),
          const SizedBox(height:6),
          Text('$displayHp PV',style:cinzel(15,c:kGold)),
          const SizedBox(height:12),
          _InfoBox(icon:'⚡',label:'CAPACITÉ',text:displayAbility),
          const SizedBox(height:8),
          _InfoBox(icon:'🏆',label:'CONDITION DE VICTOIRE',text:displayWin),
          const SizedBox(height:16),
          BHButton(label:'Fermer',outlined:true,onTap:()=>Navigator.pop(ctx)),
        ]),
      ),
    ));
  }

  @override
  Widget build(BuildContext ctx) {
    final isCurrent = p.uid == (gp.gameState?.currentPlayerId??'');
    final isMe = p.uid == gp.myUid;
    final t = gp.terrainOf(p);
    final woundColor = p.wounds >= 10 ? kRed : p.wounds >= 6 ? kGold : kGreen;
    // Jason (Caméléon) : les AUTRES joueurs voient le déguisement, pas la vraie identité.
    // Lui-même (isMe) voit toujours la vérité.
    final hasDisguise = !isMe && p.disguiseNameOverride != null;
    final displayName = hasDisguise ? p.disguiseNameOverride! : p.character?.name;
    final displayIcon = hasDisguise ? p.disguiseIconOverride : null;
    // HP max apparent = HP du perso imité (Jason garde ses vrais PV)
    final disguisedChar = hasDisguise && p.disguiseCharIdOverride != null
        ? kAllCharacters.where((ch) => ch.id == p.disguiseCharIdOverride).firstOrNull
        : null;
    final displayMaxHp = disguisedChar?.hp ?? p.character?.hp ?? 0;
    final knowMaxHp = (isMe || p.revealed) && p.character != null;
    final fc = p.revealed && p.character != null
        ? (hasDisguise
            ? factionColor(p.disguiseFactionOverride ?? 'neutral')
            : factionColor(p.character!.faction.name))
        : null;

    return GestureDetector(
      onTap: (p.revealed && p.character != null) ? () => _showCard(ctx) : null,
      child: Opacity(
      opacity:p.alive?1.0:0.35,
      child:Container(
        margin:const EdgeInsets.only(bottom:6),
        padding:const EdgeInsets.all(10),
        decoration:surfaceDecor(border:isCurrent?kGold:kBord),
        child:Row(children:[
          // Jeton avec anneau de faction si révélé
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: EdgeInsets.all(p.revealed ? 2.5 : 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: fc != null
                ? [BoxShadow(color: fc.withValues(alpha: 0.7), blurRadius: 8, spreadRadius: 1)]
                : null,
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: fc != null ? Border.all(color: fc, width: 2.5) : null,
              ),
              child: Stack(alignment: Alignment.topRight, children: [
                // Jason garde toujours son jeton — seul le contour change de couleur
                TokenWidget(tokenId: p.token, size: 32, isDead: !p.alive),
                if (isMe) const Positioned(top: 0, right: 0,
                  child: Text('★', style: TextStyle(fontSize: 9, color: kGold))),
                // Jeanne : marquage visible de tous
                if (gp.gameState?.markedPlayerUid == p.uid)
                  const Positioned(top: 0, left: 0,
                    child: Text('💀', style: TextStyle(fontSize: 10))),
              ]),
            ),
          ),
          const SizedBox(width:10),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              Text(p.name,style:body(13,fw:FontWeight.w600)),
              if(p.revealed && p.character != null)...[
                const SizedBox(width:6),
                if (hasDisguise)
                  FactionBadge(p.disguiseFactionOverride ?? 'neutral', small: true)
                else
                  FactionBadge(p.character!.faction.name,small:true),
              ],
              if(!p.alive) const Text(' 💀',style:TextStyle(fontSize:11)),
            ]),
            Text('${t?.icon??""} ${t?.name??""}',style:body(11,c:kTextSub)),
            if (p.equipment.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 2),
                child: Wrap(spacing: 2, children: p.equipment.map((eq) => Tooltip(
                  message: eq.name,
                  child: Text('⚔', style: const TextStyle(fontSize: 10, color: kTextDim)),
                )).toList())),
          ])),
          // Blessures — barre PV seulement si on connaît le PV max
          if (!p.alive)
            const Text('💀', style: TextStyle(fontSize: 18))
          else if (knowMaxHp)
            Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
              Text('${p.wounds}/$displayMaxHp',style:cinzel(12,c:woundColor)),
              const SizedBox(height:3),
              SizedBox(width:55,height:4,child:ClipRRect(
                borderRadius:BorderRadius.circular(2),
                child:LinearProgressIndicator(
                  value:((displayMaxHp-p.wounds)/displayMaxHp).clamp(0.0,1.0),
                  backgroundColor:kBord,valueColor:AlwaysStoppedAnimation(woundColor)))),
            ])
          else
            Text('🗡 ${p.wounds}', style: cinzel(13, c: woundColor, fw: FontWeight.w700)),
        ]),
      ),
    ));
  }
}

class _WaitPanel extends StatelessWidget {
  final GameProvider gp;
  const _WaitPanel({required this.gp});

  @override
  Widget build(BuildContext ctx) {
    final gs = gp.gameState;
    final punishTargetUid = gs?.pendingPunishTargetUid;
    if (punishTargetUid != null && punishTargetUid != gp.myUid) {
      final target = gp.players[punishTargetUid];
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('\u23f3', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          Text('En attente de ${target?.name ?? "\u2014"}\u2026',
            style: cinzel(14, c: kGold), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('Il doit choisir entre donner un \u00e9quipement ou subir 1 blessure',
            style: body(11, c: kTextSub), textAlign: TextAlign.center),
        ]),
      );
    }
    final bonusLeft = gs?.bonusTurnsRemaining ?? 0;
    final pta = gs?.pendingTargetAction;
    if (bonusLeft > 0) {
      return Padding(padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🥷', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text('${gp.currentPlayer?.name ?? "Ninja"} rejoue !',
            style: cinzel(16, c: const Color(0xFFAA1144))),
          Text('$bonusLeft tour(s) bonus restant(s)', style: body(12, c: kTextSub)),
        ]));
    }
    if (pta == 'swap_zone_pick1' || pta == 'swap_zone_pick2') {
      return Padding(padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('👑', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text('${gp.currentPlayer?.name ?? "Richard II"} choisit des zones…',
            style: cinzel(14, c: kGold)),
          Text('Les terrains vont bientôt s\'échanger !',
            style: body(11, c: kTextSub), textAlign: TextAlign.center),
        ]));
    }
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('\u23f3', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 8),
        Text('Tour de ${gp.currentPlayer?.name ?? "\u2014"}', style: cinzel(16, c: kGold)),
        Text(gp.phase.name, style: body(12, c: kTextSub)),
      ]),
    );
  }
}
class _ActionPanel extends StatefulWidget {
  final GameProvider gp;
  const _ActionPanel({required this.gp});
  @override State<_ActionPanel> createState()=>_ActionPanelState();
}

class _ActionPanelState extends State<_ActionPanel> {
  int? _atkD4,_atkD6,_atkDmg;
  int? _d4, _d6, _sum;
  int? _d4b, _d6b, _sum2; // Boussole Mystique : 2e lancer optionnel
  bool _boussoleDecided = false;
  bool _busy = false;
  bool _casinoActive = false; // état local pour Mr Casino — évite le délai Firebase
  String? _atkTargetId;
  bool _showingSwapTargets = false;

  GameProvider get gp => widget.gp;

  /// Exécute une action async en empêchant les doubles-clics (anti-spam).
  Future<void> _act(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() => _busy = true);
    try { await fn(); } finally { if (mounted) setState(() => _busy = false); }
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
      gp.revealSelf();
      return;
    }
    final hunterPick = hunters[Random().nextInt(hunters.length)];
    final shadowPick = shadows[Random().nextInt(shadows.length)];
    showDialog(context: ctx, builder: (dctx) => AlertDialog(
      backgroundColor: kBg2,
      title: Text('🦎 Jason — Choisissez votre déguisement', style: cinzel(15, c: kGold2)),
      content: Text('Les autres joueurs verront ce personnage à la place du vôtre.',
        style: body(12, c: kTextSub)),
      actions: [
        TextButton(
          onPressed: () { Navigator.pop(dctx); gp.revealAsDisguise(hunterPick); },
          child: Text('${hunterPick.icon} ${hunterPick.name} (Hunter)', style: cinzel(12, c: kGold)),
        ),
        TextButton(
          onPressed: () { Navigator.pop(dctx); gp.revealAsDisguise(shadowPick); },
          child: Text('${shadowPick.icon} ${shadowPick.name} (Shadow)', style: cinzel(12, c: kRed)),
        ),
      ],
    ));
  }

  void _showJulienChoice(BuildContext ctx) {
    showDialog(context: ctx, builder: (dctx) => AlertDialog(
      backgroundColor: kBg2,
      title: Text('😈 Julien', style: cinzel(16, c: kGold2)),
      content: Text('Infliger 2 blessures à un joueur, ou se soigner de 1 blessure ?',
        style: body(13)),
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.pop(dctx);
            await gp.requestTarget('damage2_or_heal1');
          },
          child: Text('⚔️ Attaquer', style: cinzel(12, c: kRed)),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(dctx);
            await gp.useAbility();
          },
          child: Text('💚 Se soigner', style: cinzel(12, c: kGreen)),
        ),
      ],
    ));
  }

  void _showMyCard(BuildContext ctx) {
    final me = gp.me;
    final c = me?.character;
    if (c == null) return;
    final fc = factionColor(c.faction.name);
    showDialog(context: ctx, builder: (_) => Dialog(
      backgroundColor: kBg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
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
          const SizedBox(height:6),
          Text('${c.hp} PV',style:cinzel(15,c:kGold)),
          const SizedBox(height:12),
          _InfoBox(icon:'⚡',label:'CAPACITÉ UNIQUE',text:c.ability),
          const SizedBox(height:8),
          _InfoBox(icon:'🏆',label:'CONDITION DE VICTOIRE',text:c.winCondition),
          const SizedBox(height:16),
          BHButton(label:'Fermer',outlined:true,onTap:()=>Navigator.pop(ctx)),
        ]),
      ),
    ));
  }

  @override
  Widget build(BuildContext ctx) {
    return Padding(
      padding:const EdgeInsets.all(14),
      child:Column(mainAxisSize:MainAxisSize.min,children:[
        Text(_phaseLabel(),style:cinzel(11,c:kGold,ls:2)),
        const SizedBox(height:10),
        ..._buildActions(ctx),
      ]),
    );
  }

  String _phaseLabel() => switch(gp.phase.name){
    'ability'=>'Capacité unique','move'=>'Déplacement','zoneEffect'=>'Effet du terrain',
    'cardChoice'=>'Choix du deck','cardDrawn'=>'Carte piochée',
    'chooseTarget'=>'Choisir une cible','attack'=>'Attaque',_=>gp.phase.name};

  List<Widget> _buildActions(BuildContext ctx) {
    final me = gp.me;
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
        return [
          if(me?.revealed==false)
            BHButton(label:'🃏 Se révéler',onTap:() async {
              if (me?.character?.abilityEffect == 'chameleon_passive') {
                _showJasonDisguiseChoice(ctx);
                return;
              }
              await gp.revealSelf();
              if (ctx.mounted) _showMyCard(ctx);
            }),
          BHButton(label:'🃏 Voir ma carte', outlined: true,
            onTap: () => _showMyCard(ctx)),
          if (me?.character?.abilityEffect == 'double_move_dice' && me?.revealed == true)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kBg3, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kGold.withValues(alpha: 0.4))),
              child: Text('⏱ Albane — ton pouvoir s\'active automatiquement lors du déplacement : lance les dés puis relance pour garder le meilleur.',
                style: body(11, c: kGold2), textAlign: TextAlign.center),
            ),
          if(me?.revealed==true) ...[
            if(me?.abilityUsed==false && !const {
              'heal_on_same_terrain', 'heal_per_equip_eot', 'counter_attack_passive',
              'death_heal_allies', 'gege_passive', 'tenebres_heal_instead',
              'zero_wound_power', 'third_attack_bonus', 'infinite_range',
              'chameleon_passive', 'heal1_on_own_attack', 'builder_power', 'prophete_mark',
              'double_move_dice',
            }.contains(me?.character?.abilityEffect))
              BHButton(label:'⚡ Utiliser ma capacité',
                onTap: me?.character?.abilityEffect == 'damage2_or_heal1'
                  ? () => _showJulienChoice(ctx)
                  : me?.character?.abilityEffect == 'casino_bet'
                    ? () { setState(() => _casinoActive = true); gp.useAbility(); }
                    : () => _act(gp.useAbility)),
          ],
          BHButton(label:'Passer → Déplacement',onTap:()=>_act(gp.skipAbility),outlined:true),
        ];
      case GamePhase.move:
        if (_showingSwapTargets) {
          final others = gp.players.values.where((p) => p.alive && p.uid != gp.myUid).toList();
          return [
            Text('🌀 Échangez votre place avec qui ?', style: cinzel(11, c: kGold)),
            const SizedBox(height: 6),
            if (others.isEmpty) Text('Aucun autre joueur en vie.', style: body(13, c: kTextSub)),
            ...others.map((t) => BHButton(
              label: '${t.token} ${t.name}',
              onTap: () { setState(() => _showingSwapTargets = false); gp.swapPosition(t); },
            )),
            BHButton(label: 'Annuler', outlined: true,
              onTap: () => setState(() => _showingSwapTargets = false)),
          ];
        }
        final hasPortail = gp.me?.equipment.any((e) => e.effect == 'swap_position_equip') ?? false;
        final hasBoussole = gp.me?.equipment.any((e) => e.effect == 'double_dice_choice') ?? false;
        final hasAlbane = (gp.me?.character?.abilityEffect == 'double_move_dice')
            && (gp.me?.revealed == true) && (gp.me?.abilityUsed == false);
        final hasDoubleRoll = hasBoussole || hasAlbane;
        if (_sum == null) {
          return [
            if (hasPortail)
              BHButton(label: '🌀 Échanger de place avec un joueur', outlined: true,
                onTap: () => setState(() { _showingSwapTargets = true; })),
            // Albane/Boussole : lancer les deux d'un coup
            if (hasDoubleRoll)
              BHButton(
                label: hasAlbane ? '⏱ Albane — lancer 2 dés (choisir le meilleur)' : '🧭 Boussole — lancer 2 dés (choisir le meilleur)',
                gold: true,
                onTap: () {
                  final r1 = GameEngine.instance.rollMove();
                  final r2 = GameEngine.instance.rollMove();
                  setState(() {
                    _d4 = r1['d4'] as int; _d6 = r1['d6'] as int; _sum = r1['sum'] as int;
                    _d4b = r2['d4'] as int; _d6b = r2['d6'] as int; _sum2 = r2['sum'] as int;
                  });
                })
            else
              BHButton(label: '🎲 Lancer les dés (d4 + d6)', onTap: _rollDice, gold: true),
          ];
        }
        // Albane/Boussole : afficher les deux résultats pour choisir
        if (hasDoubleRoll && _sum2 != null && !_boussoleDecided) {
          return [
            Row(children: [
              Expanded(child: _DiceWidget(d4: _d4!, d6: _d6!, sum: _sum!, isAttack: false)),
              const SizedBox(width: 8),
              Expanded(child: _DiceWidget(d4: _d4b!, d6: _d6b!, sum: _sum2!, isAttack: false)),
            ]),
            const SizedBox(height: 8),
            BHButton(label: '✅ Choisir lancer 1 ($_sum)', gold: true,
              onTap: () {
                if (hasAlbane) gp.markAlbaneUsed();
                setState(() { _sum2 = null; _d4b = null; _d6b = null; _boussoleDecided = true; });
              }),
            BHButton(label: '✅ Choisir lancer 2 ($_sum2)', gold: true,
              onTap: () {
                if (hasAlbane) gp.markAlbaneUsed();
                setState(() {
                  _d4 = _d4b; _d6 = _d6b; _sum = _sum2;
                  _sum2 = null; _d4b = null; _d6b = null; _boussoleDecided = true;
                });
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
          BHButton(label:'Appliquer l\'effet du terrain',onTap:()=>_act(gp.applyTerrainEffect)),
          BHButton(label:'Ignorer → Attaquer',onTap:()=>_act(gp.skipTerrainEffect),outlined:true),
        ];
      case GamePhase.cardChoice:
        return [
          BHButton(label:'✨ Deck Lumière',   onTap:()=>gp.drawCard(DeckType.lumiere)),
          BHButton(label:'🌑 Deck Ténèbres',  onTap:()=>gp.drawCard(DeckType.tenebres)),
          BHButton(label:'🔮 Deck Vision',    onTap:()=>gp.drawCard(DeckType.vision)),
        ];
      case GamePhase.cardDrawn:
        final cardId = gp.gameState?.pendingAction;
        final card = cardId != null ? findCardById(cardId) : null;
        return [
          if (card != null) _CardWidget(card: card),
          const SizedBox(height: 10),
          BHButton(label:'✅ Appliquer la carte',onTap:()=>_act(gp.applyCard), gold: true),
          // Pas de bouton "Ignorer" — une carte piochée doit être appliquée
        ];
      case GamePhase.chooseTarget:
        final pta = gp.gameState?.pendingTargetAction;
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
              Text('💨 Vlad — aucun joueur adjacent à portée.',
                style: body(13, c: kTextSub), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              BHButton(label: '← Retour', outlined: true,
                onTap: () => _act(gp.backToAbility)),
            ];
          } // attackTargets already filters by adjacency
        } else if (pta == 'clemence_target' || pta == 'terrain_damage9') {
          // Clémence et Terrain 9 peuvent se cibler eux-mêmes
          all = gp.players.values.where((p) => p.alive).toList();
        } else {
          all = gp.players.values.where((p)=>p.alive&&p.uid!=gp.myUid).toList();
        }
        String title = 'Choisissez une cible';
        if (pta == 'terrain_damage9') title = '🏹 Clairière — 2 blessures à la cible';
        if (pta == 'terrain_steal')   title = '🗼 Tour du Voleur — voler un équipement';
        if (pta == 'set_wounds5')     title = '📍 Marion — placer à 5 blessures';
        if (pta == 'damage2_then_heal3') title = '🥷 Raph — soigner de 3 (vous subissez 2)';
        if (pta == 'ally_sacrifice_heal') title = '✨ Amélia — soigner de 4 (vous subissez 2)';
        if (pta == 'terrain_max_aoe') title = '⚡ Hong Yi — 8 blessures (vous mourrez)';
        if (pta == 'd6_lifesteal')    title = '🐢 Carapatte — D6 lifesteal';
        if (pta == 'd6_global_attack') title = '🎲 Travert — D6 dégâts';
        if (pta == 'd4_bonus_attack') title = '💨 Vlad — D4 dégâts (répétable)';
        if (pta == 'swap_equipment') title = '🔄 Tristan — Échanger un équipement (répétable)';
        if (pta == 'damage2_or_heal1') title = '😈 Julien — Choisissez une cible (2 dégâts)';
        if (pta == 'vision_shadow_heal_or_dmg') title = '🔮 Intuition Shadow — Choisissez une cible';
        if (pta == 'vision_hunter_heal_or_dmg') title = '🔮 Intuition Hunter — Choisissez une cible';
        if (pta == 'vision_neutral_heal_or_dmg') title = '🔮 Intuition Neutre — Choisissez une cible';
        if (pta == 'vision_show_card') title = '🔮 Vision Suprême — Choisissez une cible';
        if (pta == 'vision_punish_neutral_shadow') title = '🔮 Divination — Choisissez une cible';
        if (pta == 'vision_punish_neutral_hunter') title = '🔮 Divination — Choisissez une cible';
        if (pta == 'vision_punish_shadow_hunter') title = '🔮 Divination — Choisissez une cible';
        if (pta == 'vision_hp_12plus') title = '🔮 Divination Vétéran — Choisissez une cible';
        if (pta == 'vision_hp_11minus') title = '🔮 Divination Novice — Choisissez une cible';
        if (pta == 'damage3_give_dague') title = '🗡️ Marin — Choisissez une cible (3 dégâts + dague)';
        if (pta == 'heal_other_d4') title = '🍓 Fraise Tagada — Choisissez qui soigner (D4)';
        if (pta == 'creation_marin') title = '🩸 Création de Marin — Choisissez une cible';
        if (pta == 'corne_des_woods') title = '🌳 Corne des Woods — Qui doit attaquer ?';
        if (pta == 'corne_des_woods_victim') title = '🌳 Corne des Woods — Choisissez la victime';
        if (pta == 'clemence_target') title = '🎨 Clémence — Choisissez une cible';
        if (pta == 'jeanne_mark_target') title = '🔮 Jeanne — Choisissez qui marquer';
        if (pta == 'casino_win') title = '🎰 Mr Casino — Infligez 3 blessures à qui ?';
        if (pta == 'ability_vlad_adjacent') title = '💨 Vlad — Choisissez un joueur adjacent';
        if (pta == 'equip_choice') title = '⚔️ Choisissez un équipement';
        // Richard II : afficher les zones du plateau
        if ((pta == 'swap_zone_pick1' || pta == 'swap_zone_pick2') && gp.isMyTurn) {
          final myZoneIdx = gp.me?.zoneIndex ?? 0;
          final layout = gp.gameState?.terrainLayout ?? [];
          return [
            Text('👑 Richard II — Choisissez la zone à échanger avec la vôtre',
              style: cinzel(12, c: kGold)), const SizedBox(height: 8),
            ...layout.asMap().entries.where((e) => e.key != myZoneIdx).map((entry) {
              final idx = entry.key; final terrain = entry.value;
              final here = gp.players.values.where((p) => p.alive && p.zoneIndex == idx)
                  .map((p) => p.token).join(' ');
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
              Text(mode == 'steal' ? '🗡 Choisissez l\'équipement à voler' : '🍌 Choisissez l\'équipement à donner',
                style: cinzel(11, c: kGold)),
              const SizedBox(height: 6),
              if (equipList.isEmpty)
                Text('Aucun équipement disponible', style: body(12, c: kTextSub))
              else ...equipList.asMap().entries.map((entry) => BHButton(
                label: entry.value.name,
                onTap: () => gp.resolveEquipChoiceMulti(mode, actorUid, targetUid, entry.key),
              )),
            ];
          }
        }
        return [
          Text(title, style: cinzel(11, c: kGold)),
          const SizedBox(height: 6),
          if (all.isEmpty) Text('Aucune cible valide.', style: body(13, c: kTextSub)),
          ...all.map((t) {
            void onTap() {
              if (pta == 'terrain_damage9' || pta == 'terrain_steal') {
                gp.applyTerrainTarget(t);
              } else if (pta == 'corne_des_woods_victim') {
                gp.resolveCorneVictim(t);
              } else if (pta == 'ability_vlad_adjacent') {
                gp.useAbility(target: t);
              } else if (pta == 'terrain_max_aoe') {
                gp.hongYiApplyAbility(t);
              } else if (pta == 'jeanne_mark_target') {
                gp.jeanneChooseTarget(t);
              } else if (pta == 'casino_win') {
                gp.casinoApplyDamage(t);
              } else if (pta != null && pta.startsWith('vision_') ||
                  pta == 'banane_demonique' || pta == 'vampirisation' ||
                  pta == 'blue_shell' || pta == 'veuve_noire' ||
                  pta == 'peau_banane' || pta == 'pince_attrape' ||
                  pta == 'trebuchet' || pta == 'set_marker7_choice' ||
                  pta == 'heal_other_d6' || pta == 'heal_other_d4' ||
                  pta == 'creation_marin' || pta == 'corne_des_woods') {
                gp.applyCard(target: t);
              } else {
                // Pouvoirs nécessitant une cible (set_wounds5, damage2_then_heal3, etc.)
                gp.useAbility(target: t);
              }
            }
            return BHButton(
              label:'${t.name} (${t.token})  ${t.wounds}🩸',
              onTap: onTap,
            );
          }),
        ];
      case GamePhase.attack:
        final targets = gp.attackTargets;
        final alreadyAttacked = gp.gameState?.hasAttacked == true;
        final hasHache = gp.me?.hache == true && gp.me?.equipment.any((e) => e.effect == 'hache_berserker') == true;
        final mustAttackNow = hasHache && !alreadyAttacked && targets.isNotEmpty;
        final hasBazooka = gp.me?.bazooka == true;
        // Mathieu : afficher le compteur d'attaques
        final isMathieu = gp.me?.character?.abilityEffect == 'third_attack_bonus';
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
              child: Text('✅ Tu as déjà attaqué ce tour-ci',
                style: body(12, c: kTextSub), textAlign: TextAlign.center),
            )
          else if(targets.isEmpty) Text('Aucune cible accessible',style:body(13,c:kTextSub)),
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
              ...targets.map((t)=>BHButton(
                label:'Attaquer ${t.name} (${t.token})',
                danger:true,
                onTap:()=>_startAttack(t.uid),
              )),
            ],
          ] else if (!alreadyAttacked) ...[
            Container(
              margin:const EdgeInsets.only(bottom:8),
              padding:const EdgeInsets.all(12),
              decoration:BoxDecoration(color:kShadow.withOpacity(0.1),
                borderRadius:BorderRadius.circular(10),border:Border.all(color:kShadow)),
              child:Column(children:[
                Text('$_atkDmg dégâts',style:cinzel(28,c:kRed,fw:FontWeight.w900)),
                if (!hasBazooka)
                  Text('|d4($_atkD4) − d6($_atkD6)| = $_atkDmg',style:body(12,c:kTextSub))
                else
                  Text('💥 Bazooka — tous les joueurs accessibles',style:body(12,c:kRed)),
              ]),
            ),
            BHButton(label:'💥 Confirmer',danger:true,
              onTap:()=>_act(_confirmAttack)),
          ],
          if (mustAttackNow)
            Container(
              margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: kRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8), border: Border.all(color: kRed.withValues(alpha: 0.5))),
              child: Text('🪓 Tu DOIS attaquer avant de terminer le tour !', style: body(11, c: kRed)),
            )
          else
            BHButton(label:'Terminer le tour →', onTap: () => _act(gp.endTurn), outlined:true),
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
      label: '${t.icon} ${t.num} — ${t.name}',
      onTap: () => _act(() async { gp.moveTo(i, diceSum: _sum!, d4: _d4!, d6: _d6!); _resetDice(); }),
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
      label: '→ ${t.icon} ${t.name}  (${t.desc})',
      onTap: () => _act(() async { gp.moveTo(idx, diceSum: _sum!, d4: _d4!, d6: _d6!); _resetDice(); }),
    );
  }

  void _startAttack(String targetId) {
    final hasHache = gp.me?.hache == true &&
        (gp.me?.equipment.any((e) => e.effect == 'hache_berserker') ?? false);
    if (gp.gameState?.fifiGoldenTurn == true) {
      final atk = gp.gameState?.fifiAtkResult ?? 5;
      final d4 = (atk / 2).ceil().clamp(0, 4).toInt();
      final d6 = (atk - d4).clamp(0, 6).toInt();
      setState(() { _atkD4 = d4; _atkD6 = d6; _atkDmg = atk; _atkTargetId = targetId; });
    } else if (hasHache) {
      // Sabre Hanté : D4 seulement
      final r = GameEngine.instance.rollHacheAttack();
      setState(() { _atkD4 = r['d4']!; _atkD6 = 0; _atkDmg = r['damage']; _atkTargetId = targetId; });
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
    await gp.attackPlayer(_atkTargetId!, _atkDmg!, d4: _atkD4 ?? 0, d6: _atkD6 ?? 0);
    setState((){_atkD4=_atkD6=_atkDmg=null;_atkTargetId=null;});
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
        child: AnimatedBuilder(
          animation: _rollAc,
          builder: (_, __) => Stack(alignment: Alignment.center, children: [
            Transform.translate(
              offset: Offset(_rollD4x.value, _rollD4y.value),
              child: Transform.rotate(angle: _rollRotD4.value,
                child: _RollingDie(
                  value: widget.d4, label: 'd4',
                  color: widget.isAttack ? kRed : kGold,
                  rolling: !_showResult,
                )),
            ),
            Transform.translate(
              offset: Offset(_rollD6x.value + 60, _rollD6y.value),
              child: Transform.rotate(angle: _rollRotD6.value,
                child: _RollingDie(
                  value: widget.d6, label: 'd6',
                  color: widget.isAttack ? kRed : kGold,
                  rolling: !_showResult,
                )),
            ),
          ]),
        ),
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
        ? '|d4(${widget.d4}) − d6(${widget.d6})| = ${widget.sum} dégâts'
        : 'd4(${widget.d4}) + d6(${widget.d6}) = ${widget.sum}',
        style: body(11, c: kTextSub)),
      if (!widget.isAttack && widget.sum == 7)
        Padding(padding: const EdgeInsets.only(top: 4),
          child: Text('🎯 Choisis ta destination !', style: cinzel(11, c: kGold))),
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

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: dc.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dc.withValues(alpha: 0.6)),
        boxShadow: [BoxShadow(color: dc.withValues(alpha: 0.15), blurRadius: 10)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (imgPath != null)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            child: SizedBox(
              height: 180, width: double.infinity,
              child: Image.asset(imgPath, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 80, color: dc.withValues(alpha: 0.1),
                  child: Center(child: Text(deckIcon(card.deck.name),
                    style: const TextStyle(fontSize: 40))))),
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
                  card.type == CardType.equipement ? '⚔ Équipement' : '✨ Usage unique',
                  style: body(9, c: dc)),
              ),
            ]),
            const SizedBox(height: 6),
            Text(card.name, style: cinzel(15, c: kGold2, fw: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(card.text, style: body(12)),
          ]),
        ),
      ]),
    );
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
        Text('🎨 CLÉMENCE', style: cinzel(18, c: purple, fw: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(step == 1
          ? 'Choix 1/2 — Sélectionnez un effet'
          : 'Choix 2/2 — Sélectionnez un effet',
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
            onTap: () => gp.clemenceChooseEffect(eff),
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
        Text('Choisissez secrètement la récompense du tueur',
          style: body(11, c: kTextSub), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ...rewards.map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: BHButton(
            label: eg.jeanneRewardLabel(r),
            onTap: () => gp.jeanneChooseReward(r),
          ),
        )),
      ]),
    );
  }
}

// ─── Bannière dés (visible des non-joueurs) ───────────────────────────────────
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
                _DieFace(value: d4, sides: 4),
                const SizedBox(width: 10),
                Text('−', style: cinzel(18, c: kTextSub)),
                const SizedBox(width: 10),
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
        Text('Pariez pair ou impair', style: body(12, c: kTextSub)),
        const SizedBox(height: 16),
        if (_result == null) ...[
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            BHButton(label: '⚫ Pair', onTap: () => _roll(false)),
            BHButton(label: '🔴 Impair', onTap: () => _roll(true)),
          ]),
        ] else ...[
          Text('Résultat : $_result ${(_result! % 2 == 0) ? "(Pair)" : "(Impair)"}',
            style: cinzel(20, c: _won! ? Colors.greenAccent : kRed,
              fw: FontWeight.w900)),
          const SizedBox(height: 8),
          if (_won!)
            Text('✅ Gagné ! Choisissez une cible', style: body(12, c: Colors.greenAccent))
          else
            Text('❌ Perdu — vous subissez 2 blessures', style: body(12, c: kRed)),
          const SizedBox(height: 12),
          BHButton(
            label: _won! ? '🎯 Choisir une cible' : '💸 Subir 2 blessures',
            gold: _won!,
            danger: !_won!,
            onTap: () {
              if (_won!) {
                widget.onDone?.call();
                widget.gp.casinoWin();
              } else {
                widget.onDone?.call();
                widget.gp.casinoLose();
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
                Text('Gège attaque !',
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
  const _ScottCounterOverlay({required this.onDone});
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
                Text('CONTRE-ATTAQUE !', style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900, color: Colors.orange,
                  shadows: [Shadow(color: Colors.black, blurRadius: 8)])),
              ]),
            ),
          ),
        ),
      ),
    ),
  );
}

// ─── PlayerChip : version compacte pour mobile horizontal ────────────────────
class _PlayerChip extends StatelessWidget {
  final Player p; final GameProvider gp;
  const _PlayerChip({required this.p, required this.gp});

  @override
  Widget build(BuildContext ctx) {
    final c = p.character;
    final isMe = p.uid == gp.myUid;
    final isMarked = gp.gameState?.markedPlayerUid == p.uid;
    final fc = p.revealed && c != null ? factionColor(c.faction.name) : null;
    return GestureDetector(
      onTap: () {
        if (p.revealed && c != null) {
          showDialog(context: ctx, builder: (_) => Dialog(
            backgroundColor: kBg2,
            child: Padding(padding: const EdgeInsets.all(16), child: Column(
              mainAxisSize: MainAxisSize.min, children: [
                Text(c.name, style: cinzel(15, c: kGold)),
                const SizedBox(height: 6),
                Text('${p.wounds} / ${c.hp} PV', style: body(13, c: kRed)),
                const SizedBox(height: 8),
                Text(c.ability, style: body(11, c: kTextSub), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                TextButton(onPressed: () => Navigator.pop(ctx),
                  child: Text('Fermer', style: body(13, c: kGold))),
              ],
            )),
          ));
        }
      },
      child: Container(
        width: 60, height: 56,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: isMe ? kBg3 : kBg2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: fc != null ? fc : (isMe ? kGold : Colors.white12),
            width: isMe ? 2 : 1),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Stack(alignment: Alignment.topRight, children: [
            TokenWidget(tokenId: p.token, size: 28, isDead: !p.alive),
            if (isMe) const Positioned(top: 0, right: 0,
              child: Text('★', style: TextStyle(fontSize: 7, color: kGold))),
            if (isMarked) const Positioned(top: 0, left: 0,
              child: Text('💀', style: TextStyle(fontSize: 8))),
          ]),
          const SizedBox(height: 2),
          Text('${p.wounds}🩸', style: body(9, c: p.wounds >= (c?.hp ?? 10) - 2 ? kRed : kTextSub)),
        ]),
      ),
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
        Text('Choisissez vos valeurs pour ce tour',
          style: body(12, c: kTextSub), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        // Déplacement
        Text('🚶 DÉPLACEMENT : $_move', style: cinzel(13, c: kGold2)),
        Slider(
          value: _move.toDouble(), min: 2, max: 10,
          divisions: 8, label: '$_move',
          activeColor: kGold2,
          onChanged: (v) => setState(() => _move = v.toInt()),
        ),
        const SizedBox(height: 12),
        // Attaque
        Text('⚔️ DÉGÂTS ATTAQUE : $_atk', style: cinzel(13, c: kRed)),
        Slider(
          value: _atk.toDouble(), min: 0, max: 5,
          divisions: 5, label: '$_atk',
          activeColor: kRed,
          onChanged: (v) => setState(() => _atk = v.toInt()),
        ),
        const SizedBox(height: 20),
        BHButton(
          label: '✅ Confirmer — Dépl. $_move · Atk. $_atk',
          gold: true,
          onTap: () => widget.gp.fifiConfirmChoices(_move, _atk),
        ),
      ]),
    );
  }
}
