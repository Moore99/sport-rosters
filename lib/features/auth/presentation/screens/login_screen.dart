import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../../core/router/app_router.dart';
import '../providers/auth_notifier.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  bool _obscure     = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authNotifierProvider.notifier).signIn(
      _emailCtrl.text,
      _passCtrl.text,
    );
    // On success GoRouter redirect takes over — no manual navigation needed.
    if (!ok && mounted) {
      final err = ref.read(authNotifierProvider).error?.toString() ?? 'Login failed.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AsyncLoading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Logo / Title ──────────────────────────────────────
                    Image.asset('assets/icons/app_icon.png', width: 96, height: 96),
                    const SizedBox(height: 16),
                    Text(
                      'Sport Rosters',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to your account',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // ── Email ─────────────────────────────────────────────
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Email is required.';
                        if (!v.contains('@')) return 'Enter a valid email.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── Password ──────────────────────────────────────────
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Password is required.' : null,
                    ),
                    const SizedBox(height: 8),

                    // ── Forgot password ───────────────────────────────────
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push(AppRoutes.forgotPassword),
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Sign in button ────────────────────────────────────
                    FilledButton(
                      onPressed: isLoading ? null : _submit,
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width:  20,
                              child:  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sign In'),
                    ),
                    const SizedBox(height: 16),

                    // ── Divider ───────────────────────────────────────────
                    Row(children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.outline)),
                      ),
                      const Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: 16),

                    // ── Google Sign-In ────────────────────────────────────
                    OutlinedButton.icon(
                      icon:  Image.asset('assets/icons/google_logo.png',
                          height: 20,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.login)),
                      label: const Text('Continue with Google'),
                      onPressed: isLoading ? null : () async {
                        await ref
                            .read(authNotifierProvider.notifier)
                            .signInWithGoogle();
                        if (context.mounted) {
                          final authState = ref.read(authNotifierProvider);
                          if (authState is AsyncError) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(authState.error.toString())),
                            );
                          }
                        }
                      },
                    ),

                    // ── Sign in with Apple (iOS only — required by App Store) ─
                    if (Platform.isIOS) ...[
                      const SizedBox(height: 12),
                      SignInWithAppleButton(
                        onPressed: isLoading ? () {} : () async {
                          await ref
                              .read(authNotifierProvider.notifier)
                              .signInWithApple();
                          if (context.mounted) {
                            final authState = ref.read(authNotifierProvider);
                            if (authState is AsyncError) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(authState.error.toString())),
                              );
                            }
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 24),

                    // ── Register link ─────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account?"),
                        TextButton(
                          onPressed: () => context.push(AppRoutes.register),
                          child: const Text('Create one'),
                        ),
                      ],
                    ),

                    // ── Discovery links ───────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(
                              textStyle: const TextStyle(fontSize: 12)),
                          onPressed: () => context.push(AppRoutes.tour),
                          child: const Text('See how it works'),
                        ),
                        Text('·',
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.outline)),
                        TextButton(
                          style: TextButton.styleFrom(
                              textStyle: const TextStyle(fontSize: 12)),
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => const _TeamPreviewDialog(),
                          ),
                          child: const Text('Have a Team ID?'),
                        ),
                      ],
                    ),

                    // ── Legal links ───────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => context.push(AppRoutes.privacy),
                          child: const Text('Privacy Policy', style: TextStyle(fontSize: 12)),
                        ),
                        const Text('·', style: TextStyle(fontSize: 12)),
                        TextButton(
                          onPressed: () => context.push(AppRoutes.terms),
                          child: const Text('Terms', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Team Preview Dialog ────────────────────────────────────────────────────────

class _TeamPreviewDialog extends StatefulWidget {
  const _TeamPreviewDialog();

  @override
  State<_TeamPreviewDialog> createState() => _TeamPreviewDialogState();
}

class _TeamPreviewDialogState extends State<_TeamPreviewDialog> {
  final _idCtrl = TextEditingController();
  bool    _loading = false;
  String? _teamName;
  String? _teamSport;
  String? _error;

  @override
  void dispose() {
    _idCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final id = _idCtrl.text.trim();
    if (id.isEmpty) return;
    setState(() { _loading = true; _error = null; _teamName = null; });
    try {
      final fn     = FirebaseFunctions.instanceFor(region: 'northamerica-northeast1');
      final result = await fn.httpsCallable('previewTeam').call({'teamId': id});
      setState(() {
        _teamName  = result.data['name']  as String?;
        _teamSport = result.data['sport'] as String?;
      });
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = e.code == 'not-found'
          ? 'Team not found. Check the ID and try again.'
          : 'Something went wrong. Please try again.');
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPreview = _teamName != null;

    return AlertDialog(
      title: const Text('Find Your Team'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Enter the Team ID your coach shared with you.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller:     _idCtrl,
                  autocorrect:    false,
                  textCapitalization: TextCapitalization.none,
                  decoration: const InputDecoration(
                    labelText:   'Team ID',
                    border:      OutlineInputBorder(),
                    prefixIcon:  Icon(Icons.tag),
                  ),
                  onSubmitted: (_) => _lookup(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: _loading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.search),
                onPressed: _loading ? null : _lookup,
              ),
            ],
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13)),
          ],

          if (hasPreview) ...[
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.groups,
                        color: Theme.of(context).colorScheme.onPrimaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_teamName!,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer)),
                          if (_teamSport != null)
                            Text(_teamSport!,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (hasPreview)
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.push(AppRoutes.register);
            },
            child: const Text('Create Account'),
          ),
      ],
    );
  }
}
