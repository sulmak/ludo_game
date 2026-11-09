import 'dart:math';
import 'dart:ui';

/// Geometry of a Ludo board with [n] arms (4, 5 or 6), in board units
/// (1 unit = 1 cell). Built once per arm count and cached.
class BoardGeometry {
  final int n;
  final double w, h; // board size in units
  final double delta; // angle between arms
  final double hubRadius; // distance from center to the hub polygon corners
  final Offset center;
  final List<Offset> path; // 13*n track cells; path[13*k] is player k's start
  final List<double> pathAngle; // rotation of each track cell
  final List<List<Offset>> home; // n x 5 home column cells
  final List<double> armAngle; // direction of each arm
  final List<Offset> yardCenter;
  final List<List<Offset>> yardSpots; // n x 4 token spots

  const BoardGeometry._({
    required this.n,
    required this.w,
    required this.h,
    required this.delta,
    required this.hubRadius,
    required this.center,
    required this.path,
    required this.pathAngle,
    required this.home,
    required this.armAngle,
    required this.yardCenter,
    required this.yardSpots,
  });

  static final _cache = <int, BoardGeometry>{};
  static BoardGeometry of(int n) => _cache.putIfAbsent(n, () => _build(n));

  int get trackLast => 13 * n - 2;
  int get finish => 13 * n + 4;

  /// Position (board units) of token [t] of player [p] at progress [prog].
  Offset tokenPos(int p, int t, int prog) {
    if (prog < 0) return yardSpots[p][t];
    if (prog <= trackLast) return path[(13 * p + prog) % (13 * n)];
    if (prog < finish) return home[p][prog - trackLast - 1];
    final d = Offset(cos(armAngle[p]), sin(armAngle[p]));
    final perp = Offset(-d.dy, d.dx);
    return center + d * .75 + perp * ((t - 1.5) * .27);
  }

  static BoardGeometry _build(int n) {
    final delta = 2 * pi / n;
    final apothem = 1.5 / tan(pi / n); // arms are 3 cells wide
    final arm = List.generate(n, (k) => pi + k * delta); // clockwise on screen

    // a = distance along the arm (1 = next to hub), b = sideways (-1 out lane, +1 in lane)
    Offset cell(int k, double a, double b) {
      final d = Offset(cos(arm[k]), sin(arm[k]));
      final p = Offset(-d.dy, d.dx);
      return d * (apothem + a - .5) + p * b;
    }

    final u = <Offset>[];
    final ua = <double>[];
    for (var k = 0; k < n; k++) {
      for (var a = 1; a <= 6; a++) {
        u.add(cell(k, a.toDouble(), -1));
        ua.add(arm[k]);
      }
      u.add(cell(k, 6, 0));
      ua.add(arm[k]);
      for (var a = 6; a >= 1; a--) {
        u.add(cell(k, a.toDouble(), 1));
        ua.add(arm[k]);
      }
    }
    final total = 13 * n;
    // player k starts on the in-lane, 2 cells after its arm tip
    final path = List.generate(total, (i) => u[(i + 8) % total]);
    final pathAngle = List.generate(total, (i) => ua[(i + 8) % total]);
    final home = [
      for (var k = 0; k < n; k++) [for (var a = 5; a >= 1; a--) cell(k, a.toDouble(), 0)]
    ];

    final yardDist = n == 4 ? 4.5 * sqrt2 : 4.1 / sin(delta / 2);
    final yards = [
      for (var k = 0; k < n; k++)
        Offset(cos(arm[k] + delta / 2), sin(arm[k] + delta / 2)) * yardDist
    ];

    // bounds
    final e = n == 4 ? .5 : .72;
    final ye = n == 4 ? 3.0 : 2.5;
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    void grow(Offset o, double r) {
      minX = min(minX, o.dx - r);
      minY = min(minY, o.dy - r);
      maxX = max(maxX, o.dx + r);
      maxY = max(maxY, o.dy + r);
    }

    for (final o in path) {
      grow(o, e);
    }
    for (final h in home) {
      for (final o in h) {
        grow(o, e);
      }
    }
    for (final y in yards) {
      grow(y, ye);
    }
    final pad = n == 4 ? 0.0 : .25;
    final shift = Offset(-minX + pad, -minY + pad);
    final sp = n == 4 ? 1.0 : .8;
    const corners = [Offset(-1, -1), Offset(1, -1), Offset(-1, 1), Offset(1, 1)];

    return BoardGeometry._(
      n: n,
      w: maxX - minX + 2 * pad,
      h: maxY - minY + 2 * pad,
      delta: delta,
      hubRadius: 1.5 / sin(delta / 2),
      center: shift,
      path: [for (final o in path) o + shift],
      pathAngle: pathAngle,
      home: [
        for (final h in home) [for (final o in h) o + shift]
      ],
      armAngle: arm,
      yardCenter: [for (final y in yards) y + shift],
      yardSpots: [
        for (final y in yards) [for (final c in corners) y + shift + c * sp]
      ],
    );
  }
}
