import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/spare_request.dart';
import '../domain/spares.dart';

class SparesRepository {
  final FirebaseFirestore _db;
  final FirebaseFunctions _fn;
  SparesRepository(this._db, this._fn);

  CollectionReference<Map<String, dynamic>> _spares(String teamId) =>
      _db.collection('teams').doc(teamId).collection('spares');

  CollectionReference<Map<String, dynamic>> _requests(String teamId) =>
      _db.collection('teams').doc(teamId).collection('spareRequests');

  Stream<List<TeamSpare>> watchSpares(String teamId) =>
      _spares(teamId).orderBy('joinedAt').snapshots().map(
            (s) => s.docs.map(TeamSpare.fromFirestore).toList(),
          );

  Future<List<TeamSpare>> getSpares(String teamId) async {
    final snap = await _spares(teamId).orderBy('joinedAt').get();
    return snap.docs.map(TeamSpare.fromFirestore).toList();
  }

  Future<void> addSpares(String teamId, List<String> userIds) async {
    final batch = _db.batch();
    final now = DateTime.now();
    for (final userId in userIds) {
      batch.set(
        _spares(teamId).doc(userId),
        {'teamId': teamId, 'joinedAt': Timestamp.fromDate(now)},
      );
    }
    await batch.commit();
  }

  Future<void> removeSpares(String teamId, List<String> userIds) async {
    final batch = _db.batch();
    for (final userId in userIds) {
      batch.delete(_spares(teamId).doc(userId));
    }
    await batch.commit();
  }

  // ── Spare requests ─────────────────────────────────────────────���───────────

  Stream<List<SpareRequest>> watchSpareRequests(String teamId) =>
      _requests(teamId)
          .orderBy('requestedAt', descending: true)
          .snapshots()
          .map((s) => s.docs.map(SpareRequest.fromFirestore).toList());

  Stream<SpareRequest?> watchMySpareRequest(String teamId, String userId) =>
      _requests(teamId).doc(userId).snapshots().map(
            (doc) => doc.exists ? SpareRequest.fromFirestore(doc) : null,
          );

  Future<void> createSpareRequest(SpareRequest req) =>
      _requests(req.teamId).doc(req.userId).set(req.toFirestore());

  /// Approve: add to spares + delete request atomically.
  Future<void> approveSpareRequest(String teamId, String userId) async {
    final batch = _db.batch();
    batch.set(_spares(teamId).doc(userId), {
      'teamId':   teamId,
      'joinedAt': Timestamp.fromDate(DateTime.now()),
    });
    batch.delete(_requests(teamId).doc(userId));
    await batch.commit();
  }

  Future<void> denySpareRequest(String teamId, String userId) =>
      _requests(teamId).doc(userId).delete();

  // ── Notifications ──────────────────────────────────────────────���────────────

  Future<int> notifySpares({
    required String eventId,
    required String teamId,
    required String teamName,
    required DateTime eventDate,
    int batchSize = 10,
  }) async {
    try {
      final result = await _fn.httpsCallable('notifySpares').call({
        'eventId': eventId,
        'teamId': teamId,
        'teamName': teamName,
        'eventDate': eventDate.toIso8601String(),
        'batchSize': batchSize,
      });
      return result.data['sent'] as int? ?? 0;
    } on FirebaseFunctionsException {
      return 0;
    }
  }

  Future<bool> spareResponds({
    required String eventId,
    required String teamId,
    required String userId,
    required bool isAvailable,
    int? maxPlayers,
  }) async {
    if (!isAvailable) {
      return false;
    }

    final eventRef = _db.collection('events').doc(eventId);
    final availRef = eventRef.collection('availability').doc(userId);

    return _db.runTransaction((tx) async {
      final eventSnap = await tx.get(eventRef);
      if (!eventSnap.exists) return false;

      final availSnap = await tx.get(availRef);
      if (availSnap.exists) {
        final existing = availSnap.data();
        if (existing?['response'] == 'yes') {
          return false;
        }
      }

      tx.set(availRef, {
        'userId': userId,
        'teamId': teamId,
        'response': 'yes',
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      return true;
    });
  }
}

final sparesRepositoryProvider = Provider<SparesRepository>((ref) {
  return SparesRepository(
      FirebaseFirestore.instance, FirebaseFunctions.instance);
});
