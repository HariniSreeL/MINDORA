
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
}
