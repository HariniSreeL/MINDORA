// Mindora - Level Progression System Model
// Manages unlocked and completed levels for each game independently.
// Persistent via SharedPreferences.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LevelProgressManager extends ChangeNotifier {
  LevelProgressManager._();
  static final LevelProgressManager instance = LevelProgressManager._();

  // Maps gameId to highest unlocked level (1-indexed)
  final Map<String, int> _unlockedLevels = {
    'memory_match': 1,
    'pattern_match': 1,
    'word_recall': 1,
    'sound_recognition': 1,
  };

  // Maps gameId to list of completed level numbers
  final Map<String, Set<int>> _completedLevels = {
    'memory_match': {},
    'pattern_match': {},
    'word_recall': {},
    'sound_recognition': {},
  };

  int getUnlockedLevel(String gameId) => _unlockedLevels[gameId] ?? 1;

  bool isLevelCompleted(String gameId, int level) =>
      _completedLevels[gameId]?.contains(level) ?? false;

  bool isLevelUnlocked(String gameId, int level) {
    if (level <= 1) return true;
    final maxUnlocked = _unlockedLevels[gameId] ?? 1;
    return level <= maxUnlocked;
  }

  Future<void> loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    for (final gameId in _unlockedLevels.keys) {
      final unlocked = prefs.getInt('${gameId}_unlocked') ?? 1;
      _unlockedLevels[gameId] = unlocked;

      final completedList = prefs.getStringList('${gameId}_completed') ?? [];
      _completedLevels[gameId] = completedList.map((e) => int.tryParse(e) ?? 1).toSet();
    }
    notifyListeners();
  }

  Future<void> completeLevel(String gameId, int level, {int maxLevel = 5}) async {
    final prefs = await SharedPreferences.getInstance();

    _completedLevels[gameId] ??= {};
    _completedLevels[gameId]!.add(level);

    if (level >= (_unlockedLevels[gameId] ?? 1) && level < maxLevel) {
      _unlockedLevels[gameId] = level + 1;
      await prefs.setInt('${gameId}_unlocked', level + 1);
    }

    final completedStrings = _completedLevels[gameId]!.map((e) => e.toString()).toList();
    await prefs.setStringList('${gameId}_completed', completedStrings);

    notifyListeners();
  }
}
