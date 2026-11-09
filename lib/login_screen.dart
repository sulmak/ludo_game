import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'board_painter.dart';
import 'ludo_logic.dart';
import 'main.dart';
import 'profile.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _name.dispose();
    super.dispose();
  }

  String _msg(FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => 'That email address looks wrong.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Wrong email or password.',
        'email-already-in-use' => 'An account with this email already exists.',
        'weak-password' => 'Password must be at least 6 characters.',
        'network-request-failed' => 'No internet connection.',
        'too-many-requests' => 'Too many attempts. Try again later.',
        'operation-not-allowed' => 'Email/Password sign-in is disabled in your Firebase console. Please enable Email/Password provider in Firebase Console -> Authentication -> Sign-in method, or use "Play as guest".',
        'missing-name' => 'Please enter your name.',
        _ => e.message ?? e.code,
      };

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() => _run(() async {
        final auth = FirebaseAuth.instance;
        final email = _email.text.trim();
        if (_signUp) {
          final name = _name.text.trim();
          if (name.isEmpty) {
            throw FirebaseAuthException(code: 'missing-name');
          }
          Profile.name = name;
          Profile.chosen = true;
          final cred = await auth.createUserWithEmailAndPassword(email: email, password: _pass.text);
          await cred.user?.updateDisplayName(name);
          await Profile.save();
        } else {
          Profile.chosen = false;
          final cred = await auth.signInWithEmailAndPassword(email: email, password: _pass.text);
          if (cred.user != null) {
            await Profile.load(cred.user!);
          }
        }
      });

  Future<void> _guest() => _run(() async {
        Profile.chosen = false;
        try {
          final cred = await FirebaseAuth.instance.signInAnonymously();
          if (cred.user != null) {
            await Profile.load(cred.user!);
          }
        } catch (_) {
          // Fallback to local guest mode if anonymous auth is not enabled in Firebase
        }
      });

  Future<void> _forgot() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Type your email first, then tap "Forgot password".');
      return;
    }
    await _run(() async {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Password reset email sent to $email')));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 56, fontWeight: FontWeight.w900, letterSpacing: 6);
    return Scaffold(
      backgroundColor: const Color(0xFF1B1530),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: 'L', style: style.copyWith(color: kColors[0])),
                    TextSpan(text: 'U', style: style.copyWith(color: kColors[1])),
                    TextSpan(text: 'D', style: style.copyWith(color: kColors[2])),
                    TextSpan(text: 'O', style: style.copyWith(color: kColors[3])),
                  ]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Login')),
                    ButtonSegment(value: true, label: Text('Sign up')),
                  ],
                  selected: {_signUp},
                  onSelectionChanged: (v) => setState(() {
                    _signUp = v.first;
                    _error = null;
                  }),
                ),
                const SizedBox(height: 16),
                if (_signUp) ...[
                  TextField(
                    controller: _name,
                    maxLength: 12,
                    decoration: const InputDecoration(
                        labelText: 'Your name',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                        counterText: ''),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                      labelText: 'Email', prefixIcon: Icon(Icons.email), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass,
                  obscureText: _hide,
                  onSubmitted: (_) => _busy ? null : _submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _hide = !_hide),
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_signUp ? 'Create account' : 'Login'),
                  ),
                ),
                if (!_signUp)
                  TextButton(onPressed: _busy ? null : _forgot, child: const Text('Forgot password?')),
                const Divider(height: 28),
                SizedBox(
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _guest,
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Play as guest'),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Powered by Md. Atikur Rahman Mridha',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
