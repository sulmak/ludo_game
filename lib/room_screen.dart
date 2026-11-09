import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'board_painter.dart';
import 'controllers.dart';
import 'game_screen.dart';
import 'ludo_logic.dart';

class RoomScreen extends StatefulWidget {
  final String code;
  const RoomScreen({super.key, required this.code});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late final OnlineController c =
      OnlineController(widget.code, FirebaseAuth.instance.currentUser!.uid);

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        if (c.status == 'playing' && c.hasState) return GameScreen(c: c);
        final names = c.names, avatars = c.avatars;
        return Scaffold(
          backgroundColor: const Color(0xFF1B1530),
          appBar: AppBar(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              title: Text('Room ${widget.code}')),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Share this code with your friends',
                      style: TextStyle(color: Colors.white70)),
                  SelectableText(widget.code,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 44,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 6)),
                  const SizedBox(height: 20),
                  for (var i = 0; i < 4; i++)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: kColors[i],
                        child: Text(c.seats[i].isEmpty ? '' : avatars[i],
                            style: const TextStyle(fontSize: 22)),
                      ),
                      title: Text(c.seats[i].isEmpty ? kNames[i] : names[i],
                          style: const TextStyle(color: Colors.white)),
                      trailing: Text(
                          c.seats[i].isEmpty ? 'waiting...' : (c.seats[i] == c.uid ? 'You' : 'Joined'),
                          style: const TextStyle(color: Colors.white70)),
                    ),
                  const SizedBox(height: 12),
                  if (c.isHost)
                    FilledButton(
                      onPressed: c.joined >= 2 ? c.start : null,
                      child: const Text('Start game'),
                    )
                  else
                    const Text('Waiting for host to start...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
