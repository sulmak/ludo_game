import 'dart:math';
import 'package:flutter/material.dart';
import 'board_geometry.dart';
import 'ludo_logic.dart';

/// Token position for a (possibly fractional) progress value, in board grid units.
Offset pawnPos(BoardGeometry geom, int p, int t, double prog) {
  if (geom.n == 4) {
    if (prog <= -1) return tokenPos(p, t, -1);
    final lo = prog.floor(), hi = prog.ceil();
    if (lo == hi) return tokenPos(p, t, lo);
    return Offset.lerp(tokenPos(p, t, lo), tokenPos(p, t, hi), prog - lo)!;
  }
  if (prog <= -1) return geom.tokenPos(p, t, -1);
  final lo = prog.floor(), hi = prog.ceil();
  if (lo == hi) return geom.tokenPos(p, t, lo);
  return Offset.lerp(geom.tokenPos(p, t, lo), geom.tokenPos(p, t, hi), prog - lo)!;
}

class _Tok {
  final int player;
  final Offset pos;
  final double lift;
  final bool hint;
  _Tok(this.player, this.pos, this.lift, this.hint);
}

class BoardPainter extends CustomPainter {
  final LudoState s;
  final List<double> shown; // animated progress of the tokens
  final double time;
  final bool hints;
  BoardPainter(this.s, this.shown, this.time, this.hints);

  @override
  void paint(Canvas canvas, Size size) {
    final geom = BoardGeometry.of(s.boardN);
    final u = size.width / geom.w;
    final fill = Paint();
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.black38
      ..strokeWidth = 1;

    // Outer board background
    final boardRRect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(u * 0.8));
    canvas.drawRRect(boardRRect, fill..color = Colors.white);

    if (s.boardN == 4) {
      _paint4PlayerBoard(canvas, u, fill, line);
    } else {
      _paintMultiPlayerBoard(canvas, geom, u, fill, line);
    }

    // ---- tokens (pawns) ----
    final toks = <_Tok>[];
    final stack = <String, int>{};
    for (var p = 0; p < s.nPlayers; p++) {
      if (!s.active[p]) continue; // Only draw pawns for ACTIVE players!
      for (var t = 0; t < 4; t++) {
        final prog = shown[p * 4 + t];
        var pos = pawnPos(geom, p, t, prog);
        final frac = prog - prog.floor();
        final moving = prog >= 0 && prog < s.finish && frac > 0.001;
        if (!moving) {
          final key = '${(pos.dx * 10).round()},${(pos.dy * 10).round()}';
          final n = stack[key] ?? 0;
          stack[key] = n + 1;
          if (prog >= 0 && prog < s.finish) pos += Offset(n * .15, 0);
        }
        final lift = moving ? sin(frac * pi) * .45 : 0.0;
        toks.add(_Tok(p, pos, lift, hints && p == s.turn && s.canMove(t)));
      }
    }
    toks.sort((a, b) => a.pos.dy.compareTo(b.pos.dy));
    for (final t in toks) {
      _pawn(canvas, t.pos * u, u, kColors[t.player % kColors.length], t.lift, t.hint);
    }
  }

  void _paint4PlayerBoard(Canvas canvas, double u, Paint fill, Paint line) {
    // 1. Four 6x6 corner bases
    for (var p = 0; p < 4; p++) {
      final (r, c) = kCorner[p];
      // Solid colored 6x6 base
      canvas.drawRect(Rect.fromLTWH(c * u, r * u, 6 * u, 6 * u), fill..color = kColors[p]);

      // Inner white card
      final cardRect = Rect.fromLTWH((c + 1) * u, (r + 1) * u, 4 * u, 4 * u);
      canvas.drawRRect(
        RRect.fromRectAndRadius(cardRect, Radius.circular(u * 0.6)),
        fill..color = Colors.white,
      );

      // 4 token spot circles inside inner white card
      for (var t = 0; t < 4; t++) {
        final o = tokenPos(p, t, -1) * u;
        canvas.drawCircle(o, u * .42, fill..color = kColors[p].withValues(alpha: .15));
        canvas.drawCircle(
          o,
          u * .42,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = kColors[p].withValues(alpha: .40),
        );
      }
    }

    // 2. Track cells
    void cell(int r, int c, Color col) {
      final rect = Rect.fromLTWH(c * u, r * u, u, u);
      canvas.drawRect(rect, fill..color = col);
      canvas.drawRect(rect, line);
    }

    for (var i = 0; i < 52; i++) {
      final (r, c) = kPath[i];
      final si = kStart.indexOf(i);
      cell(r, c, si >= 0 ? kColors[si] : Colors.white);
      if (kSafe.contains(i) && si < 0) {
        _star(canvas, Offset((c + .5) * u, (r + .5) * u), u);
      }
    }

    // 3. Home columns
    for (var p = 0; p < 4; p++) {
      for (final (r, c) in kHomeCol[p]) {
        cell(r, c, kColors[p]);
      }
    }

    // 4. Center hub (4 colored triangles)
    final ctr = Offset(7.5 * u, 7.5 * u);
    final k = [Offset(6 * u, 6 * u), Offset(9 * u, 6 * u), Offset(9 * u, 9 * u), Offset(6 * u, 9 * u)];
    const pairs = [(3, 0), (0, 1), (1, 2), (2, 3)];
    for (var p = 0; p < 4; p++) {
      final path = Path()
        ..moveTo(ctr.dx, ctr.dy)
        ..lineTo(k[pairs[p].$1].dx, k[pairs[p].$1].dy)
        ..lineTo(k[pairs[p].$2].dx, k[pairs[p].$2].dy)
        ..close();
      canvas.drawPath(path, fill..color = kColors[p]);
      canvas.drawPath(path, line);
    }
  }

  void _paintMultiPlayerBoard(Canvas canvas, BoardGeometry geom, double u, Paint fill, Paint line) {
    // 1. Yards (Solid base + inner white card + 4 token spots)
    for (var p = 0; p < geom.n; p++) {
      final yc = geom.yardCenter[p] * u;
      final outerR = 2.6 * u;
      final innerR = 1.8 * u;
      final col = kColors[p % kColors.length];

      // Solid colored yard base
      canvas.drawCircle(yc, outerR, fill..color = col);

      // Inner white card
      canvas.drawCircle(yc, innerR, fill..color = Colors.white);

      // 4 token spot circles inside inner white card
      for (var t = 0; t < 4; t++) {
        final o = geom.tokenPos(p, t, -1) * u;
        canvas.drawCircle(o, u * .40, fill..color = col.withValues(alpha: .15));
        canvas.drawCircle(
          o,
          u * .40,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = col.withValues(alpha: .40),
        );
      }
    }

    // 2. Track cells
    final totalTrack = geom.path.length;
    final safe = s.getSafeCells();
    for (var i = 0; i < totalTrack; i++) {
      final o = geom.path[i] * u;
      final rect = Rect.fromCenter(center: o, width: u, height: u);
      final si = (i % 13 == 0) ? (i ~/ 13) : -1;
      final isSafe = safe.contains(i);
      canvas.drawRect(rect, fill..color = si >= 0 && si < geom.n ? kColors[si % kColors.length] : Colors.white);
      canvas.drawRect(rect, line);
      if (isSafe && si < 0) {
        _star(canvas, o, u);
      }
    }

    // 3. Home columns
    for (var p = 0; p < geom.n; p++) {
      for (final cellPos in geom.home[p]) {
        final o = cellPos * u;
        final rect = Rect.fromCenter(center: o, width: u, height: u);
        canvas.drawRect(rect, fill..color = kColors[p % kColors.length]);
        canvas.drawRect(rect, line);
      }
    }

    // 4. Center hub (Colored polygon slices meeting at center point)
    final center = geom.center * u;
    final hubR = geom.hubRadius * u;
    for (var p = 0; p < geom.n; p++) {
      final a1 = geom.armAngle[p] - geom.delta / 2;
      final a2 = geom.armAngle[p] + geom.delta / 2;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx + cos(a1) * hubR, center.dy + sin(a1) * hubR)
        ..lineTo(center.dx + cos(a2) * hubR, center.dy + sin(a2) * hubR)
        ..close();
      canvas.drawPath(path, fill..color = kColors[p % kColors.length]);
      canvas.drawPath(path, line);
    }
  }

  void _pawn(Canvas canvas, Offset c, double u, Color col, double lift, bool hint) {
    final bob = hint ? (0.5 + 0.5 * sin(time * 8)) * .14 : 0.0;
    final ground = Offset(c.dx, c.dy + .28 * u);
    final base = ground - Offset(0, (lift + bob) * u);
    final dark = Color.lerp(col, Colors.black, .5)!;
    final light = Color.lerp(col, Colors.white, .6)!;

    if (hint) {
      canvas.drawOval(
        Rect.fromCenter(center: ground, width: u * (.95 + .08 * sin(time * 8)), height: u * .4),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.black.withValues(alpha: .85),
      );
    }
    // shadow
    canvas.drawOval(
      Rect.fromCenter(center: ground, width: u * .64, height: u * .22),
      Paint()
        ..color = Colors.black.withValues(alpha: .35 / (1 + lift * 2))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    // base disc
    canvas.drawOval(Rect.fromCenter(center: base + Offset(0, u * .04), width: u * .66, height: u * .26),
        Paint()..color = dark);
    canvas.drawOval(Rect.fromCenter(center: base, width: u * .66, height: u * .24), Paint()..color = col);
    // body
    final body = Path()
      ..moveTo(base.dx - u * .30, base.dy)
      ..quadraticBezierTo(base.dx - u * .10, base.dy - u * .10, base.dx - u * .09, base.dy - u * .40)
      ..lineTo(base.dx + u * .09, base.dy - u * .40)
      ..quadraticBezierTo(base.dx + u * .10, base.dy - u * .10, base.dx + u * .30, base.dy)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          colors: [dark, col, light, col, dark],
          stops: const [0, .3, .45, .7, 1],
        ).createShader(Rect.fromLTWH(base.dx - u * .3, base.dy - u * .4, u * .6, u * .4)),
    );
    // head (sphere)
    final head = base - Offset(0, u * .52);
    final r = u * .21;
    canvas.drawCircle(
      head,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.4, -.5),
          colors: [light, col, dark],
          stops: const [0, .55, 1],
        ).createShader(Rect.fromCircle(center: head, radius: r)),
    );
    canvas.drawCircle(
        head,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.black.withValues(alpha: .35));
    canvas.drawCircle(head + Offset(-r * .35, -r * .4), r * .22, Paint()..color = Colors.white.withValues(alpha: .8));
  }

  void _star(Canvas canvas, Offset c, double u) {
    final tp = TextPainter(
      text: TextSpan(text: '★', style: TextStyle(fontSize: u * .7, color: Colors.black38)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant BoardPainter old) => true;
}
