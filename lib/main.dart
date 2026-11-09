import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controllers.dart';
import 'firebase_options.dart';
import 'game_screen.dart';
import 'login_screen.dart';
import 'ludo_logic.dart';
import 'profile.dart';
import 'room_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    webExperimentalForceLongPolling: true,
  );
  var user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    try {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      user = cred.user;
    } catch (_) {}
  }
  if (user != null) {
    await Profile.load(user);
  }
  runApp(const LudoApp());
}

class LudoApp extends StatelessWidget {
  const LudoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Ludo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            colorSchemeSeed: Colors.deepPurple, brightness: Brightness.dark, useMaterial3: true),
        home: const LoginScreen(),
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TextEditingController _name = TextEditingController(text: Profile.name);
  int _playerCount = 4; // 2, 3, 4, 5, 6
  int _colorOpt2P = 0; // 0: Red & Yellow, 1: Red & Green, 2: Green & Blue, 3: Yellow & Blue
  int _colorOpt3P = 0; // 0: Red, Green, Yellow, 1: Red, Yellow, Blue, 2: Green, Yellow, Blue, 3: Red, Green, Blue

  static const _pairs2P = [
    ([0, 2], 'Red & Yellow'),
    ([0, 1], 'Red & Green'),
    ([1, 3], 'Green & Blue'),
    ([2, 3], 'Yellow & Blue'),
  ];

  static const _trios3P = [
    [0, 1, 2],
    [0, 2, 3],
    [1, 2, 3],
    [0, 1, 3],
  ];

  int get _boardN => _playerCount <= 4 ? 4 : _playerCount;

  Set<int> get _activeSeats {
    if (_playerCount == 2) {
      return _pairs2P[_colorOpt2P].$1.toSet();
    }
    if (_playerCount == 3) {
      return _trios3P[_colorOpt3P].toSet();
    }
    return {for (var i = 0; i < _playerCount; i++) i};
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _open(Widget screen) async {
    Profile.name = _name.text.trim().isEmpty ? 'Player' : _name.text.trim();
    await Profile.save();
    if (mounted) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
      setState(() {});
    }
  }

  bool _firebaseReady() {
    if (Firebase.apps.isNotEmpty) return true;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Online mode needs Firebase: run flutterfire configure and enable it in main.dart')));
    return false;
  }

  Future<void> _findMatch() async {
    if (!_firebaseReady()) return;
    Profile.name = _name.text.trim().isEmpty ? 'Player' : _name.text.trim();
    await Profile.save();
    if (!mounted) return;
    try {
      final code = await OnlineController.findMatch(FirebaseAuth.instance.currentUser!.uid);
      if (mounted) await _open(RoomScreen(code: code));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _createRoom() async {
    if (!_firebaseReady()) return;
    Profile.name = _name.text.trim().isEmpty ? 'Player' : _name.text.trim();
    await Profile.save();
    if (!mounted) return;
    try {
      final code = await OnlineController.create(FirebaseAuth.instance.currentUser!.uid);
      if (mounted) await _open(RoomScreen(code: code));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _joinRoom() async {
    if (!_firebaseReady()) return;
    Profile.name = _name.text.trim().isEmpty ? 'Player' : _name.text.trim();
    await Profile.save();
    if (!mounted) return;
    final ctrl = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Find Player / Join Room'),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'Enter Room Code or Unique User ID (e.g. LD-83A2)',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim().toUpperCase()),
              child: const Text('Find & Join')),
        ],
      ),
    );
    if (query == null || query.isEmpty) return;
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      if (query.startsWith('LD-')) {
        final roomCode = await OnlineController.findRoomByPlayerId(query);
        if (roomCode != null) {
          await OnlineController.join(roomCode, uid);
          if (mounted) await _open(RoomScreen(code: roomCode));
          return;
        } else {
          throw 'No active waiting room found for Player $query';
        }
      }
      await OnlineController.join(query, uid);
      if (mounted) await _open(RoomScreen(code: query));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget btn(String label, IconData icon, VoidCallback onTap, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: SizedBox(
            width: 270,
            height: 52,
            child: FilledButton.icon(
              onPressed: onTap,
              icon: Icon(icon),
              label: Text(label),
              style: color != null ? FilledButton.styleFrom(backgroundColor: color) : null,
            ),
          ),
        );

    const style = TextStyle(fontSize: 60, fontWeight: FontWeight.w900, letterSpacing: 6);
    return Scaffold(
      backgroundColor: const Color(0xFF1B1530),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: 'Account / Login',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
              setState(() {
                _name.text = Profile.name;
              });
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: 'L', style: style.copyWith(color: kColors[0])),
                TextSpan(text: 'U', style: style.copyWith(color: kColors[1])),
                TextSpan(text: 'D', style: style.copyWith(color: kColors[2])),
                TextSpan(text: 'O', style: style.copyWith(color: kColors[3])),
              ])),
              const SizedBox(height: 10),
              // Unique User ID Badge
              if (Profile.uniqueId.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: Profile.uniqueId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Copied User ID: ${Profile.uniqueId}')),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade700.withValues(alpha: .5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.deepPurpleAccent),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.badge, size: 14, color: Colors.amberAccent),
                        const SizedBox(width: 6),
                        Text('ID: ${Profile.uniqueId}',
                            style: const TextStyle(
                                color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(width: 6),
                        const Icon(Icons.copy, size: 12, color: Colors.white70),
                      ],
                    ),
                  ),
                ),
              // User Stats Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🏆 Wins: ${Profile.gamesWon}',
                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(width: 16),
                    Text('🎮 Played: ${Profile.gamesPlayed}',
                        style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final a in Profile.avatars)
                    GestureDetector(
                      onTap: () {
                        setState(() => Profile.avatar = a);
                        Profile.save();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white10,
                          border: Border.all(
                              color: Profile.avatar == a ? Colors.amber : Colors.transparent, width: 3),
                        ),
                        child: Text(a, style: const TextStyle(fontSize: 26)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: 270,
                child: TextField(
                  controller: _name,
                  maxLength: 12,
                  textAlign: TextAlign.center,
                  onChanged: (val) {
                    Profile.name = val.trim();
                    Profile.save();
                  },
                  decoration: const InputDecoration(
                      labelText: 'Your name', border: OutlineInputBorder(), counterText: ''),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Players: ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ToggleButtons(
                    isSelected: [for (var p = 2; p <= 6; p++) _playerCount == p],
                    onPressed: (index) => setState(() => _playerCount = index + 2),
                    borderRadius: BorderRadius.circular(8),
                    selectedColor: Colors.white,
                    fillColor: Colors.deepPurple,
                    color: Colors.white70,
                    constraints: const BoxConstraints(minWidth: 38, minHeight: 36),
                    children: [for (var p = 2; p <= 6; p++) Text('$p P')],
                  ),
                ],
              ),
              if (_playerCount == 2) ...[
                const SizedBox(height: 10),
                const Text('Select Colors:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  children: [
                    for (var i = 0; i < _pairs2P.length; i++)
                      ChoiceChip(
                        selected: _colorOpt2P == i,
                        onSelected: (_) => setState(() => _colorOpt2P = i),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final c in _pairs2P[i].$1) ...[
                              CircleAvatar(radius: 5, backgroundColor: kColors[c]),
                              const SizedBox(width: 3),
                            ],
                            Text(_pairs2P[i].$2, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
              if (_playerCount == 3) ...[
                const SizedBox(height: 10),
                const Text('Select Colors:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  children: [
                    for (var i = 0; i < _trios3P.length; i++)
                      ChoiceChip(
                        selected: _colorOpt3P == i,
                        onSelected: (_) => setState(() => _colorOpt3P = i),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final c in _trios3P[i]) ...[
                              CircleAvatar(radius: 5, backgroundColor: kColors[c]),
                              const SizedBox(width: 2),
                            ],
                            const SizedBox(width: 4),
                            Text(_trios3P[i].map((c) => kNames[c]).join('/'), style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              // Resume Game button if a saved game exists
              if (Profile.savedGameState != null) ...[
                btn(
                  'Resume Game',
                  Icons.play_arrow,
                  () => _open(GameScreen(
                      c: LocalController.resume(Profile.savedGameState!, {0}), ownsController: true)),
                  color: Colors.green.shade700,
                ),
              ],
              btn('Find Online Player', Icons.radar, _findMatch, color: Colors.deepPurple.shade600),
              btn('Play vs Computer', Icons.smart_toy,
                  () => _open(GameScreen(c: LocalController(_boardN, {0}, activeSeats: _activeSeats), ownsController: true))),
              btn('Pass & Play ($_playerCount players)', Icons.group,
                  () => _open(GameScreen(c: LocalController(_boardN, _activeSeats, activeSeats: _activeSeats), ownsController: true))),
              btn('Create Online Room (4P)', Icons.add_circle, _createRoom),
              btn('Search Player / Join Room', Icons.search, _joinRoom),
              const SizedBox(height: 24),
              const Text(
                'Powered by Md. Atikur Rahman Mridha',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
