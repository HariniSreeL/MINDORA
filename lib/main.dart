
import 'package:flutter/material.dart';
import 'memory_game.dart';
import 'progress_page.dart';
import 'caregiver_portal.dart';
import 'mood_checkin.dart';
import 'settings_page.dart';
import 'app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.loadSettings();
  runApp(const MindoraApp());
}

class MindoraApp extends StatelessWidget {
  const MindoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    const forest = Color(0xFF496C52);
    const cream = Color(0xFFFAF8F0);

    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Mindora',
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: cream,
            colorScheme: ColorScheme.fromSeed(
              seedColor: forest,
              surface: cream,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: cream,
              foregroundColor: Color(0xFF354C3C),
              elevation: 0,
            ),
          ),
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(
                  AppSettings.instance.textScale,
                ),
              ),
              child: child!,
            );
          },
          home: const HomeScreen(),
        );
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String tr(String english, String hindi) {
    return AppSettings.instance.isHindi ? hindi : english;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
    animation: AppSettings.instance,
    builder: (context, _) {
    const forest = Color(0xFF354C3C);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F0),
      appBar: AppBar(
        title: const Text(
          'Mindora',
          style: TextStyle(
            fontSize: 29,
            fontWeight: FontWeight.bold,
            color: forest,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsPage(),
                ),
              );
            },
            tooltip: tr('Settings', 'सेटिंग्स'),
            icon: const Icon(Icons.settings_outlined, size: 27),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('Welcome to Mindora', 'Mindora में आपका स्वागत है'),
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  color: forest,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr(
                  'Cognitive Wellness Through Play',
                  'खेल के माध्यम से मानसिक स्वास्थ्य',
                ),
                style: const TextStyle(
                  fontSize: 18,
                  color: Color(0xFF55584E),
                ),
              ),

              const SizedBox(height: 25),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(23),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFE7EAD9),
                      Color(0xFFF0E8D6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFDDE0D1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.spa_rounded,
                      size: 48,
                      color: Color(0xFF496C52),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      tr(
                        'Keep Your Mind Active',
                        'अपने मन को सक्रिय रखें',
                      ),
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        color: forest,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      tr(
                        'Explore gentle games and familiar activities '
                        'at your own pace.',
                        'अपनी गति से सरल खेलों और परिचित गतिविधियों '
                        'का आनंद लें।',
                      ),
                      style: const TextStyle(
                        fontSize: 17,
                        height: 1.6,
                        color: Color(0xFF454A40),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              Text(
                tr('Choose Your Activity', 'अपनी गतिविधि चुनें'),
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: forest,
                ),
              ),

              const SizedBox(height: 14),

              _activityCard(
                context,
                icon: Icons.favorite_rounded,
                title: tr('Mood Check-in', 'अपने मूड के बारे में बताएँ'),
                subtitle: tr(
                  'Share how you feel today',
                  'आज आप कैसा महसूस कर रहे हैं, बताएँ',
                ),
                color: const Color(0xFFE5DDF5),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MoodCheckIn(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 15),

              _activityCard(
                context,
                icon: Icons.grid_view_rounded,
                title: tr('Memory Match', 'याददाश्त का खेल'),
                subtitle: tr(
                  'Match pairs of identical pictures',
                  'एक जैसी तस्वीरों के जोड़े मिलाएँ',
                ),
                color: const Color(0xFFFFE9C9),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MemoryGame(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 14),

              _activityCard(
                context,
                icon: Icons.bar_chart_rounded,
                title: tr('My Progress', 'मेरी प्रगति'),
                subtitle: tr(
                  'View your games and activity history',
                  'अपने खेल और गतिविधियों का इतिहास देखें',
                ),
                color: const Color(0xFFDDEBDD),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProgressPage(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 14),

              _activityCard(
                context,
                icon: Icons.spa_rounded,
                title: tr('Feel Good', 'अच्छा महसूस करें'),
                subtitle: tr(
                  'Relax with gentle activities',
                  'सरल गतिविधियों से आराम पाएँ',
                ),
                color: const Color(0xFFF5E3DC),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        tr(
                          'Relaxing games are coming next.',
                          'आराम देने वाले खेल जल्द आएँगे।',
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 14),

              _activityCard(
                context,
                icon: Icons.volunteer_activism_rounded,
                title: tr('Caregiver Portal', 'देखभालकर्ता पोर्टल'),
                subtitle: tr(
                  'View shared activity and wellbeing',
                  'साझा की गई गतिविधियाँ और स्वास्थ्य देखें',
                ),
                color: const Color(0xFFE7EAD9),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CaregiverPortal(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 25),

              Center(
                child: Text(
                  tr(
                    'Small steps, brighter moments.',
                    'छोटे कदम, बेहतर पल।',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF55584E),
                    fontSize: 16,
                  ),
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

  Widget _activityCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: const BorderSide(
          color: Color(0xFFE7E5D9),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: CircleAvatar(
          radius: 27,
          backgroundColor: color,
          child: Icon(
            icon,
            size: 28,
            color: const Color(0xFF354C3C),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: Color(0xFF354C3C),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            subtitle,
            style: const TextStyle(
              fontSize: 16,
              height: 1.4,
              color: Color(0xFF55584E),
            ),
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 19,
          color: Color(0xFF496C52),
        ),
        onTap: onTap,
      ),
    );
  }
}
