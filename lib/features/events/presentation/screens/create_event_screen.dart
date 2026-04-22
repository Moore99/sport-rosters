import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/providers.dart';
import '../../../../core/services/analytics_service.dart';
import '../../data/event_repository.dart';
import '../../domain/event.dart';

enum _Recurrence { none, weekly, biweekly }

class CreateEventScreen extends ConsumerStatefulWidget {
  final String teamId;
  final Event? copyFrom;
  const CreateEventScreen({super.key, required this.teamId, this.copyFrom});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _locationCtrl;
  late final TextEditingController _notesCtrl;

  late EventType _type;
  DateTime  _date        = DateTime.now().add(const Duration(days: 1));
  late TimeOfDay _time;
  late int  _minPlayers;
  late int  _maxPlayers;
  late bool _allowSignups;
  DateTime?     _rsvpDeadline;
  bool          _loading       = false;

  // Recurrence
  _Recurrence   _recurrence        = _Recurrence.none;
  DateTime?     _recurrenceEndDate;

  // Sub-teams (non-Dragon Boating sports)
  late int _numSubTeams;

  // Dragon Boating boat config
  late int  _numBoats;
  late int  _seatsPerBoat;
  late bool _hasDrummer;
  bool _loadingConfig = false;

  @override
  void initState() {
    super.initState();
    final src = widget.copyFrom;
    if (src != null) {
      _locationCtrl = TextEditingController(text: src.location);
      _notesCtrl    = TextEditingController(text: src.notes ?? '');
      _type         = src.type;
      _date         = src.date;
      _time         = TimeOfDay.fromDateTime(src.date);
      _minPlayers   = src.minPlayers;
      _maxPlayers   = src.maxPlayers;
      _allowSignups = src.allowSignups;
      _numSubTeams  = src.numSubTeams;
      _numBoats     = src.boatConfig?.numBoats    ?? 1;
      _seatsPerBoat = src.boatConfig?.seatsPerBoat ?? 20;
      _hasDrummer   = src.boatConfig?.hasDrummer   ?? true;
    } else {
      _locationCtrl = TextEditingController();
      _notesCtrl    = TextEditingController();
      _type         = EventType.practice;
      _time         = const TimeOfDay(hour: 18, minute: 0);
      _minPlayers   = 1;
      _maxPlayers   = 20;
      _allowSignups = true;
      _numSubTeams  = 1;
      _numBoats     = 1;
      _seatsPerBoat = 20;
      _hasDrummer   = true;
    }
  }

  @override
  void dispose() { _locationCtrl.dispose(); _notesCtrl.dispose(); super.dispose(); }

  DateTime get _eventDateTime => DateTime(
    _date.year, _date.month, _date.day, _time.hour, _time.minute,
  );

  // Caps text scale at 1.0x so date/time pickers don't overflow on
  // small viewports (e.g. Samsung Flip half-screen / flex mode).
  Widget _pickerMediaQuery(BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0)),
        child: child!,
      );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context:          context,
      initialDate:      _date,
      firstDate:        DateTime.now(),
      lastDate:         DateTime.now().add(const Duration(days: 365 * 2)),
      initialEntryMode: DatePickerEntryMode.input,
      builder:          _pickerMediaQuery,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context:      context,
      initialTime:  _time,
      builder:      _pickerMediaQuery,
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
    if (_recurrence != _Recurrence.none && _recurrenceEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a repeat end date.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final sport = ref.read(teamProvider(widget.teamId)).valueOrNull?.sport ?? '';
    final location  = _locationCtrl.text.trim();
    final notes     = _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();
    final boatCfg   = sport == 'Dragon Boating'
        ? BoatConfig(numBoats: _numBoats, seatsPerBoat: _seatsPerBoat, hasDrummer: _hasDrummer)
        : null;
    final subTeams  = sport == 'Dragon Boating' ? 1 : _numSubTeams;
    final now       = DateTime.now();

    Event makeEvent(String id, DateTime date, {String? groupId}) => Event(
      eventId:           id,
      teamId:            widget.teamId,
      type:              _type,
      date:              date,
      location:          location,
      minPlayers:        _minPlayers,
      maxPlayers:        _maxPlayers,
      allowSignups:      _allowSignups,
      rsvpDeadline:      _rsvpDeadline,
      boatConfig:        boatCfg,
      numSubTeams:       subTeams,
      notes:             notes,
      recurrenceGroupId: groupId,
      createdAt:         now,
    );

    try {
      if (_recurrence == _Recurrence.none) {
        final docRef = FirebaseFirestore.instance.collection('events').doc();
        await ref.read(eventRepositoryProvider).createEvent(makeEvent(docRef.id, _eventDateTime));
      } else {
        final interval  = _recurrence == _Recurrence.weekly ? 7 : 14;
        final groupId   = FirebaseFirestore.instance.collection('events').doc().id;
        final endMoment = DateTime(
          _recurrenceEndDate!.year, _recurrenceEndDate!.month,
          _recurrenceEndDate!.day, 23, 59, 59,
        );
        final events = <Event>[];
        var current  = _eventDateTime;
        while (!current.isAfter(endMoment)) {
          final docId = FirebaseFirestore.instance.collection('events').doc().id;
          events.add(makeEvent(docId, current, groupId: groupId));
          current = current.add(Duration(days: interval));
        }
        await ref.read(eventRepositoryProvider).createEvents(events);
      }
      unawaited(ref.read(analyticsServiceProvider).logEventCreated(sport));
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create event: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt  = DateFormat('EEE, MMM d, yyyy');
    final timeFmt  = DateFormat('h:mm a');
    final teamAsync = ref.watch(teamProvider(widget.teamId));
    final sport     = teamAsync.valueOrNull?.sport ?? '';

    return Scaffold(
      appBar: AppBar(
          title: Text(widget.copyFrom != null ? 'Copy Event' : 'New Event')),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
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
                    Text('Event Type', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SegmentedButton<EventType>(
                      segments: EventType.values.map((t) =>
                        ButtonSegment(value: t, label: Text(t.label))).toList(),
                      selected: {_type},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) => setState(() => _type = s.first),
                    ),
                    const SizedBox(height: 20),

                    // ── Date & Time ───────────────────────────────────────
                    Text('Date & Time', style: Theme.of(context).textTheme.titleSmall),
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
                        FocusScope.of(context).unfocus();
                      },
                    ),
                    const SizedBox(height: 20),

                    // ── Player counts ─────────────────────────────────────
                    Text('Player Limits', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _CounterField(
                          label: 'Min', value: _minPlayers, min: 1, max: _maxPlayers,
                          onChanged: (v) => setState(() => _minPlayers = v),
                        )),
                        const SizedBox(width: 16),
                        Expanded(child: _CounterField(
                          label: 'Max', value: _maxPlayers, min: _minPlayers, max: 200,
                          onChanged: (v) => setState(() => _maxPlayers = v),
                        )),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Allow signups ─────────────────────────────────────
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Allow Player RSVP'),
                      subtitle: const Text('Players can mark yes / no / maybe.'),
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
                        subtitle: const Text('Optional — disables RSVP after this time.'),
                        trailing: _rsvpDeadline != null
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => setState(() => _rsvpDeadline = null),
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
                          setState(() => _rsvpDeadline =
                              DateTime(d.year, d.month, d.day, t.hour, t.minute));
                        },
                      ),
                    ],
                    const SizedBox(height: 16),

                    // ── Boat Configuration (Dragon Boating only) ──────────
                    if (sport == 'Dragon Boating') ...[
                      Row(
                        children: [
                          Text('Boat Configuration',
                              style: Theme.of(context).textTheme.titleSmall),
                          const Spacer(),
                          TextButton.icon(
                            icon: _loadingConfig
                                ? const SizedBox(
                                    height: 14, width: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.history, size: 16),
                            label: const Text('Copy last'),
                            onPressed: _loadingConfig ? null : () async {
                              setState(() => _loadingConfig = true);
                              final cfg = await ref
                                  .read(eventRepositoryProvider)
                                  .fetchLastBoatConfig(widget.teamId);
                              if (!context.mounted) return;
                              setState(() {
                                _loadingConfig = false;
                                if (cfg != null) {
                                  _numBoats     = cfg.numBoats;
                                  _seatsPerBoat = cfg.seatsPerBoat;
                                  _hasDrummer   = cfg.hasDrummer;
                                }
                              });
                              if (cfg == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('No previous boat config found.')),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _CounterField(
                            label: 'Boats', value: _numBoats, min: 1, max: 4,
                            onChanged: (v) => setState(() => _numBoats = v),
                          )),
                          const SizedBox(width: 16),
                          Expanded(child: _CounterField(
                            label: 'Seats/boat', value: _seatsPerBoat,
                            min: 8, max: 22, step: 2,
                            onChanged: (v) => setState(() => _seatsPerBoat = v),
                          )),
                        ],
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Drummer'),
                        subtitle: const Text('Each boat has a drummer at the front.'),
                        value: _hasDrummer,
                        onChanged: (v) => setState(() => _hasDrummer = v),
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

                    // ── Notes / description ───────────────────────────────
                    TextFormField(
                      controller:  _notesCtrl,
                      maxLines:    4,
                      minLines:    2,
                      textInputAction: TextInputAction.newline,
                      decoration:  const InputDecoration(
                        labelText:   'Notes (optional)',
                        hintText:    'Any details for players — location tips, what to bring, etc.',
                        prefixIcon:  Icon(Icons.notes_outlined),
                        border:      OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Recurrence ────────────────────────────────────────
                    if (widget.copyFrom == null) ...[
                      Text('Repeat', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      SegmentedButton<_Recurrence>(
                        segments: const [
                          ButtonSegment(value: _Recurrence.none,     label: Text('None')),
                          ButtonSegment(value: _Recurrence.weekly,   label: Text('Weekly')),
                          ButtonSegment(value: _Recurrence.biweekly, label: Text('Biweekly')),
                        ],
                        selected: {_recurrence},
                        showSelectedIcon: false,
                        onSelectionChanged: (s) => setState(() {
                          _recurrence = s.first;
                          if (_recurrence == _Recurrence.none) _recurrenceEndDate = null;
                        }),
                      ),
                      if (_recurrence != _Recurrence.none) ...[
                        const SizedBox(height: 8),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.event_repeat_outlined),
                          title: Text(_recurrenceEndDate == null
                              ? 'End date — required'
                              : 'Ends ${DateFormat('EEE, MMM d, yyyy').format(_recurrenceEndDate!)}'),
                          trailing: _recurrenceEndDate != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () =>
                                      setState(() => _recurrenceEndDate = null),
                                )
                              : null,
                          onTap: () async {
                            final interval = _recurrence == _Recurrence.weekly ? 7 : 14;
                            final picked = await showDatePicker(
                              context:          context,
                              initialDate:      _date.add(Duration(days: interval)),
                              firstDate:        _date.add(Duration(days: interval)),
                              lastDate:         DateTime.now().add(const Duration(days: 365 * 2)),
                              initialEntryMode: DatePickerEntryMode.input,
                              builder:          _pickerMediaQuery,
                            );
                            if (picked != null) {
                              setState(() => _recurrenceEndDate = picked);
                            }
                          },
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],

                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(widget.copyFrom != null
                              ? 'Create Copy'
                              : 'Create Event'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

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
