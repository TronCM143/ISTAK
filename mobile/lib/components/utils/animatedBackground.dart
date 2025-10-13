import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class Point4D {
  double x, y, z, w;
  Point4D(this.x, this.y, this.z, this.w);
}

class Point3D {
  double x, y, z;
  Point3D(this.x, this.y, this.z);
}

class Matrix4x4 {
  List<List<double>> data;
  Matrix4x4(this.data);

  // Matrix multiplication for 4x4 * 4x1
  Point4D multiplyVector(Point4D p) {
    final result = [
      data[0][0] * p.x + data[0][1] * p.y + data[0][2] * p.z + data[0][3] * p.w,
      data[1][0] * p.x + data[1][1] * p.y + data[1][2] * p.z + data[1][3] * p.w,
      data[2][0] * p.x + data[2][1] * p.y + data[2][2] * p.z + data[2][3] * p.w,
      data[3][0] * p.x + data[3][1] * p.y + data[3][2] * p.z + data[3][3] * p.w,
    ];
    return Point4D(result[0], result[1], result[2], result[3]);
  }
}

class Matrix3x4 {
  List<List<double>> data;
  Matrix3x4(this.data);

  // Matrix multiplication for 3x4 * 4x1
  Point3D multiplyVector(Point4D p) {
    final result = [
      data[0][0] * p.x + data[0][1] * p.y + data[0][2] * p.z + data[0][3] * p.w,
      data[1][0] * p.x + data[1][1] * p.y + data[1][2] * p.z + data[1][3] * p.w,
      data[2][0] * p.x + data[2][1] * p.y + data[2][2] * p.z + data[2][3] * p.w,
    ];
    return Point3D(result[0], result[1], result[2]);
  }
}

class Matrix2x3 {
  List<List<double>> data;
  Matrix2x3(this.data);

  // Matrix multiplication for 2x3 * 3x1
  Offset multiplyVector(Point3D p) {
    final result = [
      data[0][0] * p.x + data[0][1] * p.y + data[0][2] * p.z,
      data[1][0] * p.x + data[1][1] * p.y + data[1][2] * p.z,
    ];
    return Offset(result[0], result[1]);
  }
}

// Composes matrices (right-to-left multiplication)
Matrix4x4 composeMatrices(List<Matrix4x4> matrices) {
  return matrices.reduce((a, b) {
    final result = List.generate(4, (_) => List.filled(4, 0.0));
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        for (int k = 0; k < 4; k++) {
          result[i][j] += a.data[i][k] * b.data[k][j];
        }
      }
    }
    return Matrix4x4(result);
  });
}

Matrix4x4 createRotation4D({
  double zw = 0,
  double yw = 0,
  double yz = 0,
  double xw = 0,
  double xz = 0,
  double xy = 0,
}) {
  final zwRot = Matrix4x4([
    [math.cos(zw), -math.sin(zw), 0, 0],
    [math.sin(zw), math.cos(zw), 0, 0],
    [0, 0, 1, 0],
    [0, 0, 0, 1],
  ]);

  final ywRot = Matrix4x4([
    [math.cos(yw), 0, -math.sin(yw), 0],
    [0, 1, 0, 0],
    [math.sin(yw), 0, math.cos(yw), 0],
    [0, 0, 0, 1],
  ]);

  final yzRot = Matrix4x4([
    [math.cos(yz), 0, 0, -math.sin(yz)],
    [0, 1, 0, 0],
    [0, 0, 1, 0],
    [math.sin(yz), 0, 0, math.cos(yz)],
  ]);

  final xwRot = Matrix4x4([
    [1, 0, 0, 0],
    [0, math.cos(xw), -math.sin(xw), 0],
    [0, math.sin(xw), math.cos(xw), 0],
    [0, 0, 0, 1],
  ]);

  final xzRot = Matrix4x4([
    [1, 0, 0, 0],
    [0, math.cos(xz), 0, -math.sin(xz)],
    [0, 0, 1, 0],
    [0, math.sin(xz), 0, math.cos(xz)],
  ]);

  final xyRot = Matrix4x4([
    [1, 0, 0, 0],
    [0, 1, 0, 0],
    [0, 0, math.cos(xy), -math.sin(xy)],
    [0, 0, math.sin(xy), math.cos(xy)],
  ]);

  return composeMatrices([zwRot, ywRot, yzRot, xwRot, xzRot, xyRot]);
}

Matrix3x4 transform4dPersp(double distance, double w) {
  final scale = 1 / (distance - w == 0 ? 0.01 : distance - w);
  return Matrix3x4([
    [scale, 0, 0, 0],
    [0, scale, 0, 0],
    [0, 0, scale, 0],
  ]);
}

Matrix2x3 transform3dPersp(double distance, double z) {
  final scale = 1 / (distance - z == 0 ? 0.01 : distance - z);
  return Matrix2x3([
    [scale, 0, 0],
    [0, scale, 0],
  ]);
}

class AbstractWavesBackground extends StatefulWidget {
  final Widget? child;
  final double speed;
  final double blurSigma;
  final List<Color> palette;
  final BlendMode blendMode;
  final double size;
  final double positionX;
  final double positionY;

  const AbstractWavesBackground({
    super.key,
    this.child,
    this.speed = 1.0,
    this.blurSigma = 28,
    this.palette = const [
      Color.fromARGB(255, 31, 149, 2),
      Color.fromARGB(255, 2, 116, 84),
      Color.fromARGB(255, 2, 92, 117),
      Color.fromARGB(255, 1, 48, 118),
      Color.fromARGB(255, 1, 39, 106),
    ],
    this.blendMode = BlendMode.screen,
    this.size = 100,
    this.positionX = 0.5,
    this.positionY = 0.5,
  });

  @override
  State<AbstractWavesBackground> createState() =>
      _AbstractWavesBackgroundState();
}

class _AbstractWavesBackgroundState extends State<AbstractWavesBackground>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0.0;
  late final List<_FloatingShape3D> _shapes;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random();
    _shapes = [
      _FloatingShape3D(
        baseX: widget.positionX,
        baseY: widget.positionY,
        baseZ: rnd.nextDouble() * 0.8 + 0.2,
        size: widget.size,
        speed: 0.3 + rnd.nextDouble() * 0.8,
        rotSpeed: widget.speed,
        type: 4, // tesseract
        hueSeed: rnd.nextDouble() * math.pi * 2,
      ),
    ];
    _ticker = createTicker((elapsed) {
      _t = elapsed.inMicroseconds / 1e6 * widget.speed;
      setState(() {});
    })..start();
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
        painter: _FloatingShapes3DPainter(
          t: _t,
          shapes: _shapes,
          palette: widget.palette,
          blurSigma: widget.blurSigma,
          blendMode: widget.blendMode,
        ),
        child: widget.child ?? const SizedBox.expand(),
      ),
    );
  }
}

class _FloatingShape3D {
  final double baseX, baseY;
  final double baseZ;
  final double size;
  final double speed;
  final double rotSpeed;
  final int type;
  final double hueSeed;

  _FloatingShape3D({
    required this.baseX,
    required this.baseY,
    required this.baseZ,
    required this.size,
    required this.speed,
    required this.rotSpeed,
    required this.type,
    required this.hueSeed,
  });

  factory _FloatingShape3D.random(int seed, double size) {
    final rnd = math.Random(seed);
    return _FloatingShape3D(
      baseX: rnd.nextDouble(),
      baseY: rnd.nextDouble(),
      baseZ: rnd.nextDouble() * 0.8 + 0.2,
      size: size,
      speed: 0.3 + rnd.nextDouble() * 0.8,
      rotSpeed: 0.2 + rnd.nextDouble() * 0.4,
      type: rnd.nextInt(4),
      hueSeed: rnd.nextDouble() * math.pi * 2,
    );
  }
}

class _FloatingShapes3DPainter extends CustomPainter {
  final double t;
  final List<_FloatingShape3D> shapes;
  final List<Color> palette;
  final double blurSigma;
  final BlendMode blendMode;

  _FloatingShapes3DPainter({
    required this.t,
    required this.shapes,
    required this.palette,
    required this.blurSigma,
    required this.blendMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Background
    final base = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF030C12), Color(0xFF010409)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRect(rect, base);

    canvas.saveLayer(rect, Paint());

    for (int i = 0; i < shapes.length; i++) {
      final s = shapes[i];
      final baseColor = palette[i % palette.length];

      final cx = size.width * s.baseX;
      final cy = size.height * s.baseY;

      // Simulate depth (Z)
      final z = s.baseZ + 0.1 * math.sin(t * s.speed + i);
      final scale = 0.5 + z * 0.6;

      // Base gradient for non-tesseract shapes
      final gradient = RadialGradient(
        colors: [
          baseColor.withOpacity(0.45),
          baseColor.withOpacity(0.15),
          Colors.transparent,
        ],
        stops: const [0.0, 0.7, 1.0],
      );

      final paint = Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(center: Offset(cx, cy), radius: s.size * scale),
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma)
        ..blendMode = blendMode;

      if (s.type == 4) {
        paint.style = PaintingStyle.stroke;
        paint.strokeWidth = s.size * scale / 20;
      }

      final path = _shape3DPath(
        s.type,
        cx,
        cy,
        s.size * scale,
        t * s.rotSpeed,
        canvas,
      );
      canvas.drawPath(path, paint);
    }

    canvas.restore();
  }

  Path _shape3DPath(
    int type,
    double cx,
    double cy,
    double size,
    double rot,
    Canvas canvas,
  ) {
    switch (type) {
      case 0: // Sphere
        return Path()
          ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: size / 2));
      case 1: // Cube
        return _drawCube(cx, cy, size, rot);
      case 2: // Pyramid
        return _drawPyramid(cx, cy, size, rot);
      case 3: // Hex prism
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final ang = rot + i * 2 * math.pi / 6;
          final x = cx + math.cos(ang) * size / 2;
          final y = cy + math.sin(ang) * size / 2;
          if (i == 0)
            path.moveTo(x, y);
          else
            path.lineTo(x, y);
        }
        path.close();
        return path;
      case 4: // Tesseract
        return _drawTesseract(cx, cy, size, rot, canvas);
      default:
        return Path();
    }
  }

  Path _drawTesseract(
    double cx,
    double cy,
    double size,
    double rot,
    Canvas canvas,
  ) {
    final half = size / 2;

    // Define 16 vertices at ±0.5
    final verts = <Point4D>[];
    final pattern = [0.5, 0.5, -0.5, -0.5];
    int j = 0;
    for (int i = 0; i < 16; i++) {
      final x = pattern[(i + 1) % 4];
      final y = pattern[i % 4];
      if (i % 4 == 0) j++;
      final z = j % 2 == 0 ? 0.5 : -0.5;
      final w = i < 8 ? 0.5 : -0.5;
      verts.add(Point4D(x, y, z, w));
    }

    // Apply 4D rotation
    final rotationAngles = [
      0.0,
      0.0,
      0.0,
      rot,
      rot * 0.5,
      rot * 0.3,
    ]; // [zw, yw, yz, xw, xz, xy]
    final rotMatrix = createRotation4D(
      zw: rotationAngles[0],
      yw: rotationAngles[1],
      yz: rotationAngles[2],
      xw: rotationAngles[3],
      xz: rotationAngles[4],
      xy: rotationAngles[5],
    );

    // Rotate vertices
    final rotatedVerts = verts.map((p) => rotMatrix.multiplyVector(p)).toList();

    // Project to 3D
    const dist4D = 1.2;
    final proj3D = rotatedVerts.map((p) {
      final projMatrix = transform4dPersp(dist4D, p.w);
      return projMatrix.multiplyVector(p);
    }).toList();

    // Project to 2D and scale to size
    const dist3D = 2.0;
    final proj2D = proj3D.map((p) {
      final projMatrix = transform3dPersp(dist3D, p.z);
      final offset = projMatrix.multiplyVector(p);
      return Offset(cx + offset.dx * half, cy + offset.dy * half);
    }).toList();

    // Draw edges with individual colors and smoothed corners
    final paths = <Path>[];
    final paints = <Paint>[];
    int edgeIndex = 0;

    for (int i = 0; i < 16; i++) {
      for (int j = i + 1; j < 16; j++) {
        final diff = i ^ j;
        if ((diff & (diff - 1)) == 0) {
          final p1 = proj2D[i];
          final p2 = proj2D[j];

          // Compute color for this edge
          final baseColor = palette[edgeIndex % palette.length];
          final rgbOffset =
              math.sin(t + edgeIndex * 0.2) * 0.1 +
              0.9; // Oscillate between 0.8 and 1.0
          final edgeColor = Color.fromRGBO(
            (baseColor.red * rgbOffset).clamp(0, 255).toInt(),
            (baseColor.green * rgbOffset).clamp(0, 255).toInt(),
            (baseColor.blue * rgbOffset).clamp(0, 255).toInt(),
            0.45,
          );

          // Create paint for this edge
          final edgePaint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth =
                size *
                0.03 // Slightly thicker for visibility
            ..color = edgeColor
            ..blendMode = blendMode;

          // Compute control point for quadratic Bezier (midpoint with dynamic offset)
          final midX = (p1.dx + p2.dx) / 2;
          final midY = (p1.dy + p2.dy) / 2;
          final perpendicular = Offset(-(p2.dy - p1.dy), p2.dx - p1.dx);
          final length = math.sqrt(
            perpendicular.dx * perpendicular.dx +
                perpendicular.dy * perpendicular.dy,
          );
          final normalized = length == 0
              ? Offset.zero
              : Offset(perpendicular.dx / length, perpendicular.dy / length);
          final curveOffset =
              math.sin(t + edgeIndex * 0.3) *
              size *
              0.1; // Dynamic curve intensity
          final control = Offset(
            midX + normalized.dx * curveOffset,
            midY + normalized.dy * curveOffset,
          );

          // Create path with quadratic Bezier for smoothed edge
          final edgePath = Path()
            ..moveTo(p1.dx, p1.dy)
            ..quadraticBezierTo(control.dx, control.dy, p2.dx, p2.dy);

          paths.add(edgePath);
          paints.add(edgePaint);
          edgeIndex++;
        }
      }
    }

    // Draw all edges
    for (int i = 0; i < paths.length; i++) {
      canvas.drawPath(paths[i], paints[i]);
    }

    return Path(); // Return empty path since individual paths are drawn
  }

  Path _drawCube(double cx, double cy, double size, double rot) {
    final half = size / 2;
    final path = Path();
    final cosr = math.cos(rot);
    final sinr = math.sin(rot);

    // Front face
    final f1 = Offset(
      cx + (-half * cosr - -half * sinr),
      cy + (-half * sinr + -half * cosr),
    );
    final f2 = Offset(
      cx + (half * cosr - -half * sinr),
      cy + (half * sinr + -half * cosr),
    );
    final f3 = Offset(
      cx + (half * cosr - half * sinr),
      cy + (half * sinr + half * cosr),
    );
    final f4 = Offset(
      cx + (-half * cosr - half * sinr),
      cy + (-half * sinr + half * cosr),
    );
    path.moveTo(f1.dx, f1.dy);
    path.lineTo(f2.dx, f2.dy);
    path.lineTo(f3.dx, f3.dy);
    path.lineTo(f4.dx, f4.dy);
    path.close();
    return path;
  }

  Path _drawPyramid(double cx, double cy, double size, double rot) {
    final path = Path();
    final base = size / 2;
    for (int i = 0; i < 4; i++) {
      final ang = rot + i * math.pi / 2;
      final x = cx + math.cos(ang) * base;
      final y = cy + math.sin(ang) * base;
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _FloatingShapes3DPainter old) => old.t != t;
}
