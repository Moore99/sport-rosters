import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/providers.dart';
import '../../../../core/services/analytics_service.dart';
import '../../data/team_repository.dart';
import '../../domain/admin_role.dart';
import '../../domain/team.dart';

class CreateTeamScreen extends ConsumerStatefulWidget {
  const CreateTeamScreen({super.key});

  @override
  ConsumerState<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

// Common North American IANA timezones shown with friendly labels
const _kTimezones = [
  ('America/Toronto',    'Eastern — Toronto / New York'),
  ('America/Winnipeg',   'Central — Winnipeg / Chicago'),
  ('America/Edmonton',   'Mountain — Calgary / Denver'),
  ('America/Phoenix',    'Mountain — Phoenix (no DST)'),
  ('America/Vancouver',  'Pacific — Vancouver / Los Angeles'),
  ('America/Halifax',    'Atlantic — Halifax'),
  ('America/St_Johns',   'Newfoundland — St. John\'s'),
  ('America/Anchorage',  'Alaska — Anchorage'),
  ('Pacific/Honolulu',   'Hawaii — Honolulu'),
];

class _CreateTeamScreenState extends ConsumerState<CreateTeamScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  String  _sport    = AppConfig.defaultSports.first; // updated to first Firestore sport in build
  String  _timezone = 'America/Toronto';
  int     _minPlayers = 1;
  int     _maxPlayers = 20;
  bool    _dropIn   = false;
  bool    _loading  = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final uid  = ref.read(currentUserProvider)!.uid;
    final ref2 = FirebaseFirestore.instance.collection('teams').doc();

    final team = Team(
      teamId:       ref2.id,
      name:         _nameCtrl.text.trim(),
      sport:        _sport,
      admins:       [uid],
      players:      [],
      minPlayers:   _minPlayers,
      maxPlayers:   _maxPlayers,
      dropInEnabled: _dropIn,
      createdAt:    DateTime.now(),
      timezone:     _timezone,
    );

    try {
      await ref.read(teamRepositoryProvider).createTeam(team, uid);
      unawaited(ref.read(analyticsServiceProvider).logTeamCreated(_sport));
      if (mounted) {
        // Ask the new admin how they participate before navigating away
        final participation = await _askParticipation(context);
        await ref.read(teamRepositoryProvider).setAdminRole(
          team.teamId, uid, participation,
        );
        if (mounted) {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${team.name} created! Share the Team ID: ${team.teamId}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create team: $e')),
        );
      }
    }
  }

  Future<AdminParticipation> _askParticipation(BuildContext context) async {
    final result = await showDialog<AdminParticipation>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ParticipationDialog(),
    );
    return result ?? AdminParticipation.player;
  }

  @override
  Widget build(BuildContext context) {
    // Keep _sport valid as Firestore list loads (may differ from AppConfig order).
    final sportNames = ref.watch(sportNamesProvider);
    if (!sportNames.contains(_sport) && sportNames.isNotEmpty) {
      Future.microtask(() { if (mounted) setState(() => _sport = sportNames.first); });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Create Team')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Team name ─────────────────────────────────────────
                    TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Team Name',
                        prefixIcon: Icon(Icons.group),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Team name is required.' : null,
                    ),
                    const SizedBox(height: 16),

                    // ── Sport ─────────────────────────────────────────────
                    DropdownButtonFormField<String>(
                      initialValue: _sport,
                      decoration: const InputDecoration(
                        labelText: 'Sport',
                        prefixIcon: Icon(Icons.sports),
                        border: OutlineInputBorder(),
                      ),
                      items: sportNames
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setState(() => _sport = v!),
                    ),
                    const SizedBox(height: 16),

                    // ── Timezone ──────────────────────────────────────────
                    DropdownButtonFormField<String>(
                      value: _timezone,
                      decoration: const InputDecoration(
                        labelText: 'Team Timezone',
                        prefixIcon: Icon(Icons.schedule),
                        border: OutlineInputBorder(),
                        helperText: 'Used for event reminder times',
                      ),
                      items: _kTimezones
                          .map((t) => DropdownMenuItem(
                                value: t.$1,
                                child: Text(t.$2, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _timezone = v!),
                    ),
                    const SizedBox(height: 24),

                    // ── Player limits ─────────────────────────────────────
                    Text('Player Limits',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _NumberField(
                            label: 'Minimum',
                            value: _minPlayers,
                            min: 1,
                            max: _maxPlayers,
                            onChanged: (v) => setState(() => _minPlayers = v),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _NumberField(
                            label: 'Maximum',
                            value: _maxPlayers,
                            min: _minPlayers,
                            max: 200,
                            onChanged: (v) => setState(() => _maxPlayers = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Drop-in ───────────────────────────────────────────
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable Drop-in Sessions'),
                      subtitle: const Text(
                          'Allow players to sign up for individual sessions without being on the roster.'),
                      value: _dropIn,
                      onChanged: (v) => setState(() => _dropIn = v),
                    ),
                    const SizedBox(height: 32),

                    // ── Create button ─────────────────────────────────────
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Create Team'),
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

// ── Admin participation dialog ─────────────────────────────────────────────────

class _ParticipationDialog extends StatefulWidget {
  const _ParticipationDialog();

  @override
  State<_ParticipationDialog> createState() => _ParticipationDialogState();
}

class _ParticipationDialogState extends State<_ParticipationDialog> {
  AdminParticipation _selected = AdminParticipation.player;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Your Role on This Team'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'This controls whether you appear in lineups and how you receive event reminders.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          ...AdminParticipation.values.map((p) => RadioListTile<AdminParticipation>(
            contentPadding: EdgeInsets.zero,
            title: Text(p.label),
            value: p,
            groupValue: _selected,
            onChanged: (v) => setState(() => _selected = v!),
          )),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final int value, min, max;
  final ValueChanged<int> onChanged;

  const _NumberField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text('$label\n$value',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: value < max ? () => onChanged(value + 1) : null,
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: value > min ? () => onChanged(value - 1) : null,
            ),
          ],
        ),
      ],
    );
  }
}
