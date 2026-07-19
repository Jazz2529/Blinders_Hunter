// lib/widgets/theme.dart
// Palette et styles — aucune dépendance externe

import 'package:flutter/material.dart';

// ─── Palette ─────────────────────────────────
const kBg0    = Color(0xFF080604);
const kBg1    = Color(0xFF110D07);
const kBg2    = Color(0xFF1C1309);
const kBg3    = Color(0xFF271A0B);
const kGold   = Color(0xFFD4A017);
const kGold2  = Color(0xFFF0C040);
const kGoldDim= Color(0xFF8A6510);
const kText   = Color(0xFFEEE4CC);
const kTextSub= Color(0xFFB8A888);
const kTextDim= Color(0xFF665A40);
const kBord   = Color(0xFF3A2810);
const kBord2  = Color(0xFF5A3C18);
const kRed    = Color(0xFFE84040);
const kGreen  = Color(0xFF3DBE7A);

const kHunter   = Color(0xFF1E6ECC);
const kHunterBg = Color(0xFF0D2B52);
const kShadow   = Color(0xFFCC2222);
const kShadowBg = Color(0xFF52100D);
const kNeutral  = Color(0xFFB8860B);
const kNeutralBg= Color(0xFF3D2C04);

const kVision    = Color(0xFF7B4FD4);
const kVisionBg  = Color(0xFF2A1A52);
const kLumiere   = Color(0xFF1A9466);
const kLumiereBg = Color(0xFF0A3525);
const kTenebres  = Color(0xFFCC2222);
const kTenebresBg= Color(0xFF3D0A0A);

// ─── Helpers couleur ─────────────────────────
Color factionColor(String f) => switch(f){
  'hunter' =>kHunter,'shadow'=>kShadow,'neutral'=>kNeutral,_=>kGold};
Color factionBg(String f) => switch(f){
  'hunter'=>kHunterBg,'shadow'=>kShadowBg,'neutral'=>kNeutralBg,_=>kBg3};
String factionLabel(String f) => switch(f){
  'hunter'=>'HUNTER','shadow'=>'SHADOW','neutral'=>'NEUTRE',_=>f.toUpperCase()};

Color deckColor(String d) => switch(d){
  'vision'=>kVision,'lumiere'=>kLumiere,'tenebres'=>kTenebres,_=>kGold};
Color deckBg(String d) => switch(d){
  'vision'=>kVisionBg,'lumiere'=>kLumiereBg,'tenebres'=>kTenebresBg,_=>kBg3};
String deckLabel(String d) => switch(d){
  'vision'=>'VISION','lumiere'=>'LUMIÈRE','tenebres'=>'TÉNÈBRES',_=>d.toUpperCase()};
String deckIcon(String d) => switch(d){
  'vision'=>'🔮','lumiere'=>'✨','tenebres'=>'🌑',_=>''};

// ─── Styles texte ────────────────────────────
TextStyle cinzel(double sz, {Color c=kGold, FontWeight fw=FontWeight.w700, double ls=1}) =>
  TextStyle(fontFamily:'Cinzel',fontSize:sz,fontWeight:fw,color:c,letterSpacing:ls);
TextStyle body(double sz, {Color c=kText, FontWeight fw=FontWeight.normal}) =>
  TextStyle(fontFamily:'CrimsonText',fontSize:sz,fontWeight:fw,color:c,height:1.5);

// ─── Décorations ─────────────────────────────
BoxDecoration surfaceDecor({Color? border, double r=12, Color? bg}) => BoxDecoration(
  color: bg??kBg2, borderRadius:BorderRadius.circular(r),
  border:Border.all(color:border??kBord2));

BoxDecoration glowDecor(Color color, {double r=14}) => BoxDecoration(
  color:kBg2, borderRadius:BorderRadius.circular(r),
  border:Border.all(color:color,width:1.5),
  boxShadow:[BoxShadow(color:color.withOpacity(0.2),blurRadius:12)]);

// ─── Widgets communs ─────────────────────────

class BHButton extends StatefulWidget {
  final String label; final VoidCallback? onTap;
  final bool gold, danger, outlined, loading;
  const BHButton({super.key,required this.label,this.onTap,this.gold=false,
    this.danger=false,this.outlined=false,this.loading=false});
  @override State<BHButton> createState() => _BHButtonState();
}

class _BHButtonState extends State<BHButton> {
  bool _pressed = false;
  String get label => widget.label;
  VoidCallback? get onTap => widget.onTap;
  bool get gold => widget.gold; bool get danger => widget.danger;
  bool get outlined => widget.outlined; bool get loading => widget.loading;

  @override
  Widget build(BuildContext ctx) => Listener(
    onPointerDown: (_) { if (onTap != null) setState(() => _pressed = true); },
    onPointerUp: (_) => setState(() => _pressed = false),
    onPointerCancel: (_) => setState(() => _pressed = false),
    child: AnimatedScale(
      scale: _pressed ? 0.965 : 1.0,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      child: SizedBox(
    width:double.infinity,
    child:ElevatedButton(
      onPressed:onTap,
      style:ElevatedButton.styleFrom(
        backgroundColor: danger?kShadow.withOpacity(0.2):gold?kGold:outlined?Colors.transparent:kBg3,
        foregroundColor: danger?kRed:gold?const Color(0xFF1A0D00):outlined?kGold:kText,
        side: (outlined||danger) ? BorderSide(color:danger?kShadow:kGold) : (gold?null:const BorderSide(color:kBord2)),
        padding:const EdgeInsets.symmetric(vertical:12,horizontal:14),
        alignment:Alignment.centerLeft,
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)),
        elevation:gold?4:0,
      ),
      child:loading
        ? const Center(child:SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)))
        : Text(label,style:TextStyle(fontFamily:'Cinzel',fontSize:13,fontWeight:FontWeight.w700,
            color:danger?kRed:gold?const Color(0xFF1A0D00):outlined?kGold:kText)),
    ),
      ),
    ),
  );
}

class HPBar extends StatelessWidget {
  final int wounds, maxHp; final bool showNums;
  const HPBar({super.key,required this.wounds,required this.maxHp,this.showNums=true});

  @override
  Widget build(BuildContext ctx) {
    final pct = ((maxHp-wounds)/maxHp).clamp(0.0,1.0);
    final c = pct<0.3?kRed:pct<0.6?kGold:kGreen;
    return Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
      if(showNums) Padding(padding:const EdgeInsets.only(bottom:3),
        child:Row(children:[
          Text('${maxHp-wounds}',style:cinzel(12,c:c)),
          Text('/$maxHp PV',style:body(10,c:kTextDim)),
        ])),
      ClipRRect(borderRadius:BorderRadius.circular(3),
        child:TweenAnimationBuilder<double>(
          tween:Tween(begin:0,end:pct),
          duration:const Duration(milliseconds:500),
          builder:(_,v,__)=>LinearProgressIndicator(
            value:v,minHeight:5,
            backgroundColor:kBord,valueColor:AlwaysStoppedAnimation(c)),
        )),
    ]);
  }
}

class FactionBadge extends StatelessWidget {
  final String faction; final bool small;
  const FactionBadge(this.faction,{super.key,this.small=false});

  @override
  Widget build(BuildContext ctx) {
    final c = factionColor(faction);
    return Container(
      padding:EdgeInsets.symmetric(horizontal:small?6:10,vertical:small?2:4),
      decoration:BoxDecoration(color:factionBg(faction),borderRadius:BorderRadius.circular(20),border:Border.all(color:c)),
      child:Text(factionLabel(faction),style:cinzel(small?9:11,c:c,ls:2)),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text,{super.key});

  @override
  Widget build(BuildContext ctx) => Padding(
    padding:const EdgeInsets.only(bottom:8),
    child:Text(text,style:cinzel(10,c:kGold,ls:2)),
  );
}

class OrnamentDivider extends StatelessWidget {
  const OrnamentDivider({super.key});

  @override
  Widget build(BuildContext ctx) => Padding(
    padding:const EdgeInsets.symmetric(vertical:12),
    child:Row(children:[
      Expanded(child:Container(height:1,decoration:BoxDecoration(
        gradient:LinearGradient(colors:[Colors.transparent,kBord2])))),
      Padding(padding:const EdgeInsets.symmetric(horizontal:8),
        child:Text('✦',style:TextStyle(color:kGoldDim,fontSize:11))),
      Expanded(child:Container(height:1,decoration:BoxDecoration(
        gradient:LinearGradient(colors:[kBord2,Colors.transparent])))),
    ]),
  );
}

class BHTextField extends StatelessWidget {
  final TextEditingController ctrl; final String hint;
  final bool allCaps; final int maxLen;
  const BHTextField({super.key,required this.ctrl,required this.hint,this.allCaps=false,this.maxLen=18});

  @override
  Widget build(BuildContext ctx) => TextField(
    controller:ctrl,maxLength:maxLen,
    textCapitalization:allCaps?TextCapitalization.characters:TextCapitalization.words,
    style:body(15,c:kText).copyWith(letterSpacing:allCaps?3:0),
    decoration:InputDecoration(
      hintText:hint,hintStyle:body(14,c:kTextDim),
      filled:true,fillColor:kBg3,counterText:'',
      border:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:kBord2)),
      enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:kBord2)),
      focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:kGold)),
    ),
  );
}


// ═══════════════════════════════════════════════════════════
// WIDGETS D'ANIMATION — juice global
// ═══════════════════════════════════════════════════════════

/// Halo doré pulsant autour d'un widget (joueur actif, élément important).
class PulseGlow extends StatefulWidget {
  final bool active;
  final Color color;
  final BorderRadius borderRadius;
  final Widget child;
  const PulseGlow({super.key, required this.active, required this.child,
    this.color = kGold, this.borderRadius = const BorderRadius.all(Radius.circular(12))});
  @override State<PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<PulseGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    if (widget.active) _ac.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PulseGlow old) {
    super.didUpdateWidget(old);
    if (widget.active && !_ac.isAnimating) _ac.repeat(reverse: true);
    if (!widget.active && _ac.isAnimating) { _ac.stop(); _ac.value = 0; }
  }

  @override void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _ac,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: [BoxShadow(
            color: widget.color.withValues(alpha: 0.15 + 0.30 * _ac.value),
            blurRadius: 6 + 8 * _ac.value,
            spreadRadius: 0.5 + 1.5 * _ac.value,
          )],
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Superpose un "−N" rouge (dégâts) ou "+N" vert (soins) flottant vers le
/// haut quand la valeur `wounds` change. Enrobe n'importe quel widget.
class WoundDelta extends StatefulWidget {
  final int wounds;
  final Widget child;
  const WoundDelta({super.key, required this.wounds, required this.child});
  @override State<WoundDelta> createState() => _WoundDeltaState();
}

class _WoundDeltaState extends State<WoundDelta>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  int _delta = 0; // wounds gagnés (+ = dégâts subis)

  @override
  void didUpdateWidget(WoundDelta old) {
    super.didUpdateWidget(old);
    if (old.wounds != widget.wounds) {
      _delta = widget.wounds - old.wounds;
      _ac.forward(from: 0);
    }
  }

  @override void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    return Stack(clipBehavior: Clip.none, children: [
      widget.child,
      AnimatedBuilder(
        animation: _ac,
        builder: (_, __) {
          if (!_ac.isAnimating && _ac.value == 0) return const SizedBox.shrink();
          final isDmg = _delta > 0;
          final t = Curves.easeOut.transform(_ac.value);
          return Positioned(
            right: 4, top: -6 - 22 * t,
            child: IgnorePointer(child: Opacity(
              opacity: (1 - _ac.value).clamp(0.0, 1.0),
              child: Text(
                isDmg ? '−$_delta' : '+${-_delta}',
                style: TextStyle(
                  fontFamily: 'Cinzel', fontSize: 15, fontWeight: FontWeight.w900,
                  color: isDmg ? kRed : kGreen,
                  shadows: const [Shadow(color: Colors.black87, blurRadius: 4)],
                ),
              ),
            )),
          );
        },
      ),
    ]);
  }
}

/// Entrée en scène : scale + fade (cartes piochées, panneaux importants).
class EntranceScale extends StatelessWidget {
  final Widget child;
  final Duration duration;
  const EntranceScale({super.key, required this.child,
    this.duration = const Duration(milliseconds: 320)});

  @override
  Widget build(BuildContext ctx) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.0, end: 1.0),
    duration: duration,
    curve: Curves.easeOutBack,
    builder: (_, v, child) => Opacity(
      opacity: v.clamp(0.0, 1.0),
      child: Transform.scale(scale: 0.85 + 0.15 * v, child: child),
    ),
    child: child,
  );
}

/// Bannière "⚔️ À TON TOUR" — glisse du haut, reste 1,4 s puis disparaît.
/// Se rejoue quand la `key` change (nouveau tour).
class TurnBanner extends StatefulWidget {
  final bool show;
  const TurnBanner({super.key, required this.show});
  @override State<TurnBanner> createState() => _TurnBannerState();
}

class _TurnBannerState extends State<TurnBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2300));

  @override
  void initState() {
    super.initState();
    if (widget.show) _ac.forward();
  }

  @override void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    if (!widget.show) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _ac,
      builder: (_, __) {
        final t = _ac.value;
        if (t >= 1.0) return const SizedBox.shrink();
        // 0→0.15 : entrée | 0.15→0.8 : maintien | 0.8→1 : sortie
        final slideIn  = Curves.easeOutBack.transform((t / 0.15).clamp(0.0, 1.0));
        final fadeOut  = t < 0.8 ? 1.0 : 1.0 - ((t - 0.8) / 0.2);
        return Positioned(
          top: 60 * slideIn - 50, left: 0, right: 0,
          child: IgnorePointer(child: Opacity(
            opacity: fadeOut.clamp(0.0, 1.0),
            child: Center(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  kGold.withValues(alpha: 0.0),
                  kGold.withValues(alpha: 0.25),
                  kGold.withValues(alpha: 0.0),
                ]),
                border: const Border(
                  top: BorderSide(color: kGold, width: 1),
                  bottom: BorderSide(color: kGold, width: 1),
                ),
              ),
              child: Text('⚔️  À TON TOUR',
                style: cinzel(17, c: kGold2, fw: FontWeight.w900, ls: 3)),
            )),
          )),
        );
      },
    );
  }
}
