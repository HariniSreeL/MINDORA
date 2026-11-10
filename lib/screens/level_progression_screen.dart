// Mindora - Level Progression Map Screen
// Nature-inspired winding path showing completed, active, and locked levels.
// Dignified, calm design avoiding childish flashy game visuals.

import 'package:flutter/material.dart';
import '../theme/mindora_theme.dart';
import '../models/level_data.dart';
import '../app_settings.dart';

class LevelProgressionScreen extends StatelessWidget {
  final String gameId;
  final String gameTitle;
  final int totalLevels;
  final Function(int level) onSelectLevel;

  const LevelProgressionScreen({
    super.key,
    required this.gameId,
    required this.gameTitle,
    required this.totalLevels,
    required this.onSelectLevel,
  });

  String tr(String english, String hindi, {String? key}) =>
      AppSettings.instance.trBilingual(english, hindi, key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LevelProgressManager.instance,
      builder: (context, _) {
        final progressManager = LevelProgressManager.instance;

        return Scaffold(
          backgroundColor: MindoraColors.cream,
          appBar: AppBar(
            backgroundColor: MindoraColors.cream,
            foregroundColor: MindoraColors.forestGreen,
            elevation: 0,
            title: Text(
              gameTitle,
              style: MindoraTextStyles.displayMedium,
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  // Header Card with gentle guidance
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: mindoraGradientCard(
                      colors: [
                        MindoraColors.cardGreen,
                        MindoraColors.cardAmber.withValues(alpha: 0.4),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.landscape_rounded,
                          size: 36,
                          color: MindoraColors.sageGreen,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('Your Pathway', 'आपकी प्रगति यात्रा'),
                                style: MindoraTextStyles.titleMedium.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tr(
                                  'Choose an unlocked level to begin. Feel free to replay completed ones anytime.',
                                  'शुरू करने के लिए एक खुला स्तर चुनें। पूर्ण किए गए स्तरों को जब चाहें फिर से खेलें।',
                                ),
                                style: MindoraTextStyles.caption.copyWith(
                                  color: MindoraColors.forestGreen,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Nature-inspired winding nodes list
                  ...List.generate(totalLevels, (index) {
                    final levelNum = index + 1;
                    final isCompleted = progressManager.isLevelCompleted(gameId, levelNum);
                    final isUnlocked = progressManager.isLevelUnlocked(gameId, levelNum);
                    final isCurrent = isUnlocked && !isCompleted;

                    // Alternating curve offset for winding gentle path feel
                    final double horizontalOffset = (index % 2 == 0) ? -24.0 : 24.0;

                    return Column(
                      children: [
                        Transform.translate(
                          offset: Offset(horizontalOffset, 0),
                          child: _buildLevelNode(
                            context: context,
                            levelNum: levelNum,
                            isCompleted: isCompleted,
                            isCurrent: isCurrent,
                            isUnlocked: isUnlocked,
                            onTap: () {
                              if (isUnlocked) {
                                onSelectLevel(levelNum);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      tr(
                                        'Complete the previous level to unlock this one.',
                                        'इसे खोलने के लिए पिछले स्तर को पूरा करें।',
                                      ),
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: MindoraColors.forestGreen,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        if (index < totalLevels - 1)
                          _buildPathConnector(horizontalOffset),
                      ],
                    );
                  }),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLevelNode({
    required BuildContext context,
    required int levelNum,
    required bool isCompleted,
    required bool isCurrent,
    required bool isUnlocked,
    required VoidCallback onTap,
  }) {
    Color nodeBg;
    Color borderColor;
    Widget content;

    if (isCompleted) {
      nodeBg = MindoraColors.cardGreen;
      borderColor = MindoraColors.sageGreen;
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded, color: MindoraColors.sageGreen, size: 28),
          const SizedBox(height: 2),
          Text(
            'Lvl $levelNum',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: MindoraColors.forestGreen,
            ),
          ),
        ],
      );
    } else if (isCurrent) {
      nodeBg = MindoraColors.cardAmber;
      borderColor = MindoraColors.terracotta;
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.play_circle_filled_rounded, color: MindoraColors.terracotta, size: 30),
          const SizedBox(height: 2),
          Text(
            'Lvl $levelNum',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: MindoraColors.terracotta,
            ),
          ),
        ],
      );
    } else {
      nodeBg = MindoraColors.borderLight;
      borderColor = MindoraColors.borderMedium;
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline_rounded, color: MindoraColors.textMuted, size: 24),
          const SizedBox(height: 2),
          Text(
            'Lvl $levelNum',
            style: const TextStyle(
              fontSize: 12,
              color: MindoraColors.textMuted,
            ),
          ),
        ],
      );
    }

    return Semantics(
      button: true,
      label: 'Level $levelNum ${isCompleted ? "Completed" : isCurrent ? "Active" : "Locked"}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            color: nodeBg,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: isCurrent ? 3.0 : 2.0),
            boxShadow: [
              BoxShadow(
                color: borderColor.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(child: content),
        ),
      ),
    );
  }

  Widget _buildPathConnector(double currentOffset) {
    return SizedBox(
      height: 38,
      child: Center(
        child: Container(
          width: 4,
          height: 38,
          decoration: BoxDecoration(
            color: MindoraColors.borderMedium,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
