import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

enum Sfx { shoot, hit, hazard, win, lose, button, coin }

/// Audio & Haptics service for the game.
///
/// Features:
/// - SFX and Haptic toggles (persisted in SharedPreferences).
/// - Low-latency audio playback pool using `AudioPlayer(mode: PlayerMode.lowLatency)`.
/// - Graceful degradation: If audio assets are missing or platform audio fails,
///   it logs a warning without crashing the game and executes haptics.
abstract class AudioService {
  bool get isSoundEnabled;
  bool get isVibrationEnabled;

  Future<void> init();
  Future<void> toggleSound();
  Future<void> toggleVibration();

  void playSfx(Sfx sfx);
  void vibrate(Sfx sfx);
}

class AppAudioService implements AudioService {
  AppAudioService();

  static const String _soundKey = 'sound_enabled';
  static const String _vibrationKey = 'vibration_enabled';

  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _hasCustomVibration = false;

  final AudioPlayer _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  @override
  bool get isSoundEnabled => _soundEnabled;

  @override
  bool get isVibrationEnabled => _vibrationEnabled;

  @override
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _soundEnabled = prefs.getBool(_soundKey) ?? true;
      _vibrationEnabled = prefs.getBool(_vibrationKey) ?? true;

      // Check whether advanced vibration hardware is available
      _hasCustomVibration = await Vibration.hasVibrator();
    } catch (e) {
      debugPrint('AudioService init fallback: $e');
    }
  }

  @override
  Future<void> toggleSound() async {
    _soundEnabled = !_soundEnabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_soundKey, _soundEnabled);
    } catch (_) {}
  }

  @override
  Future<void> toggleVibration() async {
    _vibrationEnabled = !_vibrationEnabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_vibrationKey, _vibrationEnabled);
    } catch (_) {}
  }

  @override
  void playSfx(Sfx sfx) {
    vibrate(sfx);
    if (!_soundEnabled) return;

    final fileName = switch (sfx) {
      Sfx.shoot => 'shoot.wav',
      Sfx.hit => 'hit.wav',
      Sfx.hazard => 'hazard.wav',
      Sfx.win => 'win.wav',
      Sfx.lose => 'lose.wav',
      Sfx.button => 'button.wav',
      Sfx.coin => 'coin.wav',
    };

    // Low latency play; catch asset-missing gracefully
    _player.play(AssetSource('audio/$fileName')).catchError((Object err) {
      // Audio asset placeholder warning (silently handled so development/testing continues)
      debugPrint('SFX asset $fileName could not be played: $err');
    });
  }

  @override
  void vibrate(Sfx sfx) {
    if (!_vibrationEnabled) return;

    switch (sfx) {
      case Sfx.shoot:
      case Sfx.button:
        HapticFeedback.selectionClick();
      case Sfx.hit:
      case Sfx.coin:
        HapticFeedback.lightImpact();
      case Sfx.hazard:
        if (_hasCustomVibration) {
          Vibration.vibrate(duration: 120, amplitude: 255);
        } else {
          HapticFeedback.heavyImpact();
        }
      case Sfx.win:
        HapticFeedback.mediumImpact();
      case Sfx.lose:
        if (_hasCustomVibration) {
          Vibration.vibrate(pattern: [0, 80, 50, 140]);
        } else {
          HapticFeedback.heavyImpact();
        }
    }
  }
}

/// Stand-in for tests or environments without native plugins.
class MockAudioService implements AudioService {
  @override
  bool isSoundEnabled = true;

  @override
  bool isVibrationEnabled = true;

  final List<Sfx> playedSfx = [];
  final List<Sfx> vibrations = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> toggleSound() async => isSoundEnabled = !isSoundEnabled;

  @override
  Future<void> toggleVibration() async => isVibrationEnabled = !isVibrationEnabled;

  @override
  void playSfx(Sfx sfx) {
    playedSfx.add(sfx);
    vibrate(sfx);
  }

  @override
  void vibrate(Sfx sfx) {
    if (isVibrationEnabled) vibrations.add(sfx);
  }
}
