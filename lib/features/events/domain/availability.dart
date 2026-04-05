import 'package:cloud_firestore/cloud_firestore.dart';

enum AvailabilityResponse { yes, no, maybe }

extension AvailabilityLabel on AvailabilityResponse {
  String get label => switch (this) {
    AvailabilityResponse.yes   => 'Yes',
    AvailabilityResponse.no    => 'No',
    AvailabilityResponse.maybe => 'Maybe',
  };
  String get emoji => switch (this) {
    AvailabilityResponse.yes   => '✅',
    AvailabilityResponse.no    => '❌',
    AvailabilityResponse.maybe => '❓',
  };
}

class Availability {
  final String               userId;
  final String               eventId;
  final String               teamId;   // denormalized for Firestore rules
  final AvailabilityResponse response;
  final DateTime             updatedAt;

  const Availability({
    required this.userId,
    required this.eventId,
    required this.teamId,
    required this.response,
    required this.updatedAt,
  });

  factory Availability.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Availability(
      userId:    d['userId']   as String? ?? doc.id,  // field preferred; doc.id for legacy docs
      eventId:   d['eventId']  as String? ?? '',
      teamId:    d['teamId']   as String? ?? '',
      response:  _responseFrom(d['response'] as String? ?? 'maybe'),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'userId':    userId,   // denormalized so collectionGroup queries can filter by userId
    'eventId':   eventId,
    'teamId':    teamId,
    'response':  response.name,
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  static AvailabilityResponse _responseFrom(String s) =>
      AvailabilityResponse.values.firstWhere((e) => e.name == s,
          orElse: () => AvailabilityResponse.maybe);
}
