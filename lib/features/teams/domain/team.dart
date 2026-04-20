import 'package:cloud_firestore/cloud_firestore.dart';

class Team {
  final String teamId;
  final String name;
  final String sport;
  final List<String> admins;
  final List<String> players;
  final int minPlayers;
  final int maxPlayers;
  final bool dropInEnabled;
  final DateTime createdAt;
  final String? logoUrl;
  final String timezone; // IANA timezone ID, e.g. 'America/Toronto'
  final bool archived;  // soft-archive; hidden from member lists

  const Team({
    required this.teamId,
    required this.name,
    required this.sport,
    required this.admins,
    required this.players,
    required this.minPlayers,
    required this.maxPlayers,
    required this.dropInEnabled,
    required this.createdAt,
    this.logoUrl,
    this.timezone = 'America/Toronto',
    this.archived = false,
  });

  factory Team.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Team(
      teamId:       doc.id,
      name:         d['name']          as String? ?? '',
      sport:        d['sport']         as String? ?? '',
      admins:       List<String>.from(d['admins']  as List? ?? []),
      players:      List<String>.from(d['players'] as List? ?? []),
      minPlayers:   (d['minPlayers']   as num?)?.toInt() ?? 1,
      maxPlayers:   (d['maxPlayers']   as num?)?.toInt() ?? 20,
      dropInEnabled: d['dropInEnabled'] as bool? ?? false,
      createdAt:    (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      logoUrl:      d['logoUrl'] as String?,
      timezone:     d['timezone'] as String? ?? 'America/Toronto',
      archived:     d['archived'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name':          name,
    'sport':         sport,
    'admins':        admins,
    'players':       players,
    'minPlayers':    minPlayers,
    'maxPlayers':    maxPlayers,
    'dropInEnabled': dropInEnabled,
    'createdAt':     Timestamp.fromDate(createdAt),
    if (logoUrl != null) 'logoUrl': logoUrl,
    'timezone': timezone,
    if (archived) 'archived': true,
  };

  bool isAdmin(String uid)  => admins.contains(uid);
  bool isMember(String uid) => admins.contains(uid) || players.contains(uid);
  int get totalMembers      => admins.length + players.length;
}
