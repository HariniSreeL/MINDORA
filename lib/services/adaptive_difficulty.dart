import 'package:flutter/foundation.dart';

import 'api_service.dart';
// Mindora - Adaptive Difficulty Engine
// Modular cognitive comfort evaluation system designed for elderly users.
// Evaluates performance signals (correct actions, errors, hints requested, repeated attempts)
// using rule-based heuristics that gently adapt challenge levels without stress or speed penalty.
//
// Future integration: Structured to export feature vectors to Python Scikit-learn Decision Tree models.

import 'dart:math';

enum PerformanceBand {
  comfortable, // Performing comfortably without struggle -> candidate for mild progression
  balanced,    // Performing steadily at current challenge
  needsSupport // Experiencing difficulties -> candidate for maintaining or offering relaxed mode/hints
}

class SessionMetrics {
  final String gameId;
  final int level;
  final int correctMatches;
  final int incorrectAttempts;
  final int hintsUsed;
  final int totalAttempts;
  final Duration elapsed;
  final bool completed;
  final bool relaxedMode;

  const SessionMetrics({
    required this.gameId,
    required this.level,
    required this.correctMatches,
    required this.incorrectAttempts,
    required this.hintsUsed,
    required this.totalAttempts,
    required this.elapsed,
    required this.completed,
    this.relaxedMode = false,
  });

  // Feature vector ready for future Python ML Decision Tree model
  Map<String, dynamic> toFeatureMap() {
    final accuracy = totalAttempts > 0 ? correctMatches / totalAttempts : 0.0;
    return {
      'game_id': gameId,
      'level': level,
      'correct_matches': correctMatches,
      'incorrect_attempts': incorrectAttempts,
      'hints_used': hintsUsed,
      'total_attempts': totalAttempts,
      'accuracy_ratio': accuracy,
      'duration_seconds': elapsed.inSeconds,
      'completed': completed ? 1 : 0,
      'relaxed_mode': relaxedMode ? 1 : 0,
    };
  }
}

class AdaptiveDifficulty {
  AdaptiveDifficulty._();
  static final AdaptiveDifficulty instance = AdaptiveDifficulty._();

  final List<SessionMetrics> _history = [];

  /// Records the attempt locally and persists it through the shared API layer.
  ///
  /// Returns the backend save outcome so game screens can tell the player when
  /// an attempt is queued for later sync instead of silently losing it.
  Future<GameSaveStatus> recordSession(SessionMetrics metrics) async {
    _history.add(metrics);
    try {
      final recorded = await ApiService.instance.recordGameSession(metrics);
      if (recorded != null) return GameSaveStatus.saved;
      return ApiService.instance.lastGameSaveStatus;
    } catch (error) {
      // Keep the local history and let the offline queue handle retries; never
      // fail the completion flow because persistence had a problem.
      debugPrint('AdaptiveDifficulty.recordSession failed: $error');
      return GameSaveStatus.failed;
    }
  }

  /// Evaluates the user's comfort based on recent performance
  /// Speed is intentionally NOT the sole determinant to respect elderly user pacing.
  PerformanceBand evaluatePerformance(String gameId) {
    final gameSessions = _history.where((s) => s.gameId == gameId).toList();
    if (gameSessions.isEmpty) {
      return PerformanceBand.balanced;
    }

    final recent = gameSessions.reversed.take(3).toList();
    int totalErrors = 0;
    int totalHints = 0;
    int totalMatches = 0;

    for (final s in recent) {
      totalErrors += s.incorrectAttempts;
      totalHints += s.hintsUsed;
      totalMatches += s.correctMatches;
    }

    final errorRate = totalMatches > 0 ? totalErrors / totalMatches : 0.0;

    // Struggling: Multiple repeated errors per match or heavy hint reliance
    if (errorRate > 1.8 || (totalHints >= 3 && errorRate > 1.0)) {
      return PerformanceBand.needsSupport;
    }

    // Comfortable: Very few mistakes, completed smoothly, minimal hint reliance
    if (errorRate <= 0.4 && totalHints <= 1) {
      return PerformanceBand.comfortable;
    }

    return PerformanceBand.balanced;
  }

  /// Suggests whether to advance level, stay, or suggest relaxed assistance
  int getNextRecommendedLevel({required String gameId, required int currentLevel, required int maxLevel}) {
    final band = evaluatePerformance(gameId);

    switch (band) {
      case PerformanceBand.comfortable:
        return min(currentLevel + 1, maxLevel);
      case PerformanceBand.needsSupport:
        // Keep current level and offer gentle assistance rather than punishing backward movement
        return currentLevel;
      case PerformanceBand.balanced:
        return currentLevel;
    }
  }

  /// Gentle encouraging message tailored to performance band
  String getAdaptiveEncouragement(PerformanceBand band, {bool isHindi = false}) {
    switch (band) {
      case PerformanceBand.comfortable:
        return isHindi
            ? 'बहुत सुंदर! आपने बहुत सहजता से पूरा किया।'
            : 'Wonderful! You moved through that very comfortably.';
      case PerformanceBand.needsSupport:
        return isHindi
            ? 'शानदार प्रयास! अपनी गति से आराम से खेलें।'
            : 'Great effort! Take your time, there is no hurry.';
      case PerformanceBand.balanced:
        return isHindi
            ? 'बहुत अच्छा प्रयास! आपका ध्यान प्रशंसनीय है।'
            : 'Well done! You are doing beautifully.';
    }
  }
}
