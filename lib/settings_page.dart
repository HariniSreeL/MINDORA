// Mindora - Enhanced Application Settings Page
// Manages regional language selection for all 8 North-Eastern states,
// background instrumental music toggle & volume, accessibility text sizing,
// high contrast, and independent caregiver language preference.

import 'package:flutter/material.dart';
import 'app_settings.dart';
import 'theme/mindora_theme.dart';
import 'localization/app_localizations.dart';
import 'services/audio_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String tr(String en, String hi, {String? key}) =>
      AppSettings.instance.trBilingual(en, hi, key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([AppSettings.instance, AudioService.instance]),
      builder: (context, _) {
        final settings = AppSettings.instance;
        final audio = AudioService.instance;

        return Scaffold(
          backgroundColor: MindoraColors.cream,
          appBar: AppBar(
            backgroundColor: MindoraColors.cream,
            foregroundColor: MindoraColors.forestGreen,
            elevation: 0,
            title: Text(
              tr('Settings', 'सेटिंग्स'),
              style: MindoraTextStyles.displayMedium,
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                Text(
                  tr(
                    'Customize Mindora for Your Comfort',
                    'अपनी सुविधा के अनुसार सेटिंग्स चुनें',
                  ),
                  style: MindoraTextStyles.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  tr(
                    'Adjust language, text size and soft background music.',
                    'भाषा, अक्षरों का आकार और शांत संगीत को समायोजित करें।',
                  ),
                  style: MindoraTextStyles.bodyMedium,
                ),

                const SizedBox(height: 24),

                // ── 1. Regional Languages (8 NE States + National) ─────
                _sectionTitle(tr('Preferred Language', 'पसंदीदा भाषा'), Icons.language_rounded),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: mindoraCard(color: Colors.white),
                  child: Column(
                    children: MindoraLocalization.supportedLanguages.map((lang) {
                      final isSelected = settings.selectedLanguage == lang.name ||
                          (lang.code == 'en' && settings.selectedLanguage == 'English') ||
                          (lang.code == 'hi' && settings.selectedLanguage == 'Hindi');

                      return ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        selectedTileColor: MindoraColors.cardGreen,
                        leading: Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: isSelected ? MindoraColors.sageGreen : MindoraColors.textMuted,
                        ),
                        title: Text(
                          '${lang.nativeName} (${lang.name})',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: MindoraColors.forestGreen,
                          ),
                        ),
                        subtitle: Text(lang.region, style: MindoraTextStyles.caption),
                        onTap: () {
                          settings.setLanguage(lang.name);
                        },
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 24),

                // ── 2. Background Instrumental Music ────────────────────
                _sectionTitle(tr('Background Instrumental Music', 'शांत वाद्य संगीत'), Icons.music_note_rounded),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: mindoraCard(color: Colors.white),
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: MindoraColors.sageGreen,
                        title: Text(
                          tr('Soft Flute & Santoor Ambience', 'बांसुरी एवं संतूर की शांत धुन'),
                          style: MindoraTextStyles.titleMedium,
                        ),
                        subtitle: Text(
                          tr('Calming instrumental melody across all screens.', 'सभी स्क्रीन पर बजने वाला मधुर शांत संगीत।'),
                          style: MindoraTextStyles.caption,
                        ),
                        value: audio.isEnabled,
                        onChanged: (val) {
                          audio.setEnabled(val);
                          settings.setBackgroundMusic(val);
                        },
                      ),
                      if (audio.isEnabled) ...[
                        const Divider(height: 24),
                        Row(
                          children: [
                            Icon(
                              audio.isPlaying ? Icons.play_circle_filled_rounded : Icons.pause_circle_filled_rounded,
                              color: MindoraColors.sageGreen,
                              size: 26,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                audio.isPlaying ? tr('Playing gently', 'चल रहा है') : tr('Paused', 'रुका हुआ'),
                                style: MindoraTextStyles.bodyMedium,
                              ),
                            ),
                            TextButton(
                              onPressed: () => audio.togglePlayPause(),
                              child: Text(
                                audio.isPlaying ? tr('Pause', 'रोकें') : tr('Play', 'बजाएं'),
                                style: const TextStyle(color: MindoraColors.sageGreen, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.volume_down_rounded, size: 20, color: MindoraColors.textMuted),
                            Expanded(
                              child: Slider(
                                value: audio.volume,
                                min: 0.0,
                                max: 1.0,
                                activeColor: MindoraColors.sageGreen,
                                inactiveColor: MindoraColors.borderLight,
                                onChanged: (val) {
                                  audio.setVolume(val);
                                  settings.setMusicVolume(val);
                                },
                              ),
                            ),
                            const Icon(Icons.volume_up_rounded, size: 20, color: MindoraColors.textMuted),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── 3. Text Size Accessibility ──────────────────────────
                _sectionTitle(tr('Text Size', 'अक्षरों का आकार'), Icons.format_size_rounded),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: mindoraCard(color: Colors.white),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ['Small', 'Medium', 'Large'].map((size) {
                      final isSelected = settings.selectedTextSize == size;
                      final label = size == 'Small'
                          ? tr('Small', 'छोटा')
                          : (size == 'Medium' ? tr('Medium', 'मध्यम') : tr('Large', 'बड़ा'));

                      return ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        selectedColor: MindoraColors.cardGreen,
                        backgroundColor: MindoraColors.cream,
                        labelStyle: TextStyle(
                          color: isSelected ? MindoraColors.forestGreen : MindoraColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: size == 'Large' ? 18 : 15,
                        ),
                        onSelected: (_) => settings.setTextSize(size),
                      );
                    }).toList(),
                  ),
                ),



                const SizedBox(height: 30),

                // App info footer
                Center(
                  child: Text(
                    'Mindora • Version 1.0.0 (Review Build)\nCognitive Wellness for North-East India',
                    textAlign: TextAlign.center,
                    style: MindoraTextStyles.caption,
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: MindoraColors.forestGreen),
          const SizedBox(width: 8),
          Text(
            title,
            style: MindoraTextStyles.titleLarge.copyWith(fontSize: 18),
          ),
        ],
      ),
    );
  }
}
