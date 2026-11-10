// Mindora - Professional Caregiver Dashboard
// Designed for family caregivers and care partners to view wellness and activity summaries.
// Strictly conforms to medical dignity standards: NEVER uses the word "Patient".
// Includes Daily Activity, Activity Overview, Game Progress, Mood History, Weekly Summary,
// Activity Calendar, Engagement Trends, Notifications, and Activity Insights.

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'theme/mindora_theme.dart';
import 'app_settings.dart';
import 'screens/caregiver_login_screen.dart';

class CaregiverPortal extends StatelessWidget {
  const CaregiverPortal({super.key});

  String tr(String en, String hi, {String? key}) =>
      AppSettings.instance.trBilingual(en, hi, key: key);

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
              tr('Caregiver Portal', 'देखभालकर्ता पोर्टल'),
              style: MindoraTextStyles.displayMedium.copyWith(fontSize: 22),
            ),
            actions: [
              IconButton(
                tooltip: tr('Sign Out', 'लॉग आउट'),
                icon: const Icon(Icons.logout_rounded),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CaregiverLoginScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // Family Member Profile Header (Never uses the word "Patient")
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: mindoraGradientCard(
                    colors: [
                      MindoraColors.cardGreen,
                      MindoraColors.cardAmber.withValues(alpha: 0.3),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: MindoraColors.forestGreen,
                        child: const Icon(Icons.person_rounded, size: 34, color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('Family Member Overview', 'परिवार के सदस्य का विवरण'),
                              style: MindoraTextStyles.titleLarge.copyWith(fontSize: 18),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${tr("Connected profile", "संबद्ध खाता")}: H. S. (Guwahati, Assam)',
                              style: MindoraTextStyles.caption.copyWith(color: MindoraColors.forestGreen),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: MindoraColors.cardGreen,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: MindoraColors.sageGreen),
                        ),
                        child: Text(
                          tr('Active', 'सक्रिय'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: MindoraColors.forestGreen),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 1. Daily Activity
                _sectionHeader(tr('Daily Activity', 'दैनिक गतिविधि'), Icons.today_rounded),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _statMetricCard(
                        title: tr('Games Played', 'खेले गए खेल'),
                        value: '4',
                        subtitle: tr('Today', 'आज'),
                        icon: Icons.sports_esports_rounded,
                        color: MindoraColors.cardGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statMetricCard(
                        title: tr('Time Spent', 'बिताया गया समय'),
                        value: '22m',
                        subtitle: tr('Calm pacing', 'सहज गति'),
                        icon: Icons.schedule_rounded,
                        color: MindoraColors.cardAmber,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 2. Activity Overview
                _sectionHeader(tr('Activity Overview', 'गतिविधि अवलोकन'), Icons.dashboard_outlined),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: mindoraCard(color: Colors.white),
                  child: Column(
                    children: [
                      _overviewRow(tr('Breathing Sessions Completed', 'श्वास सत्र पूर्ण किए'), '2 sessions', Icons.spa_rounded),
                      const Divider(height: 20),
                      _overviewRow(tr('Average Session Comfort', 'सत्र में सहजता स्तर'), '94% Comfortable', Icons.sentiment_very_satisfied_rounded),
                      const Divider(height: 20),
                      _overviewRow(tr('Hints Assisted', 'सहायता संकेत प्रयुक्त'), '2 gentle cues', Icons.lightbulb_outline_rounded),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 3. Game Progress
                _sectionHeader(tr('Game Progress', 'खेलों में प्रगति'), Icons.stairs_rounded),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: mindoraCard(color: Colors.white),
                  child: Column(
                    children: [
                      _gameProgressRow(tr('Memory Match', 'स्मृति मिलान'), 'Level 3 Unlocked', 0.75),
                      const SizedBox(height: 12),
                      _gameProgressRow(tr('Pattern Match', 'पैटर्न पहचान'), 'Level 2 Active', 0.50),
                      const SizedBox(height: 12),
                      _gameProgressRow(tr('Word Recall', 'शब्द स्मरण'), 'Level 2 Active', 0.50),
                      const SizedBox(height: 12),
                      _gameProgressRow(tr('Sound Recognition', 'ध्वनि पहचान'), 'Level 2 Active', 0.50),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 4. Mood History
                _sectionHeader(tr('Mood History', 'मनोदशा का इतिहास'), Icons.favorite_outline_rounded),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: mindoraCard(color: Colors.white),
                  child: Column(
                    children: [
                      _moodItem(tr('Today, Morning', 'आज, सुबह'), tr('Calm & Content', 'शांत और प्रसन्न'), Icons.sentiment_satisfied_alt_rounded, MindoraColors.sageGreen),
                      const SizedBox(height: 8),
                      _moodItem(tr('Yesterday, Afternoon', 'कल, दोपहर'), tr('Happy', 'आनंदित'), Icons.sentiment_very_satisfied_rounded, MindoraColors.warmAmber),
                      const SizedBox(height: 8),
                      _moodItem(tr('2 Days ago', '२ दिन पहले'), tr('Peaceful', 'शांत'), Icons.spa_rounded, MindoraColors.softBlue),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 5. Weekly Summary & Chart
                _sectionHeader(tr('Weekly Summary', 'साप्ताहिक सारांश'), Icons.bar_chart_rounded),
                const SizedBox(height: 10),
                Container(
                  height: 180,
                  padding: const EdgeInsets.all(16),
                  decoration: mindoraCard(color: Colors.white),
                  child: BarChart(
                    BarChartData(
                      maxY: 30,
                      barGroups: [
                        BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 15, color: MindoraColors.sageGreen, width: 14, borderRadius: BorderRadius.circular(4))]),
                        BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 20, color: MindoraColors.sageGreen, width: 14, borderRadius: BorderRadius.circular(4))]),
                        BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 12, color: MindoraColors.sageGreen, width: 14, borderRadius: BorderRadius.circular(4))]),
                        BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 25, color: MindoraColors.sageGreen, width: 14, borderRadius: BorderRadius.circular(4))]),
                        BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: 18, color: MindoraColors.sageGreen, width: 14, borderRadius: BorderRadius.circular(4))]),
                        BarChartGroupData(x: 5, barRods: [BarChartRodData(toY: 22, color: MindoraColors.sageGreen, width: 14, borderRadius: BorderRadius.circular(4))]),
                        BarChartGroupData(x: 6, barRods: [BarChartRodData(toY: 28, color: MindoraColors.terracotta, width: 14, borderRadius: BorderRadius.circular(4))]),
                      ],
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (val, meta) => Text('${val.toInt()}m', style: const TextStyle(fontSize: 10)),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, meta) {
                              const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                              return Text(days[val.toInt() % 7], style: const TextStyle(fontSize: 11));
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: true, drawVerticalLine: false),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 6. Activity Calendar
                _sectionHeader(tr('Activity Calendar', 'गतिविधि कैलेंडर'), Icons.calendar_month_rounded),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: mindoraCard(color: Colors.white),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(7, (index) {
                      final dayNum = 1 + index;
                      final isActive = index != 2;

                      return Column(
                        children: [
                          Text('Nov $dayNum', style: const TextStyle(fontSize: 11, color: MindoraColors.textMuted)),
                          const SizedBox(height: 6),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: isActive ? MindoraColors.cardGreen : MindoraColors.borderLight,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isActive ? MindoraColors.sageGreen : MindoraColors.borderMedium,
                              ),
                            ),
                            child: Icon(
                              isActive ? Icons.check_rounded : Icons.horizontal_rule_rounded,
                              size: 18,
                              color: isActive ? MindoraColors.forestGreen : MindoraColors.textMuted,
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 24),

                // 7. Engagement Trends
                _sectionHeader(tr('Engagement Trends', 'सहभागिता का रुझान'), Icons.trending_up_rounded),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: mindoraCard(color: MindoraColors.cardBlue.withValues(alpha: 0.5)),
                  child: Row(
                    children: [
                      const Icon(Icons.show_chart_rounded, size: 36, color: MindoraColors.softBlue),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          tr(
                            'Consistent engagement: 85% steady comfort over the past 14 days with positive morning activity patterns.',
                            'स्थिर सहभागिता: पिछले १४ दिनों में सकारात्मक सुबह की गतिविधियों के साथ ८५% सहजता दर्ज की गई।',
                          ),
                          style: MindoraTextStyles.bodyMedium.copyWith(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 8. Notifications
                _sectionHeader(tr('Notifications', 'सूचनाएं'), Icons.notifications_none_rounded),
                const SizedBox(height: 10),
                _notificationTile(
                  title: tr('Memory Match Milestone', 'स्मृति मिलान उपलब्धि'),
                  subtitle: tr('Completed Level 2 handloom set with zero stress hints.', 'बिना किसी परेशानी के स्तर २ पूरा किया।'),
                  time: tr('2 hours ago', '२ घंटे पहले'),
                ),
                const SizedBox(height: 8),
                _notificationTile(
                  title: tr('Morning Check-in Recorded', 'सुबह की मनोदशा दर्ज'),
                  subtitle: tr('Selected "Calm" after morning garden walking prompt.', 'उद्यान विश्राम के बाद शांत भाव दर्ज किया।'),
                  time: tr('5 hours ago', '५ घंटे पहले'),
                ),

                const SizedBox(height: 24),

                // 9. Activity Insights
                _sectionHeader(tr('Activity Insights', 'गतिविधि अंतर्दृष्टि'), Icons.insights_rounded),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: mindoraCard(color: MindoraColors.cardAmber),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('Key Observations', 'प्रमुख अवलोकन'),
                        style: MindoraTextStyles.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr(
                          '• Responsive to regional nature themes (living root bridges & tea flora).\n'
                          '• Word recall shows high comfort during mid-morning tea hours.\n'
                          '• Relaxed mode breathing brings visible evening calm.',
                          '• प्रकृति और चाय बगान के विषयों में उच्च रुचि।\n'
                          '• सुबह की चाय के समय शब्द स्मरण में अच्छी सहजता।\n'
                          '• शाम के समय शांत श्वास अभ्यास से सकारात्मक प्रभाव।',
                        ),
                        style: MindoraTextStyles.bodyMedium.copyWith(fontSize: 14, height: 1.6),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Consent Notice
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MindoraColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded, color: MindoraColors.forestGreen),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tr(
                            'All information is stored locally during frontend preview. Cloud authentication and sync will be established during backend integration.',
                            'यह सारा विवरण वर्तमान में केवल पूर्वावलोकन डेटा है। आगामी चरण में सुरक्षित बैकएंड से वास्तविक डेटा जोड़ा जाएगा।',
                          ),
                          style: MindoraTextStyles.caption,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: MindoraColors.sageGreen, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: MindoraTextStyles.titleLarge.copyWith(fontSize: 18),
        ),
      ],
    );
  }

  Widget _statMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: mindoraCard(color: color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: MindoraColors.forestGreen, size: 26),
          const SizedBox(height: 10),
          Text(value, style: MindoraTextStyles.displayMedium.copyWith(fontSize: 26)),
          const SizedBox(height: 2),
          Text(title, style: MindoraTextStyles.titleMedium.copyWith(fontSize: 14)),
          Text(subtitle, style: MindoraTextStyles.caption),
        ],
      ),
    );
  }

  Widget _overviewRow(String title, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 22, color: MindoraColors.sageGreen),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: MindoraTextStyles.bodyMedium)),
        Text(value, style: MindoraTextStyles.titleMedium.copyWith(fontSize: 14)),
      ],
    );
  }

  Widget _gameProgressRow(String game, String status, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(game, style: MindoraTextStyles.titleMedium.copyWith(fontSize: 15)),
            Text(status, style: MindoraTextStyles.caption),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: MindoraColors.borderLight,
          color: MindoraColors.sageGreen,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }

  Widget _moodItem(String time, String mood, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(child: Text(mood, style: MindoraTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600))),
        Text(time, style: MindoraTextStyles.caption),
      ],
    );
  }

  Widget _notificationTile({
    required String title,
    required String subtitle,
    required String time,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: mindoraCard(color: Colors.white),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, size: 10, color: MindoraColors.sageGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: MindoraTextStyles.titleMedium.copyWith(fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: MindoraTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(time, style: MindoraTextStyles.caption.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}
