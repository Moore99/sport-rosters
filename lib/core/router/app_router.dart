import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/analytics_service.dart';

import '../../features/auth/presentation/screens/app_tour_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/email_verify_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/teams/presentation/screens/teams_screen.dart';
import '../../features/teams/presentation/screens/team_detail_screen.dart';
import '../../features/teams/presentation/screens/create_team_screen.dart';
import '../../features/events/domain/event.dart';
import '../../features/events/presentation/screens/create_event_screen.dart';
import '../../features/events/presentation/screens/edit_event_screen.dart';
import '../../features/rankings/presentation/screens/rankings_screen.dart';
import '../../features/events/presentation/screens/events_screen.dart';
import '../../features/events/presentation/screens/event_detail_screen.dart';
import '../../features/lineups/presentation/screens/lineup_screen.dart';
import '../../features/lineups/presentation/screens/boat_seating_screen.dart';
import '../../features/lineups/presentation/screens/position_preference_screen.dart';
import '../../features/dropins/presentation/screens/dropin_screen.dart';
import '../../core/services/biometric_service.dart';
import '../../features/auth/presentation/screens/biometric_lock_screen.dart';
import '../../features/shared/screens/help_screen.dart';
import '../../features/shared/screens/privacy_screen.dart';
import '../../features/shared/screens/terms_screen.dart';
import '../../features/shared/screens/accessibility_screen.dart';
import '../../features/shared/screens/profile_screen.dart';
import '../../features/shared/screens/spare_response_screen.dart';
import '../../features/teams/presentation/screens/send_notification_screen.dart';
import '../../features/teams/presentation/screens/notification_inbox_screen.dart';
import '../../features/teams/presentation/screens/manage_spares_screen.dart';
import '../../features/events/presentation/screens/player_attendance_screen.dart';
import '../../features/events/presentation/screens/team_stats_screen.dart';
import '../../features/events/presentation/screens/my_schedule_screen.dart';
import '../../features/teams/presentation/screens/team_announcements_screen.dart';
import '../../features/teams/presentation/screens/join_via_link_screen.dart';
import '../../features/admin/presentation/screens/sports_admin_screen.dart';

// Route paths
class AppRoutes {
  static const login = '/login';
  static const biometricLock = '/biometric-lock';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const emailVerify = '/email-verify';
  static const teams = '/teams';
  static const teamDetail = '/teams/:teamId';
  static const createTeam = '/teams/create';
  static const events = '/teams/:teamId/events';
  static const createEvent = '/teams/:teamId/events/create';
  static const eventDetail = '/teams/:teamId/events/:eventId';
  static const editEvent = '/teams/:teamId/events/:eventId/edit';
  static const rankings = '/teams/:teamId/rankings';
  static const positionPrefs = '/teams/:teamId/preferences/:userId';
  static const lineup = '/teams/:teamId/events/:eventId/lineup';
  static const dropin = '/teams/:teamId/events/:eventId/dropin';
  static const boatSeating = '/teams/:teamId/events/:eventId/boat-seating';
  static const sendNotification = '/teams/:teamId/notify';
  static const notificationInbox = '/teams/:teamId/inbox';
  static const manageSpares = '/teams/:teamId/spares';
  static const announcements = '/teams/:teamId/announcements';
  static const profile = '/profile';
  static const privacy = '/privacy';
  static const terms = '/terms';
  static const help = '/help';
  static const accessibility = '/accessibility';
  static const tour = '/tour';
  static const mySchedule = '/schedule';
  static const joinViaLink = '/join/:teamId';
  static const sportsAdmin = '/admin/sports';
  static const spareResponse = '/spare-response/:eventId/:teamId';
  static const playerAttendance = '/teams/:teamId/attendance/:userId';
  static const teamStats = '/teams/:teamId/stats';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final bioLocked = ref.watch(biometricLockProvider);
  final analyticsObserver = ref.read(analyticsObserverProvider);

  return GoRouter(
    initialLocation: AppRoutes.teams,
    observers: [analyticsObserver],
    redirect: (context, state) {
      // Strip custom URI scheme so deep links like sportsrostering://join/teamId
      // are converted to /join/teamId before GoRouter tries to match routes.
      final fullUri = state.uri.toString();
      if (fullUri.startsWith('sportsrostering://')) {
        return fullUri.replaceFirst('sportsrostering:/', '');
      }

      final isLoggedIn = authState.valueOrNull != null;
      final currentPath = state.matchedLocation;
      final isAuthRoute = currentPath == AppRoutes.login ||
          currentPath == AppRoutes.register ||
          currentPath == AppRoutes.forgotPassword ||
          currentPath == AppRoutes.privacy ||
          currentPath == AppRoutes.terms ||
          currentPath == AppRoutes.accessibility ||
          currentPath == AppRoutes.tour ||
          currentPath.startsWith('/join/');

      if (!isLoggedIn && !isAuthRoute) return AppRoutes.login;

      // Gate all authenticated routes behind biometric lock when active.
      if (isLoggedIn && bioLocked && currentPath != AppRoutes.biometricLock) {
        return AppRoutes.biometricLock;
      }
      // Once unlocked, leave the lock screen.
      if (isLoggedIn && !bioLocked && currentPath == AppRoutes.biometricLock) {
        return AppRoutes.teams;
      }

      // Gate email/password accounts behind email verification
      final firebaseUser = authState.valueOrNull;
      final isEmailUser =
          firebaseUser?.providerData.any((p) => p.providerId == 'password') ??
              false;
      if (isLoggedIn &&
          !bioLocked &&
          isEmailUser &&
          firebaseUser?.emailVerified == false &&
          currentPath != AppRoutes.emailVerify) {
        return AppRoutes.emailVerify;
      }
      if (isLoggedIn &&
          !bioLocked &&
          currentPath == AppRoutes.emailVerify &&
          (!isEmailUser || firebaseUser?.emailVerified == true)) {
        return AppRoutes.teams;
      }

      if (isLoggedIn && currentPath == AppRoutes.login) return AppRoutes.teams;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(
          path: AppRoutes.biometricLock,
          builder: (_, __) => const BiometricLockScreen()),
      GoRoute(
          path: AppRoutes.register, builder: (_, __) => const RegisterScreen()),
      GoRoute(
          path: AppRoutes.forgotPassword,
          builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
          path: AppRoutes.emailVerify,
          builder: (_, __) => const EmailVerifyScreen()),
      GoRoute(path: AppRoutes.teams, builder: (_, __) => const TeamsScreen()),
      GoRoute(
          path: AppRoutes.createTeam,
          builder: (_, __) => const CreateTeamScreen()),
      GoRoute(
        path: AppRoutes.teamDetail,
        builder: (_, state) =>
            TeamDetailScreen(teamId: state.pathParameters['teamId']!),
        routes: [
          // Rankings — admin only; guard enforced in RankingsScreen + Firestore rules
          GoRoute(
            path: 'rankings',
            builder: (_, state) => RankingsScreen(
              teamId: state.pathParameters['teamId']!,
            ),
          ),
          GoRoute(
            path: 'preferences/:userId',
            builder: (_, state) => PositionPreferenceScreen(
              teamId: state.pathParameters['teamId']!,
              userId: state.pathParameters['userId']!,
              sport: state.uri.queryParameters['sport'] ?? '',
              playerName: state.uri.queryParameters['name'] ?? '',
            ),
          ),
          GoRoute(
            path: 'notify',
            builder: (_, state) => SendNotificationScreen(
              teamId: state.pathParameters['teamId']!,
              eventId: state.extra as String?,
            ),
          ),
          GoRoute(
            path: 'inbox',
            builder: (_, state) => NotificationInboxScreen(
              teamId: state.pathParameters['teamId']!,
            ),
          ),
          GoRoute(
            path: 'spares',
            builder: (_, state) => ManageSparesScreen(
              teamId: state.pathParameters['teamId']!,
            ),
          ),
          GoRoute(
            path: 'announcements',
            builder: (_, state) => TeamAnnouncementsScreen(
              teamId: state.pathParameters['teamId']!,
            ),
          ),
          GoRoute(
            path: 'attendance/:userId',
            builder: (_, state) => PlayerAttendanceScreen(
              teamId: state.pathParameters['teamId']!,
              userId: state.pathParameters['userId']!,
            ),
          ),
          GoRoute(
            path: 'stats',
            builder: (_, state) => TeamStatsScreen(
              teamId: state.pathParameters['teamId']!,
            ),
          ),
          GoRoute(
            path: 'events',
            builder: (_, state) =>
                EventsScreen(teamId: state.pathParameters['teamId']!),
            routes: [
              // 'create' must be declared before ':eventId' so it isn't swallowed by the param
              GoRoute(
                path: 'create',
                builder: (_, state) => CreateEventScreen(
                  teamId: state.pathParameters['teamId']!,
                  copyFrom: state.extra as Event?,
                ),
              ),
              GoRoute(
                path: ':eventId',
                builder: (_, state) => EventDetailScreen(
                  teamId: state.pathParameters['teamId']!,
                  eventId: state.pathParameters['eventId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, state) {
                      final x = state.extra;
                      if (x is EditEventArgs) {
                        return EditEventScreen(
                            event: x.event, editSeries: x.editSeries);
                      }
                      return EditEventScreen(event: x as Event);
                    },
                  ),
                  GoRoute(
                    path: 'lineup',
                    builder: (_, state) => LineupScreen(
                      teamId: state.pathParameters['teamId']!,
                      eventId: state.pathParameters['eventId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'dropin',
                    builder: (_, state) => DropInScreen(
                      teamId: state.pathParameters['teamId']!,
                      eventId: state.pathParameters['eventId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'boat-seating',
                    builder: (_, state) => BoatSeatingScreen(
                      teamId: state.pathParameters['teamId']!,
                      eventId: state.pathParameters['eventId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
          path: AppRoutes.profile, builder: (_, __) => const ProfileScreen()),
      GoRoute(
          path: AppRoutes.privacy, builder: (_, __) => const PrivacyScreen()),
      GoRoute(path: AppRoutes.terms, builder: (_, __) => const TermsScreen()),
      GoRoute(path: AppRoutes.help, builder: (_, __) => const HelpScreen()),
      GoRoute(
          path: AppRoutes.accessibility,
          builder: (_, __) => const AccessibilityScreen()),
      GoRoute(path: AppRoutes.tour, builder: (_, __) => const AppTourScreen()),
      GoRoute(
          path: AppRoutes.sportsAdmin,
          builder: (_, __) => const SportsAdminScreen()),
      GoRoute(
          path: AppRoutes.joinViaLink,
          builder: (_, state) => JoinViaLinkScreen(
              teamId: state.pathParameters['teamId']!)),
      GoRoute(
          path: AppRoutes.mySchedule,
          builder: (_, __) => const MyScheduleScreen()),
      GoRoute(
        path: AppRoutes.spareResponse,
        builder: (_, state) => SpareResponseScreen(
          eventId: state.pathParameters['eventId']!,
          teamId: state.pathParameters['teamId']!,
        ),
      ),
    ],
  );
});
