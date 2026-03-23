import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/phase1_integration_test_service.dart';
import '../theme/glass_card.dart';
import '../widgets/gradient_button.dart';

class Phase1IntegrationScreen extends StatefulWidget {
  const Phase1IntegrationScreen({super.key});

  @override
  State<Phase1IntegrationScreen> createState() => _Phase1IntegrationScreenState();
}

class _Phase1IntegrationScreenState extends State<Phase1IntegrationScreen> {
  final _service = const Phase1IntegrationTestService();
  bool _isLoading = false;
  String? _message;

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  Future<void> _signInAnonymously() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      setState(() {
        _message = 'Signed in: uid=${cred.user?.uid}';
      });
    } catch (e) {
      setState(() {
        _message = 'Sign-in failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    setState(() {
      _message = 'Signed out';
    });
  }

  Future<void> _runTest() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final user = await _service.run();
      setState(() {
        _message = 'PASS: Firebase user synced to Supabase and read back.\\n'
            'uid=${user['uid']}\\nname=${user['name']}\\ntitle=${user['title']}';
      });
    } catch (e) {
      setState(() {
        _message = 'FAIL: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phase 1 Integration Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const GlassCard(
              child: Text(
                'Expected flow: Firebase Auth login -> Supabase user upsert -> read back from users table.',
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              child: Text(
                _currentUser == null
                    ? 'Firebase user: not signed in'
                    : 'Firebase user: ${_currentUser!.uid}',
              ),
            ),
            const SizedBox(height: 16),
            GradientButton(
              label: _currentUser == null ? 'Sign In Anonymously' : 'Sign Out',
              onPressed: _isLoading
                  ? () {}
                  : () {
                      if (_currentUser == null) {
                        _signInAnonymously();
                      } else {
                        _signOut();
                      }
                    },
            ),
            const SizedBox(height: 16),
            if (_isLoading) const LinearProgressIndicator(),
            GradientButton(
              label: 'Run Integration Smoke Test',
              onPressed: _isLoading ? () {} : _runTest,
            ),
            const SizedBox(height: 16),
            if (_message != null)
              GlassCard(
                child: Text(_message!),
              ),
          ],
        ),
      ),
    );
  }
}
