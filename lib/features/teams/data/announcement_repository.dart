import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/announcement.dart';

class AnnouncementRepository {
  final FirebaseFirestore _db;
  AnnouncementRepository(this._db);

  CollectionReference<Map<String, dynamic>> _col(String teamId) =>
      _db.collection('teams').doc(teamId).collection('announcements');

  Stream<List<Announcement>> watchTeamAnnouncements(String teamId) =>
      _col(teamId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => s.docs.map(Announcement.fromFirestore).toList());

  Future<void> createAnnouncement(Announcement a) =>
      _col(a.teamId).doc(a.announcementId).set(a.toFirestore());

  Future<void> updateAnnouncement(Announcement a) =>
      _col(a.teamId).doc(a.announcementId).update({
        'title':  a.title,
        'body':   a.body,
        'pinned': a.pinned,
      });

  Future<void> deleteAnnouncement(String teamId, String announcementId) =>
      _col(teamId).doc(announcementId).delete();
}

final announcementRepositoryProvider = Provider<AnnouncementRepository>(
  (ref) => AnnouncementRepository(FirebaseFirestore.instance),
);
