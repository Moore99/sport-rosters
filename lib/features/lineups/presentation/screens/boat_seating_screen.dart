import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/export_service.dart';
import '../../../../core/services/weight_unit_provider.dart';
import '../../../../features/auth/data/user_repository.dart';
import '../../../../features/auth/domain/app_user.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/events/domain/event.dart';
import '../../../../features/events/presentation/providers/events_provider.dart';
import '../../../../features/teams/domain/team.dart';
import '../../../../features/teams/presentation/providers/teams_provider.dart';
import '../../data/lineup_repository.dart';
import '../../domain/lineup.dart';
import '../providers/lineup_provider.dart';

class BoatSeatingScreen extends ConsumerStatefulWidget {
  final String teamId;
  final String eventId;
  const BoatSeatingScreen({super.key, required this.teamId, required this.eventId});

  @override
  ConsumerState<BoatSeatingScreen> createState() => _BoatSeatingScreenState();
}

class _BoatSeatingScreenState extends ConsumerState<BoatSeatingScreen> {
  Map<String, String> _draft = {}; // positionKey → uid
  bool _initialized = false;
  bool _saving      = false;
  bool _balancing   = false;

  // ── Position key helpers ───────────────────────────────────────────────────

  // ── Row selection: even linear interpolation from row 1 → numRows ───────────
  // Distributes N active rows across the full boat length so gaps are spread
  // evenly — no clustering of empty rows in the middle or back.
  // e.g.  7 pairs, 10 rows → [1, 3, 4, 6, 7, 9, 10]
  //        4 pairs, 10 rows → [1, 4, 7, 10]
  static List<int> _activeRows(int numPairs, int numRows) {
    if (numPairs <= 0) return [];
    if (numPairs >= numRows) return List.generate(numRows, (i) => i + 1);
    if (numPairs == 1) return [1];
    final seen = <int>{};
    final rows = <int>[];
    for (int i = 0; i < numPairs; i++) {
      final r = (1.0 + i * (numRows - 1.0) / (numPairs - 1)).round();
      if (seen.add(r)) rows.add(r);
    }
    return rows;
  }

  static List<String> _positionKeys(BoatConfig cfg) {
    final keys = <String>[];
    for (int b = 1; b <= cfg.numBoats; b++) {
      if (cfg.hasDrummer) keys.add('Boat $b Drummer');
      for (int r = 1; r <= cfg.rowsPerBoat; r++) {
        keys.add('Boat $b Row $r Left');
        keys.add('Boat $b Row $r Right');
      }
      keys.add('Boat $b Steersperson');
    }
    return keys;
  }

  void _initDraft(Lineup? saved, BoatConfig cfg) {
    if (_initialized) return;
    _initialized = true;
    _draft = {
      for (final k in _positionKeys(cfg)) k: saved?.assignments[k] ?? '',
    };
  }

  // ── Balance algorithm ──────────────────────────────────────────────────────
  //
  // 1. Sort all available players by weight desc (default 70 kg if unknown).
  // 2. Snake-draft across boats so each boat gets a balanced mix.
  // 3. Within each boat, choose active rows by alternating front/back so both
  //    ends of the boat are occupied and any empty rows fall in the middle.
  //    e.g. 7 pairs in a 10-row boat → active rows [1,2,3,4,8,9,10].
  // 4. Assign heaviest pairs to front active rows first (front slightly heavier).
  // 5. For each pair, put the heavier paddler on the lighter side (L/R balance).
  // 6. Drummer and Steersperson are left unassigned (coach assigns manually).

  Future<void> _balance(List<String> availableUids, BoatConfig cfg) async {
    setState(() => _balancing = true);

    final userRepo = ref.read(userRepositoryProvider);
    final weightMap = <String, double>{};
    for (final uid in availableUids) {
      final user = await userRepo.getUser(uid);
      weightMap[uid] = user?.weightKg ?? 70.0;
    }

    final sorted = [...availableUids]
      ..sort((a, b) => (weightMap[b] ?? 70.0).compareTo(weightMap[a] ?? 70.0));

    // Snake draft across boats
    final boatPlayers = List.generate(cfg.numBoats, (_) => <String>[]);
    int dir = 1;
    for (int i = 0; i < sorted.length; i++) {
      final indexInRound = i % cfg.numBoats;
      final boatIdx = dir == 1 ? indexInRound : (cfg.numBoats - 1 - indexInRound);
      boatPlayers[boatIdx].add(sorted[i]);
      if (indexInRound == cfg.numBoats - 1) dir = -dir;
    }

    final result = {for (final k in _draft.keys) k: ''};

    for (int b = 0; b < cfg.numBoats; b++) {
      final boatNum = b + 1;
      final players = boatPlayers[b];

      // ── Row selection: evenly distributed via linear interpolation ───────
      final numFullRows = players.length ~/ 2;
      final activeRows  = _activeRows(numFullRows, cfg.rowsPerBoat);

      // ── Assign pairs: heaviest to front rows, lighter side gets heavier ───
      double leftTotal = 0, rightTotal = 0;

      for (int i = 0; i < activeRows.length; i++) {
        final r  = activeRows[i];
        final pi = i * 2;
        if (pi + 1 >= players.length) break;

        final pa = players[pi];
        final pb = players[pi + 1];
        final wa = weightMap[pa] ?? 70.0;
        final wb = weightMap[pb] ?? 70.0;
        final lKey = 'Boat $boatNum Row $r Left';
        final rKey = 'Boat $boatNum Row $r Right';

        if (leftTotal <= rightTotal) {
          result[lKey] = pa; leftTotal  += wa;
          result[rKey] = pb; rightTotal += wb;
        } else {
          result[rKey] = pa; rightTotal += wa;
          result[lKey] = pb; leftTotal  += wb;
        }
      }

      // ── Odd paddler: place in next available front row, lighter side ───────
      if (players.length.isOdd && players.isNotEmpty) {
        final last     = players.last;
        final usedRows = activeRows.toSet();
        // Find the lowest-numbered row not yet used
        int oddRow = 1;
        while (usedRows.contains(oddRow) && oddRow <= cfg.rowsPerBoat) {
          oddRow++;
        }
        if (oddRow <= cfg.rowsPerBoat) {
          final lKey = 'Boat $boatNum Row $oddRow Left';
          final rKey = 'Boat $boatNum Row $oddRow Right';
          if (leftTotal <= rightTotal) {
            result[lKey] = last;
          } else {
            result[rKey] = last;
          }
        }
      }
    }

    setState(() { _draft = result; _balancing = false; });

    if (mounted) {
      final filled = result.values.where((v) => v.isNotEmpty).length;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Balanced: $filled paddlers placed. '
            'Assign Drummer and Steersperson manually.'),
      ));
    }
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(lineupRepositoryProvider).saveLineup(Lineup(
      lineupId:      widget.eventId,
      eventId:       widget.eventId,
      teamId:        widget.teamId,
      assignments:   Map.from(_draft),
      autoGenerated: false,
      createdAt:     DateTime.now(),
    ));
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Boat seating saved.')));
    }
  }

  void _clearAll() => setState(() {
    _draft = {for (final k in _draft.keys) k: ''};
  });

  Future<void> _exportPdf(
      BuildContext context, WidgetRef ref, Team team,
      Event event, BoatConfig cfg) async {
    final userRepo = ref.read(userRepositoryProvider);
    final named = <String, String>{};
    for (final entry in _draft.entries) {
      if (entry.value.isNotEmpty) {
        final user = await userRepo.getUser(entry.value);
        named[entry.key] =
            user?.name.isNotEmpty == true ? user!.name : entry.value;
      }
    }
    await ExportService.shareBoatSeatingPdf(
      teamName:    team.name,
      eventLabel:  event.type.label,
      eventDate:   event.date,
      assignments: named,
      numBoats:    cfg.numBoats,
      rowsPerBoat: cfg.rowsPerBoat,
      hasDrummer:  cfg.hasDrummer,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final teamAsync   = ref.watch(teamProvider(widget.teamId));
    final eventAsync  = ref.watch(eventProvider(widget.eventId));
    final lineupAsync = ref.watch(lineupProvider(widget.eventId));
    final uid         = ref.watch(currentUserProvider)?.uid ?? '';

    return teamAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:   (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (team) {
        if (team == null) return const Scaffold(body: Center(child: Text('Team not found.')));
        final isAdmin = team.isAdmin(uid);

        return eventAsync.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error:   (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
          data: (event) {
            if (event == null) return const Scaffold(body: Center(child: Text('Event not found.')));
            final cfg = event.boatConfig ?? BoatConfig.defaults;

            return lineupAsync.when(
              loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
              error:   (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
              data: (saved) {
                _initDraft(saved, cfg);

                final availableUids = ref
                    .watch(eventAvailabilityProvider((widget.eventId, widget.teamId)))
                    .valueOrNull
                    ?.where((a) =>
                        a.response.name == 'yes' || a.response.name == 'maybe')
                    .map((a) => a.userId)
                    .where((u) => team.players.contains(u) || team.admins.contains(u))
                    .toList() ?? [];

                return Scaffold(
                  appBar: AppBar(
                    title: const Text('Boat Seating'),
                    actions: [
                      if (isAdmin) ...[
                        TextButton(onPressed: _clearAll, child: const Text('Clear')),
                        _balancing
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2)))
                            : IconButton(
                                icon: const Icon(Icons.balance),
                                tooltip: 'Balance by weight',
                                onPressed: () => _balance(availableUids, cfg),
                              ),
                      ],
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        tooltip: 'Export PDF',
                        onPressed: () =>
                            _exportPdf(context, ref, team, event, cfg),
                      ),
                    ],
                  ),
                  body: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    children: [
                      for (int b = 1; b <= cfg.numBoats; b++)
                        _BoatCard(
                          boatNum:       b,
                          cfg:           cfg,
                          team:          team,
                          draft:         _draft,
                          isAdmin:       isAdmin,
                          availableUids: availableUids,
                          onAssign: isAdmin
                              ? (key, assignedUid) => setState(() {
                                  // Auto-clear old position when moving a player
                                  if (assignedUid.isNotEmpty) {
                                    _draft.updateAll(
                                        (k, v) => v == assignedUid && k != key ? '' : v);
                                  }
                                  _draft[key] = assignedUid;
                                })
                              : null,
                        ),
                    ],
                  ),
                  bottomNavigationBar: isAdmin
                      ? SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: FilledButton(
                              onPressed: _saving ? null : _save,
                              child: _saving
                                  ? const SizedBox(
                                      height: 20, width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2))
                                  : Text(
                                      '${_draft.values.where((v) => v.isNotEmpty).length}'
                                      '/${_draft.length} assigned — Save'),
                            ),
                          ),
                        )
                      : null,
                );
              },
            );
          },
        );
      },
    );
  }
}

// ── Boat card ──────────────────────────────────────────────────────────────────

class _BoatCard extends ConsumerWidget {
  final int  boatNum;
  final BoatConfig cfg;
  final Team team;
  final Map<String, String> draft;
  final bool isAdmin;
  final List<String> availableUids; // yes/maybe RSVPs for picker filtering
  final void Function(String key, String uid)? onAssign;

  const _BoatCard({
    required this.boatNum,
    required this.cfg,
    required this.team,
    required this.draft,
    required this.isAdmin,
    required this.availableUids,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reverse map: uid → positionKey (for picker "already placed" section)
    final uidToPos = <String, String>{
      for (final e in draft.entries) if (e.value.isNotEmpty) e.value: e.key,
    };

    // Compute L/R and front/back weight totals for this boat
    double leftKg = 0, rightKg = 0, frontKg = 0, backKg = 0;
    final mid = cfg.rowsPerBoat ~/ 2;
    for (int r = 1; r <= cfg.rowsPerBoat; r++) {
      final lw = ref.watch(_weightProvider(draft['Boat $boatNum Row $r Left']  ?? '')).valueOrNull ?? 0.0;
      final rw = ref.watch(_weightProvider(draft['Boat $boatNum Row $r Right'] ?? '')).valueOrNull ?? 0.0;
      leftKg  += lw;
      rightKg += rw;
      if (r <= mid) { frontKg += lw + rw; } else { backKg += lw + rw; }
    }
    final hasWeights  = leftKg > 0 || rightKg > 0;
    final label       = cfg.numBoats > 1 ? 'Boat $boatNum' : 'Boat';
    final weightUnit  = ref.watch(weightUnitProvider);
    final leftDisplay  = toDisplayWeight(leftKg,  weightUnit);
    final rightDisplay = toDisplayWeight(rightKg, weightUnit);
    final unitLabel    = weightUnit.name;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [

            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(children: [
                Text(label, style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (hasWeights)
                  Text(
                    'L: ${leftDisplay.toStringAsFixed(1)} $unitLabel  |  R: ${rightDisplay.toStringAsFixed(1)} $unitLabel',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _balanceColor(leftKg, rightKg, context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ]),
            ),
            const Divider(height: 1),

            // ── Drummer ───────────────────────────────────────────────────
            if (cfg.hasDrummer)
              _FullWidthSeatTile(
                posKey:        'Boat $boatNum Drummer',
                roleLabel:     'Drummer',
                uid:           draft['Boat $boatNum Drummer'] ?? '',
                team:          team,
                isAdmin:       isAdmin,
                uidToPos:      uidToPos,
                availableUids: availableUids,
                onAssign:      onAssign,
              ),

            // ── Bow label ─────────────────────────────────────────────────
            _directionLabel('← Bow (front)', context),

            // ── Column headers ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                Expanded(child: Center(
                    child: Text('Left', style: Theme.of(context).textTheme.labelSmall))),
                const SizedBox(width: 1),
                Expanded(child: Center(
                    child: Text('Right', style: Theme.of(context).textTheme.labelSmall))),
              ]),
            ),

            // ── Paddler rows ──────────────────────────────────────────────
            for (int r = 1; r <= cfg.rowsPerBoat; r++) ...[
              if (r > 1) const Divider(height: 1, indent: 8, endIndent: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: IntrinsicHeight(
                  child: Row(children: [
                    Expanded(child: _SeatTile(
                      posKey:        'Boat $boatNum Row $r Left',
                      rowLabel:      'Row $r',
                      uid:           draft['Boat $boatNum Row $r Left'] ?? '',
                      team:          team,
                      isAdmin:       isAdmin,
                      uidToPos:      uidToPos,
                      availableUids: availableUids,
                      onAssign:      onAssign,
                    )),
                    VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
                    Expanded(child: _SeatTile(
                      posKey:        'Boat $boatNum Row $r Right',
                      rowLabel:      'Row $r',
                      uid:           draft['Boat $boatNum Row $r Right'] ?? '',
                      team:          team,
                      isAdmin:       isAdmin,
                      uidToPos:      uidToPos,
                      availableUids: availableUids,
                      onAssign:      onAssign,
                    )),
                  ]),
                ),
              ),
            ],

            // ── Stern label ───────────────────────────────────────────────
            _directionLabel('← Stern (back)', context),

            // ── Steersperson ──────────────────────────────────────────────
            _FullWidthSeatTile(
              posKey:        'Boat $boatNum Steersperson',
              roleLabel:     'Steersperson',
              uid:           draft['Boat $boatNum Steersperson'] ?? '',
              team:          team,
              isAdmin:       isAdmin,
              uidToPos:      uidToPos,
              availableUids: availableUids,
              onAssign:      onAssign,
            ),

            // ── Weight summary footer ──────────────────────────────────────
            if (hasWeights) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Weight balance',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline)),
                    const SizedBox(height: 4),
                    Row(children: [
                      _weightChip(
                        label: 'Front (rows 1–$mid)',
                        kg: frontKg,
                        unit: weightUnit,
                        color: _frontBackColor(frontKg, backKg, context),
                        context: context,
                      ),
                      const SizedBox(width: 12),
                      _weightChip(
                        label: 'Back (rows ${mid + 1}–${cfg.rowsPerBoat})',
                        kg: backKg,
                        unit: weightUnit,
                        color: _frontBackColor(backKg, frontKg, context),
                        context: context,
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      _weightChip(
                        label: 'Left',
                        kg: leftKg,
                        unit: weightUnit,
                        color: _balanceColor(leftKg, rightKg, context),
                        context: context,
                      ),
                      const SizedBox(width: 12),
                      _weightChip(
                        label: 'Right',
                        kg: rightKg,
                        unit: weightUnit,
                        color: _balanceColor(rightKg, leftKg, context),
                        context: context,
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _weightChip({
    required String label,
    required double kg,
    required WeightUnit unit,
    required Color color,
    required BuildContext context,
  }) {
    final display = toDisplayWeight(kg, unit);
    final unitStr = unit.name;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
            Text('${display.toStringAsFixed(1)} $unitStr',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  // Front-heavy is good (green). Back-heavy is bad (red).
  Color _frontBackColor(double thisSide, double otherSide, BuildContext context) {
    if (thisSide + otherSide == 0) return Theme.of(context).colorScheme.outline;
    final diff = thisSide - otherSide;
    if (diff >= 0) return Colors.green.shade600;       // this side >= other: good
    final absDiff = diff.abs();
    if (absDiff < 13.6) return Colors.orange.shade600; // < 30 lbs off
    return Colors.red.shade400;
  }

  Color _balanceColor(double l, double r, BuildContext context) {
    if (l + r == 0) return Theme.of(context).colorScheme.outline;
    final pct = (l - r).abs() / (l + r);
    if (pct < 0.03) return Colors.green.shade600;
    if (pct < 0.07) return Colors.orange.shade600;
    return Colors.red.shade400;
  }
}

Widget _directionLabel(String text, BuildContext context) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
  child: Row(children: [
    const Expanded(child: Divider()),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.outline)),
    ),
    const Expanded(child: Divider()),
  ]),
);

// ── Paddler seat tile (side-by-side) ──────────────────────────────────────────

class _SeatTile extends ConsumerWidget {
  final String posKey, rowLabel, uid;
  final Team   team;
  final bool   isAdmin;
  final Map<String, String> uidToPos;
  final List<String> availableUids;
  final void Function(String key, String uid)? onAssign;

  const _SeatTile({
    required this.posKey,
    required this.rowLabel,
    required this.uid,
    required this.team,
    required this.isAdmin,
    required this.uidToPos,
    required this.availableUids,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = uid.isNotEmpty ? ref.watch(_profileProvider(uid)) : null;
    final name       = profileAsync?.valueOrNull?.name;
    final weightKg   = profileAsync?.valueOrNull?.weightKg;
    final weightUnit = ref.watch(weightUnitProvider);
    final assigned   = uid.isNotEmpty;

    return InkWell(
      onTap: isAdmin ? () => _showPicker(context, ref) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rowLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 2),
            Text(
              assigned ? (name ?? uid) : '—',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: assigned ? null : Theme.of(context).colorScheme.outline,
                fontWeight: assigned ? FontWeight.w500 : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (weightKg != null)
              Text(formatWeight(weightKg, weightUnit),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary)),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PlayerPickerSheet(
        team:          team,
        posKey:        posKey,
        currentUid:    uid,
        uidToPos:      uidToPos,
        availableUids: availableUids,
        onSelect:      (u) => onAssign!(posKey, u),
      ),
    );
  }
}

// ── Full-width seat tile (Drummer / Steersperson) ─────────────────────────────

class _FullWidthSeatTile extends ConsumerWidget {
  final String posKey, roleLabel, uid;
  final Team   team;
  final bool   isAdmin;
  final Map<String, String> uidToPos;
  final List<String> availableUids;
  final void Function(String key, String uid)? onAssign;

  const _FullWidthSeatTile({
    required this.posKey,
    required this.roleLabel,
    required this.uid,
    required this.team,
    required this.isAdmin,
    required this.uidToPos,
    required this.availableUids,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = uid.isNotEmpty ? ref.watch(_profileProvider(uid)) : null;
    final name       = profileAsync?.valueOrNull?.name;
    final weightKg   = profileAsync?.valueOrNull?.weightKg;
    final weightUnit = ref.watch(weightUnitProvider);
    final assigned   = uid.isNotEmpty;

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        child: Text(roleLabel[0],
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSecondaryContainer)),
      ),
      title: Text(roleLabel,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline)),
      subtitle: Row(children: [
        Text(
          assigned ? (name ?? uid) : 'Unassigned',
          style: TextStyle(
            color: assigned ? null : Theme.of(context).colorScheme.outline,
          ),
        ),
        if (weightKg != null) ...[
          const SizedBox(width: 8),
          Text(formatWeight(weightKg, weightUnit),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary)),
        ],
      ]),
      trailing: isAdmin
          ? IconButton(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Assign',
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => _PlayerPickerSheet(
                  team:          team,
                  posKey:        posKey,
                  currentUid:    uid,
                  uidToPos:      uidToPos,
                  availableUids: availableUids,
                  onSelect:      (u) => onAssign!(posKey, u),
                ),
              ),
            )
          : null,
    );
  }
}

// ── Player picker bottom sheet ─────────────────────────────────────────────────

class _PlayerPickerSheet extends ConsumerWidget {
  final Team   team;
  final String posKey, currentUid;
  final Map<String, String> uidToPos;    // uid → posKey of their current seat
  final List<String>        availableUids; // yes/maybe RSVPs only
  final ValueChanged<String> onSelect;

  const _PlayerPickerSheet({
    required this.team,
    required this.posKey,
    required this.currentUid,
    required this.uidToPos,
    required this.availableUids,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only show players who said yes/maybe (plus whoever is already in this seat)
    final yesSet = availableUids.toSet();
    final eligible = [...team.admins, ...team.players]
        .where((u) => yesSet.contains(u) || u == currentUid)
        .toList();

    // Split: available = not placed elsewhere; placed = in a *different* seat
    final available = eligible
        .where((u) => !uidToPos.containsKey(u) || u == currentUid)
        .toList();
    final placed = eligible
        .where((u) => uidToPos.containsKey(u) && u != currentUid)
        .toList();

    Widget memberTile(String uid, {String? placedAt}) {
      final profileAsync = ref.watch(_profileProvider(uid));
      final profile    = profileAsync.valueOrNull;
      final name       = profile?.name.isNotEmpty == true ? profile!.name : uid;
      final weightKg   = profile?.weightKg;
      final weightUnit = ref.watch(weightUnitProvider);
      final subtitle   = placedAt != null
          ? '${placedAt.replaceFirst(RegExp(r'^Boat \d+ '), '')}${weightKg != null ? ' · ${formatWeight(weightKg, weightUnit)}' : ''}'
          : weightKg != null ? formatWeight(weightKg, weightUnit) : null;
      return ListTile(
        leading: CircleAvatar(
          backgroundColor: placedAt != null
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : null,
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        title:    Text(name,
            style: TextStyle(
                color: placedAt != null
                    ? Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
                    : null)),
        subtitle: subtitle != null ? Text(subtitle) : null,
        selected: uid == currentUid,
        onTap: () { onSelect(uid); Navigator.of(context).pop(); },
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize:     0.9,
      minChildSize:     0.4,
      expand: false,
      builder: (_, sc) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Assign to $posKey',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              controller: sc,
              children: [
                // Unassign option
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person_off)),
                  title: const Text('Unassigned'),
                  selected: currentUid.isEmpty,
                  onTap: () { onSelect(''); Navigator.of(context).pop(); },
                ),
                const Divider(height: 1),

                // Available section
                if (available.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text('Available (${available.length})',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary)),
                  ),
                  for (final uid in available) memberTile(uid),
                ],

                // Already placed section
                if (placed.isNotEmpty) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text('Already placed (${placed.length})',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline)),
                  ),
                  for (final uid in placed) memberTile(uid, placedAt: uidToPos[uid]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Providers ──────────────────────────────────────────────────────────────────

/// Full user profile (name + weight) — cached per uid.
final _profileProvider = FutureProvider.family<AppUser?, String>((ref, uid) async {
  if (uid.isEmpty) return null;
  return ref.read(userRepositoryProvider).getUser(uid);
});

/// Weight only — used for L/R totals in _BoatCard.
final _weightProvider = FutureProvider.family<double?, String>((ref, uid) async {
  if (uid.isEmpty) return null;
  return ref.read(userRepositoryProvider).getUser(uid).then((u) => u?.weightKg);
});
