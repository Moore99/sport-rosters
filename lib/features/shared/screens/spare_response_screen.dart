import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../teams/data/spares_repository.dart';
import '../../events/domain/event.dart';
import '../../events/presentation/providers/events_provider.dart';
import '../../auth/presentation/providers/auth_provider.dart';

class SpareResponseScreen extends ConsumerStatefulWidget {
  final String eventId;
  final String teamId;
  const SpareResponseScreen({
    super.key,
    required this.eventId,
    required this.teamId,
  });

  @override
  ConsumerState<SpareResponseScreen> createState() =>
      _SpareResponseScreenState();
}

class _SpareResponseScreenState extends ConsumerState<SpareResponseScreen> {
  bool _loading = false;
  bool? _added;

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventProvider(widget.eventId));
    final uid = ref.watch(currentUserProvider)?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fill In?'),
      ),
      body: eventAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (event) {
          if (event == null) {
            return const Center(child: Text('Event not found'));
          }

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_add,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Spares Needed!',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                Text(
                  '${event.type.label} on ${DateFormat.MMMd().format(event.date)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Location: ${event.location}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                if (_added == true) ...[
                  const Icon(Icons.check_circle, size: 48, color: Colors.green),
                  const SizedBox(height: 16),
                  const Text(
                    "You're in! See you there!",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ] else ...[
                  Text(
                    'Your team needs players. Want to fill in?',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed:
                            _loading ? null : () => Navigator.of(context).pop(),
                        child: const Text("Can't Make It"),
                      ),
                      const SizedBox(width: 16),
                      FilledButton(
                        onPressed:
                            _loading ? null : () => _respondYes(event, uid),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text("I'm In!"),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _respondYes(Event event, String uid) async {
    setState(() => _loading = true);
    try {
      final added = await ref.read(sparesRepositoryProvider).spareResponds(
            eventId: widget.eventId,
            teamId: widget.teamId,
            userId: uid,
            isAvailable: true,
            maxPlayers: event.maxPlayers,
          );
      setState(() => _added = added);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
