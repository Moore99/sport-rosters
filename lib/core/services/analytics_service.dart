import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// firebase_analytics has no Windows plugin — every call below is a no-op there.
bool get _analyticsAvailable => kIsWeb || !Platform.isWindows;

/// Thin wrapper around [FirebaseAnalytics] exposed as a Riverpod provider.
///
/// Usage:
///   final analytics = ref.read(analyticsServiceProvider);
///   analytics.logLogin('email');
class AnalyticsService {
  final FirebaseAnalytics _a;
  const AnalyticsService(this._a);

  FirebaseAnalyticsObserver? get observer =>
      _analyticsAvailable ? FirebaseAnalyticsObserver(analytics: _a) : null;

  // ── Auth ───────────────────────────────────────────────────────────────────

  Future<void> logLogin(String method) =>
      _analyticsAvailable ? _a.logLogin(loginMethod: method) : Future.value();

  Future<void> logSignUp(String method) =>
      _analyticsAvailable ? _a.logSignUp(signUpMethod: method) : Future.value();

  // ── Teams ──────────────────────────────────────────────────────────────────

  Future<void> logTeamCreated(String sport) => logEvent('team_created', {'sport': sport});

  Future<void> logTeamJoined(String sport) => logEvent('team_joined', {'sport': sport});

  // ── Events ─────────────────────────────────────────────────────────────────

  Future<void> logEventCreated(String sport) => logEvent('event_created', {'sport': sport});

  Future<void> logAvailabilitySet(String status) =>
      logEvent('availability_set', {'status': status});

  // ── Drop-ins ───────────────────────────────────────────────────────────────

  Future<void> logDropInSignup() => logEvent('dropin_signup');

  // ── IAP ────────────────────────────────────────────────────────────────────

  Future<void> logRemoveAdsPurchased() => logEvent('remove_ads_purchased');

  // ── Generic ────────────────────────────────────────────────────────────────

  Future<void> logEvent(String name, [Map<String, Object>? params]) =>
      _analyticsAvailable
          ? _a.logEvent(name: name, parameters: params)
          : Future.value();
}

final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => AnalyticsService(FirebaseAnalytics.instance),
);

final analyticsObserverProvider = Provider<FirebaseAnalyticsObserver?>(
  (ref) => ref.read(analyticsServiceProvider).observer,
);
