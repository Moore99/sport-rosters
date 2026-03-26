import 'package:cloud_firestore/cloud_firestore.dart';

/// A coach's private assessment of a player on a specific team.
/// COACH PRIVATE — players cannot read their own ranking.
/// Stored as: teams/{teamId}/rankings/{userId}
class Ranking {
  final String  userId;
  final String  teamId;
  final double  score;     // overall 0.0–10.0
  final String? notes;     // private coaching notes
  final DateTime updatedAt;

  const Ranking({
    required this.userId,
    required this.teamId,
    required this.score,
    this.notes,
    required this.updatedAt,
  });

  factory Ranking.fromFirestore(DocumentSnapshot doc, String teamId) {
    final d = doc.data() as Map<String, dynamic>;
    return Ranking(
      userId:    doc.id,
      teamId:    teamId,
      score:     (d['score'] as num?)?.toDouble() ?? 0.0,
      notes:     d['notes'] as String?,
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'score':     score,
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  /// Returns a display label for the score (e.g. "7.5").
  String get scoreLabel => score == score.truncateToDouble()
      ? score.toInt().toString()
      : score.toStringAsFixed(1);
}
