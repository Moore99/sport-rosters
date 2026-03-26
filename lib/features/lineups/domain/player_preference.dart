import 'package:cloud_firestore/cloud_firestore.dart';

/// A player's position preferences for a specific team.
/// Stored at teams/{teamId}/playerPreferences/{userId}.
///
/// [preferredPositions] is a list of strings, each of which is either:
///   - A specific position name (e.g. "Centre", "Left Wing")
///   - A category name      (e.g. "Any Forward", "Any Defence")
///   - The wildcard "Any"   (willing to play any position)
///
/// Empty list = no preference set (treated as "Any" by the lineup generator).
class PlayerPreference {
  final String       userId;
  final String       teamId;
  final List<String> preferredPositions;
  final DateTime     updatedAt;

  const PlayerPreference({
    required this.userId,
    required this.teamId,
    required this.preferredPositions,
    required this.updatedAt,
  });

  factory PlayerPreference.fromFirestore(DocumentSnapshot doc, String teamId) {
    final d = doc.data() as Map<String, dynamic>;
    return PlayerPreference(
      userId:             doc.id,
      teamId:             teamId,
      preferredPositions: List<String>.from(d['preferredPositions'] as List? ?? []),
      updatedAt:          (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'preferredPositions': preferredPositions,
    'updatedAt':          Timestamp.fromDate(updatedAt),
  };

  bool get hasPreferences => preferredPositions.isNotEmpty;
}
