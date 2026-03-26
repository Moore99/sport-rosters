import 'package:cloud_firestore/cloud_firestore.dart';

class DropInSession {
  final String       sessionId;   // same as eventId — one session per event
  final String       eventId;
  final String       teamId;
  final List<String> signups;
  final List<String> waitlist;
  /// Generated teams (Phase 2). Each inner list is a team of userIds.
  final List<List<String>> generatedTeams;
  final DateTime     createdAt;

  const DropInSession({
    required this.sessionId,
    required this.eventId,
    required this.teamId,
    required this.signups,
    this.waitlist = const [],
    required this.generatedTeams,
    required this.createdAt,
  });

  factory DropInSession.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return DropInSession(
      sessionId:      doc.id,
      eventId:        d['eventId']   as String? ?? '',
      teamId:         d['teamId']    as String? ?? '',
      signups:        List<String>.from(d['signups'] as List? ?? []),
      waitlist:       List<String>.from(d['waitlist'] as List? ?? []),
      generatedTeams: (d['generatedTeams'] as List? ?? [])
          .map((t) => List<String>.from(t as List))
          .toList(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'eventId':       eventId,
    'teamId':        teamId,
    'signups':       signups,
    'waitlist':      waitlist,
    'generatedTeams': generatedTeams,
    'createdAt':     Timestamp.fromDate(createdAt),
  };

  bool isSignedUp(String uid)  => signups.contains(uid);
  bool isWaitlisted(String uid) => waitlist.contains(uid);
  int  waitlistPosition(String uid) => waitlist.indexOf(uid) + 1;
}
