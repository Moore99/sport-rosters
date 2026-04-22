import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/sport.dart';

const _cacheKey = 'cached_sports';
const _cacheTtlMs = 1000 * 60 * 60; // 1 hour

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
    final cached = await _getCachedSports();
    if (cached != null) return cached;

    final snap = await _sports.orderBy('name').get();
    final sports = snap.docs.map(Sport.fromFirestore).toList();
    await _cacheSports(sports);
    return sports;
  }

  Future<List<Sport>?> _getCachedSports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_cacheKey);
      if (json == null) return null;
      final data = jsonDecode(json) as Map<String, dynamic>;
      if (DateTime.now().millisecondsSinceEpoch - (data['ts'] as int) > _cacheTtlMs) {
        return null;
      }
      return (data['sports'] as List)
          .map((e) => Sport.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheSports(List<Sport> sports) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'ts': DateTime.now().millisecondsSinceEpoch,
        'sports': sports.map((s) => s.toJson()).toList(),
      };
      await prefs.setString(_cacheKey, jsonEncode(data));
    } catch (_) {}
  }

  Future<void> addSport(Sport sport) async {
    await _sports.doc(sport.sportId).set(sport.toFirestore());
    await invalidateCache();
  }

  Future<void> updateSport(Sport sport) async {
    await _sports.doc(sport.sportId).update(sport.toFirestore());
    await invalidateCache();
  }

  Future<void> deleteSport(String sportId) async {
    await _sports.doc(sportId).delete();
    await invalidateCache();
  }

  Future<void> invalidateCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } catch (_) {}
  }
}

final sportRepositoryProvider = Provider<SportRepository>(
  (ref) => SportRepository(FirebaseFirestore.instance),
);
