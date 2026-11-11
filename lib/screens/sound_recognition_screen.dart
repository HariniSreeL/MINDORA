// Mindora - Sound Recognition Game
// Culturally relevant environmental and musical sound identification.
// Uses audioplayers for genuine audio playback on Web (Chrome), Windows, and Android.
// Includes real audio replay, previous sound cancellation, loading/error states, hints, and progression.

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../theme/mindora_theme.dart';
import '../app_settings.dart';
import '../models/level_data.dart';
import '../services/adaptive_difficulty.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../game_progress.dart';
import 'level_progression_screen.dart';

class SoundItem {
  final String id;
  final String nameEn;
  final String nameHi;
  final String audioAsset;
  final String audioDescriptionEn;
  final String audioDescriptionHi;
  final IconData icon;
  final Color tint;

  const SoundItem({
    required this.id,
    required this.nameEn,
    required this.nameHi,
    required this.audioAsset,
    required this.audioDescriptionEn,
    required this.audioDescriptionHi,
    required this.icon,
    required this.tint,
  });
}

class SoundChallenge {
  final SoundItem targetSound;
  final List<SoundItem> choices;
  final String hintEn;
  final String hintHi;

  const SoundChallenge({
    required this.targetSound,
    required this.choices,
    required this.hintEn,
    required this.hintHi,
  });
}

class SoundRecognitionScreen extends StatefulWidget {
  final int initialLevel;
  const SoundRecognitionScreen({super.key, this.initialLevel = 1});

  @override
  State<SoundRecognitionScreen> createState() => _SoundRecognitionScreenState();
}

class _SoundRecognitionScreenState extends State<SoundRecognitionScreen>
    with SingleTickerProviderStateMixin {
  late int currentLevel;
  static const int maxLevels = 4;

  final AudioPlayer _audioPlayer = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  bool _isLoadingAudio = false;
  String? _audioErrorMessage;

  static const birdSound = SoundItem(
    id: 'bird',
    nameEn: 'Hoolock Gibbon & Morning Birds',
    nameHi: 'वन पक्षियों का मधुर कलरव',
    audioAsset: 'audio/bird.wav',
    audioDescriptionEn: 'Melodic morning birds and gibbon calls in misty canopy trees.',
    audioDescriptionHi: 'सुबह के समय घने पेड़ों में चहचहाते हुए पक्षी।',
    icon: Icons.air_rounded,
    tint: Color(0xFF27AE60),
  );

  static const rainSound = SoundItem(
    id: 'rain',
    nameEn: 'Monsoon Rain on Bamboo Roof',
    nameHi: 'बांस की छत पर रिमझिम बारिश',
    audioAsset: 'audio/rain.wav',
    audioDescriptionEn: 'Gentle, steady patter of rainwater drops falling overhead.',
    audioDescriptionHi: 'छत पर गिरती हुई शांत वर्षा की बूंदों की आवाज।',
    icon: Icons.water_drop_rounded,
    tint: Color(0xFF2980B9),
  );

  static const bellSound = SoundItem(
    id: 'bell',
    nameEn: 'Monastery Prayer Bell',
    nameHi: 'मठ की पवित्र प्रार्थना घंटी',
    audioAsset: 'audio/bell.wav',
    audioDescriptionEn: 'Deep, resonant brass chime vibrating calmly.',
    audioDescriptionHi: 'पीतल की घंटी की गहरी और शांत गूंज।',
    icon: Icons.notifications_active_rounded,
    tint: Color(0xFFF39C12),
  );

  static const fluteSound = SoundItem(
    id: 'flute',
    nameEn: 'Bamboo Flute Melody',
    nameHi: 'बांसुरी की मधुर धुन',
    audioAsset: 'audio/flute.wav',
    audioDescriptionEn: 'Soft North-Eastern wooden breath melody in pentatonic scale.',
    audioDescriptionHi: 'घाटी में गूंजती हुई बांसुरी की धीमी और मधुर तान।',
    icon: Icons.music_note_rounded,
    tint: Color(0xFF8E44AD),
  );

  static const drumSound = SoundItem(
    id: 'drum',
    nameEn: 'Bihu Folk Dhol',
    nameHi: 'पारंपरिक बीहू ढोल',
    audioAsset: 'audio/drum.wav',
    audioDescriptionEn: 'Warm rhythmic folk drum beats celebrating harvest.',
    audioDescriptionHi: 'उत्सव और फसल की खुशी में बजती ढोल की ताल।',
    icon: Icons.album_rounded,
    tint: Color(0xFFD35400),
  );

  static final Map<int, List<SoundChallenge>> levelChallenges = {
    1: [
      SoundChallenge(
        targetSound: rainSound,
        choices: [rainSound, bellSound, birdSound],
        hintEn: 'Listen to the rhythmic dripping of water on thatch.',
        hintHi: 'पानी की बूंदों के शांत गिरने की ध्वनि पर ध्यान दें।',
      ),
    ],
    2: [
      SoundChallenge(
        targetSound: bellSound,
        choices: [bellSound, fluteSound, rainSound],
        hintEn: 'Listen to the ringing brass metallic vibration of meditation.',
        hintHi: 'धातु की घंटी की गूंजती आवाज को पहचानें।',
      ),
    ],
    3: [
      SoundChallenge(
        targetSound: fluteSound,
        choices: [fluteSound, drumSound, birdSound, rainSound],
        hintEn: 'A gentle breath passing through hollow bamboo notes.',
        hintHi: 'खोखले बांस से निकलती हुई सांस की धुन।',
      ),
    ],
    4: [
      SoundChallenge(
        targetSound: drumSound,
        choices: [drumSound, fluteSound, bellSound, birdSound],
        hintEn: 'Rhythmic percussive beats played during spring harvest gatherings.',
        hintHi: 'वसंत और उत्सव में बजने वाली तालबद्ध थाप।',
      ),
    ],
  };

  late AnimationController _waveController;
  SoundItem? selectedChoice;
  bool? isAnswerCorrect;
  bool showHint = false;
  int mistakes = 0;
  int hintsUsed = 0;
  late Stopwatch stopwatch;

  bool get isPlaying => _playerState == PlayerState.playing;

  String tr(String en, String hi, {String? key}) =>
      AppSettings.instance.trBilingual(en, hi, key: key);

  @override
  void initState() {
    super.initState();
    currentLevel = widget.initialLevel;
    stopwatch = Stopwatch()..start();
    ApiService.instance.beginGameSession('sound_recognition', currentLevel);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _playerState = state;
          _isLoadingAudio = false;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playerState = PlayerState.stopped;
        });
      }
    });

    // Background music stays paused for the whole Sound Recognition session so
    // target sounds, instructions and effects always have complete priority.
    AudioService.instance.pauseForPriorityAudio();
  }

  @override
  void dispose() {
    _waveController.dispose();
    stopwatch.stop();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    // Only leaving the game restores the very low background music.
    AudioService.instance.resumeAfterPriorityAudio();
    super.dispose();
  }

  void _loadLevel(int lvl) async {
    ApiService.instance.beginGameSession('sound_recognition', lvl);
    await _audioPlayer.stop();
    setState(() {
      currentLevel = lvl;
      selectedChoice = null;
      isAnswerCorrect = null;
      showHint = false;
      mistakes = 0;
      hintsUsed = 0;
      _playerState = PlayerState.stopped;
      _audioErrorMessage = null;
      stopwatch.reset();
      stopwatch.start();
    });
  }

  Future<void> _playSound() async {
    final challenges = levelChallenges[currentLevel] ?? levelChallenges[1]!;
    final challenge = challenges.first;

    setState(() {
      _isLoadingAudio = true;
      _audioErrorMessage = null;
    });

    try {
      // Pause background music so the foreground sound plays clearly without interference
      await AudioService.instance.pauseForPriorityAudio();
      // Stop any current sound before playing another
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(challenge.targetSound.audioAsset));
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAudio = false;
          _audioErrorMessage = 'Audio error: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('Could not play audio. Please try again.', 'ऑडियो नहीं चल सका। कृपया पुनः प्रयास करें।')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _replaySound() async {
    await _playSound();
  }

  void _checkChoice(SoundItem choice, SoundChallenge challenge) async {
    final correct = choice.id == challenge.targetSound.id;

    setState(() {
      selectedChoice = choice;
      isAnswerCorrect = correct;
    });

    if (correct) {
      await _audioPlayer.stop();
      _onLevelCompleted();
    } else {
      setState(() => mistakes++);
    }
  }

  /// Saves the completed attempt and tells the player if it is waiting to sync.
  void _persistSession(SessionMetrics metrics) {
    AdaptiveDifficulty.instance.recordSession(metrics).then((status) {
      if (!mounted) return;
      if (status == GameSaveStatus.queued) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(
              'Saved on this device. It will sync when you are online.',
              'इस डिवाइस पर सहेजा गया। ऑनलाइन होने पर सिंक हो जाएगा।',
            )),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (status == GameSaveStatus.failed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(
              'Could not save this game to your account yet.',
              'यह खेल अभी आपके खाते में सहेजा नहीं जा सका।',
            )),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  void _onLevelCompleted() {
    stopwatch.stop();

    _persistSession(
      SessionMetrics(
        gameId: 'sound_recognition',
        level: currentLevel,
        correctMatches: 1,
        incorrectAttempts: mistakes,
        hintsUsed: hintsUsed,
        totalAttempts: mistakes + 1,
        elapsed: stopwatch.elapsed,
        completed: true,
      ),
    );

    GameProgress.instance.addSession(
      GameSession(
        gameName: 'Sound Recognition',
        date: DateTime.now(),
        duration: stopwatch.elapsed,
        moves: mistakes + 1,
        pairsMatched: 1,
        completed: true,
      ),
    );

    LevelProgressManager.instance.completeLevel('sound_recognition', currentLevel, maxLevel: maxLevels);

    final band = AdaptiveDifficulty.instance.evaluatePerformance('sound_recognition');
    final encouragement = AdaptiveDifficulty.instance.getAdaptiveEncouragement(band, isHindi: AppSettings.instance.isHindi);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: MindoraColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          tr('Sound Identified! 🌿', 'ध्वनि पहचान ली! 🌿', key: 'well_done'),
          textAlign: TextAlign.center,
          style: MindoraTextStyles.displayMedium.copyWith(color: MindoraColors.forestGreen),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              encouragement,
              textAlign: TextAlign.center,
              style: MindoraTextStyles.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              '${tr("Duration", "समय", key: "time")}: ${stopwatch.elapsed.inSeconds}s',
              style: MindoraTextStyles.titleMedium,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          OutlinedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _loadLevel(currentLevel);
            },
            child: Text(tr('Replay', 'फिर से खेलें', key: 'replay')),
          ),
          if (currentLevel < maxLevels)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _loadLevel(currentLevel + 1);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: MindoraColors.sageGreen,
                foregroundColor: Colors.white,
              ),
              child: Text(tr('Next Level', 'अगला स्तर', key: 'next_level')),
            )
          else
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: MindoraColors.sageGreen,
                foregroundColor: Colors.white,
              ),
              child: Text(tr('Finished 🌸', 'पूर्ण 🌸', key: 'finished')),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final challenges = levelChallenges[currentLevel] ?? levelChallenges[1]!;
    final challenge = challenges.first;

    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: MindoraColors.cream,
          appBar: AppBar(
            backgroundColor: MindoraColors.cream,
            foregroundColor: MindoraColors.forestGreen,
            elevation: 0,
            title: Text(
              '${tr("Sound Recognition", "ध्वनि पहचान", key: "sound_recognition")} - ${tr("Lvl", "स्तर", key: "lvl")} $currentLevel',
              style: MindoraTextStyles.displayMedium.copyWith(fontSize: 22),
            ),
            actions: [
              IconButton(
                tooltip: tr('Levels Map', 'स्तर सूची'),
                icon: const Icon(Icons.map_rounded),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LevelProgressionScreen(
                        gameId: 'sound_recognition',
                        gameTitle: tr('Sound Recognition Levels', 'ध्वनि पहचान स्तर'),
                        totalLevels: maxLevels,
                        onSelectLevel: (lvl) {
                          Navigator.pop(context);
                          _loadLevel(lvl);
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  // Player Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: mindoraCard(color: Colors.white, radius: 24),
                    child: Column(
                      children: [
                        Text(
                          tr('Tap to Listen', 'सुनने के लिए टैप करें', key: 'tap_to_listen'),
                          style: MindoraTextStyles.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tr(
                            'Press the play button to hear the sound. Use the replay button as often as you like.',
                            'ध्वनि सुनने के लिए प्ले बटन दबाएं। आप इसे जितनी बार चाहें दोबारा सुन सकते हैं।',
                          ),
                          textAlign: TextAlign.center,
                          style: MindoraTextStyles.bodyMedium,
                        ),

                        const SizedBox(height: 20),

                        // Tactile Play / Replay button with actual audio player
                        Semantics(
                          button: true,
                          label: isPlaying ? 'Playing audio sound' : 'Play audio sound',
                          child: InkWell(
                            onTap: _isLoadingAudio ? null : _playSound,
                            borderRadius: BorderRadius.circular(55),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: 105,
                              height: 105,
                              decoration: BoxDecoration(
                                color: isPlaying ? MindoraColors.sageGreen : MindoraColors.cardGreen,
                                shape: BoxShape.circle,
                                border: Border.all(color: MindoraColors.sageGreen, width: 3.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: MindoraColors.sageGreen.withValues(alpha: isPlaying ? 0.45 : 0.15),
                                    blurRadius: isPlaying ? 18 : 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _isLoadingAudio
                                    ? const SizedBox(
                                        width: 38,
                                        height: 38,
                                        child: CircularProgressIndicator(color: MindoraColors.forestGreen, strokeWidth: 3),
                                      )
                                    : Icon(
                                        isPlaying ? Icons.volume_up_rounded : Icons.play_arrow_rounded,
                                        size: 54,
                                        color: isPlaying ? Colors.white : MindoraColors.forestGreen,
                                      ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Status & Replay Button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isPlaying) ...[
                              Text(
                                tr('Playing sound…', 'ध्वनि बज रही है…'),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: MindoraColors.sageGreen),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: tr('Stop', 'रोकें', key: 'stop'),
                                icon: const Icon(Icons.stop_circle_rounded, color: MindoraColors.terracotta, size: 28),
                                onPressed: () async {
                                  await _audioPlayer.stop();
                                },
                              ),
                            ] else ...[
                              ElevatedButton.icon(
                                onPressed: _replaySound,
                                icon: const Icon(Icons.replay_rounded, size: 20),
                                label: Text(tr('Replay Sound', 'पुनः सुनें', key: 'replay')),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: MindoraColors.sageGreen,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ],
                          ],
                        ),

                        if (_audioErrorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _audioErrorMessage!,
                              style: const TextStyle(color: MindoraColors.terracotta, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Prompt question
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      tr('What sound did you hear?', 'आपने क्या सुना?', key: 'what_sound'),
                      style: MindoraTextStyles.titleMedium,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Choice Cards
                  ...challenge.choices.map((item) {
                    final isSelected = selectedChoice?.id == item.id;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Semantics(
                        button: true,
                        selected: isSelected,
                        label: tr(item.nameEn, item.nameHi),
                        child: InkWell(
                          onTap: () => _checkChoice(item, challenge),
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isAnswerCorrect == true ? MindoraColors.cardGreen : MindoraColors.cardRose)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelected
                                    ? (isAnswerCorrect == true ? MindoraColors.sageGreen : MindoraColors.terracotta)
                                    : MindoraColors.borderLight,
                                width: isSelected ? 2.5 : 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: item.tint.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(item.icon, color: item.tint, size: 26),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tr(item.nameEn, item.nameHi),
                                        style: MindoraTextStyles.titleMedium.copyWith(fontSize: 17),
                                      ),
                                      Text(
                                        tr(item.audioDescriptionEn, item.audioDescriptionHi),
                                        style: MindoraTextStyles.caption,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 14),

                  // Hint control
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            hintsUsed++;
                            showHint = !showHint;
                          });
                        },
                        icon: const Icon(Icons.lightbulb_outline_rounded, color: MindoraColors.terracotta),
                        label: Text(
                          showHint
                              ? tr('Hide Hint', 'संकेत छिपाएं', key: 'hide_hint')
                              : tr('Show Hint', 'संकेत देखें', key: 'show_hint'),
                          style: const TextStyle(color: MindoraColors.terracotta),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _loadLevel(currentLevel),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(tr('Reset', 'रीसेट', key: 'reset')),
                        style: OutlinedButton.styleFrom(foregroundColor: MindoraColors.forestGreen),
                      ),
                    ],
                  ),

                  if (showHint)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: mindoraCard(color: MindoraColors.cardAmber),
                        child: Text(
                          tr(challenge.hintEn, challenge.hintHi),
                          style: MindoraTextStyles.bodyMedium.copyWith(color: MindoraColors.forestGreen),
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
