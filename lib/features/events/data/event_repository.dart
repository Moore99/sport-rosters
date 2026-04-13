import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/availability.dart';
import '../domain/event.dart';

class EventRepository {
  final FirebaseFirestore _db;
  EventRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _events =>
      _db.collection('events');

  CollectionReference<Map<String, dynamic>> _avail(String eventId) =>
      _events.doc(eventId).collection('availability');

  // ── Events ─────────────────────────────────────────────────────────────────

  Stream<List<Event>> watchTeamEvents(String teamId) => _events
      .where('teamId', isEqualTo: teamId)
      .orderBy('date')
      .snapshots()
      .map((s) => s.docs.map(Event.fromFirestore).toList());

  Stream<Event?> watchEvent(String eventId) =>
      _events.doc(eventId).snapshots().map(
            (doc) => doc.exists ? Event.fromFirestore(doc) : null,
          );

  Future<String> createEvent(Event event) async {
    final ref = _events.doc(event.eventId);
    await ref.set(event.toFirestore());
    return event.eventId;
  }

  /// Batch-creates multiple events (used for recurring series).
  Future<void> createEvents(List<Event> events) async {
    final batch = _db.batch();
    for (final e in events) {
      batch.set(_events.doc(e.eventId), e.toFirestore());
    }
    await batch.commit();
  }

  Future<void> updateEvent(Event event) =>
      _events.doc(event.eventId).update(event.toFirestore());

  Future<void> deleteEvent(String eventId) => _events.doc(eventId).delete();

  /// Deletes all events sharing [groupId] (a recurring series).
  Future<void> deleteEventSeries(String groupId) async {
    final snap =
        await _events.where('recurrenceGroupId', isEqualTo: groupId).get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Updates non-date fields on all events sharing [groupId].
  /// Each event keeps its own date; only shared fields are overwritten.
  Future<void> updateEventSeriesFields(
      String groupId, Map<String, dynamic> fields) async {
    final snap =
        await _events.where('recurrenceGroupId', isEqualTo: groupId).get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, fields);
    }
    await batch.commit();
  }

  Future<void> updateGameResult(String eventId, GameResult? result) =>
      _events.doc(eventId).update({
        'gameResult': result != null ? result.toMap() : FieldValue.delete(),
      });

  /// Returns the boatConfig from the most recent Dragon Boating event for a team.
  /// Used in CreateEventScreen to pre-fill boat config fields.
  Future<BoatConfig?> fetchLastBoatConfig(String teamId) async {
    final snap = await _events
        .where('teamId', isEqualTo: teamId)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();
    for (final doc in snap.docs) {
      final cfg = Event.fromFirestore(doc).boatConfig;
      if (cfg != null) return cfg;
    }
    return null;
  }

  // ── Availability ───────────────────────────────────────────────────────────

  /// The current user's RSVP for one event.
  Stream<Availability?> watchMyAvailability(String eventId, String userId) =>
      _avail(eventId).doc(userId).snapshots().map(
            (doc) => doc.exists ? Availability.fromFirestore(doc) : null,
          );

  /// All RSVPs for an event — used by admins to see the full picture.
  /// teamId is included as a where-clause so Firestore security rules can
  /// evaluate resource.data.teamId against it during the list query.
  Stream<List<Availability>> watchEventAvailability(
          String eventId, String teamId) =>
      _avail(eventId)
          .where('teamId', isEqualTo: teamId)
          .snapshots()
          .map((s) => s.docs.map(Availability.fromFirestore).toList());

  /// Player sets or updates their RSVP.
  Future<void> setAvailability(Availability avail) =>
      _avail(avail.eventId).doc(avail.userId).set(avail.toFirestore());

  /// Upcoming events for a team (date ≥ now), sorted ascending.
  Future<List<Event>> fetchUpcomingTeamEvents(String teamId) async {
    final snap = await _events.where('teamId', isEqualTo: teamId).get();
    final now = DateTime.now();
    final upcoming = snap.docs
        .map(Event.fromFirestore)
        .where((e) => e.date.isAfter(now))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return upcoming;
  }

  /// All past events for a team, most recent first.
  /// Uses only a single-field equality filter (no orderBy) to avoid requiring
  /// a composite index. Filtering and sorting done client-side.
  Future<List<Event>> fetchPastTeamEvents(String teamId) async {
    final snap = await _events.where('teamId', isEqualTo: teamId).get();
    final now = DateTime.now();
    final past = snap.docs
        .map(Event.fromFirestore)
        .where((e) => e.date.isBefore(now))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return past;
  }

  /// Fetches availability docs for [userId] across the given [eventIds] using
  /// direct document reads (no composite index required).
  Future<List<Availability>> fetchPlayerAvailabilityForEvents(
      List<String> eventIds, String userId) async {
    if (eventIds.isEmpty) return [];
    final snaps = await Future.wait(
      eventIds.map((id) => _avail(id).doc(userId).get()),
    );
    return snaps
        .where((s) => s.exists)
        .map(Availability.fromFirestore)
        .toList();
  }

  /// Fetches all availability docs for a team's past events.
  Future<List<Availability>> fetchAllAvailabilityForTeam(String teamId) async {
    final pastEvents = await fetchPastTeamEvents(teamId);
    if (pastEvents.isEmpty) return [];

    final allAvail = <Availability>[];
    for (final event in pastEvents) {
      final snap = await _avail(event.eventId).get();
      allAvail.addAll(snap.docs.map(Availability.fromFirestore));
    }
    return allAvail;
  }
}

final eventRepositoryProvider = Provider<EventRepository>(
  (ref) => EventRepository(FirebaseFirestore.instance),
);
