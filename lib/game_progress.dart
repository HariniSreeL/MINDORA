
import 'package:flutter/foundation.dart';

class GameSession {
  final String gameName;
  final DateTime date;
  final Duration duration;
  final int moves;
  final int pairsMatched;
  final bool completed;

  GameSession({
    required this.gameName,
    required this.date,
    required this.duration,
    required this.moves,
    required this.pairsMatched,
    required this.completed,
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

  /// Replaces local history with server history. Rows are expected newest-first.
  /// Returns false when no valid rows were supplied.
  bool replaceFromServer(List<dynamic> rows) {
    final parsed = <GameSession>[];
    for (final row in rows) {
      if (row is! Map) continue;
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
      ));
    }
    if (parsed.isEmpty) return false;
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
