// Mindora - Pattern Match Game
// Sequence deduction, geometric motifs (handloom diamond, bamboo weave, regional colors & flowers).
// Distinct from Memory Match: Focuses on identifying missing pattern elements in visual sequences.

import 'package:flutter/material.dart';
import '../theme/mindora_theme.dart';
import '../app_settings.dart';
import '../models/level_data.dart';
import '../services/adaptive_difficulty.dart';
import '../services/api_service.dart';
import '../game_progress.dart';
import 'level_progression_screen.dart';

class PatternElement {
  final String id;
  final String nameEn;
  final String nameHi;
  final IconData icon;
  final Color color;

  const PatternElement({
    required this.id,
    required this.nameEn,
    required this.nameHi,
    required this.icon,
    required this.color,
  });
}

class PatternChallenge {
  final String descriptionEn;
  final String descriptionHi;
  final List<PatternElement> sequence; // The sequence with the last or middle item missing
  final PatternElement correctAnswer;
  final List<PatternElement> options;
  final String hintEn;
  final String hintHi;

  const PatternChallenge({
    required this.descriptionEn,
    required this.descriptionHi,
    required this.sequence,
    required this.correctAnswer,
    required this.options,
    required this.hintEn,
    required this.hintHi,
  });
}

class PatternMatchScreen extends StatefulWidget {
  final int initialLevel;
  const PatternMatchScreen({super.key, this.initialLevel = 1});

  @override
  State<PatternMatchScreen> createState() => _PatternMatchScreenState();
}

class _PatternMatchScreenState extends State<PatternMatchScreen> {
  late int currentLevel;
  static const int maxLevels = 4;

  // Catalog of motifs
  static const squareMotif = PatternElement(id: 'sq', nameEn: 'Weave Square', nameHi: 'बुनाई चौकोर', icon: Icons.crop_square_rounded, color: Color(0xFFC0392B));
  static const diamondMotif = PatternElement(id: 'dia', nameEn: 'Handloom Lozenge', nameHi: 'हथकरघा हीरा', icon: Icons.change_history_rounded, color: Color(0xFF27AE60));
  static const circleMotif = PatternElement(id: 'cir', nameEn: 'Bamboo Ring', nameHi: 'बांस का चक्र', icon: Icons.circle_outlined, color: Color(0xFFD4AC0D));
  static const flowerMotif = PatternElement(id: 'flw', nameEn: 'Kopou Orchid', nameHi: 'ऑर्किड फूल', icon: Icons.local_florist_rounded, color: Color(0xFF8E44AD));
  static const leafMotif = PatternElement(id: 'lef', nameEn: 'Tea Leaf', nameHi: 'चाय पत्ती', icon: Icons.eco_rounded, color: Color(0xFF1E8449));
  static const sunMotif = PatternElement(id: 'sun', nameEn: 'Rising Sun', nameHi: 'सूर्य किरण', icon: Icons.wb_sunny_rounded, color: Color(0xFFE67E22));
  static const waterMotif = PatternElement(id: 'wtr', nameEn: 'River Wave', nameHi: 'नदी की तरंग', icon: Icons.water_rounded, color: Color(0xFF2980B9));

  // Levels containing challenges
  static final Map<int, List<PatternChallenge>> levelChallenges = {
    // Level 1: Simple 2-element ABAB alternating sequence
    1: [
      PatternChallenge(
        descriptionEn: 'Follow the alternating handloom pattern. What comes next?',
        descriptionHi: 'बारी-बारी से आने वाले पैटर्न को देखें। आगे क्या आएगा?',
        sequence: [squareMotif, diamondMotif, squareMotif, diamondMotif],
        correctAnswer: squareMotif,
        options: [squareMotif, diamondMotif, circleMotif],
        hintEn: 'Notice how the red square and green diamond take turns.',
        hintHi: 'ध्यान दें कि लाल चौकोर और हरा त्रिकोण बारी-बारी से आ रहे हैं।',
      ),
      PatternChallenge(
        descriptionEn: 'Look at the nature rhythm. What completes this sequence?',
        descriptionHi: 'प्रकृति के क्रम को देखें। इस क्रम को क्या पूरा करता है?',
        sequence: [leafMotif, sunMotif, leafMotif, sunMotif],
        correctAnswer: leafMotif,
        options: [sunMotif, leafMotif, waterMotif],
        hintEn: 'Leaf, then Sun, then Leaf, then Sun... what starts the next pair?',
        hintHi: 'पत्ती, फिर सूरज, फिर पत्ती, फिर सूरज... अगला क्या होगा?',
      ),
    ],
    // Level 2: 3-element ABCABC sequence
    2: [
      PatternChallenge(
        descriptionEn: 'Identify the next motif in this regional textile border.',
        descriptionHi: 'इस पारंपरिक वस्त्र बॉर्डर में अगले रूपांकन को पहचानें।',
        sequence: [squareMotif, circleMotif, diamondMotif, squareMotif, circleMotif],
        correctAnswer: diamondMotif,
        options: [circleMotif, diamondMotif, leafMotif],
        hintEn: 'Square is followed by Circle, which is followed by Diamond.',
        hintHi: 'चौकोर के बाद चक्र आता है, और चक्र के बाद हीरा आता है।',
      ),
      PatternChallenge(
        descriptionEn: 'Complete the garden cycle.',
        descriptionHi: 'उद्यान चक्र को पूरा करें।',
        sequence: [sunMotif, waterMotif, flowerMotif, sunMotif, waterMotif],
        correctAnswer: flowerMotif,
        options: [flowerMotif, leafMotif, sunMotif],
        hintEn: 'Sun gives warmth, Water nourishes, and Flower blooms.',
        hintHi: 'धूप, फिर पानी, और उसके बाद खिलता है फूल।',
      ),
    ],
    // Level 3: AABAAB repeated grouped sequence
    3: [
      PatternChallenge(
        descriptionEn: 'Look at the rhythm: two leaves followed by a flower.',
        descriptionHi: 'ताल को देखें: दो पत्तियां और फिर एक फूल।',
        sequence: [leafMotif, leafMotif, flowerMotif, leafMotif, leafMotif],
        correctAnswer: flowerMotif,
        options: [leafMotif, flowerMotif, diamondMotif],
        hintEn: 'Two green leaves are always paired before a flower blooms.',
        hintHi: 'फूल खिलने से पहले हमेशा दो हरी पत्तियां आती हैं।',
      ),
    ],
    // Level 4: Complex multi-attribute motif progression
    4: [
      PatternChallenge(
        descriptionEn: 'Symphony of the hills: what completes the day?',
        descriptionHi: 'पहाड़ियों का क्रम: दिन का चक्र किससे पूरा होता है?',
        sequence: [sunMotif, waterMotif, leafMotif, flowerMotif, sunMotif, waterMotif, leafMotif],
        correctAnswer: flowerMotif,
        options: [circleMotif, leafMotif, flowerMotif],
        hintEn: 'Look back at the first 4 elements: Sun, Water, Leaf, then Flower.',
        hintHi: 'पहले 4 तत्वों को देखें: सूरज, पानी, पत्ती, और फिर फूल।',
      ),
    ],
  };

  int currentChallengeIndex = 0;
  int mistakes = 0;
  int hintsUsed = 0;
  bool showHint = false;
  PatternElement? selectedAnswer;
  bool? isAnswerCorrect;
  late Stopwatch stopwatch;

  bool get isHindi => AppSettings.instance.isHindi;
  String tr(String en, String hi, {String? key}) =>
      AppSettings.instance.trBilingual(en, hi, key: key);

  @override
  void initState() {
    super.initState();
    currentLevel = widget.initialLevel;
    stopwatch = Stopwatch()..start();
    ApiService.instance.beginGameSession('pattern_match', currentLevel);
  }

  void _loadLevel(int lvl) {
    ApiService.instance.beginGameSession('pattern_match', lvl);
    setState(() {
      currentLevel = lvl;
      currentChallengeIndex = 0;
      mistakes = 0;
      hintsUsed = 0;
      showHint = false;
      selectedAnswer = null;
      isAnswerCorrect = null;
      stopwatch.reset();
      stopwatch.start();
    });
  }

  void _checkAnswer(PatternElement chosen, PatternChallenge challenge) {
    final correct = chosen.id == challenge.correctAnswer.id;

    setState(() {
      selectedAnswer = chosen;
      isAnswerCorrect = correct;
    });

    if (correct) {
      // Record metrics
      final challenges = levelChallenges[currentLevel] ?? levelChallenges[1]!;

      Future.delayed(const Duration(milliseconds: 1000), () {
        if (!mounted) return;

        if (currentChallengeIndex + 1 < challenges.length) {
          setState(() {
            currentChallengeIndex++;
            selectedAnswer = null;
            isAnswerCorrect = null;
            showHint = false;
          });
        } else {
          // Level Completed
          _onLevelCompleted();
        }
      });
    } else {
      setState(() {
        mistakes++;
      });
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
        gameId: 'pattern_match',
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
        gameName: 'Pattern Match',
        date: DateTime.now(),
        duration: stopwatch.elapsed,
        moves: mistakes + 1,
        pairsMatched: 1,
        completed: true,
      ),
    );

    LevelProgressManager.instance.completeLevel('pattern_match', currentLevel, maxLevel: maxLevels);

    final band = AdaptiveDifficulty.instance.evaluatePerformance('pattern_match');
    final encouragement = AdaptiveDifficulty.instance.getAdaptiveEncouragement(band, isHindi: isHindi);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: MindoraColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          tr('Pattern Solved! 🌿', 'पैटर्न पूरा हुआ! 🌿'),
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
            const SizedBox(height: 16),
            Text(
              '${tr("Time Taken", "लिया गया समय")}: ${stopwatch.elapsed.inSeconds}s',
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
            child: Text(tr('Replay', 'फिर से खेलें')),
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
              child: Text(tr('Next Level', 'अगला स्तर')),
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
              child: Text(tr('Finished 🌸', 'पूर्ण 🌸')),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final challenges = levelChallenges[currentLevel] ?? levelChallenges[1]!;
    final challenge = challenges[currentChallengeIndex.clamp(0, challenges.length - 1)];

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
              '${tr("Pattern Match", "पैटर्न पहचान")} - ${tr("Lvl", "स्तर")} $currentLevel',
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
                        gameId: 'pattern_match',
                        gameTitle: tr('Pattern Match Levels', 'पैटर्न पहचान स्तर'),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Prompt card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: mindoraGradientCard(
                      colors: [
                        MindoraColors.cardAmber,
                        MindoraColors.cardGreen.withValues(alpha: 0.3),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isHindi ? challenge.descriptionHi : challenge.descriptionEn,
                          style: MindoraTextStyles.titleLarge.copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr(
                            'Examine the sequence below, then tap the motif that should come next.',
                            'नीचे दिए गए क्रम को ध्यान से देखें, फिर उस विकल्प को चुनें जो आगे आना चाहिए।',
                          ),
                          style: MindoraTextStyles.bodyMedium.copyWith(fontSize: 14),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Sequence Display Card
                  Text(
                    tr('Sequence Row', 'पैटर्न क्रम'),
                    style: MindoraTextStyles.titleMedium,
                  ),
                  const SizedBox(height: 12),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
                    decoration: mindoraCard(color: Colors.white, radius: 20),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ...challenge.sequence.map((item) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: _buildMotifBox(item),
                            );
                          }),
                          // Missing Question Box
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: selectedAnswer != null
                                    ? (isAnswerCorrect == true ? MindoraColors.cardGreen : MindoraColors.cardRose)
                                    : MindoraColors.cardAmber.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: selectedAnswer != null
                                      ? (isAnswerCorrect == true ? MindoraColors.sageGreen : MindoraColors.terracotta)
                                      : MindoraColors.terracotta,
                                  width: 2.5,
                                ),
                              ),
                              child: Center(
                                child: selectedAnswer != null
                                    ? Icon(selectedAnswer!.icon, size: 36, color: selectedAnswer!.color)
                                    : const Text(
                                        '?',
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: MindoraColors.forestGreen,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Options
                  Text(
                    tr('Which comes next?', 'आगे कौन सा रूपांकन आएगा?'),
                    style: MindoraTextStyles.titleMedium,
                  ),
                  const SizedBox(height: 14),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: challenge.options.map((opt) {
                      final isSelected = selectedAnswer?.id == opt.id;

                      return Semantics(
                        button: true,
                        label: isHindi ? opt.nameHi : opt.nameEn,
                        child: InkWell(
                          onTap: () => _checkAnswer(opt, challenge),
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            width: 86,
                            height: 86,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isAnswerCorrect == true ? MindoraColors.cardGreen : MindoraColors.cardRose)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelected
                                    ? (isAnswerCorrect == true ? MindoraColors.sageGreen : MindoraColors.terracotta)
                                    : MindoraColors.borderMedium,
                                width: 2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x10000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(opt.icon, size: 38, color: opt.color),
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    isHindi ? opt.nameHi : opt.nameEn,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Feedback indicator
                  if (isAnswerCorrect == false)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: mindoraCard(color: MindoraColors.cardRose),
                      child: Text(
                        tr(
                          'Gentle try! Look closely at the sequence or tap Hint below.',
                          'कोई बात नहीं! क्रम को ध्यान से देखें या नीचे संकेत पर टैप करें।',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: MindoraColors.terracotta, fontWeight: FontWeight.w600),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Hint Button and Display
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
                          showHint ? tr('Hide Hint', 'संकेत छिपाएं') : tr('Show Hint', 'संकेत देखें'),
                          style: const TextStyle(color: MindoraColors.terracotta, fontSize: 16),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _loadLevel(currentLevel),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(tr('Reset', 'रीसेट')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: MindoraColors.forestGreen,
                          side: const BorderSide(color: MindoraColors.borderMedium),
                        ),
                      ),
                    ],
                  ),

                  if (showHint)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: mindoraCard(color: MindoraColors.cardAmber),
                        child: Text(
                          isHindi ? challenge.hintHi : challenge.hintEn,
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

  Widget _buildMotifBox(PatternElement item) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: MindoraColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MindoraColors.borderLight, width: 1.5),
      ),
      child: Center(
        child: Icon(item.icon, size: 34, color: item.color),
      ),
    );
  }
}
