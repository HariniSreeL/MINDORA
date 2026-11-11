// Focused tests for the much softer background music, migration of old loud
// preferences, mute handling, single-instance start guards and the priority
// pause/resume behaviour used by Sound Recognition.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/services/audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final audio = AudioService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await audio.debugReset();
  });

  test('default background volume is very low and old loud values migrate', () async {
    expect(AudioService.softDefaultVolume, lessThanOrEqualTo(0.05));
    expect(AudioService.maxBackgroundVolume, lessThanOrEqualTo(0.10));

    // A stored 0.5 from an older build must not come back at full loudness.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'musicVolume': 0.5,
    });
    await audio.initialize();
    expect(audio.volume, AudioService.softDefaultVolume);
    expect(audio.volume, lessThan(0.1));
  });

  test('setVolume clamps to the soft range and persists the soft value', () async {
    await audio.initialize();

    await audio.setVolume(0.5);
    expect(audio.volume, AudioService.softDefaultVolume);

    await audio.setVolume(0.08);
    expect(audio.volume, closeTo(0.08, 0.0001));

    await audio.setVolume(-1);
    expect(audio.volume, 0);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('musicVolume'), 0);

    expect(AudioService.normalizeVolume(1.0), AudioService.softDefaultVolume);
    expect(AudioService.normalizeVolume(0.06), closeTo(0.06, 0.0001));
  });

  test('mute stops music and priority resume respects mute', () async {
    await audio.initialize();
    audio.debugSetPlaying(true);

    await audio.setEnabled(false);
    expect(audio.isEnabled, isFalse);
    expect(audio.isPlaying, isFalse);

    await audio.pauseForPriorityAudio();
    await audio.resumeAfterPriorityAudio();
    expect(audio.isPlaying, isFalse);

    await audio.setEnabled(true);
    expect(audio.isPlaying, isTrue);
    expect(audio.volume, AudioService.softDefaultVolume);
  });

  test('priority pause keeps one resume intent across repeated pauses', () async {
    await audio.initialize();
    audio.debugSetPlaying(true);
    expect(audio.isPlaying, isTrue);

    // Entering Sound Recognition pauses once.
    await audio.pauseForPriorityAudio();
    expect(audio.isPlaying, isFalse);
    expect(audio.wasPlayingBeforePriority, isTrue);

    // Replaying or answering must not clear the resume intent.
    await audio.pauseForPriorityAudio();
    expect(audio.wasPlayingBeforePriority, isTrue);

    await audio.resumeAfterPriorityAudio();
    expect(audio.isPlaying, isTrue);
    expect(audio.volume, AudioService.softDefaultVolume);
    expect(audio.wasPlayingBeforePriority, isFalse);
  });

  test('startMusic never duplicates work when already playing', () async {
    await audio.initialize();
    expect(audio.isPlaying, isFalse); // test environment skips real playback

    await audio.startMusic();
    expect(audio.isPlaying, isTrue);

    await audio.startMusic();
    await audio.startMusic();
    expect(audio.isPlaying, isTrue);

    await audio.stopMusic();
    expect(audio.isPlaying, isFalse);
  });
}
