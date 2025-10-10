import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Animated background with large curvy wave ribbons whose COLORS
/// drift in every direction (orientation, hue, position).
class AbstractWavesBackground extends StatefulWidget {
  final Widget? child;

  /// 3–6 looks nice.
  final int layerCount;

  /// Animation speed multiplier.
  final double speed;

  /// Overall wave height as a fraction of screen height (0.0–1.0).
  final double amplitudeFactor;

  /// Range (min..max) of ribbon thickness in px.
  final (double, double) thicknessRange;

  /// Optional RNG seed for reproducible layouts.
  final int? randomSeed;

  /// Base colors per layer (cycled); they will hue-drift over time.
  final List<Color> palette;

  /// Edge softness for each ribbon.
  final double blurSigma;

  /// Blend mode for layering ribbons.
  final BlendMode blendMode;

  /// Max hue drift in degrees (±).
  final double maxHueDriftDegrees;

  /// Rotation speed of the gradient (radians/sec).
  final double gradientRotationSpeed;

  /// How much ribbons wander around (0..1). 0.06 is subtle, 0.15 is wild.
  final double driftAmount;

  const AbstractWavesBackground({
    super.key,
    this.child,
    this.layerCount = 4,
    this.speed = 1.0,
    this.amplitudeFactor = 0.22,
    this.thicknessRange = (140, 240),
    this.randomSeed,
    this.palette = const [
      Color(0xFF00F5C4), // minty green
      Color(0xFF2E6BFF), // blue
      Color(0xFF00D0FF), // cyan
      Color(0xFF00C49A), // teal-green
    ],
    this.blurSigma = 28,
    this.blendMode = BlendMode.screen,
    this.maxHueDriftDegrees = 18.0,
    this.gradientRotationSpeed = 0.6,
    this.driftAmount = 0.08,
  });

  @override
  State<AbstractWavesBackground> createState() =>
      _AbstractWavesBackgroundState();
}

class _AbstractWavesBackgroundState extends State<AbstractWavesBackground>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0.0;
  late List<_WaveLayer> _layers;

  @override
  void initState() {
    super.initState();
    _layers = _makeLayers(widget.layerCount, widget.randomSeed);
    _ticker = createTicker((elapsed) {
      _t = elapsed.inMicroseconds / 1e6 * widget.speed;
      setState(() {});
    })..start();
  }

  @override
  void didUpdateWidget(covariant AbstractWavesBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layerCount != widget.layerCount ||
        oldWidget.randomSeed != widget.randomSeed) {
      _layers = _makeLayers(widget.layerCount, widget.randomSeed);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _WavesPainter(
          t: _t,
          layers: _layers,
          amplitudeFactor: widget.amplitudeFactor,
          thicknessRange: widget.thicknessRange,
          palette: widget.palette,
          blurSigma: widget.blurSigma,
          blendMode: widget.blendMode,
          maxHueDriftDegrees: widget.maxHueDriftDegrees,
          gradientRotationSpeed: widget.gradientRotationSpeed,
          driftAmount: widget.driftAmount,
        ),
        isComplex: true,
        willChange: true,
        child: widget.child ?? const SizedBox.expand(),
      ),
    );
  }

  List<_WaveLayer> _makeLayers(int count, int? seed) {
    final rnd = seed == null ? math.Random() : math.Random(seed);
    return List.generate(count, (i) {
      final baseYFrac = 0.2 + 0.6 * (i / math.max(1, count - 1));
      return _WaveLayer(
        baseYFrac: baseYFrac + (rnd.nextDouble() - 0.5) * 0.06,
        phase1: rnd.nextDouble() * math.pi * 2,
        phase2: rnd.nextDouble() * math.pi * 2,
        freq1: 2.0 * math.pi / 900.0 * (0.8 + rnd.nextDouble() * 0.6),
        freq2: 2.0 * math.pi / 550.0 * (0.8 + rnd.nextDouble() * 0.6),
        speed1: 0.6 + rnd.nextDouble() * 0.7,
        speed2: 0.8 + rnd.nextDouble() * 0.8,
        // Color drift (hue) params:
        hueSeed: rnd.nextDouble() * math.pi * 2,
        hueSpeed: 0.4 + rnd.nextDouble() * 0.6,
        // Gradient rotation:
        gradSeed: rnd.nextDouble() * math.pi * 2,
        gradSpeed: 0.6 + rnd.nextDouble() * 0.7,
        // XY drift:
        driftSeedX: rnd.nextDouble() * math.pi * 2,
        driftSeedY: rnd.nextDouble() * math.pi * 2,
        driftSpeedX: 0.5 + rnd.nextDouble() * 0.8,
        driftSpeedY: 0.5 + rnd.nextDouble() * 0.8,
        z: i.toDouble(),
      );
    });
  }
}

class _WaveLayer {
  final double baseYFrac;
  final double phase1, phase2;
  final double freq1, freq2;
  final double speed1, speed2;
  final double z;

  // Color drift (hue)
  final double hueSeed;
  final double hueSpeed;

  // Gradient rotation drift
  final double gradSeed;
  final double gradSpeed;

  // XY translation drift
  final double driftSeedX, driftSeedY;
  final double driftSpeedX, driftSpeedY;

  const _WaveLayer({
    required this.baseYFrac,
    required this.phase1,
    required this.phase2,
    required this.freq1,
    required this.freq2,
    required this.speed1,
    required this.speed2,
    required this.z,
    required this.hueSeed,
    required this.hueSpeed,
    required this.gradSeed,
    required this.gradSpeed,
    required this.driftSeedX,
    required this.driftSeedY,
    required this.driftSpeedX,
    required this.driftSpeedY,
  });
}

class _WavesPainter extends CustomPainter {
  final double t;
  final List<_WaveLayer> layers;
  final double amplitudeFactor;
  final (double, double) thicknessRange;
  final List<Color> palette;
  final double blurSigma;
  final BlendMode blendMode;

  final double maxHueDriftDegrees;
  final double gradientRotationSpeed;
  final double driftAmount;

  _WavesPainter({
    required this.t,
    required this.layers,
    required this.amplitudeFactor,
    required this.thicknessRange,
    required this.palette,
    required this.blurSigma,
    required this.blendMode,
    required this.maxHueDriftDegrees,
    required this.gradientRotationSpeed,
    required this.driftAmount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Deep base so colors pop.
    final basePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF08121D), Color(0xFF030812)],
      ).createShader(rect);
    canvas.drawRect(rect, basePaint);

    canvas.saveLayer(rect, Paint());

    final amp = amplitudeFactor.clamp(0.0, 1.0) * size.height;
    final minTh = thicknessRange.$1;
    final maxTh = thicknessRange.$2;

    // Back-to-front.
    for (var i = 0; i < layers.length; i++) {
      final layer = layers[i];
      final baseColor = palette[i % palette.length];

      // Thickness per layer (front is thicker).
      final tNorm = i / math.max(1, layers.length - 1);
      final thickness = _mix(minTh, maxTh, 0.25 + 0.75 * tNorm);

      // Build ribbon shape
      final path = _buildRibbonPath(
        width: size.width,
        height: size.height,
        baseY: layer.baseYFrac * size.height,
        amp: amp * (0.75 + 0.25 * (1.0 - tNorm)),
        thickness: thickness,
        phase1: layer.phase1 + t * layer.speed1,
        phase2: layer.phase2 - t * layer.speed2,
        freq1: layer.freq1,
        freq2: layer.freq2,
      );

      // XY drift (ribbons wander around)
      final dx =
          math.cos(t * layer.driftSpeedX + layer.driftSeedX) *
          size.width *
          driftAmount *
          (0.45 + 0.55 * (tNorm)); // front moves a hair more
      final dy =
          math.sin(t * layer.driftSpeedY + layer.driftSeedY) *
          size.height *
          driftAmount *
          (0.35 + 0.65 * (1.0 - tNorm));

      canvas.save();
      canvas.translate(dx, dy);

      // Gradient direction rotates over time (feels like color drifting)
      final ang =
          t * (gradientRotationSpeed * layer.gradSpeed) + layer.gradSeed;
      final begin = Alignment(math.cos(ang), math.sin(ang));
      final end = Alignment(-math.cos(ang), -math.sin(ang));

      // Hue drift around base color
      final baseHSV = HSVColor.fromColor(baseColor);
      final hueOffset =
          math.sin(t * layer.hueSpeed + layer.hueSeed) * maxHueDriftDegrees;
      final drifted = baseHSV.withHue((baseHSV.hue + hueOffset) % 360.0);
      final c0 = drifted.withSaturation(
        (baseHSV.saturation * 1.00).clamp(0, 1),
      );
      final c1 = drifted.withSaturation(
        (baseHSV.saturation * 0.85).clamp(0, 1),
      );
      final c2 = drifted.withSaturation(
        (baseHSV.saturation * 0.70).clamp(0, 1),
      );

      final grad = LinearGradient(
        begin: begin,
        end: end,
        colors: [
          c0.toColor().withOpacity(0.42),
          c1.toColor().withOpacity(0.20),
          c2.toColor().withOpacity(0.08),
        ],
        stops: const [0.0, 0.55, 1.0],
      );

      final paint = Paint()
        ..blendMode = blendMode
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma)
        ..shader = grad.createShader(rect);

      canvas.drawPath(path, paint);
      canvas.restore();
    }

    // Subtle vignette for depth
    final vignette = Paint()
      ..blendMode = BlendMode.multiply
      ..shader = const RadialGradient(
        center: Alignment.center,
        radius: 0.95,
        colors: [
          Colors.transparent,
          Color.fromARGB(38, 0, 0, 0),
          Color.fromARGB(60, 0, 0, 0),
        ],
        stops: [0.65, 0.90, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);

    canvas.restore();
  }

  Path _buildRibbonPath({
    required double width,
    required double height,
    required double baseY,
    required double amp,
    required double thickness,
    required double phase1,
    required double phase2,
    required double freq1,
    required double freq2,
  }) {
    final dx = math.max(6.0, width / 64.0);

    final centers = <Offset>[];
    for (double x = 0; x <= width; x += dx) {
      final y =
          baseY +
          amp *
              (0.60 * math.sin(x * freq1 + phase1) +
                  0.40 * math.sin(x * freq2 + phase2));
      centers.add(Offset(x, y));
    }
    if (centers.last.dx < width) {
      final x = width;
      final y =
          baseY +
          amp *
              (0.60 * math.sin(x * freq1 + phase1) +
                  0.40 * math.sin(x * freq2 + phase2));
      centers.add(Offset(x, y));
    }

    final half = thickness / 2.0;
    final top = <Offset>[];
    final bot = <Offset>[];

    for (int i = 0; i < centers.length; i++) {
      final p = centers[i];
      final pPrev = centers[i == 0 ? i : i - 1];
      final pNext = centers[i == centers.length - 1 ? i : i + 1];

      final tx = pNext.dx - pPrev.dx;
      final ty = pNext.dy - pPrev.dy;
      final len = math.sqrt(tx * tx + ty * ty) + 1e-6;

      final nx = -ty / len;
      final ny = tx / len;

      top.add(Offset(p.dx + nx * half, p.dy + ny * half));
      bot.add(Offset(p.dx - nx * half, p.dy - ny * half));
    }

    final path = Path()..moveTo(bot.first.dx, bot.first.dy);
    for (final b in bot.skip(1)) {
      path.lineTo(b.dx, b.dy);
    }
    for (final t in top.reversed) {
      path.lineTo(t.dx, t.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _WavesPainter old) {
    return old.t != t ||
        old.layers != layers ||
        old.amplitudeFactor != amplitudeFactor ||
        old.thicknessRange != thicknessRange ||
        old.palette != palette ||
        old.blurSigma != blurSigma ||
        old.blendMode != blendMode ||
        old.maxHueDriftDegrees != maxHueDriftDegrees ||
        old.gradientRotationSpeed != gradientRotationSpeed ||
        old.driftAmount != driftAmount;
  }
}

double _mix(double a, double b, double t) => a + (b - a) * t;
