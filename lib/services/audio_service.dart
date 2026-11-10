// Mindora - Background Music & Audio Service
// Plays gentle ambient instrumental background music (flute/santoor).
// Persists across screen navigation without restarting.
// Responsive to user enable/disable and volume slider preferences.

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioService extends ChangeNotifier {
  AudioService._();
  static final AudioService instance = AudioService._();

  final AudioPlayer _musicPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isEnabled = true;
  double _volume = 0.5;
  bool _isInitialized = false;
  bool _wasPlayingBeforePriority = false;

  bool get isPlaying => _isPlaying;
  bool get isEnabled => _isEnabled;
  double get volume => _volume;
  bool get wasPlayingBeforePriority => _wasPlayingBeforePriority;

  bool get _isTestEnv {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool('backgroundMusic') ?? true;
      _volume = prefs.getDouble('musicVolume') ?? 0.5;

      if (!_isTestEnv) {
        await _musicPlayer.setReleaseMode(ReleaseMode.loop);
        await _musicPlayer.setVolume(_volume);

        _musicPlayer.onPlayerStateChanged.listen((state) {
          final active = state == PlayerState.playing;
          if (_isPlaying != active) {
            _isPlaying = active;
            notifyListeners();
          }
        });

        if (_isEnabled) {
          await startMusic();
        }
      }
    } catch (e) {
      debugPrint('Background audio init error: $e');
    }

    notifyListeners();
  }

  Future<void> startMusic() async {
    if (_isTestEnv) return;
    try {
      await _musicPlayer.stop();
      await _musicPlayer.setVolume(_volume);
      await _musicPlayer.play(AssetSource('audio/ambient_flute.wav'));
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Background audio start exception: $e');
    }
  }

  Future<void> pauseMusic() async {
    if (_isTestEnv) return;
    try {
      await _musicPlayer.pause();
      _isPlaying = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Background audio pause exception: $e');
    }
  }

  Future<void> resumeMusic() async {
    if (_isTestEnv) return;
    try {
      await _musicPlayer.resume();
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Background audio resume exception: $e');
    }
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pauseMusic();
    } else {
      if (_isEnabled) {
        await resumeMusic();
      } else {
        await setEnabled(true);
      }
    }
  }

  /// Automatically pause background music for a priority audio prompt (e.g., Sound Recognition).
  /// Preserves prior playing state so it can be resumed when the sound finishes.
  Future<void> pauseForPriorityAudio() async {
    if (_isPlaying) {
      _wasPlayingBeforePriority = true;
      await pauseMusic();
    }
  }

  /// Resumes background music after a priority foreground sound finishes, stops, or navigates away,
  /// provided background music was active beforehand and remains enabled.
  Future<void> resumeAfterPriorityAudio() async {
    if (_wasPlayingBeforePriority) {
      _wasPlayingBeforePriority = false;
      if (_isEnabled) {
        await resumeMusic();
      }
    }
  }

  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    if (!enabled) {
      _wasPlayingBeforePriority = false;
      if (!_isTestEnv) {
        await _musicPlayer.stop();
      }
      _isPlaying = false;
    } else {
      await startMusic();
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('backgroundMusic', enabled);
    } catch (_) {}
  }

  Future<void> setVolume(double val) async {
    _volume = val.clamp(0.0, 1.0);
    if (!_isTestEnv) {
      try {
        await _musicPlayer.setVolume(_volume);
      } catch (_) {}
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('musicVolume', _volume);
    } catch (_) {}
  }
}
