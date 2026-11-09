import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'board_geometry.dart';
import 'board_painter.dart';
import 'board_view.dart';
import 'controllers.dart';
import 'dice3d.dart';
import 'ludo_logic.dart';
import 'sfx.dart';
import 'win_overlay.dart';

class GameScreen extends StatefulWidget {
  final GameController c;
  final bool ownsController;
  const GameScreen({super.key, required this.c, this.ownsController = false});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final _boardBusy = ValueNotifier<bool>(false);
  bool _diceBusy = false;
  int _seenSeq = 0;
  int _gameKey = 0;
  Timer? _diceTimer;

  GameController get c => widget.c;

  @override
  void initState() {
    super.initState();
    _seenSeq = c.state.rollSeq;
    c.addListener(_onChange);
  }

  void _onChange() {
    final s = c.state;
    if (s.rollSeq != _seenSeq) {
      _seenSeq = s.rollSeq;
      if (s.rollSeq > 0) {
        Sfx.play('dice');
        _diceTimer?.cancel();
        setState(() => _diceBusy = true);
        _diceTimer = Timer(const Duration(milliseconds: 950), () {
          if (mounted) setState(() => _diceBusy = false);
        });
      }
    }
  }

  void _again() {
    final lc = c;
    if (lc is LocalController) {
      lc.restart();
      setState(() {
        _gameKey++;
        _seenSeq = 0;
        _diceBusy = false;
        _boardBusy.value = false;
      });
    }
  }

  @override
  void dispose() {
    _diceTimer?.cancel();
    c.removeListener(_onChange);
    if (widget.ownsController) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final s = c.state;
        final names = c.names;
        final avatars = c.avatars;
        return ValueListenableBuilder<bool>(
          valueListenable: _boardBusy,
          builder: (context, boardBusy, _) {
            final myTurn = c.canAct(s.turn) && !s.over;
            final canRoll = myTurn && s.dice == 0 && !_diceBusy && !boardBusy;
            final canPick = myTurn && s.dice != 0 && !_diceBusy;
            final diceOwner = _diceBusy ? s.lastPlayer : s.turn;

            String status;
            if (s.over) {
              status = 'Game over';
            } else if (_diceBusy || boardBusy) {
              status = '';
            } else if (myTurn) {
              status = s.dice == 0 ? 'Your turn - tap the dice' : 'Tap a glowing guti';
            } else {
              status = "${names[s.turn]}'s turn";
            }

            Widget card(int seat) => _PlayerCard(
                seat: seat, s: s, name: names[seat], avatar: avatars[seat]);

            final activeSeats = [for (var i = 0; i < s.nPlayers; i++) if (s.active[i]) i];

            return Scaffold(
              backgroundColor: const Color(0xFF1B1530),
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                title: Text('Ludo (${s.activeCount} Players)'),
                actions: [
                  IconButton(
                    icon: Icon(Sfx.enabled ? Icons.volume_up : Icons.volume_off),
                    onPressed: () => setState(() => Sfx.enabled = !Sfx.enabled),
                  ),
                ],
              ),
              body: Stack(
                children: [
                  SafeArea(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(
                          children: [
                            // Top Row: Active Player Cards + Aligned 3D Dice
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        for (final seat in activeSeats)
                                          SizedBox(width: 140, child: card(seat)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Dice3D(
                                    value: s.lastRoll,
                                    rollSeq: s.rollSeq,
                                    accent: kColors[diceOwner % kColors.length],
                                    size: 52,
                                    glow: canRoll,
                                    onTap: canRoll ? () => c.roll(Random().nextInt(6) + 1) : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: Center(
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: Container(
                                    margin: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: const [
                                        BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 6))
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: BoardView(
                                        key: ValueKey(_gameKey),
                                        s: s,
                                        canPick: canPick,
                                        busy: _boardBusy,
                                        onToken: c.move,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 32,
                              child: Text(status,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (s.over && !boardBusy && !_diceBusy)
                    WinOverlay(
                      s: s,
                      names: names,
                      avatars: avatars,
                      onAgain: c is LocalController ? _again : null,
                      onHome: () => Navigator.of(context).popUntil((r) => r.isFirst),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final int seat;
  final LudoState s;
  final String name;
  final String avatar;
  const _PlayerCard({required this.seat, required this.s, required this.name, required this.avatar});

  @override
  Widget build(BuildContext context) {
    final on = s.active[seat];
    final turn = s.turn == seat && !s.over;
    final home = List.generate(4, (t) => s.tok(seat, t)).where((x) => x == s.finish).length;
    final place = s.finished.indexOf(seat);
    final col = kColors[seat % kColors.length];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: on ? .10 : .03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: turn ? col : Colors.white24, width: turn ? 3 : 1),
        boxShadow: turn ? [BoxShadow(color: col.withValues(alpha: .6), blurRadius: 12)] : null,
      ),
      child: Opacity(
        opacity: on ? 1 : .3,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: col,
              child: Text(avatar, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(place >= 0 ? '🏆 #${place + 1}' : '🏠 $home/4',
                      style: const TextStyle(color: Colors.white70, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
