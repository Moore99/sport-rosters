enum AdminParticipation {
  /// Admin plays on the team — included in lineups, gets full RSVP reminder.
  player,
  /// Admin coaches only — excluded from lineups, gets reminder without RSVP nudge.
  coachOnly,
  /// Admin plays sometimes — included in lineups, gets full RSVP reminder.
  sometimes;

  String get label {
    switch (this) {
      case AdminParticipation.player:    return 'I play on the team';
      case AdminParticipation.coachOnly: return 'I coach only (not in lineup)';
      case AdminParticipation.sometimes: return 'Sometimes play, sometimes coach';
    }
  }

  /// Whether this participation type means the admin plays (i.e. goes in lineup).
  bool get playsInLineup => this != AdminParticipation.coachOnly;
}
