// lib/widgets/ability_animations.dart
// Animations de capacités — extraites du mode solo, partagées avec le multi.
// Chaque widget affiche un effet visuel plein écran lié à une capacité de
// personnage, puis appelle onDone() une fois l'animation terminée.

import 'dart:math' show sin, cos, Random;
import 'package:flutter/material.dart';
import '../widgets/theme.dart';

// ═══════════════════════════════════════════════════════════════════
// ART'CADE — Animation flammes sur la zone 6
// ═══════════════════════════════════════════════════════════════════
class ArtcadeFlameOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const ArtcadeFlameOverlay({required this.onDone});
  @override State<ArtcadeFlameOverlay> createState() => ArtcadeFlameState();
}

class ArtcadeFlameState extends State<ArtcadeFlameOverlay>
    with TickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _flicker, _opacity;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2400));
    _flicker = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: AnimationController(vsync: this,
            duration: const Duration(milliseconds: 180))..repeat(reverse: true),
            curve: Curves.easeInOut));
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_ac);
    _ac.forward().then((_) { if (mounted) widget.onDone(); });
  }

  @override void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) => AnimatedBuilder(
    animation: _ac,
    builder: (_, __) => IgnorePointer(child: Opacity(
      opacity: _opacity.value.clamp(0.0, 1.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: RadialGradient(
            colors: [
              Colors.orange.withValues(alpha: 0.55),
              Colors.red.withValues(alpha: 0.25),
              Colors.transparent,
            ],
          ),
        ),
        child: Stack(children: [
          // Flamme centrale
          const Center(child: Text('🔥', style: TextStyle(fontSize: 44))),
          // Flammes décoratives
          Positioned(left: 8,  top: 6,  child: Text('🔥', style: TextStyle(fontSize: 24 + _opacity.value * 6))),
          Positioned(right: 6, top: 10, child: Text('🔥', style: TextStyle(fontSize: 20 + _opacity.value * 4))),
          Positioned(left: 18, bottom: 8, child: Text('🔥', style: TextStyle(fontSize: 18 + _opacity.value * 4))),
          // Label
          Positioned(
            bottom: 4, left: 0, right: 0,
            child: Text("🐉 Art'Cade",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, fontFamily: 'Cinzel',
                fontWeight: FontWeight.w700, color: Colors.orange,
                shadows: const [Shadow(color: Colors.black, blurRadius: 4)]))),
        ]),
      ),
    )),
  );
}


// ═══════════════════════════════════════════════════════════════════
// AUGUSTIN — Blé qui tombe du haut
// ═══════════════════════════════════════════════════════════════════
class AugustinWheatOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const AugustinWheatOverlay({required this.onDone});
  @override State<AugustinWheatOverlay> createState() => AugustinWheatState();
}

class AugustinWheatState extends State<AugustinWheatOverlay>
    with TickerProviderStateMixin {
  late AnimationController _ac, _fadeAc;
  late Animation<double> _opacity;
  final List<Particle> _particles = [];
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _ac    = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 100))..addListener(() => setState(() {}))..repeat();
    _fadeAc = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2400));
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_fadeAc);
    // Créer 28 épis de blé
    for (int i = 0; i < 28; i++) {
      _particles.add(Particle(
        x: _rng.nextDouble(),
        y: -_rng.nextDouble() * 0.5,
        speed: 0.003 + _rng.nextDouble() * 0.004,
        emoji: ['🌾', '🌾', '🌾', '🌿'][_rng.nextInt(4)],
        size: 18 + _rng.nextDouble() * 20,
        drift: (_rng.nextDouble() - 0.5) * 0.001,
        rot: _rng.nextDouble() * 2,
      ));
    }
    _fadeAc.forward().then((_) { if (mounted) widget.onDone(); });
  }

  @override
  void dispose() { _ac.dispose(); _fadeAc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    // Update particles
    for (final p in _particles) {
      p.y += p.speed;
      p.x += p.drift;
      p.rot += 0.02;
      if (p.y > 1.1) { p.y = -0.05; p.x = _rng.nextDouble(); }
    }
    final size = MediaQuery.of(ctx).size;
    return Positioned.fill(child: IgnorePointer(child: Opacity(
      opacity: _opacity.value.clamp(0.0, 1.0),
      child: Stack(children: [
        // Fond dorée légère
        Container(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFFD700).withValues(alpha: 0.12),
            Colors.transparent,
          ]))),
        // Épis
        ..._particles.map((p) => Positioned(
          left: p.x * size.width,
          top:  p.y * size.height,
          child: Transform.rotate(angle: p.rot,
            child: Text(p.emoji,
              style: TextStyle(fontSize: p.size))))),
        // Label centré
        Positioned(left: 0, right: 0, top: size.height * 0.42,
          child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFD700))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('🌾 AUGUSTIN', style: cinzel(16, c: const Color(0xFFFFD700),
                fw: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('Les récoltes vous soignent !', style: body(12, c: Colors.white)),
            ])))),
      ]),
    )));
  }
}

class Particle {
  double x, y, speed, size, drift, rot;
  final String emoji;
  Particle({required this.x, required this.y, required this.speed,
    required this.emoji, required this.size, required this.drift, required this.rot});
}

// ═══════════════════════════════════════════════════════════════════
// FIJACKED (FIGEAC) — Ville qui se construit
// ═══════════════════════════════════════════════════════════════════
class FijackedCityOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const FijackedCityOverlay({required this.onDone});
  @override State<FijackedCityOverlay> createState() => FijackedCityState();
}

class FijackedCityState extends State<FijackedCityOverlay>
    with TickerProviderStateMixin {
  late AnimationController _buildAc, _fadeAc;
  late Animation<double> _build, _opacity, _glow;

  @override
  void initState() {
    super.initState();
    _buildAc = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1600));
    _fadeAc  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2600));
    _build = CurvedAnimation(parent: _buildAc, curve: Curves.easeOutCubic);
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_fadeAc);
    _glow = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: AnimationController(vsync: this,
            duration: const Duration(milliseconds: 800))..repeat(reverse: true),
            curve: Curves.easeInOut));
    _buildAc.forward();
    _fadeAc.forward().then((_) { if (mounted) widget.onDone(); });
  }

  @override void dispose() { _buildAc.dispose(); _fadeAc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    final size = MediaQuery.of(ctx).size;
    final cx = size.width / 2;
    final baseY = size.height * 0.72;

    return AnimatedBuilder(
      animation: Listenable.merge([_buildAc, _fadeAc, _glow]),
      builder: (_, __) => Positioned.fill(child: IgnorePointer(child: Opacity(
        opacity: _opacity.value.clamp(0.0, 1.0),
        child: CustomPaint(
          painter: CityPainter(build: _build.value, glow: _glow.value,
              cx: cx, baseY: baseY),
          child: Positioned(
            left: 0, right: 0, top: size.height * 0.22,
            child: Center(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4FC3F7))),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('🏗️ FIJACKED', style: cinzel(16, c: const Color(0xFF4FC3F7),
                  fw: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('Construction en cours…', style: body(12, c: Colors.white)),
              ])))),
        ),
      ))),
    );
  }
}

class CityPainter extends CustomPainter {
  final double build, glow, cx, baseY;
  const CityPainter({required this.build, required this.glow,
    required this.cx, required this.baseY});

  @override
  void paint(Canvas canvas, Size size) {
    final buildings = [
      // [relX, width, height, r, g, b]
      [-140.0, 55.0, 90.0,  0x37, 0x47, 0x4F],
      [-75.0,  40.0, 130.0, 0x45, 0x56, 0x6A],
      [-25.0,  60.0, 160.0, 0x29, 0x39, 0x4A],
      [ 45.0,  50.0, 110.0, 0x3E, 0x51, 0x63],
      [105.0,  45.0, 80.0,  0x37, 0x47, 0x4F],
    ];

    for (final b in buildings) {
      final rx = b[0].toDouble(); final bw = b[1].toDouble(); final bh = b[2].toDouble() * build;
      final left = cx + rx - bw / 2;
      final paint = Paint()
        ..color = Color.fromARGB(255, b[3].round(), b[4].round(), b[5].round());
      canvas.drawRect(Rect.fromLTWH(left, baseY - bh, bw, bh), paint);
      // Fenêtres
      if (build > 0.3) {
        final winPaint = Paint()
          ..color = Color.fromARGB(
              (((build - 0.3) / 0.7) * 200 * glow).round().clamp(0, 255),
              0xFF, 0xF0, 0x80);
        for (double wy = baseY - bh + 8; wy < baseY - 8; wy += 16) {
          for (double wx = left + 6; wx < left + bw - 6; wx += 12) {
            canvas.drawRect(Rect.fromLTWH(wx, wy, 7, 9), winPaint);
          }
        }
      }
      // Toit triangulaire
      if (build > 0.6) {
        final roofPaint = Paint()
          ..color = const Color(0xFF4FC3F7).withValues(alpha: glow * 0.8);
        final path = Path()
          ..moveTo(left - 4, baseY - bh)
          ..lineTo(cx + rx, baseY - bh - 20)
          ..lineTo(left + bw + 4, baseY - bh)
          ..close();
        canvas.drawPath(path, roofPaint);
      }
    }

    // Sol
    canvas.drawRect(Rect.fromLTWH(cx - 200, baseY, 400, 4),
      Paint()..color = const Color(0xFF4FC3F7).withValues(alpha: 0.6));

    // Grue
    if (build < 0.95) {
      final cranePaint = Paint()
        ..color = Colors.orange.withValues(alpha: build < 0.8 ? 1.0 : (0.95 - build) / 0.15)
        ..strokeWidth = 3;
      canvas.drawLine(Offset(cx + 60, baseY), Offset(cx + 60, baseY - 180), cranePaint);
      canvas.drawLine(Offset(cx + 60, baseY - 180), Offset(cx + 130, baseY - 180), cranePaint);
      canvas.drawLine(Offset(cx + 130, baseY - 180), Offset(cx + 130, baseY - 60 * build), cranePaint);
    }
  }

  @override bool shouldRepaint(CityPainter old) =>
      old.build != build || old.glow != glow;
}

// ═══════════════════════════════════════════════════════════════════
// LOUNA — Bouclier magique
// ═══════════════════════════════════════════════════════════════════
class LounaShieldOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const LounaShieldOverlay({required this.onDone});
  @override State<LounaShieldOverlay> createState() => LounaShieldState();
}

class LounaShieldState extends State<LounaShieldOverlay>
    with TickerProviderStateMixin {
  late AnimationController _expandAc, _pulseAc, _fadeAc;
  late Animation<double> _expand, _pulse, _opacity;

  @override
  void initState() {
    super.initState();
    _expandAc = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 700));
    _pulseAc  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _fadeAc   = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2600));
    _expand = CurvedAnimation(parent: _expandAc, curve: Curves.easeOutBack);
    _pulse  = Tween<double>(begin: 0.95, end: 1.05)
        .animate(CurvedAnimation(parent: _pulseAc, curve: Curves.easeInOut));
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 12),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 58),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_fadeAc);
    _expandAc.forward();
    _fadeAc.forward().then((_) { if (mounted) widget.onDone(); });
  }

  @override void dispose() { _expandAc.dispose(); _pulseAc.dispose(); _fadeAc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) => AnimatedBuilder(
    animation: Listenable.merge([_expandAc, _pulseAc, _fadeAc]),
    builder: (_, __) => Positioned.fill(child: IgnorePointer(child: Opacity(
      opacity: _opacity.value.clamp(0.0, 1.0),
      child: Center(child: Transform.scale(
        scale: _expand.value * _pulse.value,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Bouclier SVG-like via CustomPaint
          CustomPaint(
            size: const Size(180, 200),
            painter: ShieldPainter(glow: _pulse.value)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF64B5F6), width: 2)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('🛡️ LOUNA', style: cinzel(16, c: const Color(0xFF64B5F6),
                fw: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('Insensible aux blessures !', style: body(12, c: Colors.white)),
            ])),
        ]),
      )),
    ))),
  );
}

class ShieldPainter extends CustomPainter {
  final double glow;
  const ShieldPainter({required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final paint = Paint();

    // Forme bouclier
    final path = Path()
      ..moveTo(cx, 0)
      ..lineTo(size.width, size.height * 0.25)
      ..lineTo(size.width, size.height * 0.55)
      ..quadraticBezierTo(size.width, size.height * 0.85, cx, size.height)
      ..quadraticBezierTo(0, size.height * 0.85, 0, size.height * 0.55)
      ..lineTo(0, size.height * 0.25)
      ..close();

    // Remplissage dégradé
    paint.shader = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF1565C0).withValues(alpha: 0.9),
        const Color(0xFF0D47A1).withValues(alpha: 0.8),
      ]).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, paint);

    // Bordure lumineuse
    paint
      ..shader = null
      ..color = const Color(0xFF64B5F6).withValues(alpha: 0.9 * glow)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawPath(path, paint);

    // Croix centrale
    paint
      ..color = Colors.white.withValues(alpha: 0.8 * glow)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(cx - 5, size.height * 0.25, 10, size.height * 0.45), paint);
    canvas.drawRect(Rect.fromLTWH(cx - 30, size.height * 0.42, 60, 10), paint);

    // Halo
    paint.shader = RadialGradient(colors: [
      const Color(0xFF64B5F6).withValues(alpha: 0.3 * glow),
      Colors.transparent,
    ]).createShader(Rect.fromCircle(center: Offset(cx, size.height / 2), radius: 120));
    canvas.drawCircle(Offset(cx, size.height / 2), 120, paint);
  }

  @override bool shouldRepaint(ShieldPainter old) => old.glow != glow;
}

// ═══════════════════════════════════════════════════════════════════
// MARION — Plantes qui remontent vers le haut
// ═══════════════════════════════════════════════════════════════════
class MarionPlantsOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const MarionPlantsOverlay({required this.onDone});
  @override State<MarionPlantsOverlay> createState() => MarionPlantsState();
}

class MarionPlantsState extends State<MarionPlantsOverlay>
    with TickerProviderStateMixin {
  late AnimationController _ac, _fadeAc;
  late Animation<double> _opacity;
  final List<Particle> _plants = [];
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _ac    = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 80))..addListener(() => setState(() {}))..repeat();
    _fadeAc = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2400));
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_fadeAc);
    // Créer 24 plantes qui montent
    for (int i = 0; i < 24; i++) {
      _plants.add(Particle(
        x: _rng.nextDouble(),
        y: 0.6 + _rng.nextDouble() * 0.5, // commence en bas
        speed: -(0.003 + _rng.nextDouble() * 0.005), // négatif = monte
        emoji: ['🌿', '🌱', '🍃', '🌾', '🌻'][_rng.nextInt(5)],
        size: 16 + _rng.nextDouble() * 22,
        drift: (_rng.nextDouble() - 0.5) * 0.0015,
        rot: _rng.nextDouble() * 3.14,
      ));
    }
    _fadeAc.forward().then((_) { if (mounted) widget.onDone(); });
  }

  @override void dispose() { _ac.dispose(); _fadeAc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    for (final p in _plants) {
      p.y += p.speed;
      p.x += p.drift;
      p.rot += 0.025;
      if (p.y < -0.1) { p.y = 1.1; p.x = _rng.nextDouble(); }
    }
    final size = MediaQuery.of(ctx).size;
    return Positioned.fill(child: IgnorePointer(child: Opacity(
      opacity: _opacity.value.clamp(0.0, 1.0),
      child: Stack(children: [
        // Fond verdâtre
        Container(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [
            const Color(0xFF2E7D32).withValues(alpha: 0.2),
            Colors.transparent,
          ]))),
        // Plantes
        ..._plants.map((p) => Positioned(
          left: p.x * size.width,
          top:  p.y * size.height,
          child: Transform.rotate(angle: p.rot,
            child: Text(p.emoji, style: TextStyle(fontSize: p.size))))),
        // Label
        Positioned(left: 0, right: 0, top: size.height * 0.42,
          child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF66BB6A))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('🌿 MARION', style: cinzel(16, c: const Color(0xFF66BB6A),
                fw: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('Placé à 5 blessures !', style: body(12, c: Colors.white)),
            ])))),
      ]),
    )));
  }
}


// ═══════════════════════════════════════════════════════════════════
// LÉO — Flammes bleues sur TOUS les terrains
// ═══════════════════════════════════════════════════════════════════
class LeoFlamesAllOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const LeoFlamesAllOverlay({required this.onDone});
  @override State<LeoFlamesAllOverlay> createState() => LeoFlamesAllState();
}

class LeoFlamesAllState extends State<LeoFlamesAllOverlay>
    with TickerProviderStateMixin {
  late AnimationController _flickerAc, _fadeAc;
  late Animation<double> _flicker, _opacity;

  @override
  void initState() {
    super.initState();
    _flickerAc = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 220))..repeat(reverse: true);
    _fadeAc    = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2400));
    _flicker = Tween<double>(begin: 0.8, end: 1.0)
        .animate(CurvedAnimation(parent: _flickerAc, curve: Curves.easeInOut));
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 12),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 58),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_fadeAc);
    _fadeAc.forward().then((_) { if (mounted) widget.onDone(); });
  }

  @override void dispose() { _flickerAc.dispose(); _fadeAc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    final size = MediaQuery.of(ctx).size;
    return AnimatedBuilder(
      animation: Listenable.merge([_flickerAc, _fadeAc]),
      builder: (_, __) => Positioned.fill(child: IgnorePointer(child: Opacity(
        opacity: _opacity.value.clamp(0.0, 1.0),
        child: Stack(children: [
          // Halo bleu général
          Container(decoration: BoxDecoration(gradient: RadialGradient(
            center: Alignment.center, radius: 1.1,
            colors: [
              const Color(0xFF2196F3).withValues(alpha: 0.25 * _flicker.value),
              const Color(0xFF7C4DFF).withValues(alpha: 0.12 * _flicker.value),
              Colors.transparent,
            ]))),
          // Flammes bleues réparties sur tout l'écran (6 zones)
          for (final pos in [
            [0.16, 0.30], [0.50, 0.22], [0.83, 0.30],
            [0.16, 0.70], [0.50, 0.78], [0.83, 0.70],
          ])
            Positioned(
              left: pos[0] * size.width - 22,
              top:  pos[1] * size.height - 22,
              child: Transform.scale(scale: _flicker.value,
                child: const Text('🔥', style: TextStyle(fontSize: 44,
                  shadows: [Shadow(color: Color(0xFF2196F3), blurRadius: 24)])))),
          // Label central
          Positioned(left: 0, right: 0, top: size.height * 0.46,
            child: Center(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2196F3), width: 2)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('🔥 LÉO', style: cinzel(18, c: const Color(0xFF64B5F6),
                  fw: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('Le feu embrase TOUS les terrains !', style: body(12, c: Colors.white)),
                Text('Tous les joueurs, lui inclus, sont touchés', style: body(10, c: kTextDim)),
              ])))),
        ]),
      ))),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CAMBOU — Moutons qui sautent + écran qui s'endort
// ═══════════════════════════════════════════════════════════════════
class CambouSheepOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const CambouSheepOverlay({required this.onDone});
  @override State<CambouSheepOverlay> createState() => CambouSheepState();
}

class CambouSheepState extends State<CambouSheepOverlay>
    with TickerProviderStateMixin {
  late AnimationController _ac, _hopAc;
  late Animation<double> _darkness, _opacity;
  final List<double> _sheepOffsets = [0.0, 0.25, 0.5, 0.75, 1.0, -0.2, 1.2];

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 3200));
    _hopAc = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 400))..repeat(reverse: true);

    // Moutons traversent pendant les 70% premiers, écran noircit progressivement
    _darkness = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.92), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 0.92), weight: 20),
    ]).animate(CurvedAnimation(parent: _ac, curve: Curves.easeIn));

    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 8),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 80),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 12),
    ]).animate(_ac);

    _ac.forward().then((_) { if (mounted) widget.onDone(); });
  }

  @override void dispose() { _ac.dispose(); _hopAc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    final size = MediaQuery.of(ctx).size;
    return AnimatedBuilder(
      animation: Listenable.merge([_ac, _hopAc]),
      builder: (_, __) {
        // Progression de traversée (0 → 1.4 pour sortir de l'écran)
        final crossT = (_ac.value / 0.8).clamp(0.0, 1.4);
        final hop = sin(_hopAc.value * 3.14159).abs(); // 0..1 saut

        return Positioned.fill(child: IgnorePointer(child: Opacity(
          opacity: _opacity.value.clamp(0.0, 1.0),
          child: Stack(children: [
            // Fond qui s'assombrit
            Container(color: Colors.black.withValues(alpha: _darkness.value)),

            // Moutons qui sautent en traversant l'écran
            if (_darkness.value < 0.85)
              ..._sheepOffsets.map((offset) {
                final t = (crossT + offset) % 1.6 - 0.3;
                final x = t * (size.width + 120) - 60;
                final laneY = size.height * (0.35 + 0.08 * (offset % 0.5));
                final y = laneY - hop * 28;
                return Positioned(
                  left: x, top: y,
                  child: Opacity(
                    opacity: (1 - _darkness.value / 0.92).clamp(0.0, 1.0),
                    child: Transform.flip(flipX: true,
                      child: const Text('🐑', style: TextStyle(fontSize: 38)))),
                );
              }),

            // Texte "Bonne nuit"
            Positioned(left: 0, right: 0, top: size.height * 0.42,
              child: Center(child: Opacity(
                opacity: _darkness.value.clamp(0.0, 1.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF9575CD), width: 2)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('🌙 CAMBOU', style: cinzel(18, c: const Color(0xFFB39DDB),
                      fw: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text('Zzz... Soigné et protégé pour ce tour',
                      style: body(12, c: Colors.white70)),
                  ]),
                ),
              )),
            ),
          ]),
        )));
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CARAPATTE — Fruits & légumes qui tombent
// ═══════════════════════════════════════════════════════════════════
class CarapatteFoodOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const CarapatteFoodOverlay({required this.onDone});
  @override State<CarapatteFoodOverlay> createState() => CarapatteFoodState();
}

class CarapatteFoodState extends State<CarapatteFoodOverlay>
    with TickerProviderStateMixin {
  late AnimationController _ac, _fadeAc;
  late Animation<double> _opacity;
  final List<Particle> _food = [];
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 60))
      ..addListener(() => setState(() {}))
      ..repeat();
    _fadeAc = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2400));
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_fadeAc);

    const emojis = ['🍎','🍌','🥦','🍅','🥕','🍇','🍓','🍉','🌽','🍐'];
    for (int i = 0; i < 26; i++) {
      _food.add(Particle(
        x: _rng.nextDouble(),
        y: -_rng.nextDouble() * 0.6,
        speed: 0.004 + _rng.nextDouble() * 0.006,
        emoji: emojis[_rng.nextInt(emojis.length)],
        size: 20 + _rng.nextDouble() * 18,
        drift: (_rng.nextDouble() - 0.5) * 0.0012,
        rot: _rng.nextDouble() * 3.14,
      ));
    }
    _fadeAc.forward().then((_) { if (mounted) widget.onDone(); });
  }

  @override void dispose() { _ac.dispose(); _fadeAc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    for (final p in _food) {
      p.y += p.speed;
      p.x += p.drift;
      p.rot += 0.03;
      if (p.y > 1.1) { p.y = -0.05; p.x = _rng.nextDouble(); }
    }
    final size = MediaQuery.of(ctx).size;
    return Positioned.fill(child: IgnorePointer(child: Opacity(
      opacity: _opacity.value.clamp(0.0, 1.0),
      child: Stack(children: [
        Container(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF66BB6A).withValues(alpha: 0.10),
            Colors.transparent,
          ]))),
        ..._food.map((p) => Positioned(
          left: p.x * size.width,
          top:  p.y * size.height,
          child: Transform.rotate(angle: p.rot,
            child: Text(p.emoji, style: TextStyle(fontSize: p.size))))),
        Positioned(left: 0, right: 0, top: size.height * 0.42,
          child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF8BC34A))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('🐢 CARAPATTE', style: cinzel(16, c: const Color(0xFF9CCC65),
                fw: FontWeight.w900)),
              const SizedBox(height: 4),
              Text("Festin volé à l'adversaire !", style: body(12, c: Colors.white)),
            ])))),
      ]),
    )));
  }
}


// ═══════════════════════════════════════════════════════════════════
// OCÉANE — Notes de musique qui traversent l'écran
// ═══════════════════════════════════════════════════════════════════
class OceaneNotesOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const OceaneNotesOverlay({required this.onDone});
  @override State<OceaneNotesOverlay> createState() => OceaneNotesState();
}

class OceaneNotesState extends State<OceaneNotesOverlay>
    with TickerProviderStateMixin {
  late AnimationController _ac, _fadeAc;
  late Animation<double> _opacity;
  final List<Particle> _notes = [];
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 50))
      ..addListener(() => setState(() {}))..repeat();
    _fadeAc = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2200));
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 62),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 28),
    ]).animate(_fadeAc);

    const emojis = ['🎵','🎶','🎼','🎹','🎷'];
    for (int i = 0; i < 18; i++) {
      _notes.add(Particle(
        x: -0.1 - _rng.nextDouble() * 0.4,
        y: 0.15 + _rng.nextDouble() * 0.65,
        speed: 0.005 + _rng.nextDouble() * 0.006, // horizontal
        emoji: emojis[_rng.nextInt(emojis.length)],
        size: 20 + _rng.nextDouble() * 18,
        drift: (_rng.nextDouble() - 0.5) * 0.001, // vertical wave
        rot: _rng.nextDouble() * 0.6 - 0.3,
      ));
    }
    _fadeAc.forward().then((_) { if (mounted) widget.onDone(); });
  }

  @override void dispose() { _ac.dispose(); _fadeAc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    for (final n in _notes) {
      n.x += n.speed; // déplacement horizontal
      n.y += sin(n.x * 6) * 0.0015; // ondulation
      n.rot += 0.02;
      if (n.x > 1.15) { n.x = -0.1 - _rng.nextDouble() * 0.3; n.y = 0.15 + _rng.nextDouble() * 0.65; }
    }
    final size = MediaQuery.of(ctx).size;
    return Positioned.fill(child: IgnorePointer(child: Opacity(
      opacity: _opacity.value.clamp(0.0, 1.0),
      child: Stack(children: [
        Container(decoration: BoxDecoration(gradient: LinearGradient(
          colors: [
            const Color(0xFF4FC3F7).withValues(alpha: 0.10),
            Colors.transparent,
          ]))),
        ..._notes.map((n) => Positioned(
          left: n.x * size.width,
          top:  n.y * size.height,
          child: Transform.rotate(angle: n.rot,
            child: Text(n.emoji, style: TextStyle(fontSize: n.size,
              shadows: const [Shadow(color: Color(0xFF4FC3F7), blurRadius: 12)]))))),
        Positioned(left: 0, right: 0, top: size.height * 0.42,
          child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4FC3F7))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('🌊 OCÉANE', style: cinzel(16, c: const Color(0xFF4FC3F7),
                fw: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('Mélodie apaisante — soin des voisins', style: body(12, c: Colors.white)),
            ])))),
      ]),
    )));
  }
}

// ═══════════════════════════════════════════════════════════════════
// RAPH (SOLEIL LEVANT) — Arbre qui fait tomber des pétales
// ═══════════════════════════════════════════════════════════════════
class RaphPetalsOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const RaphPetalsOverlay({required this.onDone});
  @override State<RaphPetalsOverlay> createState() => RaphPetalsState();
}

class RaphPetalsState extends State<RaphPetalsOverlay>
    with TickerProviderStateMixin {
  late AnimationController _ac, _fadeAc;
  late Animation<double> _opacity, _grow;
  final List<Particle> _petals = [];
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 60))
      ..addListener(() => setState(() {}))..repeat();
    _fadeAc = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2600));
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_fadeAc);
    _grow = CurvedAnimation(parent: _fadeAc,
        curve: const Interval(0, 0.35, curve: Curves.easeOutBack));

    for (int i = 0; i < 22; i++) {
      _petals.add(Particle(
        x: 0.30 + _rng.nextDouble() * 0.45,
        y: -_rng.nextDouble() * 0.4,
        speed: 0.0025 + _rng.nextDouble() * 0.004,
        emoji: ['🌸','🌸','🍃','🌺'][_rng.nextInt(4)],
        size: 16 + _rng.nextDouble() * 16,
        drift: (_rng.nextDouble() - 0.5) * 0.0015,
        rot: _rng.nextDouble() * 3.14,
      ));
    }
    _fadeAc.forward().then((_) { if (mounted) widget.onDone(); });
  }

  @override void dispose() { _ac.dispose(); _fadeAc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    for (final p in _petals) {
      p.y += p.speed;
      p.x += p.drift + sin(p.y * 8) * 0.0008;
      p.rot += 0.02;
      if (p.y > 1.05) { p.y = -0.05; p.x = 0.30 + _rng.nextDouble() * 0.45; }
    }
    final size = MediaQuery.of(ctx).size;
    return Positioned.fill(child: IgnorePointer(child: Opacity(
      opacity: _opacity.value.clamp(0.0, 1.0),
      child: Stack(children: [
        // Arbre stylisé en bas, centré, qui pousse
        Positioned(left: 0, right: 0, bottom: 0,
          child: Align(alignment: Alignment.bottomCenter,
            child: Transform.scale(
              scale: 0.6 + 0.4 * _grow.value,
              alignment: Alignment.bottomCenter,
              child: const Text('🌳', style: TextStyle(fontSize: 130))))),
        // Pétales qui tombent
        ..._petals.map((p) => Positioned(
          left: p.x * size.width,
          top:  p.y * size.height,
          child: Transform.rotate(angle: p.rot,
            child: Text(p.emoji, style: TextStyle(fontSize: p.size))))),
        Positioned(left: 0, right: 0, top: size.height * 0.18,
          child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFF8A65))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('🌸 RAPH', style: cinzel(16, c: const Color(0xFFFF8A65),
                fw: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('Sacrifice de soi pour soigner', style: body(12, c: Colors.white)),
            ])))),
      ]),
    )));
  }
}

// ═══════════════════════════════════════════════════════════════════
// MONKEY RAPH — Yeux de démon qui s'ouvrent au centre
// ═══════════════════════════════════════════════════════════════════
class MonkeyDemonEyesOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const MonkeyDemonEyesOverlay({required this.onDone});
  @override State<MonkeyDemonEyesOverlay> createState() => MonkeyDemonEyesState();
}

class MonkeyDemonEyesState extends State<MonkeyDemonEyesOverlay>
    with TickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _eyeOpen, _opacity, _glow;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2000));
    // S'ouvrent (0→0.4), restent ouverts, se referment (0.75→1)
    _eyeOpen = TweenSequence([
      TweenSequenceItem(tween: CurveTween(curve: Curves.easeOutBack), weight: 35),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 35),
      TweenSequenceItem(tween: CurveTween(curve: Curves.easeIn).chain(Tween(begin: 1.0, end: 0.0)), weight: 30),
    ]).animate(_ac);
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 12),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 28),
    ]).animate(_ac);
    _glow = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: AnimationController(vsync: this,
            duration: const Duration(milliseconds: 500))..repeat(reverse: true),
            curve: Curves.easeInOut));
    _ac.forward().then((_) { if (mounted) widget.onDone(); });
  }

  @override void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) => AnimatedBuilder(
    animation: Listenable.merge([_ac, _glow]),
    builder: (_, __) {
      final openAmt = _eyeOpen.value.clamp(0.0, 1.0);
      return Positioned.fill(child: IgnorePointer(child: Opacity(
        opacity: _opacity.value.clamp(0.0, 1.0),
        child: Stack(children: [
          Container(color: Colors.black.withValues(alpha: 0.55 * openAmt)),
          Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
            _demonEye(openAmt, _glow.value),
            const SizedBox(width: 24),
            _demonEye(openAmt, _glow.value),
          ])),
          Positioned(left: 0, right: 0,
            bottom: MediaQuery.of(ctx).size.height * 0.28,
            child: Center(child: Opacity(opacity: openAmt,
              child: Text('🐒 Monkey Raph pioche dans les Ténèbres...',
                style: cinzel(13, c: const Color(0xFFE57373), fw: FontWeight.w700))))),
        ]),
      )));
    },
  );

  Widget _demonEye(double open, double glow) => Container(
    width: 70, height: 16 + 54 * open,
    decoration: BoxDecoration(
      color: Colors.black,
      borderRadius: BorderRadius.circular(40),
      border: Border.all(color: const Color(0xFFD32F2F), width: 2),
      boxShadow: [BoxShadow(
        color: const Color(0xFFFF1744).withValues(alpha: glow * 0.9),
        blurRadius: 24 * glow, spreadRadius: 2)],
    ),
    child: open > 0.15 ? Center(child: Container(
      width: 18 * open, height: 18 * open,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFF1744),
        boxShadow: [BoxShadow(color: const Color(0xFFFF1744).withValues(alpha: 0.8),
            blurRadius: 10)]),
    )) : null,
  );
}

// ═══════════════════════════════════════════════════════════════════
// HONG YI — Énorme haltère qui tombe
// ═══════════════════════════════════════════════════════════════════
class HongYiDumbbellOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const HongYiDumbbellOverlay({required this.onDone});
  @override State<HongYiDumbbellOverlay> createState() => HongYiDumbbellState();
}

class HongYiDumbbellState extends State<HongYiDumbbellOverlay>
    with TickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _fallY, _opacity, _shake;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2200));
    // Chute rapide (0→0.55) puis impact + secousse
    _fallY = TweenSequence([
      TweenSequenceItem(tween: CurveTween(curve: Curves.easeIn), weight: 55),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 45),
    ]).animate(_ac);
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 8),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 22),
    ]).animate(_ac);
    _shake = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ac, curve: const Interval(0.5, 0.65, curve: Curves.easeOut)));
    _ac.forward().then((_) { if (mounted) widget.onDone(); });
  }

  @override void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    final size = MediaQuery.of(ctx).size;
    return AnimatedBuilder(
      animation: _ac,
      builder: (_, __) {
        final fall = Curves.easeIn.transform((_ac.value / 0.55).clamp(0.0, 1.0));
        final y = -150 + fall * (size.height * 0.5 + 150);
        // Secousse écran à l'impact
        final shakeT = _shake.value;
        final shakeOffset = shakeT > 0 && shakeT < 1
            ? sin(shakeT * 3.14159 * 6) * 8 * (1 - shakeT)
            : 0.0;

        return Positioned.fill(child: IgnorePointer(child: Opacity(
          opacity: _opacity.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, shakeOffset),
            child: Stack(children: [
              // Haltère
              Positioned(
                left: size.width / 2 - 50, top: y,
                child: const Text('🏋️', style: TextStyle(fontSize: 100))),
              // Onde d'impact au sol
              if (_ac.value > 0.5)
                Positioned(
                  left: size.width / 2 - 80,
                  top: size.height * 0.5 + 30,
                  child: Opacity(opacity: (1 - (_ac.value - 0.5) / 0.5).clamp(0.0, 1.0),
                    child: Container(width: 160, height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.orange, width: 4))))),
              // Label
              Positioned(left: 0, right: 0, top: size.height * 0.65,
                child: Center(child: Opacity(opacity: _ac.value > 0.5 ? 1.0 : 0.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange)),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('⚡ HONG YI', style: cinzel(16, c: Colors.orange,
                        fw: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text('Sacrifice ultime — 9 dégâts !', style: body(12, c: Colors.white)),
                    ]))))),
            ]),
          ),
        )));
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// VLAD — Montagne qui pousse puis explose
// ═══════════════════════════════════════════════════════════════════
class VladMountainOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const VladMountainOverlay({required this.onDone});
  @override State<VladMountainOverlay> createState() => VladMountainState();
}

class VladMountainState extends State<VladMountainOverlay>
    with TickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _grow, _opacity, _shake;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2200));
    // Pousse (0→0.55), explose (0.55→0.7), retombe (0.7→1)
    _grow = TweenSequence([
      TweenSequenceItem(tween: CurveTween(curve: Curves.easeOutCubic), weight: 55),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 45),
    ]).animate(_ac);
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 8),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 22),
    ]).animate(_ac);
    _shake = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ac, curve: const Interval(0.52, 0.68, curve: Curves.easeOut)));
    _ac.forward().then((_) { if (mounted) widget.onDone(); });
  }

  @override void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    final size = MediaQuery.of(ctx).size;
    return AnimatedBuilder(
      animation: _ac,
      builder: (_, __) {
        final exploded = _ac.value > 0.55;
        final shakeT = _shake.value;
        final shakeOffset = shakeT > 0 && shakeT < 1
            ? sin(shakeT * 3.14159 * 8) * 6 * (1 - shakeT)
            : 0.0;

        return Positioned.fill(child: IgnorePointer(child: Opacity(
          opacity: _opacity.value.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(shakeOffset, 0),
            child: Stack(children: [
              // Montagne qui pousse depuis le bas
              Positioned(left: 0, right: 0, bottom: 0,
                child: Align(alignment: Alignment.bottomCenter,
                  child: Opacity(
                    opacity: exploded
                        ? (1 - ((_ac.value - 0.55) / 0.45)).clamp(0.0, 1.0)
                        : 1.0,
                    child: Transform.scale(
                      scale: _grow.value.clamp(0.0, 1.0),
                      alignment: Alignment.bottomCenter,
                      child: const Text('⛰️', style: TextStyle(fontSize: 140)))))),
              // Explosion
              if (exploded)
                Positioned(left: 0, right: 0,
                  bottom: size.height * 0.18,
                  child: Center(child: Opacity(
                    opacity: (1 - (_ac.value - 0.55) / 0.45).clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.5 + ((_ac.value - 0.55) / 0.45) * 1.5,
                      child: const Text('💥', style: TextStyle(fontSize: 90)))))),
              // Label
              Positioned(left: 0, right: 0, top: size.height * 0.2,
                child: Center(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF8D6E63))),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('⛰️ VLAD', style: cinzel(16, c: const Color(0xFFBCAAA4),
                      fw: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text("Une montagne s'élève... et explose !", style: body(12, c: Colors.white)),
                  ])))),
            ]),
          ),
        )));
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TRAVERT — Ondes de choc lumineuses depuis le bas
// ═══════════════════════════════════════════════════════════════════
class TravertShockwaveOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const TravertShockwaveOverlay({required this.onDone});
  @override State<TravertShockwaveOverlay> createState() => TravertShockwaveState();
}

class TravertShockwaveState extends State<TravertShockwaveOverlay>
    with TickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2000))
      ..addListener(() => setState(() {}));
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 8),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 22),
    ]).animate(_ac);
    _ac.forward().then((_) { if (mounted) widget.onDone(); });
  }

  @override void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    final size = MediaQuery.of(ctx).size;
    final t = _ac.value;
    return Positioned.fill(child: IgnorePointer(child: Opacity(
      opacity: _opacity.value.clamp(0.0, 1.0),
      child: Stack(children: [
        // 3 ondes décalées dans le temps, depuis le bas
        for (int i = 0; i < 3; i++)
          _wave(size, ((t - i * 0.18) % 1.0).clamp(0.0, 1.0)),
        Positioned(left: 0, right: 0, top: size.height * 0.18,
          child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFEE58))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('⚡ TRAVERT', style: cinzel(16, c: const Color(0xFFFFEE58),
                fw: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('Onde de choc dévastatrice !', style: body(12, c: Colors.white)),
            ])))),
      ]),
    )));
  }

  Widget _wave(Size size, double prog) {
    final diameter = prog * size.width * 1.8;
    final opacity = (1 - prog).clamp(0.0, 1.0);
    return Positioned(
      left: size.width / 2 - diameter / 2,
      bottom: -diameter / 3,
      child: Opacity(opacity: opacity * 0.8, child: Container(
        width: diameter, height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFFFEE58),
            width: 4 * (1 - prog) + 1),
          boxShadow: [BoxShadow(
            color: const Color(0xFFFFEE58).withValues(alpha: 0.5 * opacity),
            blurRadius: 20)],
        ),
      )),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ALBANE — Animation montre qui se rembobine
// ═══════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════
// AMÉLIA — Lumière divine du ciel
// ═══════════════════════════════════════════════════════════════════
class AmeliaLightOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const AmeliaLightOverlay({required this.onDone});
  @override State<AmeliaLightOverlay> createState() => AmeliaLightState();
}

class AmeliaLightState extends State<AmeliaLightOverlay>
    with TickerProviderStateMixin {
  late AnimationController _ac, _rayAc, _particleAc;
  late Animation<double> _opacity, _rayLen, _glow;

  @override
  void initState() {
    super.initState();
    _ac         = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2600));
    _rayAc      = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _particleAc = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 400))..repeat(reverse: true);

    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_ac);
    _rayLen = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _ac,
            curve: const Interval(0, 0.3, curve: Curves.easeOut)));
    _glow   = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _rayAc, curve: Curves.easeInOut));

    _ac.forward().then((_) { if (mounted) widget.onDone(); });
  }

  @override
  void dispose() { _ac.dispose(); _rayAc.dispose(); _particleAc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    final size = MediaQuery.of(ctx).size;
    final cx   = size.width / 2;

    return AnimatedBuilder(
      animation: Listenable.merge([_ac, _rayAc, _particleAc]),
      builder: (_, __) => Positioned.fill(child: IgnorePointer(child: Opacity(
        opacity: _opacity.value.clamp(0.0, 1.0),
        child: CustomPaint(
          painter: DivineLightPainter(
            cx:     cx,
            rayLen: _rayLen.value * size.height,
            glow:   _glow.value,
            t:      _ac.value,
            pt:     _particleAc.value,
          ),
          child: Stack(children: [

            // Icône centrale (coeur ou croix divine)
            Positioned(
              left: cx - 30,
              top: size.height * 0.30,
              child: Text('✨', style: TextStyle(
                fontSize: 40 + _glow.value * 16,
                shadows: [Shadow(color: Colors.white.withValues(alpha: 0.9),
                    blurRadius: 20 * _glow.value)]))),

            // Label
            Positioned(
              left: 0, right: 0,
              top: size.height * 0.50,
              child: Column(children: [
                Text('LUMIÈRE DIVINE', style: cinzel(16, c: Colors.white,
                  fw: FontWeight.w900, ls: 3).copyWith(
                    shadows: [Shadow(color: const Color(0xFFFFE680),
                        blurRadius: 18 * _glow.value)])),
                const SizedBox(height: 6),
                Text('Amélia — Sacrifice & Guérison',
                  style: body(12, c: const Color(0xFFFFE680))),
              ]),
            ),
          ]),
        ),
      ))),
    );
  }
}

class DivineLightPainter extends CustomPainter {
  final double cx, rayLen, glow, t, pt;
  const DivineLightPainter({
    required this.cx, required this.rayLen,
    required this.glow, required this.t, required this.pt});

  @override
  void paint(Canvas canvas, Size size) {
    // ── Colonne de lumière principale ─────────────────────────
    final beamW = 90.0 + glow * 30;
    final beamPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFFFFFFF).withValues(alpha: 0.9 * glow),
          const Color(0xFFFFE680).withValues(alpha: 0.6 * glow),
          const Color(0xFFFFD700).withValues(alpha: 0.2 * glow),
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.6, 1.0],
      ).createShader(Rect.fromLTWH(cx - beamW / 2, 0, beamW, rayLen));
    canvas.drawRect(Rect.fromLTWH(cx - beamW / 2, 0, beamW, rayLen), beamPaint);

    // ── Rayons latéraux ───────────────────────────────────────
    final rayAngles = [-0.35, -0.2, 0.2, 0.35, -0.55, 0.55];
    final rayLengths = [160.0, 220.0, 220.0, 160.0, 100.0, 100.0];
    for (int i = 0; i < rayAngles.length; i++) {
      final a   = rayAngles[i];
      final len = rayLengths[i] * glow * t.clamp(0.0, 1.0);
      final endX = cx + sin(a) * len;
      final endY = cos(a) < 0 ? 0.0 : cos(a) * len;
      final rPaint = Paint()
        ..color = const Color(0xFFFFE680).withValues(alpha: 0.3 * glow)
        ..strokeWidth = 3.0 - i.toDouble() * 0.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(cx, 0), Offset(endX, endY), rPaint);
    }

    // ── Halo circulaire au point de départ ────────────────────
    final haloPaint = Paint()
      ..shader = RadialGradient(colors: [
        Colors.white.withValues(alpha: 0.9 * glow),
        const Color(0xFFFFE680).withValues(alpha: 0.4 * glow),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: Offset(cx, 0), radius: 80 * glow));
    canvas.drawCircle(Offset(cx, 0), 80 * glow, haloPaint);

    // ── Particules flottantes ─────────────────────────────────
    final numParticles = 12;
    for (int i = 0; i < numParticles; i++) {
      final progress = (t + i / numParticles) % 1.0;
      final px = cx + sin(i * 2.6 + pt * 6.28) * (beamW * 0.6);
      final py = progress * rayLen * 0.85;
      final ps = (3 + i % 4).toDouble() * glow;
      canvas.drawCircle(
        Offset(px, py), ps,
        Paint()..color = Colors.white.withValues(alpha: 0.7 * (1 - progress) * glow));
    }
  }

  @override bool shouldRepaint(DivineLightPainter old) =>
      old.rayLen != rayLen || old.glow != glow || old.t != t || old.pt != pt;
}


class AlbaneClockOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const AlbaneClockOverlay({required this.onDone});
  @override State<AlbaneClockOverlay> createState() => AlbaneClockState();
}

class AlbaneClockState extends State<AlbaneClockOverlay>
    with TickerProviderStateMixin {
  late AnimationController _rewindAc, _fadeAc;
  late Animation<double> _rewind, _opacity;

  @override
  void initState() {
    super.initState();
    // Rembobinage : tourne en SENS INVERSE sur 1.5s
    _rewindAc = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1500));
    _fadeAc   = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2200));

    // Aiguilles tournent en arrière (0 → -2π × 2)
    _rewind = Tween<double>(begin: 0.0, end: -6.28 * 2.5)
        .animate(CurvedAnimation(parent: _rewindAc, curve: Curves.easeInOut));
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 12),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 58),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_fadeAc);

    _rewindAc.forward();
    _fadeAc.forward().then((_) { if (mounted) widget.onDone(); });
  }

  @override void dispose() { _rewindAc.dispose(); _fadeAc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: Listenable.merge([_rewindAc, _fadeAc]),
        builder: (_, __) => Opacity(
          opacity: _opacity.value.clamp(0.0, 1.0),
          child: Center(child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kBg2.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kGold, width: 2),
              boxShadow: [BoxShadow(color: kGold.withValues(alpha: 0.4), blurRadius: 16)],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('⏪ ALBANE', style: cinzel(11, c: kGold, fw: FontWeight.w700)),
              const SizedBox(height: 10),
              // Cadran de montre
              CustomPaint(
                size: const Size(100, 100),
                painter: ClockPainter(angle: _rewind.value),
              ),
              const SizedBox(height: 8),
              Text('Rembobinage !', style: body(10, c: kGold2)),
              Text('Lance 2 fois les dés', style: body(9, c: kTextDim)),
            ]),
          )),
        ),
      ),
    );
  }
}

class ClockPainter extends CustomPainter {
  final double angle; // angle des aiguilles (négatif = sens inverse)
  const ClockPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2 - 2;

    // Cercle du cadran
    canvas.drawCircle(Offset(cx, cy), r,
      Paint()..color = const Color(0xFF1A1A2E)..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(cx, cy), r,
      Paint()..color = const Color(0xFFD4A017)..style = PaintingStyle.stroke..strokeWidth = 2.5);

    // Graduations
    for (int i = 0; i < 12; i++) {
      final a  = i * 3.14159 / 6;
      final r1 = i % 3 == 0 ? r - 8 : r - 5;
      canvas.drawLine(
        Offset(cx + r1 * sin(a), cy - r1 * cos(a)),
        Offset(cx + (r - 2) * sin(a), cy - (r - 2) * cos(a)),
        Paint()..color = const Color(0xFFD4A017)
            ..strokeWidth = i % 3 == 0 ? 2.0 : 1.0
            ..strokeCap = StrokeCap.round);
    }

    // Aiguille des minutes (longue)
    final mAngle = angle * 1.0;
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + (r - 12) * sin(mAngle), cy - (r - 12) * cos(mAngle)),
      Paint()..color = Colors.white..strokeWidth = 2.0..strokeCap = StrokeCap.round);

    // Aiguille des heures (courte)
    final hAngle = angle * 0.4;
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + (r - 24) * sin(hAngle), cy - (r - 24) * cos(hAngle)),
      Paint()..color = const Color(0xFFD4A017)..strokeWidth = 3.0..strokeCap = StrokeCap.round);

    // Centre
    canvas.drawCircle(Offset(cx, cy), 4,
      Paint()..color = const Color(0xFFFFD700));
  }

  @override bool shouldRepaint(ClockPainter old) => old.angle != angle;
}



// ═══════════════════════════════════════════════════════════════════
// Résultat de dé pour les capacités — version générique (onDone callback)
// Identique au solo (_AbilityDiceRoll) mais sans dépendance au contrôleur.
// ═══════════════════════════════════════════════════════════════════
class AbilityDiceRoll extends StatefulWidget {
  final Map<String, int> result;
  final VoidCallback onDone;
  const AbilityDiceRoll({super.key, required this.result, required this.onDone});
  @override State<AbilityDiceRoll> createState() => _AbilityDiceRollState();
}

class _AbilityDiceRollState extends State<AbilityDiceRoll>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1400));

    _ac.forward().then((_) {
      if (!mounted) return;
      setState(() => _revealed = true);
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (!mounted) return;
        widget.onDone();
      });
    });
  }

  @override void dispose() { _ac.dispose(); super.dispose(); }

  Widget _dieBox(int val, int sides, Color color) => Container(
    width: 90, height: 90,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: sides == 4
          ? BorderRadius.circular(10)
          : BorderRadius.circular(18),
      border: Border.all(color: color, width: 3),
      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 16)],
    ),
    child: Center(child: Text('$val',
      style: TextStyle(fontSize: 44, fontFamily: 'Cinzel',
        fontWeight: FontWeight.w900, color: color))),
  );

  @override
  Widget build(BuildContext ctx) {
    final d      = widget.result['d'] ?? 6;
    final result = widget.result['result'] ?? 0;
    final dmg    = widget.result['dmg'] ?? 0;
    final d4val  = widget.result['d4val'];
    final d6val  = widget.result['d6val'];
    final isBombe = d4val != null && d6val != null;
    final isD4   = d == 4 && !isBombe;
    final sides  = isD4 ? 4 : 6;
    final color  = dmg >= 6 ? kRed : dmg >= 3 ? kGold : kGreen;
    final label  = isBombe ? 'BOMBE  D4 + D6' : (isD4 ? 'D4' : 'D6');

    return Center(child: Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0A2E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color, width: 2.5),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 18)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: cinzel(13, c: kTextSub, ls: 2)),
        const SizedBox(height: 14),
        AnimatedBuilder(
          animation: _ac,
          builder: (_, __) {
            if (_revealed) {
              if (isBombe) {
                return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _dieBox(d4val!, 4, color),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('+', style: cinzel(24, c: kGold))),
                  _dieBox(d6val!, 6, color),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('=$result', style: cinzel(24, c: kGold))),
                ]);
              }
              return _dieBox(result, sides, color);
            }
            final spinning = ((_ac.value * 18).floor() % sides) + 1;
            return _dieBox(spinning, sides, kBord2);
          },
        ),
        const SizedBox(height: 14),
        if (_revealed) ...[
          Text(
            isBombe
              ? 'Zone $result — 2 blessures'
              : dmg > 0
                ? '$dmg blessure${dmg > 1 ? "s" : ""}'
                : 'Soigne ${ -dmg } blessure${ -dmg > 1 ? "s" : "" }',
            style: cinzel(18, c: color, fw: FontWeight.w900)),
        ] else
          Text('Lancement...', style: body(13, c: kTextSub)),
      ]),
    ));
  }
}

// ═══════════════════════════════════════════════════════════════════
// BALEINE — à sa mort, des bulles et étoiles d'eau montent et soignent
// tous les Hunters révélés
// ═══════════════════════════════════════════════════════════════════
class BaleineHealOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const BaleineHealOverlay({required this.onDone});
  @override State<BaleineHealOverlay> createState() => BaleineHealState();
}

class BaleineHealState extends State<BaleineHealOverlay>
    with TickerProviderStateMixin {
  late AnimationController _ac, _fadeAc;
  late Animation<double> _opacity;
  final List<Particle> _bubbles = [];
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 60))
      ..addListener(() => setState(() {}))
      ..repeat();
    _fadeAc = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2800));
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 12),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 58),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_fadeAc);

    const emojis = ['💧','✨','🫧','💙','⭐'];
    for (int i = 0; i < 26; i++) {
      _bubbles.add(Particle(
        x: _rng.nextDouble(),
        y: 1.0 + _rng.nextDouble() * 0.4, // partent du bas, montent (contrairement à Carapatte qui tombe)
        speed: 0.003 + _rng.nextDouble() * 0.005,
        emoji: emojis[_rng.nextInt(emojis.length)],
        size: 16 + _rng.nextDouble() * 20,
        drift: (_rng.nextDouble() - 0.5) * 0.0010,
        rot: _rng.nextDouble() * 3.14,
      ));
    }
    _fadeAc.forward().then((_) { if (mounted) widget.onDone(); });
  }

  @override void dispose() { _ac.dispose(); _fadeAc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    for (final p in _bubbles) {
      p.y -= p.speed; // montent au lieu de tomber
      p.x += p.drift;
      p.rot += 0.02;
      if (p.y < -0.1) { p.y = 1.05; p.x = _rng.nextDouble(); }
    }
    final size = MediaQuery.of(ctx).size;
    return Positioned.fill(child: IgnorePointer(child: Opacity(
      opacity: _opacity.value.clamp(0.0, 1.0),
      child: Stack(children: [
        Container(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [
            const Color(0xFF4FC3F7).withValues(alpha: 0.14),
            Colors.transparent,
          ]))),
        ..._bubbles.map((p) => Positioned(
          left: p.x * size.width,
          top:  p.y * size.height,
          child: Transform.rotate(angle: p.rot,
            child: Text(p.emoji, style: TextStyle(fontSize: p.size))))),
        Positioned(left: 0, right: 0, top: size.height * 0.42,
          child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4FC3F7))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('🐋 BALEINE', style: cinzel(16, c: const Color(0xFF81D4FA),
                fw: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('Dernier souffle — les Hunters révélés sont soignés',
                style: body(12, c: Colors.white)),
            ])))),
      ]),
    )));
  }
}

