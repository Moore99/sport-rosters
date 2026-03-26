import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

// ── Domain ────────────────────────────────────────────────────────────────────

class _TeamNotification {
  final String  id;
  final String  title;
  final String  body;
  final String? eventId;
  final DateTime sentAt;

  const _TeamNotification({
    required this.id,
    required this.title,
    required this.body,
    this.eventId,
    required this.sentAt,
  });

  factory _TeamNotification.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _TeamNotification(
      id:      doc.id,
      title:   d['title']    as String? ?? '',
      body:    d['body']     as String? ?? '',
      eventId: d['eventId']  as String?,
      sentAt:  (d['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final _inboxProvider = StreamProvider.family<List<_TeamNotification>, String>(
  (ref, teamId) => FirebaseFirestore.instance
      .collection('teamNotifications')
      .doc(teamId)
      .collection('messages')
      .orderBy('sentAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map(_TeamNotification.fromDoc).toList()),
);

// ── Screen ────────────────────────────────────────────────────────────────────

class NotificationInboxScreen extends ConsumerWidget {
  final String teamId;
  const NotificationInboxScreen({super.key, required this.teamId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inboxAsync = ref.watch(_inboxProvider(teamId));

    return Scaffold(
      appBar: AppBar(title: const Text('Team Notifications')),
      body: SafeArea(top: false, child: inboxAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (messages) {
          if (messages.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none,
                      size: 56,
                      color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 12),
                  Text('No notifications yet.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: messages.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) => _NotificationTile(msg: messages[i]),
          );
        },
      )),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final _TeamNotification msg;
  const _NotificationTile({required this.msg});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, h:mm a');
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(Icons.notifications_outlined,
            color: Theme.of(context).colorScheme.onPrimaryContainer),
      ),
      title:    Text(msg.title,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(msg.body),
          const SizedBox(height: 2),
          Text(fmt.format(msg.sentAt),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline)),
        ],
      ),
      isThreeLine: true,
    );
  }
}
