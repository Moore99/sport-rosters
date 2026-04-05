import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../providers/auth_notifier.dart';
import '../providers/auth_provider.dart';

class EmailVerifyScreen extends ConsumerStatefulWidget {
  const EmailVerifyScreen({super.key});

  @override
  ConsumerState<EmailVerifyScreen> createState() => _EmailVerifyScreenState();
}

class _EmailVerifyScreenState extends ConsumerState<EmailVerifyScreen> {
  bool _resending  = false;
  bool _checking   = false;
  bool _resentOnce = false;
  String? _message;

  Future<void> _resend() async {
    setState(() { _resending = true; _message = null; });
    final ok = await ref.read(authNotifierProvider.notifier).sendEmailVerification();
    if (mounted) {
      setState(() {
        _resending  = false;
        _resentOnce = ok;
        _message    = ok ? 'Email resent. Check your inbox (and spam folder).' : null;
      });
    }
  }

  Future<void> _checkVerified() async {
    setState(() { _checking = true; _message = null; });
    final verified = await ref.read(authNotifierProvider.notifier).reloadAndCheckVerified();
    if (!mounted) return;
    if (verified) {
      context.go(AppRoutes.teams);
    } else {
      setState(() {
        _checking = false;
        _message  = 'Email not verified yet. Check your inbox and click the link.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(currentUserProvider)?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.mark_email_unread_outlined, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Verify your email',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'A verification link was sent to:\n$email\n\n'
                    'Click the link in the email, then tap "I\'ve Verified" below.\n\n'
                    'Check your spam folder if you don\'t see it.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    icon:  _checking
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline),
                    label: const Text("I've Verified"),
                    onPressed: (_checking || _resending) ? null : _checkVerified,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon:  _resending
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_outlined),
                    label: Text(_resentOnce ? 'Resend Again' : 'Resend Email'),
                    onPressed: (_resending || _checking) ? null : _resend,
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _message!.contains('not verified')
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  TextButton(
                    onPressed: () async {
                      await ref.read(authNotifierProvider.notifier).signOut();
                    },
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
