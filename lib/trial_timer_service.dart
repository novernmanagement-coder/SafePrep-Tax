import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Accumulates foreground-only usage time for unpaid users.
/// When 30 minutes is reached, calls [onTrialExpired].
///
/// Elapsed time is persisted to the iOS Keychain (via
/// flutter_secure_storage) instead of SharedPreferences. Keychain items
/// are NOT removed when the app is deleted, so a delete + reinstall no
/// longer resets the trial back to a fresh 30 minutes — this is the
/// standard mitigation for the "delete the app to reset the free trial"
/// abuse pattern on iOS.
///
/// NOTE: on Android, flutter_secure_storage is backed by a Keystore-based
/// EncryptedSharedPreferences file, which IS cleared on uninstall — this
/// mitigation is effectively iOS-only. SafePrep ships iOS-only today, so
/// that's fine; revisit if an Android build is ever planned.
class TrialTimerService with WidgetsBindingObserver {
  static const int _trialSeconds = 30 * 60; // 30 minutes
  static const String _elapsedKey = 'trial_elapsed_seconds';
  static const String _expiredKey = 'trial_expired';

  // Legacy SharedPreferences key from the pre-Keychain implementation.
  // Only read once, during migration, then left alone.
  static const String _legacyPrefKey = 'trial_elapsed_seconds';

  static final TrialTimerService instance = TrialTimerService._();
  TrialTimerService._();

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      // first_unlock (not first_unlock_this_device_only) persists across
      // app deletion — that's the behavior this fix depends on. Do not
      // change this to a *_this_device_only or biometry-gated option.
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  VoidCallback? onTrialExpired;

  int _elapsedSeconds = 0;
  Timer? _ticker;
  bool _running = false;
  bool _expired = false;
  bool _initialized = false;

  /// Call once after AppStatePersistence.load() for non-unlocked users.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final expiredFlag = await _storage.read(key: _expiredKey);
    if (expiredFlag == 'true') {
      _expired = true;
      return;
    }

    var stored = await _storage.read(key: _elapsedKey);

    // One-time migration: if this install has old SharedPreferences data
    // from before the Keychain switch, carry it forward so an in-progress
    // trial isn't unfairly reset to 0 the first time this ships.
    if (stored == null) {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getInt(_legacyPrefKey);
      if (legacy != null) {
        stored = legacy.toString();
        await _storage.write(key: _elapsedKey, value: stored);
        await prefs.remove(_legacyPrefKey);
      }
    }

    _elapsedSeconds = int.tryParse(stored ?? '') ?? 0;

    if (_elapsedSeconds >= _trialSeconds) {
      _expired = true;
      await _storage.write(key: _expiredKey, value: 'true');
      return;
    }
    WidgetsBinding.instance.addObserver(this);
  }

  /// Start the timer — call when HomePage first mounts.
  void start() {
    if (_expired || _running) return;
    _running = true;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() async {
    _elapsedSeconds++;
    // Persist every 10 seconds to avoid hammering the Keychain.
    if (_elapsedSeconds % 10 == 0) {
      await _persistElapsed();
    }
    if (_elapsedSeconds >= _trialSeconds) {
      await _persistElapsed();
      _stop();
      _expired = true;
      await _storage.write(key: _expiredKey, value: 'true');
      onTrialExpired?.call();
    }
  }

  Future<void> _persistElapsed() async {
    await _storage.write(key: _elapsedKey, value: _elapsedSeconds.toString());
  }

  void _stop() {
    _ticker?.cancel();
    _ticker = null;
    _running = false;
    // Flush immediately on every stop (backgrounding, expiry, etc) instead
    // of only every 10th tick — otherwise up to 9 seconds of usage can be
    // lost if the OS kills the app while it's backgrounded.
    _persistElapsed();
  }

  /// Pause when app goes to background, resume on foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _stop();
    if (state == AppLifecycleState.resumed && !_expired) start();
  }

  /// Reset trial — call after a successful purchase.
  Future<void> resetTrial() async {
    _stop();
    _expired = false;
    _elapsedSeconds = 0;
    WidgetsBinding.instance.removeObserver(this);
    await _storage.delete(key: _elapsedKey);
    await _storage.delete(key: _expiredKey);
  }

  bool get isExpired => _expired;

  /// Seconds remaining in the trial, clamped to 0.
  /// Used by HomePage to display a live "Trial — mm:ss" countdown.
  int get remainingSeconds =>
      (_trialSeconds - _elapsedSeconds).clamp(0, _trialSeconds);
}
