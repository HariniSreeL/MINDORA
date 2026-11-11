
import 'package:flutter/foundation.dart';

class GameSession {
  final String gameName;
  final DateTime date;
  final Duration duration;
  final int moves;
  final int pairsMatched;
  final bool completed;
  final int level;
  final double score;

  GameSession({
    required this.gameName,
    required this.date,
    required this.duration,
    required this.moves,
    required this.pairsMatched,
    required this.completed,
    this.level = 0,
    this.score = 0,
  });
}

class GameProgress extends ChangeNotifier {
  GameProgress._();

  static final GameProgress instance = GameProgress._();

  final List<GameSession> _sessions = [];

  List<GameSession> get sessions =>
      List.unmodifiable(_sessions.reversed);

  int get gamesPlayed => _sessions.length;

  int get totalPairsMatched =>
      _sessions.fold(0, (total, session) => total + session.pairsMatched);

  Duration get totalTime => _sessions.fold(
        Duration.zero,
        (total, session) => total + session.duration,
      );

  GameSession? get bestResult {
    final completedGames =
        _sessions.where((session) => session.completed).toList();

    if (completedGames.isEmpty) return null;

    completedGames.sort((a, b) {
      final movesComparison = a.moves.compareTo(b.moves);
      if (movesComparison != 0) return movesComparison;
      return a.duration.compareTo(b.duration);
    });

    return completedGames.first;
  }

  String get mostPlayedGame {
    if (_sessions.isEmpty) return 'Not yet recorded';

    final counts = <String, int>{};

    for (final session in _sessions) {
      counts[session.gameName] = (counts[session.gameName] ?? 0) + 1;
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.first.key;
  }

  void addSession(GameSession session) {
    _sessions.add(session);
    notifyListeners();
  }

  /// Drops cached progress. Used on sign-out and when the signed-in account
  /// changes so one Loved One never sees another account's history.
  void clear() {
    if (_sessions.isEmpty) return;
    _sessions.clear();
    notifyListeners();
  }

  /// Replaces local history with the authoritative server history.
  ///
  /// [rows] are the backend rows (newest-first). A successful empty response is
  /// authoritative and clears the cache, while a payload that cannot be parsed
  /// keeps the last known-good data. Returns true when the cache was updated.
  bool replaceFromServer(List<dynamic> rows) {
    final parsed = <GameSession>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final status = row['status']?.toString().toLowerCase();
      // A session that is still being played is not progress yet. Abandoned
      // sessions are excluded from analytics too, so My Progress stays
      // consistent with the caregiver dashboard.
      if (status == 'started' || status == 'abandoned') continue;
      final date = _parseServerDate(row['created_at']) ?? DateTime.now();
      final seconds = _asInt(row['duration_seconds']);
      final correct = _asInt(row['correct_matches']);
      final gameName = (row['game_name']?.toString().trim().isNotEmpty ?? false)
          ? row['game_name'].toString()
          : _displayName(row['game_id']?.toString() ?? '');
      parsed.add(GameSession(
        gameName: gameName.isEmpty ? 'Mindora Game' : gameName,
        date: date,
        duration: Duration(seconds: seconds),
        moves: _asInt(row['moves']),
        pairsMatched: correct,
        completed: row['completed'] == true ||
            row['completed'] == 1 ||
            row['completed'] == '1',
        level: _asInt(row['level']),
        score: _asDouble(row['score']),
      ));
    }
    if (rows.isNotEmpty && parsed.isEmpty) return false;
    _sessions
      ..clear()
      ..addAll(parsed.reversed);
    notifyListeners();
    return true;
  }

  static DateTime? _parseServerDate(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return null;
    var text = raw.replaceFirst(' ', 'T');
    final hasZone = text.endsWith('Z') ||
        RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(text);
    if (!hasZone) text = '${text}Z';
    return DateTime.tryParse(text)?.toLocal();
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _displayName(String gameId) {
    switch (gameId) {
      case 'memory_match':
        return 'Memory Match';
      case 'pattern_match':
        return 'Pattern Match';
      case 'word_recall':
        return 'Word Recall';
      case 'sound_recognition':
        return 'Sound Recognition';
      default:
        return gameId;
    }
  }
}
