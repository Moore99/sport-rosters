import 'package:cloud_firestore/cloud_firestore.dart';

class Announcement {
  final String   announcementId;
  final String   teamId;
  final String   title;
  final String   body;
  final String   authorId;
  final String   authorName;
  final bool     pinned;
  final DateTime createdAt;

  const Announcement({
    required this.announcementId,
    required this.teamId,
    required this.title,
    required this.body,
    required this.authorId,
    required this.authorName,
    required this.pinned,
    required this.createdAt,
  });

  factory Announcement.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Announcement(
      announcementId: doc.id,
      teamId:         d['teamId']     as String? ?? '',
      title:          d['title']      as String? ?? '',
      body:           d['body']       as String? ?? '',
      authorId:       d['authorId']   as String? ?? '',
      authorName:     d['authorName'] as String? ?? '',
      pinned:         d['pinned']     as bool?   ?? false,
      createdAt:      (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'teamId':     teamId,
    'title':      title,
    'body':       body,
    'authorId':   authorId,
    'authorName': authorName,
    'pinned':     pinned,
    'createdAt':  Timestamp.fromDate(createdAt),
  };

  Announcement copyWith({String? title, String? body, bool? pinned}) =>
      Announcement(
        announcementId: announcementId,
        teamId:         teamId,
        title:          title     ?? this.title,
        body:           body      ?? this.body,
        authorId:       authorId,
        authorName:     authorName,
        pinned:         pinned    ?? this.pinned,
        createdAt:      createdAt,
      );
}
