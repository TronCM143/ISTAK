import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:math' as math;

/// Drop-in, non-looping animated “cloudy” background (green + dark blue).
/// Usage:
///   CloudyBackground(
///     child: YourPageContent(), // optional
///   )
class CloudyBackground extends StatefulWidget {
  /// Optional content drawn above the cloudy painter.
  final Widget? child;

  /// Number of blobs (more = richer but heavier).
  final int blobCount;

  /// Fraction [0..1] of blobs that are “giant”.
  final double giantFraction;

  /// Probability [0..1] a blob is green (rest will be dark blue).
  final double greenBias;

  /// Blur sigma for softness.
  final double blurSigma;

  /// Blend mode for glow.
  final BlendMode blendMode;

  /// Base gradient behind the glow.
  final List<Color> baseGradientColors;

  /// Speed multiplier (1.0 = default).
  final double speed;

  /// Optional RNG seed for reproducible layouts.
  final int? randomSeed;

  const CloudyBackground({
    super.key,
    this.child,
    this.blobCount = 16,
    this.giantFraction = 0.28,
    this.greenBias = 0.55,
    this.blurSigma = 64,
    this.blendMode = BlendMode.screen,
    this.baseGradientColors = const [Color(0xFF06101A), Color(0xFF02050B)],
    this.speed = 1.0,
    this.randomSeed,
  });

  @override
  State<CloudyBackground> createState() => _CloudyBackgroundState();
}

class _CloudyBackgroundState extends State<CloudyBackground>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _time = 0.0;
  late List<_Blob> _blobs;

  @override
  void initState() {
    super.initState();
    _generateBlobs();

    _ticker = createTicker((elapsed) {
      _time = (elapsed.inMicroseconds / 1e6) * widget.speed;
      setState(() {});
    })..start();
  }

  @override
  void didUpdateWidget(covariant CloudyBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Regenerate only if parameters that define the field change.
    if (oldWidget.blobCount != widget.blobCount ||
        oldWidget.giantFraction != widget.giantFraction ||
        oldWidget.greenBias != widget.greenBias ||
        oldWidget.randomSeed != widget.randomSeed) {
      _generateBlobs();
    }
  }

  void _generateBlobs() {
    final rnd = widget.randomSeed != null
        ? math.Random(widget.randomSeed)
        : math.Random();

    _blobs = List.generate(widget.blobCount, (i) {
      final isGreen = rnd.nextDouble() < widget.greenBias;
      final isGiant = rnd.nextDouble() < widget.giantFraction;
      return _Blob(
        xSeed: rnd.nextDouble() * 2 * math.pi,
        ySeed: rnd.nextDouble() * 2 * math.pi,
        rSeed: rnd.nextDouble() * 2 * math.pi,
        hueSeed: rnd.nextDouble() * 2 * math.pi,
        freqX: _lerp(0.08, 0.18, rnd.nextDouble()),
        freqY: _lerp(0.06, 0.16, rnd.nextDouble()),
        freqR: _lerp(0.05, 0.11, rnd.nextDouble()),
        radiusFactor: _lerp(0.12, 0.24, rnd.nextDouble()),
        hueDrift: _lerp(0.6, 1.3, rnd.nextDouble()),
        alpha: _lerp(0.20, 0.32, rnd.nextDouble()),
        isGreen: isGreen,
        isGiant: isGiant,
      );
    });
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
        painter: _CloudPainter(
          time: _time,
          blobs: _blobs,
          blurSigma: widget.blurSigma,
          blendMode: widget.blendMode,
          baseGradientColors: widget.baseGradientColors,
        ),
        isComplex: true,
        willChange: true,
        // Draw your UI above the background
        child: widget.child ?? const SizedBox.expand(),
      ),
    );
  }
}

class _Blob {
  final double xSeed, ySeed, rSeed, hueSeed;
  final double freqX, freqY, freqR;
  final double radiusFactor;
  final double hueDrift;
  final double alpha;
  final bool isGreen;
  final bool isGiant;

  const _Blob({
    required this.xSeed,
    required this.ySeed,
    required this.rSeed,
    required this.hueSeed,
    required this.freqX,
    required this.freqY,
    required this.freqR,
    required this.radiusFactor,
    required this.hueDrift,
    required this.alpha,
    required this.isGreen,
    required this.isGiant,
  });
}

class _CloudPainter extends CustomPainter {
  final double time; // seconds since start (monotonic)
  final List<_Blob> blobs;
  final double blurSigma;
  final BlendMode blendMode;
  final List<Color> baseGradientColors;

  _CloudPainter({
    required this.time,
    required this.blobs,
    required this.blurSigma,
    required this.blendMode,
    required this.baseGradientColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Base gradient (deep navy)
    final base = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: baseGradientColors,
      ).createShader(rect);
    canvas.drawRect(rect, base);

    canvas.saveLayer(rect, Paint());

    final diag = math.sqrt(size.width * size.width + size.height * size.height);
    final cx = size.width / 2;
    final cy = size.height / 2;

    for (final b in blobs) {
      final ampX = size.width * 0.55;
      final ampY = size.height * 0.55;

      final x = cx + ampX * math.sin(time * b.freqX + b.xSeed);
      final y = cy + ampY * math.cos(time * b.freqY + b.ySeed);

      final baseR = b.radiusFactor * diag * (b.isGiant ? 1.6 : 1.0);
      final r = baseR * (1.0 + 0.25 * math.sin(time * b.freqR + b.rSeed));

      // Palette: ONLY green (~135°) and dark blue (~215°), tiny hue wobble.
      final hueCenter = b.isGreen ? 135.0 : 215.0;
      final hue = hueCenter + 8.0 * math.sin(time * b.hueDrift + b.hueSeed);
      final saturation = b.isGreen ? 0.85 : 0.90;
      final value = b.isGreen
          ? 1.00
          : 0.72 + 0.12 * (0.5 + 0.5 * math.sin(time * 0.6 + b.hueSeed));

      final color = HSVColor.fromAHSV(
        b.alpha,
        hue,
        saturation,
        value,
      ).toColor();

      final shader = RadialGradient(
        colors: [
          color,
          color.withOpacity(color.opacity * 0.35),
          color.withOpacity(0.0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(x, y), radius: r));

      final paint = Paint()
        ..shader = shader
        ..blendMode = blendMode
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);

      canvas.drawCircle(Offset(x, y), r, paint);
    }

    // Subtle vignette
    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.95,
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(0.10),
          Colors.black.withOpacity(0.22),
        ],
        stops: const [0.60, 0.90, 1.0],
      ).createShader(rect)
      ..blendMode = BlendMode.multiply;
    canvas.drawRect(rect, vignette);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CloudPainter old) {
    return old.time != time ||
        old.blobs != blobs ||
        old.blurSigma != blurSigma ||
        old.blendMode != blendMode ||
        old.baseGradientColors != baseGradientColors;
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
