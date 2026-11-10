// Mindora - Cognitive Games Hub Screen
// Central access point for all 4 cognitive gaming modules:
// 1. Memory Match (Card matching with cultural sets)
// 2. Pattern Match (Weave & sequence deduction)
// 3. Word Recall (Unhurried cultural vocabulary memory)
// 4. Sound Recognition (Environmental & traditional instruments)

import 'package:flutter/material.dart';
import '../app_settings.dart';
import '../theme/mindora_theme.dart';
import '../memory_game.dart';
import 'pattern_match_screen.dart';
import 'word_recall_screen.dart';
import 'sound_recognition_screen.dart';

class GamesHubScreen extends StatelessWidget {
  const GamesHubScreen({super.key});

  String tr(String english, String hindi, {String? key}) =>
      AppSettings.instance.trBilingual(english, hindi, key: key);

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
              tr('Cognitive Games', 'संज्ञानात्मक खेल'),
              style: MindoraTextStyles.displayMedium,
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(
                      'Choose a game and play at your own pace.',
                      'एक खेल चुनें और अपनी गति से आराम से खेलें।',
                    ),
                    style: MindoraTextStyles.bodyLarge,
                  ),

                  const SizedBox(height: 20),

                  // 1. Memory Match
                  _gameCard(
                    context,
                    icon: Icons.grid_view_rounded,
                    title: tr('Memory Match', 'स्मृति मिलान'),
                    description: tr(
                      'Find pairs of familiar fruits, orchids, tea leaves and traditional handloom objects.',
                      'परिचित फलों, फूलों, चाय की पत्तियों और पारंपरिक वस्तुओं के मिलते-जुलते जोड़े खोजें।',
                    ),
                    color: MindoraColors.cardGreen,
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

                  // 2. Pattern Match
                  _gameCard(
                    context,
                    icon: Icons.pattern_rounded,
                    title: tr('Pattern Match', 'पैटर्न पहचान'),
                    description: tr(
                      'Recognize traditional handloom weave rhythms, shapes and nature sequences.',
                      'पारंपरिक बुनाई के रूपांकनों, आकृतियों और प्राकृतिक क्रमों को पहचानें।',
                    ),
                    color: MindoraColors.cardAmber,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PatternMatchScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 14),

                  // 3. Word Recall
                  _gameCard(
                    context,
                    icon: Icons.text_fields_rounded,
                    title: tr('Word Recall', 'शब्द स्मरण'),
                    description: tr(
                      'Unhurried memory game with familiar words from family, nature, food and home.',
                      'परिवार, प्रकृति, आहार और घर से जुड़े परिचित शब्दों को याद रखने का शांत खेल।',
                    ),
                    color: MindoraColors.cardBlue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WordRecallScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 14),



                  // 5. Sound Recognition
                  _gameCard(
                    context,
                    icon: Icons.volume_up_rounded,
                    title: tr('Sound Recognition', 'ध्वनि पहचान'),
                    description: tr(
                      'Listen to familiar sounds of rain, temple bells, bamboo flutes and forest birds.',
                      'बारिश, मंदिर की घंटी, बांसुरी और वन पक्षियों की परिचित आवाजों को सुनकर पहचानें।',
                    ),
                    color: const Color(0xFFE8E0F0),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SoundRecognitionScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // Comfort Notice
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: mindoraCard(color: MindoraColors.cardGreen),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.spa_rounded,
                          size: 24,
                          color: MindoraColors.sageGreen,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            tr(
                              'Every game has hints, unlimited attempts, and a relaxed mode. Enjoy your time.',
                              'प्रत्येक खेल में संकेत, असीमित प्रयास और आराम मोड है। बिना किसी दबाव के खेलें।',
                            ),
                            style: MindoraTextStyles.bodyMedium.copyWith(
                              color: MindoraColors.forestGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _gameCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: mindoraCard(color: color),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    size: 30,
                    color: MindoraColors.forestGreen,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: MindoraTextStyles.titleLarge,
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: MindoraColors.sageGreen,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: MindoraTextStyles.bodyMedium.copyWith(
                          color: MindoraColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
