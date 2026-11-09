import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// The signed-in player's name, avatar, uniqueId, stats and saved game state (saved in Firestore users/{uid}).
class Profile {
  static String name = 'Player';
  static String avatar = '🦁';
  static String uniqueId = '';
  static bool chosen = false; // true when the user typed a name on sign-up
  static int gamesPlayed = 0;
  static int gamesWon = 0;
  static Map<String, dynamic>? savedGameState;

  static const avatars = ['🦁', '🐯', '🐼', '🦊', '🐸', '🐵', '🦄', '🐲'];
  static const defaultAvatars = ['🦁', '🐸', '🐥', '🐳', '🦄', '🐼'];
  static const botAvatars = ['🤖', '👾', '🎃', '👻', '🦾', '🛸'];

  static String generateUniqueId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random();
    final rand = List.generate(4, (_) => chars[r.nextInt(chars.length)]).join();
    return 'LD-$rand';
  }

  static Future<void> load(User user) async {
    try {
      final d = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 3));
      if (d.exists) {
        final data = d.data();
        if (data != null) {
          name = (data['name'] as String?) ?? name;
          avatar = (data['avatar'] as String?) ?? avatar;
          uniqueId = (data['uniqueId'] as String?) ?? generateUniqueId();
          gamesPlayed = (data['gamesPlayed'] as int?) ?? 0;
          gamesWon = (data['gamesWon'] as int?) ?? 0;
          if (data['savedGameState'] != null) {
            savedGameState = Map<String, dynamic>.from(data['savedGameState']);
          }
          await save();
          return;
        }
      }
    } catch (_) {}
    if (uniqueId.isEmpty) uniqueId = generateUniqueId();
    if (!chosen) {
      final dn = user.displayName;
      if (dn != null && dn.isNotEmpty) {
        name = dn;
      } else {
        name = user.isAnonymous ? 'Guest' : (user.email ?? 'Player').split('@').first;
      }
    }
    await save();
  }

  static Future<void> save() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    if (uniqueId.isEmpty) uniqueId = generateUniqueId();
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(u.uid)
          .set({
            'name': name,
            'avatar': avatar,
            'uniqueId': uniqueId,
            'gamesPlayed': gamesPlayed,
            'gamesWon': gamesWon,
            'savedGameState': savedGameState,
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  static Future<void> recordGameEnd({required bool won}) async {
    gamesPlayed++;
    if (won) gamesWon++;
    savedGameState = null;
    await save();
  }

  static Future<void> saveGame(Map<String, dynamic> stateMap) async {
    savedGameState = stateMap;
    await save();
  }

  static Future<void> clearGame() async {
    savedGameState = null;
    await save();
  }

  static void reset() {
    name = 'Player';
    avatar = '🦁';
    uniqueId = '';
    chosen = false;
    gamesPlayed = 0;
    gamesWon = 0;
    savedGameState = null;
  }
}
