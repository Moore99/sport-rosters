import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/dropin_session.dart';

class DropInRepository {
  final FirebaseFirestore _db;
  DropInRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _db.collection('dropInSessions');

  Stream<DropInSession?> watchSession(String eventId) =>
      _sessions.doc(eventId).snapshots().map(
        (doc) => doc.exists ? DropInSession.fromFirestore(doc) : null,
      );

  /// Signs up uid. If [maxPlayers] is reached, adds to waitlist instead.
  Future<void> signUp(String eventId, String teamId, String uid,
      {int? maxPlayers}) async {
    final ref = _sessions.doc(eventId);
    final doc = await ref.get();

    if (!doc.exists) {
      await ref.set(DropInSession(
        sessionId:     eventId,
        eventId:       eventId,
        teamId:        teamId,
        signups:       [uid],
        generatedTeams: [],
        createdAt:     DateTime.now(),
      ).toFirestore());
    } else {
      final session = DropInSession.fromFirestore(doc);
      final isFull  = maxPlayers != null &&
          session.signups.length >= maxPlayers;
      if (isFull) {
        await ref.update({'waitlist': FieldValue.arrayUnion([uid])});
      } else {
        await ref.update({'signups': FieldValue.arrayUnion([uid])});
      }
    }
  }

  /// Withdraws uid from signups OR waitlist. If from signups and someone is
  /// waitlisted, the first waitlisted player is promoted to signups atomically.
  Future<void> withdraw(String eventId, String uid) =>
      _db.runTransaction((tx) async {
        final ref  = _sessions.doc(eventId);
        final snap = await tx.get(ref);
        if (!snap.exists) return;

        final s        = DropInSession.fromFirestore(snap);
        final signups  = List<String>.from(s.signups);
        final waitlist = List<String>.from(s.waitlist);

        if (waitlist.contains(uid)) {
          waitlist.remove(uid);
          tx.update(ref, {'waitlist': waitlist});
          return;
        }

        signups.remove(uid);
        if (waitlist.isNotEmpty) {
          signups.add(waitlist.removeAt(0));
        }
        tx.update(ref, {'signups': signups, 'waitlist': waitlist});
      });

  Future<void> saveGeneratedTeams(
      String eventId, List<List<String>> teams) =>
      _sessions.doc(eventId).update({'generatedTeams': teams});
}

final dropInRepositoryProvider = Provider<DropInRepository>(
  (ref) => DropInRepository(FirebaseFirestore.instance),
);
