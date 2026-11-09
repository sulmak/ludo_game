import 'package:audioplayers/audioplayers.dart';

/// Plays short sound effects from assets/sounds/<name>.wav
class Sfx {
  static bool enabled = true;

  static Future<void> play(String name) async {
    if (!enabled) return;
    try {
      final p = AudioPlayer();
      await p.setReleaseMode(ReleaseMode.release);
      await p.play(AssetSource('sounds/$name.wav'));
      p.onPlayerComplete.first.then((_) => p.dispose());
    } catch (_) {
      // Sound is optional: never crash the game because of audio.
    }
  }
}
