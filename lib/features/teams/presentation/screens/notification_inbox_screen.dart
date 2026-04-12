import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class NotificationInboxScreen extends ConsumerStatefulWidget {
  final String teamId;
  const NotificationInboxScreen({super.key, required this.teamId});

  @override
  ConsumerState<NotificationInboxScreen> createState() =>
      _NotificationInboxScreenState();
}

class _NotificationInboxScreenState
    extends ConsumerState<NotificationInboxScreen> {
  /// Timestamp of the last time the inbox was opened — messages newer than
  /// this are shown as unread. Epoch 0 means never opened before.
  DateTime _lastReadAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _loadAndMarkRead();
  }

  Future<void> _loadAndMarkRead() async {
    final prefs = await SharedPreferences.getInstance();
    final key   = 'inbox_last_read_${widget.teamId}';
    final stored = prefs.getString(key);
    final prev   = stored != null
        ? (DateTime.tryParse(stored) ?? DateTime.fromMillisecondsSinceEpoch(0))
        : DateTime.fromMillisecondsSinceEpoch(0);
    if (mounted) setState(() => _lastReadAt = prev);
    // Stamp now so next visit treats all current messages as read.
    await prefs.setString(key, DateTime.now().toIso8601String());
  }

  @override
  Widget build(BuildContext context) {
    final inboxAsync = ref.watch(_inboxProvider(widget.teamId));

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
            itemBuilder: (context, i) => _NotificationTile(
              msg:   messages[i],
              isNew: messages[i].sentAt.isAfter(_lastReadAt),
            ),
          );
        },
      )),
    );
  }
}

// ── Tile ──────────────────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final _TeamNotification msg;
  final bool isNew;
  const _NotificationTile({required this.msg, required this.isNew});

  @override
  Widget build(BuildContext context) {
    final fmt    = DateFormat('MMM d, h:mm a');
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      tileColor: isNew ? scheme.primaryContainer.withValues(alpha: 0.18) : null,
      leading: Badge(
        isLabelVisible: isNew,
        backgroundColor: scheme.primary,
        child: CircleAvatar(
          radius: 20 * MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.5),
          backgroundColor: scheme.primaryContainer,
          child: Icon(Icons.notifications_outlined,
              color: scheme.onPrimaryContainer),
        ),
      ),
      title: Text(
        msg.title,
        style: TextStyle(
            fontWeight: isNew ? FontWeight.w700 : FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(msg.body),
          const SizedBox(height: 2),
          Text(fmt.format(msg.sentAt),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.outline)),
        ],
      ),
      isThreeLine: true,
    );
  }
}
