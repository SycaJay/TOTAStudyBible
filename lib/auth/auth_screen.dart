import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../app_colors.dart';
import '../app_state.dart';
import '../widgets/google_sign_in_control.dart';
import 'auth_errors.dart';

/// Google sign-in only (Firebase Auth).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  String? _error;
  bool _busy = false;

  Future<void> _completeGoogleAccount(GoogleSignInAccount account) async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await AppStateScope.of(context).signInWithGoogleAccount(account);
      if (!mounted) return;
      if (AppStateScope.of(context).signedIn) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlySignInErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onMobileGoogle() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await AppStateScope.of(context).signInWithGoogle();
      if (!mounted) return;
      final ok = AppStateScope.of(context).signedIn;
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = 'Sign-in was cancelled.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlySignInErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Account'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: CircleAvatar(
                            radius: 36,
                            backgroundColor: AppColors.accentBlue.withValues(
                              alpha: 0.18,
                            ),
                            child: const Icon(
                              Icons.person_outline_rounded,
                              size: 40,
                              color: AppColors.accentBlueDeep,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Sign in with Google to save notes, highlights, bookmarks, and prayer requests.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            height: 1.55,
                            fontSize: 15,
                            color: AppColors.inkMuted,
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 18),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                        GoogleSignInControl(
                          googleSignIn: AppStateScope.of(context).googleSignIn,
                          busy: _busy,
                          height: 48,
                          enabled: !AppStateScope.of(context).signedIn,
                          onGoogleAccount: _completeGoogleAccount,
                          onMobileSignIn: _onMobileGoogle,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

Future<bool> ensureSignedIn(BuildContext context) async {
  final app = AppStateScope.of(context);
  if (app.signedIn) return true;
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const AuthScreen(),
    ),
  );
  return result == true;
}
