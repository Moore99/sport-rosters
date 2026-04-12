import 'package:cloud_firestore/cloud_firestore.dart';

// ── Game result ────────────────────────────────────────────────────────────────

class GameResult {
  final String opponentName;
  final int    ourScore;
  final int    opponentScore;

  const GameResult({
    required this.opponentName,
    required this.ourScore,
    required this.opponentScore,
  });

  factory GameResult.fromMap(Map<String, dynamic> m) => GameResult(
    opponentName:  m['opponentName']  as String? ?? '',
    ourScore:      (m['ourScore']     as num?)?.toInt() ?? 0,
    opponentScore: (m['opponentScore'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'opponentName':  opponentName,
    'ourScore':      ourScore,
    'opponentScore': opponentScore,
  };

  bool get isWin  => ourScore > opponentScore;
  bool get isLoss => ourScore < opponentScore;
  bool get isTie  => ourScore == opponentScore;
  String get resultLabel => isWin ? 'W' : (isLoss ? 'L' : 'T');
}

// ── Boat configuration (Dragon Boating only) ───────────────────────────────────

class BoatConfig {
  final int  numBoats;     // 1–4
  final int  seatsPerBoat; // total paddler seats (even, 8–22)
  final bool hasDrummer;   // steersperson is always assumed

  const BoatConfig({
    required this.numBoats,
    required this.seatsPerBoat,
    required this.hasDrummer,
  });

  int get rowsPerBoat => seatsPerBoat ~/ 2;

  factory BoatConfig.fromMap(Map<String, dynamic> m) => BoatConfig(
    numBoats:     (m['numBoats']     as num?)?.toInt() ?? 1,
    seatsPerBoat: (m['seatsPerBoat'] as num?)?.toInt() ?? 20,
    hasDrummer:   m['hasDrummer']    as bool? ?? true,
  );

  Map<String, dynamic> toMap() => {
    'numBoats':     numBoats,
    'seatsPerBoat': seatsPerBoat,
    'hasDrummer':   hasDrummer,
  };

  static BoatConfig get defaults =>
      const BoatConfig(numBoats: 1, seatsPerBoat: 20, hasDrummer: true);
}

// ── Event ──────────────────────────────────────────────────────────────────────

enum EventType { game, practice, dropIn }

extension EventTypeLabel on EventType {
  String get label => switch (this) {
    EventType.game     => 'Game',
    EventType.practice => 'Practice',
    EventType.dropIn   => 'Drop-in',
  };
  String get icon => switch (this) {
    EventType.game     => '🏆',
    EventType.practice => '🏋️',
    EventType.dropIn   => '🔓',
  };
}

class Event {
  final String   eventId;
  final String   teamId;
  final EventType type;
  final DateTime date;
  final String   location;
  final int      minPlayers;
  final int      maxPlayers;
  final bool        allowSignups;
  final DateTime?   rsvpDeadline; // null = no deadline
  final BoatConfig? boatConfig;   // Dragon Boating only
  final int         numSubTeams;  // 1 = single roster (default), 2+ = balanced sub-teams
  final String?     notes;              // optional coach notes / description
  final String?     recurrenceGroupId;  // shared ID for events in a recurring series
  final GameResult? gameResult;         // set by admin after a game event
  final DateTime    createdAt;

  const Event({
    required this.eventId,
    required this.teamId,
    required this.type,
    required this.date,
    required this.location,
    required this.minPlayers,
    required this.maxPlayers,
    required this.allowSignups,
    this.rsvpDeadline,
    this.boatConfig,
    this.numSubTeams = 1,
    this.notes,
    this.recurrenceGroupId,
    this.gameResult,
    required this.createdAt,
  });

  factory Event.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Event(
      eventId:      doc.id,
      teamId:       d['teamId']      as String? ?? '',
      type:         _typeFrom(d['type'] as String? ?? 'practice'),
      date:         (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      location:     d['location']    as String? ?? '',
      minPlayers:   (d['minPlayers'] as num?)?.toInt() ?? 1,
      maxPlayers:   (d['maxPlayers'] as num?)?.toInt() ?? 20,
      allowSignups:  d['allowSignups'] as bool? ?? true,
      rsvpDeadline:  (d['rsvpDeadline'] as Timestamp?)?.toDate(),
      boatConfig:    d['boatConfig'] != null
          ? BoatConfig.fromMap(Map<String, dynamic>.from(d['boatConfig'] as Map))
          : null,
      numSubTeams:        (d['numSubTeams'] as num?)?.toInt() ?? 1,
      notes:              d['notes'] as String?,
      recurrenceGroupId:  d['recurrenceGroupId'] as String?,
      gameResult:         d['gameResult'] != null
          ? GameResult.fromMap(Map<String, dynamic>.from(d['gameResult'] as Map))
          : null,
      createdAt:          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'teamId':      teamId,
    'type':        type.name,
    'date':        Timestamp.fromDate(date),
    'location':    location,
    'minPlayers':  minPlayers,
    'maxPlayers':  maxPlayers,
    'allowSignups': allowSignups,
    if (rsvpDeadline != null) 'rsvpDeadline': Timestamp.fromDate(rsvpDeadline!),
    if (boatConfig != null) 'boatConfig': boatConfig!.toMap(),
    if (numSubTeams != 1) 'numSubTeams': numSubTeams,
    if (notes?.isNotEmpty == true)        'notes':             notes,
    if (recurrenceGroupId != null)        'recurrenceGroupId': recurrenceGroupId,
    if (gameResult != null)               'gameResult':        gameResult!.toMap(),
    'createdAt':   Timestamp.fromDate(createdAt),
  };

  bool get isUpcoming      => date.isAfter(DateTime.now());
  bool get isDropIn        => type == EventType.dropIn;
  bool get rsvpOpen        => allowSignups &&
      (rsvpDeadline == null || rsvpDeadline!.isAfter(DateTime.now()));

  static EventType _typeFrom(String s) =>
      EventType.values.firstWhere((e) => e.name == s,
          orElse: () => EventType.practice);
}
