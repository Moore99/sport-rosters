import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../data/dropin_repository.dart';
import '../../domain/dropin_session.dart';

final dropInSessionProvider =
    StreamProvider.family<DropInSession?, String>((ref, eventId) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return Stream.value(null);
  return ref.read(dropInRepositoryProvider).watchSession(eventId);
});
