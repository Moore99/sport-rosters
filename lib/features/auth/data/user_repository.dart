import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_user.dart';

class UserRepository {
  final FirebaseFirestore _db;
  UserRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  /// Creates the Firestore profile on first registration.
  Future<void> createUser(AppUser user) =>
      _users.doc(user.userId).set(user.toFirestore());

  /// Fetches the profile once (used after login to check role, adFree, etc.)
  Future<AppUser?> getUser(String userId) async {
    final doc = await _users.doc(userId).get();
    if (!doc.exists) return null;
    return AppUser.fromFirestore(doc);
  }

  /// Live stream for the current user's profile.
  Stream<AppUser?> watchUser(String userId) =>
      _users.doc(userId).snapshots().map(
        (doc) => doc.exists ? AppUser.fromFirestore(doc) : null,
      );

  /// Updates editable profile fields. Only provided fields are written.
  Future<void> updateProfile(String userId,
      {String? name, double? weightKg, String? photoUrl}) {
    final updates = <String, dynamic>{};
    if (name != null)     updates['name']     = name;
    if (weightKg != null) updates['weightKg'] = weightKg;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    return _users.doc(userId).update(updates);
  }

  /// Uploads a profile photo to Firebase Storage and saves the URL.
  Future<void> uploadProfilePhoto(String userId, File imageFile) async {
    final ref = FirebaseStorage.instance.ref('profile_photos/$userId.jpg');
    await ref.putFile(imageFile, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();
    await updateProfile(userId, photoUrl: url);
  }

  /// Saves the FCM push token — called on app start after permission granted.
  Future<void> updateFcmToken(String userId, String token) =>
      _users.doc(userId).update({'fcmToken': token});

  /// Soft-delete: sets deleted=true. Hard cascade handled by Cloud Function.
  /// GDPR/PIPEDA: triggers server-side deletion of all linked data.
  Future<void> softDeleteUser(String userId) =>
      _users.doc(userId).update({'deleted': true});
}

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(FirebaseFirestore.instance),
);
