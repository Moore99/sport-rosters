import 'package:cloud_firestore/cloud_firestore.dart';

class TeamSpare {
  final String userId;
  final String teamId;
  final DateTime joinedAt;

  const TeamSpare({
    required this.userId,
    required this.teamId,
    required this.joinedAt,
  });

  factory TeamSpare.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TeamSpare(
      userId: doc.id,
      teamId: d['teamId'] as String? ?? '',
      joinedAt: (d['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'teamId': teamId,
        'joinedAt': Timestamp.fromDate(joinedAt),
      };
}
