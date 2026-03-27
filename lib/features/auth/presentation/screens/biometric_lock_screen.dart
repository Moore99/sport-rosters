import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/biometric_service.dart';
import '../providers/auth_notifier.dart';

class BiometricLockScreen extends ConsumerStatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  ConsumerState<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends ConsumerState<BiometricLockScreen> {
  bool    _busy  = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_authenticate);
  }

  Future<void> _authenticate() async {
    setState(() { _busy = true; _error = null; });

    final service = ref.read(biometricServiceProvider);

    // If hardware is no longer available (e.g., user un-enrolled all biometrics),
    // don't trap them — just unlock silently.
    final available = await service.isAvailable();
    if (!mounted) return;
    if (!available) {
      ref.read(biometricLockProvider.notifier).unlock();
      return;
    }

    final success = await service.authenticate();
    if (!mounted) return;

    if (success) {
      ref.read(biometricLockProvider.notifier).unlock();
    } else {
      setState(() {
        _busy  = false;
        _error = 'Authentication failed. Tap the button to try again.';
      });
    }
  }

  Future<void> _signInDifferently() async {
    // Unlock first so the router can navigate to /login after sign-out.
    ref.read(biometricLockProvider.notifier).unlock();
    await ref.read(authNotifierProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/icons/app_icon.png', width: 80, height: 80),
                const SizedBox(height: 24),
                Text(
                  'Sport Rosters',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Authenticate to continue',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline),
                ),
                const SizedBox(height: 40),
                if (_busy)
                  const CircularProgressIndicator()
                else
                  FilledButton.icon(
                    onPressed: _authenticate,
                    icon:  const Icon(Icons.fingerprint),
                    label: const Text('Authenticate'),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 13),
                  ),
                ],
                const SizedBox(height: 40),
                TextButton(
                  onPressed: _busy ? null : _signInDifferently,
                  child: const Text('Sign in with a different account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
