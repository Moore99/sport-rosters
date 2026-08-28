import '../../events/domain/availability.dart';
import '../../teams/domain/admin_role.dart';

/// Pure input-assembly logic for lineup auto-generation.
///
/// No Riverpod, no Firebase — takes already-fetched domain objects and applies
/// the domain rules for who is eligible to appear in an auto-generated lineup.
class LineupInputResolver {
  const LineupInputResolver._();

  /// The uids eligible to be placed in an auto-generated lineup, applying:
  ///
  /// 1. Coach-only exclusion — admins whose [AdminParticipation] is
  ///    [AdminParticipation.coachOnly] are never in a lineup, even if they
  ///    RSVPed yes.
  /// 2. RSVP — only `yes` or `maybe` responses count; `no` (or a missing
  ///    response, i.e. no [Availability] entry) is excluded.
  /// 3. Team membership — the uid must be a current player or admin of the team.
  ///
  /// The result preserves [availability] order and is not de-duplicated —
  /// callers get one entry per matching [Availability] row.
  static List<String> eligiblePlayerUids({
    required List<Availability> availability,
    required Map<String, AdminParticipation> adminRoles,
    required Set<String> teamPlayerUids,
    required Set<String> teamAdminUids,
  }) {
    final coachOnlyUids = {
      for (final e in adminRoles.entries)
        if (e.value == AdminParticipation.coachOnly) e.key,
    };

    return availability
        .where((a) =>
            a.response == AvailabilityResponse.yes ||
            a.response == AvailabilityResponse.maybe)
        .map((a) => a.userId)
        .where((uid) => !coachOnlyUids.contains(uid))
        .where((uid) =>
            teamPlayerUids.contains(uid) || teamAdminUids.contains(uid))
        .toList();
  }
}
