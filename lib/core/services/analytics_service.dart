import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thin wrapper around [FirebaseAnalytics] exposed as a Riverpod provider.
///
/// Usage:
///   final analytics = ref.read(analyticsServiceProvider);
///   analytics.logLogin('email');
class AnalyticsService {
  final FirebaseAnalytics _a;
  const AnalyticsService(this._a);

  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _a);

  // ── Auth ───────────────────────────────────────────────────────────────────

  Future<void> logLogin(String method) =>
      _a.logLogin(loginMethod: method);

  Future<void> logSignUp(String method) =>
      _a.logSignUp(signUpMethod: method);

  // ── Teams ──────────────────────────────────────────────────────────────────

  Future<void> logTeamCreated(String sport) =>
      _a.logEvent(name: 'team_created', parameters: {'sport': sport});

  Future<void> logTeamJoined(String sport) =>
      _a.logEvent(name: 'team_joined', parameters: {'sport': sport});

  // ── Events ─────────────────────────────────────────────────────────────────

  Future<void> logEventCreated(String sport) =>
      _a.logEvent(name: 'event_created', parameters: {'sport': sport});

  Future<void> logAvailabilitySet(String status) =>
      _a.logEvent(name: 'availability_set', parameters: {'status': status});

  // ── Drop-ins ───────────────────────────────────────────────────────────────

  Future<void> logDropInSignup() =>
      _a.logEvent(name: 'dropin_signup');

  // ── IAP ────────────────────────────────────────────────────────────────────

  Future<void> logRemoveAdsPurchased() =>
      _a.logEvent(name: 'remove_ads_purchased');

  // ── Generic ────────────────────────────────────────────────────────────────

  Future<void> logEvent(String name, [Map<String, Object>? params]) =>
      _a.logEvent(name: name, parameters: params);
}

final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => AnalyticsService(FirebaseAnalytics.instance),
);

final analyticsObserverProvider = Provider<FirebaseAnalyticsObserver>(
  (ref) => ref.read(analyticsServiceProvider).observer,
);
