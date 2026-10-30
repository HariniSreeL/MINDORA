
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'app_settings.dart';
import 'game_progress.dart';

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});

  static const Color green = Color(0xFF52796F);
  static const Color cream = Color(0xFFF8F6EF);
  static const Color dark = Color(0xFF344E41);

  String tr(String english, String hindi) =>
      AppSettings.instance.isHindi ? hindi : english;

  String formatDuration(Duration duration) {
    if (duration.inMinutes < 1) {
      return '${duration.inSeconds}${tr('s', 'सेकंड')}';
    }
    return '${duration.inMinutes}${tr('m', 'मिनट')} '
        '${duration.inSeconds % 60}${tr('s', 'सेकंड')}';
  }

  String gameName(String name) {
    if (name == 'Memory Match') {
      return tr('Memory Match', 'मेमोरी मैच');
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        return AnimatedBuilder(
          animation: GameProgress.instance,
          builder: (context, _) {
            final progress = GameProgress.instance;
            final sessions = progress.sessions;

            return Scaffold(
              backgroundColor: cream,
              appBar: AppBar(
                title: Text(tr('My Progress', 'मेरी प्रगति')),
                backgroundColor: cream,
                foregroundColor: dark,
                elevation: 0,
              ),
              body: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Text(
                    tr('Your Journey 🌿', 'आपकी यात्रा 🌿'),
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: dark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      'Every little step counts. Keep playing at your own pace.',
                      'आपका हर छोटा कदम महत्वपूर्ण है। अपनी गति से खेलते रहें।',
                    ),
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),

                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 5.0,
                    children: [
                      _statCard(
                        tr('Games Played', 'खेले गए गेम'),
                        '${progress.gamesPlayed}',
                        Icons.sports_esports_rounded,
                      ),
                      _statCard(
                        tr('Total Play Time', 'कुल खेलने का समय'),
                        formatDuration(progress.totalTime),
                        Icons.schedule_rounded,
                      ),
                      _statCard(
                        tr('Pairs Matched', 'मिलाए गए जोड़े'),
                        '${progress.totalPairsMatched}',
                        Icons.extension_rounded,
                      ),
                      _statCard(
                        tr('Favourite Game', 'पसंदीदा गेम'),
                        gameName(progress.mostPlayedGame),
                        Icons.favorite_rounded,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  _sectionTitle(tr('Daily Play Time', 'दैनिक खेलने का समय')),
                  const SizedBox(height: 5),
                  Text(
                    tr(
                      'Your playing time over the last 7 days',
                      'पिछले 7 दिनों में आपका खेलने का समय',
                    ),
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  _chartCard(
                    child: sessions.isEmpty
                        ? _EmptyChart(
                            message: tr(
                              'Play a game to see your daily activity here.',
                              'अपनी दैनिक गतिविधि देखने के लिए कोई गेम खेलें।',
                            ),
                          )
                        : SizedBox(
                            height: 220,
                            child: _dailyChart(sessions),
                          ),
                  ),

                  const SizedBox(height: 24),
                  _sectionTitle(
                    tr('Game Duration Trend', 'गेम खेलने के समय का रुझान'),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    tr(
                      'Time taken to complete each game',
                      'हर गेम पूरा करने में लगा समय',
                    ),
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  _chartCard(
                    child: _performanceChart(sessions),
                  ),

                  const SizedBox(height: 24),
                  _sectionTitle(tr('Best Result', 'सर्वश्रेष्ठ परिणाम')),
                  const SizedBox(height: 12),
                  _chartCard(
                    child: progress.bestResult == null
                        ? _EmptyChart(
                            message: tr(
                              'Complete a game to record your best result.',
                              'अपना सर्वश्रेष्ठ परिणाम दर्ज करने के लिए एक गेम पूरा करें।',
                            ),
                          )
                        : Row(
                            children: [
                              const Icon(
                                Icons.emoji_events_rounded,
                                size: 38,
                                color: Color(0xFFC49A42),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tr(
                                        '${progress.bestResult!.moves} moves',
                                        '${progress.bestResult!.moves} चालें',
                                      ),
                                      style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.bold,
                                        color: dark,
                                      ),
                                    ),
                                    Text(
                                      tr(
                                        'Completed in ${formatDuration(progress.bestResult!.duration)}',
                                        '${formatDuration(progress.bestResult!.duration)} में पूरा हुआ',
                                      ),
                                      style: const TextStyle(
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 24),
                  _sectionTitle(tr('Recent Activity', 'हाल की गतिविधि')),
                  const SizedBox(height: 12),

                  if (sessions.isEmpty)
                    _chartCard(
                      child: _EmptyChart(
                        message: tr(
                          'Your recent games will appear here.',
                          'आपके हाल के गेम यहाँ दिखाई देंगे।',
                        ),
                      ),
                    )
                  else
                    ...sessions.take(5).map(
                      (session) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xFFE4EDE5),
                              child: Icon(
                                Icons.extension_rounded,
                                color: green,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    gameName(session.gameName),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: dark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    tr(
                                      '${session.moves} moves • ${session.pairsMatched} pairs',
                                      '${session.moves} चालें • ${session.pairsMatched} जोड़े',
                                    ),
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    session.completed
                                        ? tr('Completed', 'पूरा हुआ')
                                        : tr('Session ended', 'सत्र समाप्त'),
                                    style: TextStyle(
                                      color: session.completed
                                          ? green
                                          : Colors.black54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatDuration(session.duration),
                              style: const TextStyle(
                                color: dark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),
                  Text(
                    tr(
                      'These charts show your game activity, not a medical assessment.',
                      'ये चार्ट आपकी गेम गतिविधि दिखाते हैं, चिकित्सा मूल्यांकन नहीं।',
                    ),
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _statCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: green, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: dark,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: dark,
        fontSize: 19,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _chartCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }

  Widget _dailyChart(List<GameSession> sessions) {
    final now = DateTime.now();
    final days = List.generate(
      7,
      (index) => DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 6 - index)),
    );

    final values = days.map((day) {
      final totalSeconds = sessions
          .where(
            (session) =>
                session.date.year == day.year &&
                session.date.month == day.month &&
                session.date.day == day.day,
          )
          .fold<int>(
            0,
            (total, session) => total + session.duration.inSeconds,
          );
      return totalSeconds / 60;
    }).toList();

    final maxValue = values.fold<double>(
      1,
      (max, value) => value > max ? value : max,
    );

    const englishDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const hindiDays = ['सोम', 'मंगल', 'बुध', 'गुरु', 'शुक्र', 'शनि', 'रवि'];

    return BarChart(
      BarChartData(
        maxY: maxValue * 1.35,
        barGroups: List.generate(7, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: values[index],
                color: green,
                width: 17,
                borderRadius: BorderRadius.circular(5),
              ),
            ],
          );
        }),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: Text(tr('Minutes', 'मिनट')),
            sideTitles: const SideTitles(
              showTitles: true,
              reservedSize: 38,
              getTitlesWidget: _leftTitle,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index > 6) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    AppSettings.instance.isHindi
                        ? hindiDays[days[index].weekday - 1]
                        : englishDays[days[index].weekday - 1],
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final day = days[group.x];
              final dayLabel = AppSettings.instance.isHindi
                  ? hindiDays[day.weekday - 1]
                  : englishDays[day.weekday - 1];
              return BarTooltipItem(
                '$dayLabel\n${rod.toY.toStringAsFixed(1)} ${tr('min', 'मिनट')}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  static Widget _leftTitle(double value, TitleMeta meta) {
    return Text(
      value.toInt().toString(),
      style: const TextStyle(fontSize: 10),
    );
  }

  Widget _performanceChart(List<GameSession> sessions) {
    final completed = sessions.where((session) => session.completed).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final recent = completed.length > 7
        ? completed.sublist(completed.length - 7)
        : completed;

    if (recent.length < 2) {
      return _EmptyChart(
        message: tr(
          'Complete at least 2 games to see your duration trend.',
          'समय का रुझान देखने के लिए कम से कम 2 गेम पूरे करें।',
        ),
      );
    }

    final spots = List.generate(
      recent.length,
      (index) => FlSpot(
        (index + 1).toDouble(),
        recent[index].duration.inSeconds.toDouble(),
      ),
    );

    final maxSeconds = spots.fold<double>(
      1,
      (max, spot) => spot.y > max ? spot.y : max,
    );

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minX: 1,
          maxX: recent.length.toDouble(),
          minY: 0,
          maxY: maxSeconds * 1.25,
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: green,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: green.withValues(alpha: 0.12),
              ),
            ),
          ],
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: Text(tr('Seconds', 'सेकंड')),
              sideTitles: const SideTitles(
                showTitles: true,
                reservedSize: 38,
                getTitlesWidget: _leftTitle,
              ),
            ),
            bottomTitles: AxisTitles(
              axisNameWidget: Text(tr('Completed games', 'पूरे किए गए गेम')),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (value != value.roundToDouble()) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((spot) {
                return LineTooltipItem(
                  '${spot.y.toInt()} ${tr('seconds', 'सेकंड')}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54),
        ),
      ),
    );
  }
}
