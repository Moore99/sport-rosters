import 'package:cloud_firestore/cloud_firestore.dart';

enum JoinRequestStatus { pending, approved, denied }

class JoinRequest {
  final String requestId;
  final String userId;
  final String userName;
  final String userEmail;
  final JoinRequestStatus status;
  final DateTime createdAt;

  const JoinRequest({
    required this.requestId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.status,
    required this.createdAt,
  });

  factory JoinRequest.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return JoinRequest(
      requestId: doc.id,
      userId:    d['userId']    as String? ?? '',
      userName:  d['userName']  as String? ?? '',
      userEmail: d['userEmail'] as String? ?? '',
      status:    _statusFrom(d['status'] as String? ?? 'pending'),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'userId':    userId,
    'userName':  userName,
    'userEmail': userEmail,
    'status':    status.name,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  static JoinRequestStatus _statusFrom(String s) =>
      JoinRequestStatus.values.firstWhere((e) => e.name == s,
          orElse: () => JoinRequestStatus.pending);

  bool get isPending  => status == JoinRequestStatus.pending;
  bool get isApproved => status == JoinRequestStatus.approved;
}
