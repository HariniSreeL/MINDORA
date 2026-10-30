
import 'dart:async';

import 'package:flutter/material.dart';
import 'game_progress.dart';
import 'app_settings.dart';

class MemoryGame extends StatefulWidget {
  const MemoryGame({super.key});

  @override
  State<MemoryGame> createState() => _MemoryGameState();
}

class _MemoryGameState extends State<MemoryGame> {
  final List<String> symbols = [
    '🍎', '🌸', '🐦', '⭐',
    '🍎', '🌸', '🐦', '⭐',
  ];

  late List<String> cards;
  final List<int> selectedCards = [];
  final List<int> matchedCards = [];

  int moves = 0;
  bool checking = false;
  bool sessionSaved = false;
  late Stopwatch stopwatch;

  bool get completed => matchedCards.length == cards.length;

  bool get isHindi => AppSettings.instance.isHindi;

  String tr(String english, String hindi) {
    return isHindi ? hindi : english;
  }

  @override
  void initState() {
    super.initState();
    cards = List<String>.from(symbols)..shuffle();
    stopwatch = Stopwatch()..start();
  }

  void saveSession() {
    if (sessionSaved) return;

    stopwatch.stop();
    sessionSaved = true;

    GameProgress.instance.addSession(
      GameSession(
        gameName: 'Memory Match',
        date: DateTime.now(),
        duration: stopwatch.elapsed,
        moves: moves,
        pairsMatched: matchedCards.length ~/ 2,
        completed: completed,
      ),
    );
  }

  void resetGame() {
    saveSession();

    setState(() {
      cards = List<String>.from(symbols)..shuffle();
      selectedCards.clear();
      matchedCards.clear();
      moves = 0;
      checking = false;
      sessionSaved = false;
      stopwatch = Stopwatch()..start();
    });
  }

  Future<void> selectCard(int index) async {
    if (checking ||
        selectedCards.contains(index) ||
        matchedCards.contains(index) ||
        completed) {
      return;
    }

    setState(() {
      selectedCards.add(index);
    });

    if (selectedCards.length == 2) {
      setState(() {
        moves++;
      });

      if (cards[selectedCards[0]] == cards[selectedCards[1]]) {
        setState(() {
          matchedCards.addAll(selectedCards);
          selectedCards.clear();
        });

        if (completed) {
          saveSession();
        }
      } else {
        setState(() {
          checking = true;
        });

        await Future.delayed(const Duration(milliseconds: 900));

        if (!mounted) return;

        setState(() {
          selectedCards.clear();
          checking = false;
        });
      }
    }
  }

  @override
  void dispose() {
    saveSession();
    stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wideScreen = MediaQuery.sizeOf(context).width >= 650;

    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFFAF8F0),
          appBar: AppBar(
            title: Text(
              tr('Memory Match', 'याददाश्त का खेल'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Color(0xFF354C3C),
              ),
            ),
            backgroundColor: const Color(0xFFFAF8F0),
            foregroundColor: const Color(0xFF354C3C),
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, pageConstraints) {
                final columns = wideScreen ? 4 : 2;
                final rows = 8 ~/ columns;

                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: wideScreen ? 28 : 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      Text(
                        tr(
                          'Find the Matching Pairs',
                          'एक जैसे चित्रों के जोड़े खोजें',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF354C3C),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr(
                          'Find two pictures that are the same.',
                          'दो एक जैसे चित्रों को खोजें।',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17,
                          color: Color(0xFF55584E),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _scoreBox(
                              tr('Moves', 'चालें'),
                              '$moves',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _scoreBox(
                              tr('Pairs', 'जोड़े'),
                              '${matchedCards.length ~/ 2}/4',
                            ),
                          ),
                        ],
                      ),
                      if (completed)
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(
                            tr(
                              'Well done! All pairs matched.',
                              'बहुत अच्छा! सभी जोड़े मिल गए।',
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF356849),
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 12),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            const gap = 12.0;

                            final cardWidth =
                                (constraints.maxWidth -
                                    (columns - 1) * gap) /
                                columns;

                            final cardHeight =
                                (constraints.maxHeight -
                                    (rows - 1) * gap) /
                                rows;

                            final ratio = cardWidth / cardHeight;

                            return GridView.builder(
                              padding: EdgeInsets.zero,
                              physics:
                                  const NeverScrollableScrollPhysics(),
                              itemCount: cards.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: gap,
                                mainAxisSpacing: gap,
                                childAspectRatio: ratio,
                              ),
                              itemBuilder: (context, index) {
                                final revealed =
                                    selectedCards.contains(index) ||
                                    matchedCards.contains(index);

                                final matched =
                                    matchedCards.contains(index);

                                return Semantics(
                                  button: true,
                                  label: revealed
                                      ? tr(
                                          'Picture ${cards[index]}',
                                          'चित्र ${cards[index]}',
                                        )
                                      : tr(
                                          'Hidden picture',
                                          'छिपा हुआ चित्र',
                                        ),
                                  child: GestureDetector(
                                    onTap: () => selectCard(index),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      decoration: BoxDecoration(
                                        color: matched
                                            ? const Color(0xFFDDEBDD)
                                            : revealed
                                                ? const Color(0xFFFFE9C9)
                                                : const Color(0xFF64866B),
                                        borderRadius:
                                            BorderRadius.circular(18),
                                        border: Border.all(
                                          color: const Color(0xFFD5DFCF),
                                          width: 2,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          revealed ? cards[index] : '?',
                                          style: TextStyle(
                                            fontSize:
                                                wideScreen ? 40 : 34,
                                            fontWeight: FontWeight.bold,
                                            color: revealed
                                                ? const Color(0xFF30382F)
                                                : Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: resetGame,
                          icon: const Icon(Icons.refresh, size: 24),
                          label: Text(
                            tr('Play Again', 'फिर से खेलें'),
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF496C52),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _scoreBox(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E4D8)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF55584E),
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: Color(0xFF354C3C),
            ),
          ),
        ],
      ),
    );
  }
}
