import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'ludo_logic.dart';
import 'profile.dart';

abstract class GameController extends ChangeNotifier {
  LudoState get state;
  List<String> get names;
  List<String> get avatars;
  bool canAct(int seat);
  void roll(int value);
  void move(int token);
}

/// Offline: [humans] are seats controlled by people, the rest are bots.
class LocalController extends GameController {
  LocalController(this.nPlayers, this.humans, {Set<int>? activeSeats}) {
    final seats = activeSeats ?? {for (var i = 0; i < nPlayers; i++) i};
    final activeList = List.generate(nPlayers, (i) => seats.contains(i));
    state = LudoState.initial(nPlayers, activeList);
    final single = humans.length == 1;
    names = List.generate(
      nPlayers,
      (i) => single && !humans.contains(i)
          ? 'Bot ${kNames[i]}'
          : (single ? Profile.name : 'Player ${i + 1}'),
    );
    avatars = List.generate(
      nPlayers,
      (i) => single && !humans.contains(i)
          ? Profile.botAvatars[i % Profile.botAvatars.length]
          : Profile.defaultAvatars[i % Profile.defaultAvatars.length],
    );
    if (single && humans.contains(0)) avatars[0] = Profile.avatar;
    _schedule();
  }

  LocalController.resume(Map<String, dynamic> savedMap, this.humans)
      : nPlayers = (savedMap['nPlayers'] ?? 4) as int {
    state = LudoState.fromMap(savedMap);
    final single = humans.length == 1;
    names = List.generate(
      nPlayers,
      (i) => single && !humans.contains(i)
          ? 'Bot ${kNames[i]}'
          : (single ? Profile.name : 'Player ${i + 1}'),
    );
    avatars = List.generate(
      nPlayers,
      (i) => single && !humans.contains(i)
          ? Profile.botAvatars[i % Profile.botAvatars.length]
          : Profile.defaultAvatars[i % Profile.defaultAvatars.length],
    );
    if (single && humans.contains(0)) avatars[0] = Profile.avatar;
    _schedule();
  }

  final int nPlayers;
  final Set<int> humans;
  @override
  late LudoState state;
  @override
  late List<String> names;
  @override
  late List<String> avatars;
  Timer? _timer;

  @override
  bool canAct(int seat) => humans.contains(seat);

  void restart() {
    _timer?.cancel();
    state = LudoState.initial(nPlayers, state.active);
    Profile.clearGame();
    notifyListeners();
    _schedule();
  }

  void _persist() {
    if (state.over) {
      final won = state.finished.isNotEmpty && state.finished.first == 0;
      Profile.recordGameEnd(won: won);
    } else {
      Profile.saveGame(state.toMap());
    }
  }

  @override
  void roll(int v) {
    state.roll(v);
    notifyListeners();
    _persist();
    _schedule();
  }

  @override
  void move(int t) {
    state.move(t);
    notifyListeners();
    _persist();
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (state.over || humans.contains(state.turn)) return;
    final wait = state.dice == 0 ? 900 : 1300;
    _timer = Timer(Duration(milliseconds: wait), () {
      if (state.dice == 0) {
        state.roll(Random().nextInt(6) + 1);
      } else {
        state.move(state.botPick());
      }
      notifyListeners();
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Online: game state lives in Firestore document rooms/{code}.
class OnlineController extends GameController {
  OnlineController(this.code, this.uid) {
    _sub = _ref.snapshots().listen(_onSnap);
  }

  final String code;
  final String uid;
  late final StreamSubscription _sub;

  List<String> seats = ['', '', '', ''];
  List<String> _names = ['', '', '', ''];
  List<String> _avatars = ['', '', '', ''];
  String status = 'waiting';
  String host = '';
  LudoState? _state;

  static const _joinOrder = [2, 1, 3]; // 2 players sit opposite each other

  static DocumentReference<Map<String, dynamic>> _doc(String code) =>
      FirebaseFirestore.instance.collection('rooms').doc(code);
  DocumentReference<Map<String, dynamic>> get _ref => _doc(code);

  @override
  LudoState get state => _state!;
  @override
  List<String> get names =>
      List.generate(4, (i) => _names[i].isNotEmpty ? _names[i] : (seats[i].isEmpty ? '-' : 'Player'));
  @override
  List<String> get avatars =>
      List.generate(4, (i) => _avatars[i].isNotEmpty ? _avatars[i] : Profile.defaultAvatars[i]);

  bool get hasState => _state != null;
  int get mySeat => seats.indexOf(uid);
  bool get isHost => host == uid;
  int get joined => seats.where((s) => s.isNotEmpty).length;

  static Future<String> create(String uid) async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random();
    final code = List.generate(5, (_) => chars[r.nextInt(chars.length)]).join();
    await _doc(code).set({
      'host': uid,
      'seats': [uid, '', '', ''],
      'names': [Profile.name, '', '', ''],
      'avatars': [Profile.avatar, '', '', ''],
      'status': 'waiting',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  static Future<void> join(String code, String uid) async {
    final ref = _doc(code);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw 'Room not found';
      final d = snap.data()!;
      final seats = List<String>.from(d['seats']);
      if (seats.contains(uid)) return;
      if (d['status'] != 'waiting') throw 'Game already started';
      final free = _joinOrder.where((i) => seats[i].isEmpty);
      if (free.isEmpty) throw 'Room is full';
      final names = List<String>.from(d['names'] ?? ['', '', '', '']);
      final avatars = List<String>.from(d['avatars'] ?? ['', '', '', '']);
      final i = free.first;
      seats[i] = uid;
      names[i] = Profile.name;
      avatars[i] = Profile.avatar;
      tx.update(ref, {'seats': seats, 'names': names, 'avatars': avatars});
    });
  }

  /// Matchmaking: Finds an existing waiting room or creates a new one automatically.
  static Future<String> findMatch(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('rooms')
          .where('status', isEqualTo: 'waiting')
          .limit(8)
          .get()
          .timeout(const Duration(seconds: 4));

      for (final doc in snap.docs) {
        final seats = List<String>.from(doc.data()['seats'] ?? []);
        if (seats.contains(uid)) return doc.id;
        if (seats.where((s) => s.isNotEmpty).length < 4) {
          final code = doc.id;
          await join(code, uid);
          return code;
        }
      }
    } catch (_) {}

    return await create(uid);
  }

  /// Search online room or user profile by Unique User ID (e.g. "LD-4921").
  static Future<String?> findRoomByPlayerId(String targetId) async {
    try {
      final formattedId = targetId.trim().toUpperCase();
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('uniqueId', isEqualTo: formattedId)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 4));

      if (userSnap.docs.isNotEmpty) {
        final targetUid = userSnap.docs.first.id;
        final roomSnap = await FirebaseFirestore.instance
            .collection('rooms')
            .where('host', isEqualTo: targetUid)
            .where('status', isEqualTo: 'waiting')
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 4));

        if (roomSnap.docs.isNotEmpty) {
          return roomSnap.docs.first.id;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> start() async {
    final active = seats.map((s) => s.isNotEmpty).toList();
    await _ref.update({'status': 'playing', 'state': LudoState.initial(4, active).toMap()});
  }

  void _onSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    final d = snap.data();
    if (d == null) return;
    seats = List<String>.from(d['seats']);
    _names = List<String>.from(d['names'] ?? ['', '', '', '']);
    _avatars = List<String>.from(d['avatars'] ?? ['', '', '', '']);
    status = d['status'];
    host = d['host'];
    if (d['state'] != null) _state = LudoState.fromMap(Map<String, dynamic>.from(d['state']));
    notifyListeners();
  }

  @override
  bool canAct(int seat) => seat == mySeat;

  void _push() {
    notifyListeners();
    _ref.update({'state': state.toMap()});
  }

  @override
  void roll(int v) {
    if (!canAct(state.turn)) return;
    state.roll(v);
    _push();
  }

  @override
  void move(int t) {
    if (!canAct(state.turn)) return;
    state.move(t);
    _push();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
