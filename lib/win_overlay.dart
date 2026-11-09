import 'dart:math';
import 'package:flutter/material.dart';
import 'board_painter.dart';
import 'ludo_logic.dart';
import 'sfx.dart';

class WinOverlay extends StatefulWidget {
  final LudoState s;
  final List<String> names;
  final List<String> avatars;
  final VoidCallback? onAgain;
  final VoidCallback onHome;

  const WinOverlay({
    super.key,
    required this.s,
    required this.names,
    required this.avatars,
    required this.onHome,
    this.onAgain,
  });

  @override
  State<WinOverlay> createState() => _WinOverlayState();
}

class _WinOverlayState extends State<WinOverlay> {
  @override
  void initState() {
    super.initState();
    Sfx.play('win');
  }

  @override
  Widget build(BuildContext context) {
    final rank = widget.s.ranking;
    const medals = ['🥇', '🥈', '🥉', '4️⃣'];
    final w = rank.first;
    return Stack(
      children: [
        Positioned.fill(child: Container(color: Colors.black.withValues(alpha: .72))),
        const Positioned.fill(child: IgnorePointer(child: Confetti())),
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v.clamp(0.0, 1.3), child: child),
            child: Card(
              margin: const EdgeInsets.all(24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: kColors[w], width: 4)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 64)),
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: kColors[w],
                      child: Text(widget.avatars[w], style: const TextStyle(fontSize: 42)),
                    ),
                    const SizedBox(height: 8),
                    Text('${widget.names[w]} wins!',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    for (var i = 0; i < rank.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(medals[i], style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 8),
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: kColors[rank[i]],
                              child: Text(widget.avatars[rank[i]], style: const TextStyle(fontSize: 16)),
                            ),
                            const SizedBox(width: 8),
                            Text(widget.names[rank[i]], style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.onAgain != null) ...[
                          FilledButton.icon(
                              onPressed: widget.onAgain,
                              icon: const Icon(Icons.replay),
                              label: const Text('Play again')),
                          const SizedBox(width: 12),
                        ],
                        OutlinedButton(onPressed: widget.onHome, child: const Text('Menu')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Piece {
  final double x, phase, size;
  final int speed, sway;
  final Color color;
  _Piece(this.x, this.phase, this.size, this.speed, this.sway, this.color);
}

class Confetti extends StatefulWidget {
  const Confetti({super.key});
  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
  final _r = Random(7);
  late final List<_Piece> _ps = List.generate(
    80,
    (_) => _Piece(_r.nextDouble(), _r.nextDouble(), 6 + _r.nextDouble() * 8, 1 + _r.nextInt(2),
        1 + _r.nextInt(3), [...kColors, Colors.pinkAccent, Colors.orange][_r.nextInt(6)]),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(painter: _ConfettiPainter(_ps, _c.value), size: Size.infinite),
      );
}

class _ConfettiPainter extends CustomPainter {
  final List<_Piece> ps;
  final double t;
  _ConfettiPainter(this.ps, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in ps) {
      final y = ((t * p.speed + p.phase) % 1.0) * (size.height + 40) - 20;
      final x = p.x * size.width + sin(t * 2 * pi * p.sway + p.phase * 10) * 18;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * 2 * pi * p.sway + p.phase * 6);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * .5),
          Paint()..color = p.color);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => true;
}
