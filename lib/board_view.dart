import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'board_geometry.dart';
import 'board_painter.dart';
import 'ludo_logic.dart';
import 'sfx.dart';

/// Draws the board and animates tokens hopping cell by cell towards the
/// positions in [s]. [busy] is true while any token is still moving.
class BoardView extends StatefulWidget {
  final LudoState s;
  final bool canPick;
  final ValueNotifier<bool> busy;
  final void Function(int token) onToken;

  const BoardView({
    super.key,
    required this.s,
    required this.canPick,
    required this.busy,
    required this.onToken,
  });

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final List<double> _shown = widget.s.tokens.map((e) => e.toDouble()).toList();
  Duration _last = Duration.zero;
  double _time = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration d) {
    final dt = ((d - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = d;
    _time += dt;
    final tg = widget.s.tokens;

    var stepping = false;
    for (var i = 0; i < tg.length; i++) {
      if (_shown[i] >= 0 && tg[i] > _shown[i]) stepping = true;
    }

    for (var i = 0; i < tg.length; i++) {
      final t = tg[i].toDouble();
      final cur = _shown[i];
      if (cur == t) continue;
      if (cur < 0) {
        _shown[i] = t; // leaving the base
        Sfx.play('move');
      } else if (t > cur) {
        final next = min(t, cur + 6 * dt);
        if (next.floor() != cur.floor() || next == t) {
          Sfx.play(next == t && t == widget.s.finish ? 'home' : 'move');
        }
        _shown[i] = next;
      } else if (!stepping) {
        _shown[i] = t; // captured
        Sfx.play('capture');
      }
    }

    final busy = List.generate(tg.length, (i) => _shown[i] != tg[i].toDouble()).any((x) => x);
    if (widget.busy.value != busy) widget.busy.value = busy;
    setState(() {});
  }

  void _tapUp(Offset local, double size) {
    if (!widget.canPick || widget.busy.value) return;
    final s = widget.s;
    final geom = BoardGeometry.of(s.boardN);
    final u = size / geom.w;
    final pos = local / u;
    for (final t in s.movable()) {
      final tp = geom.tokenPos(s.turn, t, s.tok(s.turn, t)) + const Offset(0, -.15);
      if ((tp - pos).distance < .85) {
        widget.onToken(t);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final geom = BoardGeometry.of(widget.s.boardN);
    return LayoutBuilder(
      builder: (_, box) => GestureDetector(
        onTapUp: (d) => _tapUp(d.localPosition, box.maxWidth),
        child: CustomPaint(
          size: Size(box.maxWidth, box.maxWidth),
          painter: BoardPainter(
              widget.s, _shown, _time, widget.canPick && !widget.busy.value),
        ),
      ),
    );
  }
}
