import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../providers/auth_notifier.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  bool _obscure       = true;
  bool _obscureConf   = true;
  bool _termsAccepted = false;
  bool _showPhone     = false; // user chooses to provide phone

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the Terms of Service to continue.')),
      );
      return;
    }

    final ok = await ref.read(authNotifierProvider.notifier).register(
      name:     _nameCtrl.text,
      email:    _emailCtrl.text,
      password: _passCtrl.text,
      phone:    _showPhone ? _phoneCtrl.text : null,
    );

    if (!ok && mounted) {
      final err = ref.read(authNotifierProvider).error?.toString() ?? 'Registration failed.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
    // On success GoRouter redirect takes over.
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AsyncLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Name ──────────────────────────────────────────────
                    TextFormField(
                      key: const Key('field_name'),
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Name is required.' : null,
                    ),
                    const SizedBox(height: 16),

                    // ── Email ─────────────────────────────────────────────
                    TextFormField(
                      key: const Key('field_email'),
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
                      key: const Key('field_password'),
                      controller: _passCtrl,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Password is required.';
                        if (v.length < 6) return 'Password must be at least 6 characters.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── Confirm Password ──────────────────────────────────
                    TextFormField(
                      key: const Key('field_confirm_password'),
                      controller: _confirmCtrl,
                      obscureText: _obscureConf,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConf
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscureConf = !_obscureConf),
                        ),
                      ),
                      validator: (v) {
                        if (v != _passCtrl.text) return 'Passwords do not match.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // ── Optional: Phone (with consent notice) ─────────────
                    // GDPR/PIPEDA: optional field with stated purpose before collection
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('Phone Number',
                                    style: TextStyle(fontWeight: FontWeight.w600)),
                                const Spacer(),
                                Text('Optional',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.outline)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Used only so team admins can contact you directly. '
                              'Never shared with third parties.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.outline),
                            ),
                            const SizedBox(height: 8),
                            CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('I want to add my phone number',
                                  style: TextStyle(fontSize: 13)),
                              value: _showPhone,
                              onChanged: (v) => setState(() => _showPhone = v ?? false),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                            if (_showPhone) ...[
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _phoneCtrl,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.done,
                                decoration: const InputDecoration(
                                  labelText: 'Phone Number',
                                  prefixIcon: Icon(Icons.phone_outlined),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Terms acceptance ──────────────────────────────────
                    CheckboxListTile(
                      key: const Key('chk_terms'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: _termsAccepted,
                      onChanged: (v) => setState(() => _termsAccepted = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text.rich(
                        TextSpan(
                          text: 'I agree to the ',
                          style: const TextStyle(fontSize: 13),
                          children: [
                            TextSpan(
                              text: 'Terms of Service',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  decoration: TextDecoration.underline),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => context.push(AppRoutes.terms),
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  decoration: TextDecoration.underline),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => context.push(AppRoutes.privacy),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Register button ───────────────────────────────────
                    FilledButton(
                      key: const Key('btn_create_account'),
                      onPressed: isLoading ? null : _submit,
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width:  20,
                              child:  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create Account'),
                    ),
                    const SizedBox(height: 16),

                    // ── Back to login ─────────────────────────────────────
                    Center(
                      child: TextButton(
                        onPressed: () => context.pop(),
                        child: const Text('Already have an account? Sign in'),
                      ),
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
