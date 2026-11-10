
// Mindora – Main application entry point
// Cognitive Wellness Through Play
// For elderly users in North-East India

import 'package:flutter/material.dart';
import 'progress_page.dart';
import 'mood_checkin.dart';
import 'settings_page.dart';
import 'app_settings.dart';
import 'theme/mindora_theme.dart';
import 'screens/games_hub_screen.dart';
import 'screens/feel_good_screen.dart';
import 'screens/caregiver_login_screen.dart';
import 'models/level_data.dart';
import 'services/audio_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.loadSettings();
  await LevelProgressManager.instance.loadProgress();
  await AudioService.instance.initialize();
  runApp(const MindoraApp());
}

class MindoraApp extends StatelessWidget {
  const MindoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Mindora',
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: MindoraColors.cream,
            colorScheme: ColorScheme.fromSeed(
              seedColor: MindoraColors.sageGreen,
              surface: MindoraColors.cream,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: MindoraColors.cream,
              foregroundColor: MindoraColors.forestGreen,
              elevation: 0,
              scrolledUnderElevation: 0,
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

// ─────────────────────────────────────────────────────────────────────────────
// Home Screen
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String tr(String english, String hindi, {String? key}) =>
      AppSettings.instance.trBilingual(english, hindi, key: key);

  // Returns a time-of-day greeting
  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return tr('Good morning', 'सुप्रभात');
    } else if (hour < 17) {
      return tr('Good afternoon', 'शुभ दोपहर');
    } else {
      return tr('Good evening', 'शुभ संध्या');
    }
  }

  // Rotates through daily activity suggestions by day of week
  Map<String, String> _dailySuggestion() {
    final suggestions = [
      {
        'en': 'Try Memory Match today — find the matching pairs.',
        'hi': 'आज मेमोरी मैच खेलें — मिलते जुलते जोड़े खोजें।',
        'icon': 'memory',
      },
      {
        'en': 'Take a moment for the breathing exercise in Feel Good.',
        'hi': 'फील गुड में श्वास व्यायाम के लिए एक पल लें।',
        'icon': 'breathe',
      },
      {
        'en': 'Check in with how you are feeling today.',
        'hi': 'आज आप कैसा महसूस कर रहे हैं, यह देखें।',
        'icon': 'mood',
      },
      {
        'en': 'Look at your progress — every game you play matters.',
        'hi': 'अपनी प्रगति देखें — आपका हर खेल मायने रखता है।',
        'icon': 'progress',
      },
      {
        'en': 'Spend a few calm minutes with Feel Good today.',
        'hi': 'आज फील गुड के साथ कुछ शांत मिनट बिताएं।',
        'icon': 'breathe',
      },
      {
        'en': 'Try Memory Match — take your time with each card.',
        'hi': 'मेमोरी मैच खेलें — हर कार्ड के साथ अपना समय लें।',
        'icon': 'memory',
      },
      {
        'en': 'Begin with a Mood Check-in to start your day gently.',
        'hi': 'अपना दिन धीरे से शुरू करने के लिए मूड चेक-इन से शुरुआत करें।',
        'icon': 'mood',
      },
    ];
    final index = DateTime.now().weekday - 1;
    return suggestions[index % suggestions.length];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        final suggestion = _dailySuggestion();

        return Scaffold(
          backgroundColor: MindoraColors.cream,
          appBar: AppBar(
            title: const Text(
              'Mindora',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: MindoraColors.forestGreen,
                letterSpacing: -0.3,
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
                icon: const Icon(
                  Icons.settings_outlined,
                  size: 27,
                  color: MindoraColors.forestGreen,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Greeting ────────────────────────────────────────
                  Text(
                    '${_greeting()} 🌿',
                    style: MindoraTextStyles.displayLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr(
                      'Cognitive Wellness Through Play',
                      'खेल के माध्यम से मानसिक स्वास्थ्य',
                    ),
                    style: MindoraTextStyles.bodyMedium,
                  ),

                  const SizedBox(height: 24),

                  // ── Daily Activity Suggestion ───────────────────────
                  Semantics(
                    label: tr("Today's Activity", 'आज की गतिविधि'),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: mindoraGradientCard(
                        colors: [
                          const Color(0xFFE8EDD8),
                          const Color(0xFFF2E8D6),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: MindoraColors.sageGreen
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  tr("Today's Activity", 'आज की गतिविधि'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: MindoraColors.sageGreen,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.spa_rounded,
                                size: 40,
                                color: MindoraColors.sageGreen,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  AppSettings.instance.isHindi
                                      ? suggestion['hi']!
                                      : suggestion['en']!,
                                  style: MindoraTextStyles.bodyLarge.copyWith(
                                    color: MindoraColors.forestGreen,
                                    fontWeight: FontWeight.w500,
                                    height: 1.55,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Section: Activities ─────────────────────────────
                  Text(
                    tr('Choose Your Activity', 'अपनी गतिविधि चुनें'),
                    style: MindoraTextStyles.titleLarge.copyWith(fontSize: 22),
                  ),

                  const SizedBox(height: 14),

                  // Mood Check-in
                  _activityCard(
                    context,
                    icon: Icons.favorite_rounded,
                    title: tr('Mood Check-in', 'मूड चेक-इन'),
                    subtitle: tr(
                      'How are you feeling right now?',
                      'आप अभी कैसा महसूस कर रहे हैं?',
                    ),
                    color: const Color(0xFFFFE4E4),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MoodCheckIn(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // Cognitive Games hub
                  _activityCard(
                    context,
                    icon: Icons.extension_rounded,
                    title: tr('Cognitive Games', 'संज्ञानात्मक खेल'),
                    subtitle: tr(
                      'Memory Match, Pattern Match and more',
                      'मेमोरी मैच, पैटर्न मैच और अधिक',
                    ),
                    color: MindoraColors.cardGreen,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GamesHubScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // Feel Good
                  _activityCard(
                    context,
                    icon: Icons.spa_rounded,
                    title: tr('Feel Good', 'अच्छा महसूस करें'),
                    subtitle: tr(
                      'Breathing, relaxation and gentle prompts',
                      'श्वास, आराम और धीरे-धीरे संकेत',
                    ),
                    color: MindoraColors.cardRose,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FeelGoodScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // My Progress
                  _activityCard(
                    context,
                    icon: Icons.bar_chart_rounded,
                    title: tr('My Progress', 'मेरी प्रगति'),
                    subtitle: tr(
                      'Your games and activity history',
                      'आपके खेल और गतिविधि इतिहास',
                    ),
                    color: const Color(0xFFDDE8F8),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProgressPage(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // Caregiver Portal Entry
                  _activityCard(
                    context,
                    icon: Icons.volunteer_activism_rounded,
                    title: tr('Caregiver Portal', 'देखभालकर्ता पोर्टल'),
                    subtitle: tr(
                      'Dedicated caregiver login & dashboard',
                      'देखभालकर्ता लॉगिन एवं डैशबोर्ड',
                    ),
                    color: MindoraColors.cardAmber,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CaregiverLoginScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // ── Footer message ──────────────────────────────────
                  Center(
                    child: Text(
                      tr(
                        'Small steps, brighter moments. 🌸',
                        'छोटे कदम, उज्जवल पल। 🌸',
                      ),
                      textAlign: TextAlign.center,
                      style: MindoraTextStyles.bodyMedium.copyWith(
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
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
    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: MindoraColors.borderLight),
            ),
            child: Row(
              children: [
                // Icon badge
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: MindoraColors.forestGreen,
                  ),
                ),

                const SizedBox(width: 14),

                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: MindoraTextStyles.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: MindoraTextStyles.bodyMedium.copyWith(
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 17,
                  color: MindoraColors.sageGreen,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
