import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/teams/presentation/providers/teams_provider.dart';

/// Signals when the app is ready for the user.
///
/// Runs ONCE on cold start to wait for the initial auth + teams load before
/// showing the app. After that it stays AsyncData(true) permanently.
///
/// Both reads use ref.read (not ref.watch) so this provider NEVER re-runs
/// after the initial load. Re-running would briefly show the splash screen,
/// tear down the entire widget tree (destroying ScrollController state and
/// GoRouter's in-memory route), and on web cause GoRouter to re-initialise
/// at '/' and redirect to /teams. This was the root cause of:
///  - Android: scroll position resetting on every Firestore profile update
///  - Web: navigating to teams whenever a profile toggle was tapped
final userReadyProvider = FutureProvider<bool>((ref) async {
  // Wait once for auth state to initialise on cold start.
  final authState = await ref.read(authStateProvider.future);

  // If not signed in, app is ready (GoRouter will show login/landing).
  if (authState == null) return true;

  // If signed in, wait once for teams to load before showing the app.
  await ref.read(userTeamsProvider.future);
  return true;
});