import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_config.dart';
import '../../../../features/teams/presentation/providers/teams_provider.dart';
import '../../data/event_repository.dart';
import '../../domain/event.dart';

class EditEventScreen extends ConsumerStatefulWidget {
  final Event event;
  const EditEventScreen({super.key, required this.event});

  @override
  ConsumerState<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends ConsumerState<EditEventScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _locationCtrl = TextEditingController();

  late EventType _type;
  late DateTime  _date;
  late TimeOfDay _time;
  late int       _minPlayers;
  late int       _maxPlayers;
  late bool      _allowSignups;
  DateTime?      _rsvpDeadline;
  bool           _loading = false;

  // Sub-teams
  late int _numSubTeams;

  // Dragon Boating
  late int  _numBoats;
  late int  _seatsPerBoat;
  late bool _hasDrummer;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _type         = e.type;
    _date         = e.date;
    _time         = TimeOfDay.fromDateTime(e.date);
    _minPlayers   = e.minPlayers;
    _maxPlayers   = e.maxPlayers;
    _allowSignups = e.allowSignups;
    _rsvpDeadline = e.rsvpDeadline;
    _locationCtrl.text = e.location;

    _numSubTeams  = e.numSubTeams;

    final cfg     = e.boatConfig ?? BoatConfig.defaults;
    _numBoats     = cfg.numBoats;
    _seatsPerBoat = cfg.seatsPerBoat;
    _hasDrummer   = cfg.hasDrummer;
  }

  @override
  void dispose() { _locationCtrl.dispose(); super.dispose(); }

  DateTime get _eventDateTime => DateTime(
    _date.year, _date.month, _date.day, _time.hour, _time.minute,
  );

  Widget _pickerMediaQuery(BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0)),
        child: child!,
      );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context:          context,
      initialDate:      _date,
      firstDate:        DateTime(2020),
      lastDate:         DateTime.now().add(const Duration(days: 365 * 2)),
      initialEntryMode: DatePickerEntryMode.input,
      builder:          _pickerMediaQuery,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context:     context,
      initialTime: _time,
      builder:     _pickerMediaQuery,
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    if (_locationCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location is required.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final sport = ref.read(teamProvider(widget.event.teamId)).valueOrNull?.sport ?? '';
    final updated = Event(
      eventId:      widget.event.eventId,
      teamId:       widget.event.teamId,
      type:         _type,
      date:         _eventDateTime,
      location:     _locationCtrl.text.trim(),
      minPlayers:   _minPlayers,
      maxPlayers:   _maxPlayers,
      allowSignups: _allowSignups,
      rsvpDeadline: _rsvpDeadline,
      boatConfig:   sport == 'Dragon Boating'
          ? BoatConfig(
              numBoats:     _numBoats,
              seatsPerBoat: _seatsPerBoat,
              hasDrummer:   _hasDrummer)
          : null,
      numSubTeams:  sport == 'Dragon Boating' ? 1 : _numSubTeams,
      createdAt:    widget.event.createdAt,
    );

    try {
      await ref.read(eventRepositoryProvider).updateEvent(updated);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save changes: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt   = DateFormat('EEE, MMM d, yyyy');
    final timeFmt   = DateFormat('h:mm a');
    final teamAsync = ref.watch(teamProvider(widget.event.teamId));
    final sport     = teamAsync.valueOrNull?.sport ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Event')),
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

                    // ── Event type ────────────────────────────────────────
                    Text('Event Type',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SegmentedButton<EventType>(
                      segments: EventType.values.map((t) =>
                        ButtonSegment(value: t, label: Text(t.label))).toList(),
                      selected: {_type},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) =>
                          setState(() => _type = s.first),
                    ),
                    const SizedBox(height: 20),

                    // ── Date & Time ───────────────────────────────────────
                    Text('Date & Time',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon:  const Icon(Icons.calendar_today),
                            label: Text(dateFmt.format(_date)),
                            onPressed: _pickDate,
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          icon:  const Icon(Icons.access_time),
                          label: Text(timeFmt.format(
                              DateTime(0, 0, 0, _time.hour, _time.minute))),
                          onPressed: _pickTime,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Location ──────────────────────────────────────────
                    GooglePlaceAutoCompleteTextField(
                      textEditingController: _locationCtrl,
                      googleAPIKey: AppConfig.googlePlacesApiKey,
                      inputDecoration: const InputDecoration(
                        labelText: 'Location',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(),
                        hintText: 'e.g. Maple Rink, Field 3',
                      ),
                      debounceTime: 800,
                      isLatLngRequired: false,
                      getPlaceDetailWithLatLng: (_) {},
                      itemClick: (prediction) {
                        _locationCtrl.text = prediction.description ?? '';
                        _locationCtrl.selection = TextSelection.fromPosition(
                          TextPosition(offset: _locationCtrl.text.length),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // ── Player counts ─────────────────────────────────────
                    Text('Player Limits',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _CounterField(
                          label: 'Min', value: _minPlayers,
                          min: 1, max: _maxPlayers,
                          onChanged: (v) =>
                              setState(() => _minPlayers = v),
                        )),
                        const SizedBox(width: 16),
                        Expanded(child: _CounterField(
                          label: 'Max', value: _maxPlayers,
                          min: _minPlayers, max: 200,
                          onChanged: (v) =>
                              setState(() => _maxPlayers = v),
                        )),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Allow signups ─────────────────────────────────────
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Allow Player RSVP'),
                      subtitle:
                          const Text('Players can mark yes / no / maybe.'),
                      value: _allowSignups,
                      onChanged: (v) => setState(() {
                        _allowSignups = v;
                        if (!v) _rsvpDeadline = null;
                      }),
                    ),
                    if (_allowSignups) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.timer_outlined),
                        title: Text(_rsvpDeadline == null
                            ? 'RSVP Deadline — none'
                            : 'RSVP by ${DateFormat('EEE, MMM d h:mm a').format(_rsvpDeadline!)}'),
                        subtitle: const Text(
                            'Optional — disables RSVP after this time.'),
                        trailing: _rsvpDeadline != null
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () =>
                                    setState(() => _rsvpDeadline = null),
                              )
                            : null,
                        onTap: () async {
                          final d = await showDatePicker(
                            context:          context,
                            initialDate:      _date,
                            firstDate:        DateTime.now(),
                            lastDate:         _date,
                            initialEntryMode: DatePickerEntryMode.input,
                            builder:          _pickerMediaQuery,
                          );
                          if (d == null || !context.mounted) return;
                          final t = await showTimePicker(
                            context:     context,
                            initialTime: TimeOfDay.fromDateTime(_date),
                            builder:     _pickerMediaQuery,
                          );
                          if (t == null) return;
                          setState(() => _rsvpDeadline = DateTime(
                              d.year, d.month, d.day, t.hour, t.minute));
                        },
                      ),
                    ],
                    const SizedBox(height: 16),

                    // ── Boat Configuration (Dragon Boating only) ──────────
                    if (sport == 'Dragon Boating') ...[
                      Text('Boat Configuration',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _CounterField(
                            label: 'Boats', value: _numBoats, min: 1, max: 4,
                            onChanged: (v) =>
                                setState(() => _numBoats = v),
                          )),
                          const SizedBox(width: 16),
                          Expanded(child: _CounterField(
                            label: 'Seats/boat', value: _seatsPerBoat,
                            min: 8, max: 22, step: 2,
                            onChanged: (v) =>
                                setState(() => _seatsPerBoat = v),
                          )),
                        ],
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Drummer'),
                        subtitle:
                            const Text('Each boat has a drummer at the front.'),
                        value: _hasDrummer,
                        onChanged: (v) =>
                            setState(() => _hasDrummer = v),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Sub-teams (non-Dragon Boating sports) ────────────
                    if (sport != 'Dragon Boating') ...[
                      Text('Sub-teams', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                        'Split available players into balanced teams '
                        '(e.g. 2 teams for a drop-in scrimmage).',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      _CounterField(
                        label: 'Teams', value: _numSubTeams, min: 1, max: 6,
                        onChanged: (v) => setState(() => _numSubTeams = v),
                      ),
                      const SizedBox(height: 16),
                    ],

                    const SizedBox(height: 16),

                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Save Changes'),
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

// ── Counter field (shared with create screen) ─────────────────────────────────

class _CounterField extends StatelessWidget {
  final String label;
  final int value, min, max;
  final int step;
  final ValueChanged<int> onChanged;
  const _CounterField({
    required this.label, required this.value,
    required this.min,   required this.max,
    this.step = 1,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon:    const Icon(Icons.remove_circle_outline),
          tooltip: 'Decrease $label',
          onPressed: value > min ? () => onChanged(value - step) : null,
        ),
        Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text('$value', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        IconButton(
          icon:    const Icon(Icons.add_circle_outline),
          tooltip: 'Increase $label',
          onPressed: value < max ? () => onChanged(value + step) : null,
        ),
      ],
    );
  }
}
