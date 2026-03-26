import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/notification_service.dart';

/// Streams the current Firebase auth state.
/// null = signed out; User = signed in.
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Exposes the current Firebase Auth user synchronously (nullable).
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

/// Streams the current user's Firestore profile (AppUser).
/// Import user_repository and app_user from this provider — avoids circular deps.
// Defined in teams_provider.dart to avoid import cycles with UserRepository.

/// Initializes the notification service once when the user first signs in.
/// Watch this from the root widget to ensure it runs on app startup.
final notificationInitProvider = FutureProvider<void>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return;
  await ref.read(notificationServiceProvider).initialize();
});
