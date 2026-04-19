import 'package:cloud_firestore/cloud_firestore.dart';

/// The app's Firestore user profile, separate from Firebase Auth.
/// Firebase Auth holds credentials; this holds app data.
class AppUser {
  final String userId;
  final String name;
  final String email;
  final String? phone;       // optional — collected with explicit consent
  final String? photoUrl;    // optional — collected with explicit consent
  final String? fcmToken;    // FCM push token — updated on login
  final double? weightKg;    // optional — used for dragon boat balance; player-editable
  final List<String> teams;
  final bool adFree;
  final String role;         // 'player' | 'teamAdmin' | 'systemAdmin'
  final bool deleted;        // soft-delete flag (GDPR right to erasure pending cascade)
  final DateTime createdAt;
  final bool notificationsEnabled; // user-level push notification opt-out
  final List<String> mutedTeams;   // team IDs where notifications are muted

  const AppUser({
    required this.userId,
    required this.name,
    required this.email,
    this.phone,
    this.photoUrl,
    this.fcmToken,
    this.weightKg,
    required this.teams,
    required this.adFree,
    required this.role,
    required this.deleted,
    required this.createdAt,
    this.notificationsEnabled = true,
    this.mutedTeams = const [],
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      userId:    doc.id,
      name:      data['name']     as String? ?? '',
      email:     data['email']    as String? ?? '',
      phone:     data['phone']    as String?,
      photoUrl:  data['photoUrl'] as String?,
      fcmToken:  data['fcmToken'] as String?,
      weightKg:  (data['weightKg'] as num?)?.toDouble(),
      teams:     List<String>.from(data['teams'] as List? ?? []),
      adFree:    data['adFree']   as bool? ?? false,
      role:      data['role']     as String? ?? 'player',
      deleted:   data['deleted']  as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notificationsEnabled: data['notificationsEnabled'] as bool? ?? true,
      mutedTeams: List<String>.from(data['mutedTeams'] as List? ?? []),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name':      name,
    'email':     email,
    if (phone != null)     'phone':    phone,
    if (photoUrl != null)  'photoUrl': photoUrl,
    if (fcmToken != null)  'fcmToken': fcmToken,
    if (weightKg != null)  'weightKg': weightKg,
    'teams':     teams,
    'adFree':    adFree,
    'role':      role,
    'deleted':   deleted,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  bool get isSystemAdmin => role == 'systemAdmin';
  bool get isPlayer      => role == 'player';
}
