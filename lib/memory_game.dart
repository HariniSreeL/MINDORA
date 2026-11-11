// Mindora - Enhanced Memory Match Game
// Culturally relevant North-East Indian visual objects, multiple progressive levels,
// optional timer, relaxed mode, hints, level completion modal & adaptive difficulty metrics.

import 'dart:async';
import 'package:flutter/material.dart';
import 'app_settings.dart';
import 'theme/mindora_theme.dart';
import 'game_progress.dart';
import 'models/level_data.dart';
import 'services/adaptive_difficulty.dart';
import 'services/api_service.dart';
import 'screens/level_progression_screen.dart';

class MemoryCardItem {
  final String id;
  final String nameEn;
  final String nameHi;
  final IconData icon;
  final Color tint;

  const MemoryCardItem({
    required this.id,
    required this.nameEn,
    required this.nameHi,
    required this.icon,
    required this.tint,
  });
}

class MemoryGame extends StatefulWidget {
  final int initialLevel;
  const MemoryGame({super.key, this.initialLevel = 1});

  @override
  State<MemoryGame> createState() => _MemoryGameState();
}

class _MemoryGameState extends State<MemoryGame> {
  late int currentLevel;
  static const int maxLevels = 4;

  // Level themed sets with high-contrast, recognizable items
  static const Map<int, List<MemoryCardItem>> levelCardSets = {
    // Level 1: Regional Harvest & Fruits (3 pairs = 6 cards)
    1: [
      MemoryCardItem(id: 'tea', nameEn: 'Tea Leaf', nameHi: 'चाय पत्ती', icon: Icons.eco_rounded, tint: Color(0xFF1B5E20)),
      MemoryCardItem(id: 'orange', nameEn: 'Orange', nameHi: 'संतरा', icon: Icons.brightness_5_rounded, tint: Color(0xFFD35400)),
      MemoryCardItem(id: 'bamboo', nameEn: 'Bamboo', nameHi: 'बांस', icon: Icons.forest_rounded, tint: Color(0xFF2E7D32)),
    ],
    // Level 2: Regional Flora & Orchids (4 pairs = 8 cards)
    2: [
      MemoryCardItem(id: 'kopou', nameEn: 'Orchid', nameHi: 'ऑर्किड फूल', icon: Icons.local_florist_rounded, tint: Color(0xFF6A1B9A)),
      MemoryCardItem(id: 'rhododendron', nameEn: 'Red Flower', nameHi: 'लाल फूल', icon: Icons.spa_rounded, tint: Color(0xFFC62828)),
      MemoryCardItem(id: 'lotus', nameEn: 'Water Lily', nameHi: 'कमल फूल', icon: Icons.filter_vintage_rounded, tint: Color(0xFFAD1457)),
      MemoryCardItem(id: 'pine', nameEn: 'Pine Tree', nameHi: 'चीड़ का पेड़', icon: Icons.park_rounded, tint: Color(0xFF1B5E20)),
    ],
    // Level 3: Handloom & Cultural Objects (5 pairs = 10 cards)
    3: [
      MemoryCardItem(id: 'jaapi', nameEn: 'Bamboo Hat', nameHi: 'बांस की जापी', icon: Icons.shield_rounded, tint: Color(0xFFB7950B)),
      MemoryCardItem(id: 'dhol', nameEn: 'Folk Drum', nameHi: 'पारंपरिक ढोल', icon: Icons.album_rounded, tint: Color(0xFFA04000)),
      MemoryCardItem(id: 'bell', nameEn: 'Prayer Bell', nameHi: 'पूजा की घंटी', icon: Icons.notifications_active_rounded, tint: Color(0xFFD68910)),
      MemoryCardItem(id: 'pot', nameEn: 'Clay Pot', nameHi: 'मिट्टी का घड़ा', icon: Icons.coffee_rounded, tint: Color(0xFF873600)),
      MemoryCardItem(id: 'shuttle', nameEn: 'Loom Shuttle', nameHi: 'हथकरघा शटल', icon: Icons.texture_rounded, tint: Color(0xFF5B2C6F)),
    ],
    // Level 4: Cultural Nature & Landscapes (6 pairs = 12 cards)
    4: [
      MemoryCardItem(id: 'rhino', nameEn: 'Wildlife', nameHi: 'वन्यजीव', icon: Icons.pets_rounded, tint: Color(0xFF37474F)),
      MemoryCardItem(id: 'hornbill', nameEn: 'Hornbill', nameHi: 'धनेश पक्षी', icon: Icons.air_rounded, tint: Color(0xFFC0392B)),
      MemoryCardItem(id: 'bridge', nameEn: 'Root Bridge', nameHi: 'प्राकृतिक पुल', icon: Icons.alt_route_rounded, tint: Color(0xFF2E7D32)),
      MemoryCardItem(id: 'mountain', nameEn: 'Misty Hill', nameHi: 'पर्वत शिखर', icon: Icons.terrain_rounded, tint: Color(0xFF455A64)),
      MemoryCardItem(id: 'rain', nameEn: 'Raindrops', nameHi: 'मानसून वर्षा', icon: Icons.water_drop_rounded, tint: Color(0xFF1565C0)),
      MemoryCardItem(id: 'sun', nameEn: 'Warm Sun', nameHi: 'अरुणोदय', icon: Icons.wb_sunny_rounded, tint: Color(0xFFE65100)),
    ],
  };

  late List<MemoryCardItem> activeCards;
  final List<int> selectedIndices = [];
  final Set<int> matchedIndices = {};

  int moves = 0;
  int hintsUsed = 0;
  int incorrectAttempts = 0;
  bool isChecking = false;
  bool relaxedMode = false;
  bool showTimer = true;

  late Stopwatch stopwatch;
  Timer? periodicTimer;
  int elapsedSeconds = 0;

  bool get isCompleted => matchedIndices.length == activeCards.length;
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

  void _startLevel(int level) {
    ApiService.instance.beginGameSession('memory_match', level,
        relaxedMode: relaxedMode);
    stopwatch.reset();
    stopwatch.start();
    elapsedSeconds = 0;
    moves = 0;
    hintsUsed = 0;
    incorrectAttempts = 0;
    selectedIndices.clear();
    matchedIndices.clear();
    isChecking = false;

    periodicTimer?.cancel();
    periodicTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && stopwatch.isRunning) {
        setState(() {
          elapsedSeconds = stopwatch.elapsed.inSeconds;
        });
      }
    });

    final items = levelCardSets[level] ?? levelCardSets[1]!;
    // Create pairs and shuffle
    final paired = <MemoryCardItem>[...items, ...items];
    paired.shuffle();

    setState(() {
      currentLevel = level;
      activeCards = paired;
    });
  }

  @override
  void dispose() {
    periodicTimer?.cancel();
    stopwatch.stop();
    super.dispose();
  }

  void _handleCardTap(int index) async {
    if (isChecking ||
        selectedIndices.contains(index) ||
        matchedIndices.contains(index) ||
        isCompleted) {
      return;
    }

    setState(() {
      selectedIndices.add(index);
    });

    if (selectedIndices.length == 2) {
      setState(() => moves++);

      final first = activeCards[selectedIndices[0]];
      final second = activeCards[selectedIndices[1]];

      if (first.id == second.id) {
        // Match!
        setState(() {
          matchedIndices.addAll(selectedIndices);
          selectedIndices.clear();
        });

        if (isCompleted) {
          _onLevelCompleted();
        }
      } else {
        // No match
        incorrectAttempts++;
        setState(() => isChecking = true);
        await Future.delayed(const Duration(milliseconds: 950));
        if (mounted) {
          setState(() {
            selectedIndices.clear();
            isChecking = false;
          });
        }
      }
    }
  }

  void _useHint() {
    if (isCompleted || isChecking) return;

    // Find the first unmatched pair
    int? firstUnmatched;
    int? secondUnmatched;

    for (int i = 0; i < activeCards.length; i++) {
      if (!matchedIndices.contains(i)) {
        firstUnmatched = i;
        for (int j = i + 1; j < activeCards.length; j++) {
          if (!matchedIndices.contains(j) && activeCards[i].id == activeCards[j].id) {
            secondUnmatched = j;
            break;
          }
        }
        break;
      }
    }

    if (firstUnmatched != null && secondUnmatched != null) {
      setState(() {
        hintsUsed++;
        selectedIndices.clear();
        selectedIndices.addAll([firstUnmatched!, secondUnmatched!]);
        isChecking = true;
      });

      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) {
          setState(() {
            selectedIndices.clear();
            isChecking = false;
          });
        }
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
    periodicTimer?.cancel();

    // Record session metrics for adaptive difficulty
    final metrics = SessionMetrics(
      gameId: 'memory_match',
      level: currentLevel,
      correctMatches: matchedIndices.length ~/ 2,
      incorrectAttempts: incorrectAttempts,
      hintsUsed: hintsUsed,
      totalAttempts: moves,
      elapsed: stopwatch.elapsed,
      completed: true,
      relaxedMode: relaxedMode,
    );
    _persistSession(metrics);

    // Record overall game progress
    GameProgress.instance.addSession(
      GameSession(
        gameName: 'Memory Match',
        date: DateTime.now(),
        duration: stopwatch.elapsed,
        moves: moves,
        pairsMatched: matchedIndices.length ~/ 2,
        completed: true,
      ),
    );

    // Save to level progress manager
    LevelProgressManager.instance.completeLevel('memory_match', currentLevel, maxLevel: maxLevels);

    // Evaluate comfort feedback
    final band = AdaptiveDifficulty.instance.evaluatePerformance('memory_match');
    final encouragement = AdaptiveDifficulty.instance.getAdaptiveEncouragement(band, isHindi: isHindi);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: MindoraColors.cream,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            tr('Level Completed! 🌸', 'स्तर पूरा हुआ! 🌸'),
            style: MindoraTextStyles.displayMedium.copyWith(color: MindoraColors.forestGreen),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                encouragement,
                textAlign: TextAlign.center,
                style: MindoraTextStyles.bodyMedium.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: mindoraCard(color: Colors.white),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _metricStat(tr('Moves', 'प्रयास'), '$moves'),
                    if (showTimer)
                      _metricStat(tr('Time', 'समय'), '${elapsedSeconds}s'),
                    _metricStat(tr('Hints', 'संकेत'), '$hintsUsed'),
                  ],
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            OutlinedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _startLevel(currentLevel);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: MindoraColors.forestGreen,
                side: const BorderSide(color: MindoraColors.sageGreen),
              ),
              child: Text(tr('Replay', 'फिर से खेलें')),
            ),
            if (currentLevel < maxLevels)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  _startLevel(currentLevel + 1);
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
                child: Text(tr('Finished 🌿', 'पूर्ण 🌿')),
              ),
          ],
        );
      },
    );
  }

  Widget _metricStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: MindoraTextStyles.caption),
        const SizedBox(height: 4),
        Text(value, style: MindoraTextStyles.titleMedium),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        final screenWidth = MediaQuery.of(context).size.width;
        final int crossAxisCount = screenWidth > 600 ? 4 : (activeCards.length > 8 ? 3 : 2);

        return Scaffold(
          backgroundColor: MindoraColors.cream,
          appBar: AppBar(
            backgroundColor: MindoraColors.cream,
            foregroundColor: MindoraColors.forestGreen,
            elevation: 0,
            title: Text(
              '${tr("Memory Match", "स्मृति मिलान")} - ${tr("Lvl", "स्तर")} $currentLevel',
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
                        gameId: 'memory_match',
                        gameTitle: tr('Memory Match Levels', 'स्मृति मिलान स्तर'),
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
              IconButton(
                tooltip: relaxedMode ? tr('Relaxed Mode On', 'आराम मोड चालू') : tr('Normal Mode', 'सामान्य मोड'),
                icon: Icon(
                  relaxedMode ? Icons.spa_rounded : Icons.spa_outlined,
                  color: relaxedMode ? MindoraColors.sageGreen : MindoraColors.textMuted,
                ),
                onPressed: () {
                  setState(() {
                    relaxedMode = !relaxedMode;
                    showTimer = !relaxedMode;
                  });
                },
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  // Status & Controls bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: mindoraCard(color: Colors.white, radius: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.touch_app_rounded, size: 20, color: MindoraColors.sageGreen),
                            const SizedBox(width: 6),
                            Text('${tr("Moves", "प्रयास")}: $moves', style: MindoraTextStyles.titleMedium),
                          ],
                        ),
                        if (showTimer)
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined, size: 20, color: MindoraColors.terracotta),
                              const SizedBox(width: 6),
                              Text('${elapsedSeconds}s', style: MindoraTextStyles.titleMedium),
                            ],
                          ),
                        TextButton.icon(
                          onPressed: _useHint,
                          icon: const Icon(Icons.lightbulb_outline_rounded, size: 20),
                          label: Text(tr('Hint', 'संकेत')),
                          style: TextButton.styleFrom(
                            foregroundColor: MindoraColors.terracotta,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Cards Grid
                  Expanded(
                    child: GridView.builder(
                      itemCount: activeCards.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.95,
                      ),
                      itemBuilder: (context, index) {
                        final card = activeCards[index];
                        final isRevealed = selectedIndices.contains(index) || matchedIndices.contains(index);
                        final isMatched = matchedIndices.contains(index);

                        return Semantics(
                          button: true,
                          label: isRevealed ? (isHindi ? card.nameHi : card.nameEn) : tr('Hidden Card', 'बंद कार्ड'),
                          child: InkWell(
                            onTap: () => _handleCardTap(index),
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              decoration: BoxDecoration(
                                color: isMatched
                                    ? MindoraColors.cardGreen
                                    : isRevealed
                                        ? Colors.white
                                        : MindoraColors.sageGreen,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isMatched
                                      ? MindoraColors.sageGreen
                                      : isRevealed
                                          ? card.tint
                                          : MindoraColors.borderMedium,
                                  width: isRevealed ? 2.5 : 1.5,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x0C000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: isRevealed
                                    ? Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 58,
                                              height: 58,
                                              decoration: BoxDecoration(
                                                color: card.tint.withValues(alpha: 0.12),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(card.icon, size: 40, color: card.tint),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              isHindi ? card.nameHi : card.nameEn,
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: MindoraColors.forestGreen,
                                                height: 1.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Container(
                                        width: 58,
                                        height: 58,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.18),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.spa_rounded,
                                          size: 40,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom bar with Replay and Level Switcher
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _startLevel(currentLevel),
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(tr('Reset', 'रीसेट')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: MindoraColors.forestGreen,
                              side: const BorderSide(color: MindoraColors.borderMedium),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LevelProgressionScreen(
                                    gameId: 'memory_match',
                                    gameTitle: tr('Memory Match Levels', 'स्मृति मिलान स्तर'),
                                    totalLevels: maxLevels,
                                    onSelectLevel: (lvl) {
                                      Navigator.pop(context);
                                      _startLevel(lvl);
                                    },
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.stairs_rounded),
                            label: Text(tr('All Levels', 'सभी स्तर')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MindoraColors.sageGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
