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

  /// Background music is deliberately barely audible so it never competes with
  /// game prompts. The preference slider only moves within this soft range.
  static const double softDefaultVolume = 0.05;
  static const double maxBackgroundVolume = 0.10;

  AudioPlayer? _musicPlayer;
  bool _isPlaying = false;
  bool _isEnabled = true;
  double _volume = softDefaultVolume;
  bool _isInitialized = false;
  bool _wasPlayingBeforePriority = false;
  bool _starting = false;

  bool get isPlaying => _isPlaying;
  bool get isEnabled => _isEnabled;
  double get volume => _volume;
  bool get wasPlayingBeforePriority => _wasPlayingBeforePriority;

  /// Keeps older loud preferences (for example a stored 0.5) from suddenly
  /// becoming loud again, while still honouring quiet values inside the range.
  static double normalizeVolume(double value) {
    if (value > maxBackgroundVolume) return softDefaultVolume;
    return value.clamp(0.0, maxBackgroundVolume);
  }

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
      // Older builds stored 0.5 as the default. Migrate anything above the
      // soft ceiling down to the gentle default instead of blasting the user.
      _volume = normalizeVolume(prefs.getDouble('musicVolume') ?? softDefaultVolume);

      if (!_isTestEnv) {
        _musicPlayer = AudioPlayer();
        await _musicPlayer!.setReleaseMode(ReleaseMode.loop);
        await _musicPlayer!.setVolume(_volume);

        _musicPlayer!.onPlayerStateChanged.listen((state) {
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
    if (!_isEnabled) return;
    // Guard against overlapping starts from the gate, settings and editor
    // re-entry: exactly one looping player is ever created.
    if (_starting || _isPlaying) return;
    _starting = true;
    try {
      if (!_isTestEnv) {
        _musicPlayer ??= AudioPlayer();
        await _musicPlayer!.setReleaseMode(ReleaseMode.loop);
        await _musicPlayer!.setVolume(_volume);
        await _musicPlayer!.play(AssetSource('audio/ambient_flute.wav'));
      }
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Background audio start exception: $e');
    } finally {
      _starting = false;
    }
  }

  Future<void> pauseMusic() async {
    if (_isTestEnv) {
      if (_isPlaying) {
        _isPlaying = false;
        notifyListeners();
      }
      return;
    }
    try {
      await _musicPlayer?.pause();
      _isPlaying = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Background audio pause exception: $e');
    }
  }

  Future<void> resumeMusic() async {
    if (!_isEnabled) return;
    if (_isTestEnv) {
      if (!_isPlaying) {
        _isPlaying = true;
        notifyListeners();
      }
      return;
    }
    try {
      // Resume at the stored soft volume even if another screen changed it.
      await _musicPlayer?.setVolume(_volume);
      await _musicPlayer?.resume();
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Background audio resume exception: $e');
    }
  }

  /// Fully stops background audio. Used on logout so the next person starts
  /// from silence instead of inheriting a previous listener's music.
  Future<void> stopMusic() async {
    _wasPlayingBeforePriority = false;
    if (!_isTestEnv) {
      try {
        await _musicPlayer?.stop();
      } catch (e) {
        debugPrint('Background audio stop exception: $e');
      }
    }
    if (_isPlaying) {
      _isPlaying = false;
      notifyListeners();
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
    // Already paused for priority audio: keep the original flag so the music
    // resumes once the player leaves the priority screen.
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
        try {
          await _musicPlayer?.stop();
        } catch (_) {}
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
    // Clamp into the deliberately soft range and keep the stored preference
    // in sync so navigation never restores the previous loud value.
    _volume = normalizeVolume(val);
    if (!_isTestEnv) {
      try {
        await _musicPlayer?.setVolume(_volume);
      } catch (_) {}
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('musicVolume', _volume);
    } catch (_) {}
  }

  @visibleForTesting
  void debugSetPlaying(bool playing) {
    _isPlaying = playing;
    if (!playing) _wasPlayingBeforePriority = false;
    notifyListeners();
  }

  @visibleForTesting
  Future<void> debugReset() async {
    _wasPlayingBeforePriority = false;
    _isEnabled = true;
    _volume = softDefaultVolume;
    _isPlaying = false;
    _starting = false;
    _isInitialized = false;
    notifyListeners();
  }
}
