import 'package:cloud_firestore/cloud_firestore.dart';

class SpareRequest {
  final String   userId;
  final String   teamId;
  final String   userName;
  final String   userEmail;
  final DateTime requestedAt;

  const SpareRequest({
    required this.userId,
    required this.teamId,
    required this.userName,
    required this.userEmail,
    required this.requestedAt,
  });

  factory SpareRequest.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SpareRequest(
      userId:      doc.id,
      teamId:      d['teamId']      as String? ?? '',
      userName:    d['userName']    as String? ?? '',
      userEmail:   d['userEmail']   as String? ?? '',
      requestedAt: (d['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'teamId':      teamId,
    'userName':    userName,
    'userEmail':   userEmail,
    'requestedAt': Timestamp.fromDate(requestedAt),
  };
}
