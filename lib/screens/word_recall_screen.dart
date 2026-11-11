// Mindora - Word Recall Game
// Displays a small set of familiar cultural/everyday words, gives unhurried study time,
// hides them, and prompts the user to select the remembered words from a selection pool.
// Categories: Food & Harvest, Family & Warmth, Nature & Landscape, Home & Handloom.

import 'package:flutter/material.dart';
import '../theme/mindora_theme.dart';
import '../app_settings.dart';
import '../models/level_data.dart';
import '../services/adaptive_difficulty.dart';
import '../services/api_service.dart';
import '../game_progress.dart';
import 'level_progression_screen.dart';

class RecallWordItem {
  final String id;
  final String wordEn;
  final String wordHi;
  final String categoryEn;
  final String categoryHi;
  final IconData icon;

  const RecallWordItem({
    required this.id,
    required this.wordEn,
    required this.wordHi,
    required this.categoryEn,
    required this.categoryHi,
    required this.icon,
  });
}

class WordRecallScreen extends StatefulWidget {
  final int initialLevel;
  const WordRecallScreen({super.key, this.initialLevel = 1});

  static const Map<int, List<RecallWordItem>> levelWordPool = _WordRecallScreenState.levelWordPool;
  static const Map<int, List<RecallWordItem>> levelWordBanks = _WordRecallScreenState.levelWordPool;

  @override
  State<WordRecallScreen> createState() => _WordRecallScreenState();
}

enum RecallPhase { study, test, result }

class _WordRecallScreenState extends State<WordRecallScreen> {
  late int currentLevel;
  static const int maxLevels = 4;

  RecallPhase currentPhase = RecallPhase.study;

  // Level word banks & target count
  static const Map<int, List<RecallWordItem>> levelWordPool = {
    // Level 1: Beginner simple 3-4 letter words (3 Target words from pool of 5)
    1: [
      RecallWordItem(id: 'tea', wordEn: 'Tea', wordHi: 'चाय', categoryEn: 'Food', categoryHi: 'आहार', icon: Icons.emoji_food_beverage_rounded),
      RecallWordItem(id: 'rice', wordEn: 'Rice', wordHi: 'चावल', categoryEn: 'Food', categoryHi: 'आहार', icon: Icons.rice_bowl_rounded),
      RecallWordItem(id: 'fish', wordEn: 'Fish', wordHi: 'मछली', categoryEn: 'Food', categoryHi: 'आहार', icon: Icons.set_meal_rounded),
      RecallWordItem(id: 'rain', wordEn: 'Rain', wordHi: 'बारिश', categoryEn: 'Nature', categoryHi: 'प्रकृति', icon: Icons.water_drop_rounded),
      RecallWordItem(id: 'lamp', wordEn: 'Lamp', wordHi: 'दीया', categoryEn: 'Home', categoryHi: 'घर', icon: Icons.lightbulb_outline_rounded),
    ],
    // Level 2: Gentle 4-5 letter words (4 Target words from pool of 6)
    2: [
      RecallWordItem(id: 'tree', wordEn: 'Tree', wordHi: 'पेड़', categoryEn: 'Nature', categoryHi: 'प्रकृति', icon: Icons.park_rounded),
      RecallWordItem(id: 'bell', wordEn: 'Bell', wordHi: 'घंटी', categoryEn: 'Home', categoryHi: 'घर', icon: Icons.notifications_active_rounded),
      RecallWordItem(id: 'milk', wordEn: 'Milk', wordHi: 'दूध', categoryEn: 'Food', categoryHi: 'आहार', icon: Icons.local_drink_rounded),
      RecallWordItem(id: 'bird', wordEn: 'Bird', wordHi: 'चिड़िया', categoryEn: 'Nature', categoryHi: 'प्रकृति', icon: Icons.air_rounded),
      RecallWordItem(id: 'home', wordEn: 'Home', wordHi: 'घर', categoryEn: 'Home', categoryHi: 'घर', icon: Icons.home_rounded),
      RecallWordItem(id: 'aunt', wordEn: 'Aunt', wordHi: 'मौसी', categoryEn: 'Family', categoryHi: 'परिवार', icon: Icons.person_rounded),
    ],
    // Level 3: Intermediate 6-letter words (4 Target words from pool of 7)
    3: [
      RecallWordItem(id: 'mother', wordEn: 'Mother', wordHi: 'माताजी', categoryEn: 'Family', categoryHi: 'परिवार', icon: Icons.favorite_rounded),
      RecallWordItem(id: 'father', wordEn: 'Father', wordHi: 'पिताजी', categoryEn: 'Family', categoryHi: 'परिवार', icon: Icons.person_rounded),
      RecallWordItem(id: 'forest', wordEn: 'Forest', wordHi: 'जंगल', categoryEn: 'Nature', categoryHi: 'प्रकृति', icon: Icons.forest_rounded),
      RecallWordItem(id: 'stream', wordEn: 'Stream', wordHi: 'झरना', categoryEn: 'Nature', categoryHi: 'प्रकृति', icon: Icons.water_rounded),
      RecallWordItem(id: 'flower', wordEn: 'Flower', wordHi: 'फूल', categoryEn: 'Nature', categoryHi: 'प्रकृति', icon: Icons.local_florist_rounded),
      RecallWordItem(id: 'basket', wordEn: 'Basket', wordHi: 'टोकरी', categoryEn: 'Home', categoryHi: 'घर', icon: Icons.shopping_basket_rounded),
      RecallWordItem(id: 'ginger', wordEn: 'Ginger', wordHi: 'अदरक', categoryEn: 'Food', categoryHi: 'आहार', icon: Icons.eco_rounded),
    ],
    // Level 4: Progressive 7-8 letter words (5 Target words from pool of 8)
    4: [
      RecallWordItem(id: 'brother', wordEn: 'Brother', wordHi: 'भाई', categoryEn: 'Family', categoryHi: 'परिवार', icon: Icons.people_alt_rounded),
      RecallWordItem(id: 'blanket', wordEn: 'Blanket', wordHi: 'कंबल', categoryEn: 'Home', categoryHi: 'घर', icon: Icons.texture_rounded),
      RecallWordItem(id: 'lantern', wordEn: 'Lantern', wordHi: 'लालटेन', categoryEn: 'Home', categoryHi: 'घर', icon: Icons.wb_incandescent_rounded),
      RecallWordItem(id: 'harvest', wordEn: 'Harvest', wordHi: 'फसल', categoryEn: 'Food', categoryHi: 'आहार', icon: Icons.agriculture_rounded),
      RecallWordItem(id: 'sunrise', wordEn: 'Sunrise', wordHi: 'सूर्योदय', categoryEn: 'Nature', categoryHi: 'प्रकृति', icon: Icons.wb_sunny_rounded),
      RecallWordItem(id: 'orchard', wordEn: 'Orchard', wordHi: 'बगीचा', categoryEn: 'Nature', categoryHi: 'प्रकृति', icon: Icons.nature_rounded),
      RecallWordItem(id: 'village', wordEn: 'Village', wordHi: 'गाँव', categoryEn: 'Home', categoryHi: 'घर', icon: Icons.holiday_village_rounded),
      RecallWordItem(id: 'pumpkin', wordEn: 'Pumpkin', wordHi: 'कद्दू', categoryEn: 'Food', categoryHi: 'आहार', icon: Icons.circle_rounded),
    ],
  };

  late List<RecallWordItem> targetWords;
  late List<RecallWordItem> optionPool;
  final Set<String> userSelectedIds = {};
  int hintsUsed = 0;
  bool showHint = false;
  late Stopwatch stopwatch;

  bool get isHindi => AppSettings.instance.isHindi;
  String tr(String en, String hi, {String? key}) =>
      AppSettings.instance.trBilingual(en, hi, key: key);

  @override
  void initState() {
    super.initState();
    currentLevel = widget.initialLevel;
    stopwatch = Stopwatch();
    _startLevel(currentLevel);
  }

  void _startLevel(int lvl) {
    ApiService.instance.beginGameSession('word_recall', lvl);
    currentLevel = lvl;
    currentPhase = RecallPhase.study;
    userSelectedIds.clear();
    hintsUsed = 0;
    showHint = false;
    stopwatch.reset();
    stopwatch.start();

    final pool = List<RecallWordItem>.from(levelWordPool[lvl] ?? levelWordPool[1]!);
    pool.shuffle();

    // Select first N as target words
    final targetCount = lvl == 1 ? 3 : (lvl == 2 ? 4 : (lvl == 3 ? 4 : 5));
    targetWords = pool.take(targetCount).toList();

    // The option pool contains all items shuffled
    optionPool = List<RecallWordItem>.from(pool)..shuffle();

    setState(() {});
  }

  void _proceedToTest() {
    setState(() {
      currentPhase = RecallPhase.test;
    });
  }

  void _toggleWordSelection(String id) {
    setState(() {
      if (userSelectedIds.contains(id)) {
        userSelectedIds.remove(id);
      } else {
        userSelectedIds.add(id);
      }
    });
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

  void _submitRecall() {
    stopwatch.stop();

    // Check accuracy
    final targetIds = targetWords.map((e) => e.id).toSet();
    final correctlyRecalled = userSelectedIds.intersection(targetIds).length;
    final falseRecalls = userSelectedIds.difference(targetIds).length;

    // Metrics recording
    _persistSession(
      SessionMetrics(
        gameId: 'word_recall',
        level: currentLevel,
        correctMatches: correctlyRecalled,
        incorrectAttempts: falseRecalls,
        hintsUsed: hintsUsed,
        totalAttempts: targetWords.length,
        elapsed: stopwatch.elapsed,
        completed: true,
      ),
    );

    GameProgress.instance.addSession(
      GameSession(
        gameName: 'Word Recall',
        date: DateTime.now(),
        duration: stopwatch.elapsed,
        moves: userSelectedIds.length,
        pairsMatched: correctlyRecalled,
        completed: true,
      ),
    );

    if (correctlyRecalled >= targetWords.length - 1) {
      LevelProgressManager.instance.completeLevel('word_recall', currentLevel, maxLevel: maxLevels);
    }

    setState(() {
      currentPhase = RecallPhase.result;
    });
  }

  @override
  Widget build(BuildContext context) {
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
              '${tr("Word Recall", "शब्द स्मरण")} - ${tr("Lvl", "स्तर")} $currentLevel',
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
                        gameId: 'word_recall',
                        gameTitle: tr('Word Recall Levels', 'शब्द स्मरण स्तर'),
                        totalLevels: maxLevels,
                        onSelectLevel: (lvl) {
                          Navigator.pop(context);
                          _startLevel(lvl);
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
                  if (currentPhase == RecallPhase.study) _buildStudyPhase(),
                  if (currentPhase == RecallPhase.test) _buildTestPhase(),
                  if (currentPhase == RecallPhase.result) _buildResultPhase(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Phase 1: Study the words with no countdown pressure
  Widget _buildStudyPhase() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: mindoraGradientCard(
            colors: [
              MindoraColors.cardBlue,
              MindoraColors.cardGreen.withValues(alpha: 0.3),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('Take your time to remember these words', 'इन शब्दों को याद करने के लिए अपना समय लें'),
                style: MindoraTextStyles.titleLarge.copyWith(fontSize: 19),
              ),
              const SizedBox(height: 6),
              Text(
                tr(
                  'Read each word quietly or aloud. When you feel ready, tap the button below.',
                  'प्रत्येक शब्द को ध्यान से पढ़ें। जब आप तैयार महसूस करें, तो नीचे दिए गए बटन पर टैप करें।',
                ),
                style: MindoraTextStyles.bodyMedium,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // The Target Words Cards
        ...targetWords.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: mindoraCard(color: Colors.white, radius: 18),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: MindoraColors.cardGreen,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(item.icon, color: MindoraColors.forestGreen, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isHindi ? item.wordHi : item.wordEn,
                          style: MindoraTextStyles.titleLarge.copyWith(fontSize: 20),
                        ),
                        Text(
                          '${tr("Category", "श्रेणी")}: ${isHindi ? item.categoryHi : item.categoryEn}',
                          style: MindoraTextStyles.caption.copyWith(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _proceedToTest,
            icon: const Icon(Icons.check_rounded, size: 24),
            label: Text(
              tr("I'm Ready to Remember", 'मैं याद करने के लिए तैयार हूँ'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: MindoraColors.sageGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }

  // Phase 2: User selects words from pool
  Widget _buildTestPhase() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: mindoraCard(color: MindoraColors.cardAmber),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('Which words did you see?', 'आपने कौन से शब्द देखे थे?'),
                style: MindoraTextStyles.titleLarge.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 6),
              Text(
                '${tr("Please choose", "कृपया चुनें")} ${targetWords.length} ${tr("words from the choices below.", "शब्द चुनें।")}',
                style: MindoraTextStyles.bodyMedium,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Option pool
        ...optionPool.map((item) {
          final isSelected = userSelectedIds.contains(item.id);

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Semantics(
              button: true,
              selected: isSelected,
              label: isHindi ? item.wordHi : item.wordEn,
              child: InkWell(
                onTap: () => _toggleWordSelection(item.id),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? MindoraColors.cardGreen : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? MindoraColors.sageGreen : MindoraColors.borderMedium,
                      width: isSelected ? 2.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: isSelected ? MindoraColors.sageGreen : MindoraColors.textMuted,
                        size: 26,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          isHindi ? item.wordHi : item.wordEn,
                          style: MindoraTextStyles.titleMedium.copyWith(
                            fontSize: 18,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 16),

        // Hint trigger
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
                showHint ? tr('Hide Category Hint', 'संकेत छिपाएं') : tr('Show Category Hint', 'श्रेणी संकेत देखें'),
                style: const TextStyle(color: MindoraColors.terracotta),
              ),
            ),
          ],
        ),

        if (showHint)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8, bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: mindoraCard(color: MindoraColors.cardRose),
            child: Text(
              '${tr("Categories included", "शामिल श्रेणियां")}: ${targetWords.map((e) => isHindi ? e.categoryHi : e.categoryEn).toSet().join(", ")}',
              style: MindoraTextStyles.bodyMedium.copyWith(color: MindoraColors.terracotta),
            ),
          ),

        const SizedBox(height: 14),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: userSelectedIds.isEmpty ? null : _submitRecall,
            icon: const Icon(Icons.done_all_rounded),
            label: Text(
              tr('Check My Answer', 'मेरा उत्तर जांचें'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: MindoraColors.sageGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }

  // Phase 3: Results & Feedback
  Widget _buildResultPhase() {
    final targetIds = targetWords.map((e) => e.id).toSet();
    final correctlyRecalled = userSelectedIds.intersection(targetIds).length;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: mindoraGradientCard(
            colors: [
              MindoraColors.cardGreen,
              MindoraColors.cardAmber.withValues(alpha: 0.4),
            ],
          ),
          child: Column(
            children: [
              const Icon(Icons.spa_rounded, size: 48, color: MindoraColors.sageGreen),
              const SizedBox(height: 10),
              Text(
                tr('Thoughtful Effort! 🌸', 'सराहनीय प्रयास! 🌸'),
                style: MindoraTextStyles.displayMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '${tr("You remembered", "आपने")} $correctlyRecalled / ${targetWords.length} ${tr("words accurately.", "शब्द सही याद रखे।")}',
                style: MindoraTextStyles.titleMedium,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        Text(
          tr('The Original Words Were:', 'मूल शब्द ये थे:'),
          style: MindoraTextStyles.titleMedium,
        ),
        const SizedBox(height: 10),

        ...targetWords.map((w) {
          final wasFound = userSelectedIds.contains(w.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: mindoraCard(color: wasFound ? MindoraColors.cardGreen : Colors.white),
              child: Row(
                children: [
                  Icon(
                    wasFound ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                    color: wasFound ? MindoraColors.sageGreen : MindoraColors.textMuted,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isHindi ? w.wordHi : w.wordEn,
                    style: MindoraTextStyles.titleMedium.copyWith(fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _startLevel(currentLevel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MindoraColors.forestGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(tr('Try Again', 'पुनः प्रयास')),
              ),
            ),
            const SizedBox(width: 12),
            if (currentLevel < maxLevels)
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _startLevel(currentLevel + 1),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MindoraColors.sageGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(tr('Next Level', 'अगला स्तर')),
                ),
              )
            else
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MindoraColors.sageGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(tr('Done 🌿', 'पूर्ण 🌿')),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
