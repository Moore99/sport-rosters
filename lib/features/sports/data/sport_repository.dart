import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sport.dart';

class SportRepository {
  final FirebaseFirestore _db;
  SportRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _sports =>
      _db.collection('sports');

  Stream<List<Sport>> watchSports() => _sports
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map(Sport.fromFirestore).toList());

  Future<List<Sport>> getSports() async {
    final snap = await _sports.orderBy('name').get();
    return snap.docs.map(Sport.fromFirestore).toList();
  }

  Future<void> addSport(Sport sport) =>
      _sports.doc(sport.sportId).set(sport.toFirestore());

  Future<void> updateSport(Sport sport) =>
      _sports.doc(sport.sportId).update(sport.toFirestore());

  Future<void> deleteSport(String sportId) =>
      _sports.doc(sportId).delete();
}

final sportRepositoryProvider = Provider<SportRepository>(
  (ref) => SportRepository(FirebaseFirestore.instance),
);
