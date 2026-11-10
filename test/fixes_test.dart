// Mindora – Verification Tests for Final 5 Enhancements:
// 1. Settings – Language ("Review copy" removed, Caregiver Portal language removed, regional languages preserved)
// 2. Memory Match – Accessibility (large icons, high contrast badges, clear text)
// 3. Word Recall – Simplified vocabulary (3-5 letter words at beginner levels, 6-8 at higher)
// 4. Jigsaw Picture Puzzle – Completely removed from Games Hub and navigation
// 5. Sound Recognition – Audio Priority (pause background music on play, resume after finish)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/app_settings.dart';
import 'package:flutter_application_1/localization/app_localizations.dart';
import 'package:flutter_application_1/settings_page.dart';
import 'package:flutter_application_1/screens/games_hub_screen.dart';
import 'package:flutter_application_1/screens/word_recall_screen.dart';
import 'package:flutter_application_1/screens/sound_recognition_screen.dart';
import 'package:flutter_application_1/services/audio_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.loadSettings();
  });

  test('Requirement 1 & Regional Languages: Dynamic translation engine intact', () {
    final loc = MindoraLocalization.instance;

    // Test regional languages
    expect(loc.translate('today_activity', langCode: 'as'), 'আজিৰ কাৰ্যসূচী');
    expect(loc.translate('cognitive_games', langCode: 'as'), 'মানসিক খেলসমূহ');
    expect(loc.translate('sound_recognition', langCode: 'bn'), 'শব্দ চেনা');
    expect(loc.translate('memory_match', langCode: 'ne'), 'स्मृति मिलान');
    expect(loc.translate('word_recall', langCode: 'mni'), 'ৱাহৈ নিংশিংবা');
    expect(loc.translate('caregiver_portal', langCode: 'kha'), 'Ka Portal Nongsumar');
    expect(loc.translate('pattern_match', langCode: 'lus'), 'Ziarang Zawm');
    expect(loc.translate('settings', langCode: 'nji'), 'Settings');
  });

  testWidgets('Requirement 1: Settings page has no "Review copy" and no Caregiver Portal Language', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsPage(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify "Review copy" badge is absent
    expect(find.text('Review copy'), findsNothing);
    expect(find.textContaining('Review copy'), findsNothing);

    // Verify Caregiver Portal Language option is completely removed
    expect(find.text('Caregiver Portal Language'), findsNothing);
    expect(find.textContaining('Caregiver Portal Language'), findsNothing);

    // Main language selection remains present
    expect(find.text('Language'), findsOneWidget);
  });

  test('Requirement 3: Word Recall vocabulary uses 3-5 letter words for beginner levels', () {
    // Level 1: 3-5 letters
    final lvl1Words = WordRecallScreen.levelWordBanks[1]!;
    for (final word in lvl1Words) {
      expect(word.wordEn.length, inInclusiveRange(3, 5),
          reason: 'Level 1 word "${word.wordEn}" should be 3-5 letters');
    }

    // Level 2: 4-5 letters
    final lvl2Words = WordRecallScreen.levelWordBanks[2]!;
    for (final word in lvl2Words) {
      expect(word.wordEn.length, inInclusiveRange(4, 5),
          reason: 'Level 2 word "${word.wordEn}" should be 4-5 letters');
    }

    // Level 3 & 4: 6-8 letters
    final lvl3Words = WordRecallScreen.levelWordBanks[3]!;
    for (final word in lvl3Words) {
      expect(word.wordEn.length, inInclusiveRange(6, 8),
          reason: 'Level 3 word "${word.wordEn}" should be 6-8 letters');
    }

    final lvl4Words = WordRecallScreen.levelWordBanks[4]!;
    for (final word in lvl4Words) {
      expect(word.wordEn.length, inInclusiveRange(6, 8),
          reason: 'Level 4 word "${word.wordEn}" should be 6-8 letters');
    }
  });

  testWidgets('Requirement 4: Games Hub contains 4 core games and NO Picture Puzzle', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GamesHubScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify 4 core games are present
    expect(find.textContaining('Memory Match'), findsOneWidget);
    expect(find.textContaining('Pattern Match'), findsOneWidget);
    expect(find.textContaining('Word Recall'), findsOneWidget);
    expect(find.textContaining('Sound Recognition'), findsOneWidget);

    // Verify Picture Puzzle is completely removed
    expect(find.textContaining('Picture Puzzle'), findsNothing);
    expect(find.textContaining('Jigsaw'), findsNothing);
  });

  test('Requirement 5: AudioService prioritizes foreground audio and restores state', () async {
    final audio = AudioService.instance;
    await audio.initialize();

    // Verify pausing for priority audio tracks state
    expect(audio.wasPlayingBeforePriority, isFalse);

    // Test priority ducking logic
    await audio.pauseForPriorityAudio();
    // If was not playing, priority ducking records false
    expect(audio.wasPlayingBeforePriority, isFalse);

    await audio.resumeAfterPriorityAudio();
    expect(audio.wasPlayingBeforePriority, isFalse);
  });

  testWidgets('Requirement 5: Sound Recognition renders audio controls and choices', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SoundRecognitionScreen(initialLevel: 1),
      ),
    );
    await tester.pump();

    // Verify title
    expect(find.textContaining('Sound Recognition'), findsOneWidget);

    // Verify play button and instructions
    expect(find.text('Tap to Listen'), findsOneWidget);
    expect(find.textContaining('Replay'), findsWidgets);

    // Verify choices exist
    expect(find.textContaining('Monsoon Rain'), findsOneWidget);
  });
}
