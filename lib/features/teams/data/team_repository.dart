import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/join_request.dart';
import '../domain/team.dart';

class TeamRepository {
  final FirebaseFirestore _db;
  TeamRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _teams => _db.collection('teams');

  CollectionReference<Map<String, dynamic>> _requests(String teamId) =>
      _teams.doc(teamId).collection('joinRequests');

  // ── Reads ──────────────────────────────────────────────────────────────────

  Future<Team?> getTeam(String teamId) async {
    final doc = await _teams.doc(teamId).get();
    return doc.exists ? Team.fromFirestore(doc) : null;
  }

  Stream<Team?> watchTeam(String teamId) =>
      _teams.doc(teamId).snapshots().map(
        (doc) => doc.exists ? Team.fromFirestore(doc) : null,
      );

  Stream<List<JoinRequest>> watchPendingRequests(String teamId) =>
      _requests(teamId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt')
          .snapshots()
          .map((s) => s.docs.map(JoinRequest.fromFirestore).toList());

  // ── Create ─────────────────────────────────────────────────────────────────

  /// Creates team + atomically adds teamId to creator's profile.
  Future<String> createTeam(Team team, String creatorUid) async {
    final batch = _db.batch();

    final teamRef = _teams.doc(team.teamId);
    batch.set(teamRef, team.toFirestore());

    // Keep users.teams in sync
    final userRef = _db.collection('users').doc(creatorUid);
    batch.update(userRef, {
      'teams': FieldValue.arrayUnion([team.teamId]),
    });

    await batch.commit();
    return team.teamId;
  }

  // ── Join Request ───────────────────────────────────────────────────────────

  /// Player submits a join request. Idempotent — overwrites any prior request.
  Future<void> requestToJoin(String teamId, String userId, String userName, String userEmail) =>
      _requests(teamId).doc(userId).set(JoinRequest(
        requestId: userId,
        userId:    userId,
        userName:  userName,
        userEmail: userEmail,
        status:    JoinRequestStatus.pending,
        createdAt: DateTime.now(),
      ).toFirestore());

  /// Admin approves a join request — adds player to team + team to user profile.
  Future<void> approveRequest(String teamId, String userId) async {
    final batch = _db.batch();

    batch.update(_teams.doc(teamId), {
      'players': FieldValue.arrayUnion([userId]),
    });
    batch.update(_db.collection('users').doc(userId), {
      'teams': FieldValue.arrayUnion([teamId]),
    });
    batch.update(_requests(teamId).doc(userId), {'status': 'approved'});

    await batch.commit();
  }

  /// Admin denies a join request.
  Future<void> denyRequest(String teamId, String userId) =>
      _requests(teamId).doc(userId).update({'status': 'denied'});

  // ── Roster management ──────────────────────────────────────────────────────

  /// Admin promotes a player to co-admin.
  Future<void> promoteToAdmin(String teamId, String userId) =>
      _teams.doc(teamId).update({
        'admins':   FieldValue.arrayUnion([userId]),
        'players':  FieldValue.arrayRemove([userId]),
      });

  /// Uploads a logo image via the uploadTeamLogo Cloud Function (admin-verified).
  /// The function writes to Storage via Admin SDK; direct client writes are denied.
  Future<void> uploadTeamLogo(String teamId, File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final imageBase64 = base64Encode(bytes);

    final callable = FirebaseFunctions
        .instanceFor(region: 'northamerica-northeast1')
        .httpsCallable('uploadTeamLogo');

    await callable.call(<String, dynamic>{
      'teamId':      teamId,
      'imageBase64': imageBase64,
    });
    // logoUrl is written to Firestore by the function — no local update needed.
  }

  /// Admin removes a player from the team + removes teamId from their profile.
  Future<void> removePlayer(String teamId, String userId) async {
    final batch = _db.batch();
    batch.update(_teams.doc(teamId), {
      'players': FieldValue.arrayRemove([userId]),
    });
    batch.update(_db.collection('users').doc(userId), {
      'teams': FieldValue.arrayRemove([teamId]),
    });
    await batch.commit();
  }
}

final teamRepositoryProvider = Provider<TeamRepository>(
  (ref) => TeamRepository(FirebaseFirestore.instance),
);
