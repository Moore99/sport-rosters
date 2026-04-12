import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../data/announcement_repository.dart';
import '../../domain/announcement.dart';

final teamAnnouncementsProvider =
    StreamProvider.family<List<Announcement>, String>((ref, teamId) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return const Stream.empty();
  return ref.read(announcementRepositoryProvider).watchTeamAnnouncements(teamId);
});
