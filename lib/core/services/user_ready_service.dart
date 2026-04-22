import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/teams/presentation/providers/teams_provider.dart';

/// Signals when the app is ready for the user.
/// 
/// This provider:
///
/// - Returns true immediately when signed out (no data to wait for)
/// - Returns true after authState loads AND (if signed in) user's teams load
/// - Used to prevent blank/flicker on cold start before Firestore data arrives
final userReadyProvider = FutureProvider<bool>((ref) async {
  // Wait for auth state to initialize
  final authState = await ref.watch(authStateProvider.future);
  
  // If not signed in, app is ready (show login)
  if (authState == null) return true;
  
  // If signed in, also wait for teams to load
  await ref.watch(userTeamsProvider.future);
  return true;
});