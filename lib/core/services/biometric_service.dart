import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _biometricPrefKey = 'biometric_enabled';

class BiometricService {
  final _auth = LocalAuthentication();

  /// Whether the device has biometric hardware and enrolled credentials.
  Future<bool> isAvailable() async {
    try {
      final canCheck   = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricPrefKey) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricPrefKey, value);
  }

  /// Prompts the user to authenticate. Falls back to PIN/pattern on Android
  /// if biometrics are unavailable but the device is secured.
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Authenticate to access Sport Rosters',
        options: const AuthenticationOptions(
          stickyAuth:    true,
          biometricOnly: false, // allow PIN/pattern fallback
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

final biometricServiceProvider = Provider<BiometricService>((_) => BiometricService());

// ── Biometric lock state ───────────────────────────────────────────────────────

/// True when the app is locked and requires biometric authentication to proceed.
/// Initialised at startup: locks automatically if the user has an active Firebase
/// session and has opted in to biometric unlock.
class BiometricLockNotifier extends StateNotifier<bool> {
  BiometricLockNotifier() : super(false) {
    _initLock();
  }

  Future<void> _initLock() async {
    // Only lock if there is already an active Firebase session (persisted from
    // previous run). No lock needed when the user is signed out.
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_biometricPrefKey) ?? false)) return;

    // Only lock if hardware is still enrolled — don't trap user if they
    // removed all biometrics from device settings since last use.
    final available = await LocalAuthentication().canCheckBiometrics;
    if (available) state = true;
  }

  void unlock() => state = false;
  void lock()   => state = true;
}

final biometricLockProvider =
    StateNotifierProvider<BiometricLockNotifier, bool>(
  (_) => BiometricLockNotifier(),
);

// ── Enabled toggle (reactive, for profile screen) ────────────────────────────

class BiometricEnabledNotifier extends StateNotifier<bool> {
  BiometricEnabledNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_biometricPrefKey) ?? false;
  }

  Future<void> set(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricPrefKey, value);
    state = value;
  }
}

final biometricEnabledProvider =
    StateNotifierProvider<BiometricEnabledNotifier, bool>(
  (_) => BiometricEnabledNotifier(),
);
