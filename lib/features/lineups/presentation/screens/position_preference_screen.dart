import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/services/weight_unit_provider.dart';
import '../../../../features/auth/data/user_repository.dart';
import '../../../../features/auth/domain/app_user.dart';
import '../../../lineups/data/player_preference_repository.dart';
import '../../../lineups/domain/player_preference.dart';
import '../providers/player_preference_provider.dart';

class PositionPreferenceScreen extends ConsumerStatefulWidget {
  final String teamId;
  final String userId;
  final String sport;
  final String playerName;

  const PositionPreferenceScreen({
    super.key,
    required this.teamId,
    required this.userId,
    required this.sport,
    required this.playerName,
  });

  @override
  ConsumerState<PositionPreferenceScreen> createState() =>
      _PositionPreferenceScreenState();
}

class _PositionPreferenceScreenState
    extends ConsumerState<PositionPreferenceScreen> {
  late Set<String> _selected;
  bool _initialized    = false;
  bool _saving         = false;
  // Dragon Boating only
  final _weightCtrl    = TextEditingController();
  bool _weightInitialized = false;

  void _initFrom(PlayerPreference? pref) {
    if (_initialized) return;
    _initialized = true;
    _selected = Set<String>.from(pref?.preferredPositions ?? []);
  }

  void _initWeight(double? weightKg) {
    if (_weightInitialized) return;
    _weightInitialized = true;
    if (weightKg != null) {
      final unit = ref.read(weightUnitProvider);
      _weightCtrl.text = toDisplayWeight(weightKg, unit).toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
  }

  bool get _anySelected => _selected.contains('Any');

  void _toggleAny() {
    setState(() {
      if (_anySelected) {
        _selected.remove('Any');
      } else {
        _selected = {'Any'};
      }
    });
  }

  void _toggle(String item) {
    setState(() {
      if (_selected.contains(item)) {
        _selected.remove(item);
      } else {
        _selected.discard('Any'); // selecting specific items removes "Any"
        _selected.add(item);
      }
    });
  }

  bool _isEffectivelySelected(String position) {
    if (_anySelected) return true;
    if (_selected.contains(position)) return true;
    final cats = AppConfig.categoriesForSport(widget.sport);
    return cats.entries.any(
        (e) => _selected.contains(e.key) && e.value.contains(position));
  }

  Future<void> _save() async {
    // Validate weight if Dragon Boating
    double? weightKg;
    if (widget.sport == 'Dragon Boating') {
      final raw = _weightCtrl.text.trim();
      if (raw.isNotEmpty) {
        final parsed = double.tryParse(raw);
        if (parsed == null || parsed <= 0) {
          final unit = ref.read(weightUnitProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Enter a valid weight in ${unit.name}, or leave blank.')),
          );
          return;
        }
        weightKg = toStorageKg(parsed, ref.read(weightUnitProvider));
      }
    }

    setState(() => _saving = true);
    final pref = PlayerPreference(
      userId:             widget.userId,
      teamId:             widget.teamId,
      preferredPositions: _selected.toList(),
      updatedAt:          DateTime.now(),
    );
    await ref.read(playerPreferenceRepositoryProvider).savePreference(pref);
    if (weightKg != null) {
      await ref.read(userRepositoryProvider).updateProfile(
        widget.userId, weightKg: weightKg,
      );
    }
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferences saved.')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefAsync = ref.watch(
      myPreferenceProvider((teamId: widget.teamId, userId: widget.userId)),
    );
    final userAsync = widget.sport == 'Dragon Boating'
        ? ref.watch(_userProfileProvider(widget.userId))
        : null;

    return prefAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (pref) {
        _initFrom(pref);
        if (widget.sport == 'Dragon Boating') {
          _initWeight(userAsync?.valueOrNull?.weightKg);
        }
        final positions  = AppConfig.positionsForSport(widget.sport);
        final categories = AppConfig.categoriesForSport(widget.sport);

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.playerName == ''
                ? 'Position Preferences'
                : '${widget.playerName} — Positions'),
            actions: [
              TextButton(
                onPressed: () => setState(() {
                  _selected.clear();
                  _initialized = false;
                  _initFrom(null);
                }),
                child: const Text('Clear'),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(widget.sport,
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              const Text(
                'Select the positions you\'re willing to play. '
                'The auto-lineup generator will use these preferences '
                'when building lineups.',
              ),
              const SizedBox(height: 20),

              // ── Weight (Dragon Boating only) ───────────────────────────────
              if (widget.sport == 'Dragon Boating') ...[
                _SectionHeader('Your Weight'),
                Builder(builder: (context) {
                  final unit = ref.watch(weightUnitProvider);
                  return TextField(
                    controller: _weightCtrl,
                    decoration: InputDecoration(
                      labelText: 'Weight (${unit.name})',
                      hintText:  'Used for boat balance — optional',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.monitor_weight_outlined),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  );
                }),
                const SizedBox(height: 20),
              ],

              // ── Any position ──────────────────────────────────────────────
              _SectionHeader('Wildcard'),
              Wrap(spacing: 8, runSpacing: 4, children: [
                FilterChip(
                  label: const Text('Any position'),
                  selected: _anySelected,
                  onSelected: (_) => _toggleAny(),
                ),
              ]),
              const SizedBox(height: 16),

              // ── Categories ────────────────────────────────────────────────
              if (categories.isNotEmpty) ...[
                _SectionHeader('Position Groups'),
                Wrap(
                  spacing:    8,
                  runSpacing: 4,
                  children: categories.keys.map((cat) {
                    return FilterChip(
                      label:    Text(cat),
                      selected: !_anySelected && _selected.contains(cat),
                      onSelected: _anySelected ? null : (_) => _toggle(cat),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              // ── Individual positions ───────────────────────────────────────
              _SectionHeader('Specific Positions'),
              Wrap(
                spacing:    8,
                runSpacing: 4,
                children: positions.map((pos) {
                  final effectivelyOn = _isEffectivelySelected(pos);
                  final directlySelected = _selected.contains(pos);
                  return FilterChip(
                    label: Text(pos),
                    selected: effectivelyOn,
                    // Greyed out if covered by a category or "Any" (not directly toggled)
                    onSelected: (_anySelected || (effectivelyOn && !directlySelected))
                        ? null
                        : (_) => _toggle(pos),
                  );
                }).toList(),
              ),
              const SizedBox(height: 80),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_selected.isEmpty
                        ? 'Save (no preference — any position)'
                        : 'Save ${_selected.length} preference${_selected.length == 1 ? '' : 's'}'),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

// Extension to avoid null checks on Set
extension on Set<String> {
  void discard(String value) => remove(value);
}

// ── Providers ──────────────────────────────────────────────────────────────────

final _userProfileProvider =
    FutureProvider.family<AppUser?, String>((ref, uid) async {
  return ref.read(userRepositoryProvider).getUser(uid);
});
