import 'dart:math';
import 'dart:ui';

/// Players: 0 Red, 1 Green, 2 Yellow, 3 Blue, 4 Purple, 5 Orange
/// Token progress: -1 = in base, 0..trackLast = main track, trackLast+1 .. finish-1 = home column, finish = finished.

const kColors = [
  Color(0xFFE53935), // Red
  Color(0xFF43A047), // Green
  Color(0xFFFDD835), // Yellow
  Color(0xFF1E88E5), // Blue
  Color(0xFF8E24AA), // Purple
  Color(0xFFFF8F00), // Orange
];

const kNames = ['Red', 'Green', 'Yellow', 'Blue', 'Purple', 'Orange'];

const kStart = [0, 13, 26, 39];
const kSafe = {0, 8, 13, 21, 26, 34, 39, 47};

const kCorner = <(int, int)>[(0, 0), (0, 9), (9, 9), (9, 0)];

const kPath = <(int, int)>[
  (6, 1), (6, 2), (6, 3), (6, 4), (6, 5), (5, 6), (4, 6), (3, 6), (2, 6), (1, 6), (0, 6),
  (0, 7), (0, 8), (1, 8), (2, 8), (3, 8), (4, 8), (5, 8), (6, 9), (6, 10), (6, 11),
  (6, 12), (6, 13), (6, 14), (7, 14), (8, 14), (8, 13), (8, 12), (8, 11), (8, 10),
  (8, 9), (9, 8), (10, 8), (11, 8), (12, 8), (13, 8), (14, 8), (14, 7), (14, 6),
  (13, 6), (12, 6), (11, 6), (10, 6), (9, 6), (8, 5), (8, 4), (8, 3), (8, 2), (8, 1),
  (8, 0), (7, 0), (6, 0),
];

const kHomeCol = <List<(int, int)>>[
  [(7, 1), (7, 2), (7, 3), (7, 4), (7, 5)],
  [(1, 7), (2, 7), (3, 7), (4, 7), (5, 7)],
  [(7, 13), (7, 12), (7, 11), (7, 10), (7, 9)],
  [(13, 7), (12, 7), (11, 7), (10, 7), (9, 7)],
];

Offset tokenPos(int p, int t, int prog) {
  if (prog < 0) {
    final (r, c) = kCorner[p];
    return Offset(c + (t % 2 == 0 ? 2.0 : 4.0), r + (t < 2 ? 2.0 : 4.0));
  }
  if (prog <= 50) {
    final (r, c) = kPath[(kStart[p] + prog) % 52];
    return Offset(c + .5, r + .5);
  }
  if (prog <= 55) {
    final (r, c) = kHomeCol[p][prog - 51];
    return Offset(c + .5, r + .5);
  }
  return Offset(7.5 + (p - 1.5) * .22, 7.5 + (t - 1.5) * .22);
}

class LudoState {
  final int nPlayers; // 2, 3, 4, 5, or 6
  List<int> tokens; // nPlayers * 4 ints
  List<bool> active;
  int turn;
  int dice; // 0 = must roll
  int sixes;
  List<int> finished;
  int lastRoll; // last rolled number
  int lastPlayer; // who rolled it
  int rollSeq; // increases on every roll

  LudoState({
    required this.nPlayers,
    required this.tokens,
    required this.active,
    required this.turn,
    this.dice = 0,
    this.sixes = 0,
    List<int>? finished,
    this.lastRoll = 1,
    this.lastPlayer = 0,
    this.rollSeq = 0,
  }) : finished = finished ?? [];

  factory LudoState.initial(int nPlayers, List<bool> active) => LudoState(
        nPlayers: nPlayers,
        tokens: List.filled(nPlayers * 4, -1),
        active: active,
        turn: active.indexOf(true),
      );

  Map<String, dynamic> toMap() => {
        'nPlayers': nPlayers,
        'tokens': tokens,
        'active': active,
        'turn': turn,
        'dice': dice,
        'sixes': sixes,
        'finished': finished,
        'lastRoll': lastRoll,
        'lastPlayer': lastPlayer,
        'rollSeq': rollSeq,
      };

  factory LudoState.fromMap(Map<String, dynamic> m) => LudoState(
        nPlayers: (m['nPlayers'] ?? 4) as int,
        tokens: List<int>.from(m['tokens']),
        active: List<bool>.from(m['active']),
        turn: m['turn'] as int,
        dice: m['dice'] as int,
        sixes: m['sixes'] as int,
        finished: List<int>.from(m['finished'] ?? []),
        lastRoll: (m['lastRoll'] ?? 1) as int,
        lastPlayer: (m['lastPlayer'] ?? 0) as int,
        rollSeq: (m['rollSeq'] ?? 0) as int,
      );

  int get boardN => nPlayers <= 4 ? 4 : nPlayers;
  int get trackLast => 13 * boardN - 2;
  int get finish => 13 * boardN + 4;

  int absCell(int player, int prog) => (13 * player + prog) % (13 * boardN);

  Set<int> getSafeCells() {
    final s = <int>{};
    for (var k = 0; k < boardN; k++) {
      s.add(13 * k);
      s.add(13 * k + 8);
    }
    return s;
  }

  int get activeCount => active.where((a) => a).length;
  bool get over => finished.length >= max(1, activeCount - 1);
  int tok(int p, int t) => tokens[p * 4 + t];

  List<int> get ranking {
    final rest = [for (var p = 0; p < nPlayers; p++) if (active[p] && !finished.contains(p)) p];
    int score(int p) => List.generate(4, (t) => tok(p, t)).fold(0, (a, b) => a + b);
    rest.sort((a, b) => score(b).compareTo(score(a)));
    return [...finished, ...rest];
  }

  bool canMove(int t) {
    if (dice == 0 || over) return false;
    final p = tok(turn, t);
    if (p == -1) return dice == 6;
    if (p == finish) return false;
    return p + dice <= finish;
  }

  List<int> movable() => [for (var t = 0; t < 4; t++) if (canMove(t)) t];

  void roll(int v) {
    if (over || dice != 0) return;
    lastRoll = v;
    lastPlayer = turn;
    rollSeq++;
    dice = v;
    sixes = v == 6 ? sixes + 1 : 0;
    if (sixes >= 3) return _next();
    if (movable().isEmpty) _next();
  }

  bool _capturesAt(int cell) {
    final safe = getSafeCells();
    if (safe.contains(cell)) return false;
    for (var q = 0; q < nPlayers; q++) {
      if (q == turn) continue;
      for (var k = 0; k < 4; k++) {
        final qp = tok(q, k);
        if (qp >= 0 && qp <= trackLast && absCell(q, qp) == cell) return true;
      }
    }
    return false;
  }

  void move(int t) {
    if (!canMove(t)) return;
    final i = turn * 4 + t;
    final p = tokens[i];
    final np = p == -1 ? 0 : p + dice;
    tokens[i] = np;
    var extra = dice == 6;

    if (np <= trackLast) {
      final cell = absCell(turn, np);
      final safe = getSafeCells();
      if (!safe.contains(cell)) {
        for (var q = 0; q < nPlayers; q++) {
          if (q == turn) continue;
          for (var k = 0; k < 4; k++) {
            final qp = tokens[q * 4 + k];
            if (qp >= 0 && qp <= trackLast && absCell(q, qp) == cell) {
              tokens[q * 4 + k] = -1; // captured
              extra = true;
            }
          }
        }
      }
    }
    if (np == finish) {
      extra = true;
      if (List.generate(4, (k) => tokens[turn * 4 + k]).every((x) => x == finish)) {
        finished.add(turn);
      }
    }
    dice = 0;
    if (over) return;
    if (!extra || finished.contains(turn)) _next();
  }

  void _next() {
    dice = 0;
    sixes = 0;
    if (over) return;
    do {
      turn = (turn + 1) % nPlayers;
    } while (!active[turn] || finished.contains(turn));
  }

  int botPick() {
    var best = -1;
    var bestScore = -1e9;
    final safe = getSafeCells();
    for (final t in movable()) {
      final p = tok(turn, t);
      final np = p == -1 ? 0 : p + dice;
      var score = np.toDouble();
      if (np == finish) score += 80;
      if (p == -1) score += 50;
      if (np <= trackLast) {
        final cell = absCell(turn, np);
        if (safe.contains(cell)) {
          score += 15;
        } else if (_capturesAt(cell)) {
          score += 100;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        best = t;
      }
    }
    return best;
  }
}
