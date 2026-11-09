import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Rotation (about X, about Y) that brings face [v] towards the viewer.
(double, double) _faceAngles(int v) => switch (v) {
      1 => (0.0, 0.0),
      6 => (0.0, pi),
      3 => (0.0, -pi / 2),
      4 => (0.0, pi / 2),
      2 => (-pi / 2, 0.0),
      _ => (pi / 2, 0.0),
    };

class Dice3D extends StatefulWidget {
  final int value; // face to land on (1..6)
  final int rollSeq; // change this number to start a new roll animation
  final Color accent;
  final double size;
  final bool glow;
  final VoidCallback? onTap;

  const Dice3D({
    super.key,
    required this.value,
    required this.rollSeq,
    required this.accent,
    this.size = 52,
    this.glow = false,
    this.onTap,
  });

  @override
  State<Dice3D> createState() => _Dice3DState();
}

class _Dice3DState extends State<Dice3D> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900), value: 1);
  final _r = Random();
  late (double, double) _from = _faceAngles(widget.value);
  double _sx = 0, _sy = 0, _sz = 0;

  @override
  void didUpdateWidget(Dice3D old) {
    super.didUpdateWidget(old);
    if (old.rollSeq != widget.rollSeq) {
      _from = _faceAngles(old.value);
      double spin(int turns) =>
          (turns + _r.nextInt(2)) * 2 * pi * (_r.nextBool() ? 1 : -1);
      _sx = spin(2);
      _sy = spin(2);
      _sz = spin(1);
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final to = _faceAngles(widget.value);
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = _c.value;
          final e = Curves.easeOutCubic.transform(t);
          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _DicePainter(
              ax: _from.$1 + (to.$1 - _from.$1) * e + _sx * e,
              ay: _from.$2 + (to.$2 - _from.$2) * e + _sy * e,
              az: _sz * e,
              lift: sin(t * pi) * widget.size * 0.20,
              accent: widget.accent,
              glow: widget.glow,
            ),
          );
        },
      ),
    );
  }
}

class _DicePainter extends CustomPainter {
  final double ax, ay, az, lift;
  final Color accent;
  final bool glow;
  _DicePainter(
      {required this.ax,
      required this.ay,
      required this.az,
      required this.lift,
      required this.accent,
      required this.glow});

  static const _faces = <(int, List<double>, List<double>, List<double>)>[
    (1, [0.0, 0.0, 1.0], [1.0, 0.0, 0.0], [0.0, 1.0, 0.0]),
    (6, [0.0, 0.0, -1.0], [-1.0, 0.0, 0.0], [0.0, 1.0, 0.0]),
    (2, [0.0, -1.0, 0.0], [1.0, 0.0, 0.0], [0.0, 0.0, -1.0]),
    (5, [0.0, 1.0, 0.0], [1.0, 0.0, 0.0], [0.0, 0.0, 1.0]),
    (3, [1.0, 0.0, 0.0], [0.0, 0.0, -1.0], [0.0, 1.0, 0.0]),
    (4, [-1.0, 0.0, 0.0], [0.0, 0.0, 1.0], [0.0, 1.0, 0.0]),
  ];

  static const _pips = <int, List<(double, double)>>{
    1: [(0, 0)],
    2: [(-.5, -.5), (.5, .5)],
    3: [(-.5, -.5), (0, 0), (.5, .5)],
    4: [(-.5, -.5), (.5, -.5), (-.5, .5), (.5, .5)],
    5: [(-.5, -.5), (.5, -.5), (0, 0), (-.5, .5), (.5, .5)],
    6: [(-.5, -.5), (.5, -.5), (-.5, 0), (.5, 0), (-.5, .5), (.5, .5)],
  };

  List<double> _rot(List<double> p) {
    var x = p[0], y = p[1], z = p[2];
    double nx, ny, nz, c, s;
    c = cos(az); s = sin(az);
    nx = c * x - s * y; ny = s * x + c * y; x = nx; y = ny;
    c = cos(ay); s = sin(ay);
    nx = c * x + s * z; nz = -s * x + c * z; x = nx; z = nz;
    c = cos(ax); s = sin(ax);
    ny = c * y - s * z; nz = s * y + c * z; y = ny; z = nz;
    c = cos(-0.5); s = sin(-0.5);
    nx = c * x + s * z; nz = -s * x + c * z; x = nx; z = nz;
    c = cos(-0.45); s = sin(-0.45);
    ny = c * y - s * z; nz = s * y + c * z; y = ny; z = nz;
    return [x, y, z];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final k = w / 2 / 1.8;
    final cx = w / 2;
    final baseY = size.height * 0.50;
    final cy = baseY - lift;

    final sh = (1 - lift / (w * 0.4)).clamp(0.3, 1.0);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, baseY + w * 0.32), width: w * 0.58 * sh, height: w * 0.12 * sh),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3 * sh)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    if (glow) {
      final r = Rect.fromCircle(center: Offset(cx, cy), radius: w * 0.55);
      canvas.drawCircle(
          Offset(cx, cy),
          w * 0.55,
          Paint()
            ..shader = RadialGradient(colors: [
              accent.withValues(alpha: 0.6),
              accent.withValues(alpha: 0),
            ]).createShader(r));
    }

    final body = Color.lerp(Colors.white, accent, 0.12)!;
    const lx = -0.35, ly = -0.6, lz = 0.72;
    final ln = sqrt(lx * lx + ly * ly + lz * lz);

    for (final f in _faces) {
      final n = _rot(f.$2);
      if (n[2] <= 0.02) continue;
      final u = _rot(f.$3), v = _rot(f.$4);
      final bright = 0.6 + 0.4 * max(0.0, (n[0] * lx + n[1] * ly + n[2] * lz) / ln);
      final col = Color.lerp(Colors.black, body, bright)!;

      Offset pt(double a, double b) => Offset(
            cx + (n[0] + u[0] * a + v[0] * b) * k,
            cy + (n[1] + u[1] * a + v[1] * b) * k,
          );
      const m = 0.86;
      final path = Path()
        ..moveTo(pt(-m, -m).dx, pt(-m, -m).dy)
        ..lineTo(pt(m, -m).dx, pt(m, -m).dy)
        ..lineTo(pt(m, m).dx, pt(m, m).dy)
        ..lineTo(pt(-m, m).dx, pt(-m, m).dy)
        ..close();
      canvas.drawPath(path, Paint()..color = col);
      canvas.drawPath(
        path,
        Paint()
          ..color = col
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = (1 - m) * 2 * k,
      );

      canvas.save();
      canvas.transform(Float64List.fromList([
        u[0] * k, u[1] * k, 0, 0,
        v[0] * k, v[1] * k, 0, 0,
        0, 0, 1, 0,
        cx + n[0] * k, cy + n[1] * k, 0, 1,
      ]));
      final pipColor = f.$1 == 1 ? const Color(0xFFD32F2F) : const Color(0xFF212121);
      for (final p in _pips[f.$1]!) {
        canvas.drawCircle(Offset(p.$1, p.$2), f.$1 == 1 ? 0.24 : 0.17, Paint()..color = pipColor);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _DicePainter o) =>
      o.ax != ax || o.ay != ay || o.az != az || o.lift != lift || o.accent != accent || o.glow != glow;
}
