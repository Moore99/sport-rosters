import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';

class SendNotificationScreen extends ConsumerStatefulWidget {
  final String teamId;
  final String? eventId; // optional — pre-fills subject for event notifications

  const SendNotificationScreen({
    super.key,
    required this.teamId,
    this.eventId,
  });

  @override
  ConsumerState<SendNotificationScreen> createState() =>
      _SendNotificationScreenState();
}

class _SendNotificationScreenState
    extends ConsumerState<SendNotificationScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl  = TextEditingController();
  bool _sending    = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);

    try {
      final result = await FirebaseFunctions.instanceFor(
        region: 'northamerica-northeast1',
      ).httpsCallable('sendTeamNotification').call({
        'teamId': widget.teamId,
        'title':  _titleCtrl.text.trim(),
        'body':   _bodyCtrl.text.trim(),
        if (widget.eventId != null) 'eventId': widget.eventId,
      });

      final sent = (result.data as Map)['sent'] ?? 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Notification sent to $sent member${sent == 1 ? '' : 's'}.')),
        );
        Navigator.of(context).pop();
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamAsync = ref.watch(teamProvider(widget.teamId));
    final teamName  = teamAsync.valueOrNull?.name ?? 'Team';

    return Scaffold(
      appBar: AppBar(title: Text('Notify $teamName')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Send a push notification to all team members '
              'who have notifications enabled.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),

            // ── Title ────────────────────────────────────────────────────────
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText:  'e.g. Practice cancelled',
                border:    OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              maxLength: 100,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required.' : null,
            ),
            const SizedBox(height: 16),

            // ── Body ─────────────────────────────────────────────────────────
            TextFormField(
              controller: _bodyCtrl,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText:  'e.g. Field is closed — see you next week!',
                border:    OutlineInputBorder(),
                prefixIcon: Icon(Icons.message_outlined),
                alignLabelWithHint: true,
              ),
              maxLines:  4,
              maxLength: 300,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Message is required.' : null,
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send),
            label: const Text('Send Notification'),
          ),
        ),
      ),
    );
  }
}
