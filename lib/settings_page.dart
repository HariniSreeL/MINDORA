
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String selectedLanguage = 'English';
  String selectedTextSize = 'Medium';

  bool caregiverSharing = false;
  bool backgroundMusic = false;
  bool isLoading = true;

  static const forest = Color(0xFF354C3C);
  static const cream = Color(0xFFFAF8F0);

  // English and Hindi translation helper
  String _tr(String english, String hindi) {
    return selectedLanguage == 'Hindi' ? hindi : english;
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      selectedLanguage =
          prefs.getString('selectedLanguage') ?? 'English';

      selectedTextSize =
          prefs.getString('selectedTextSize') ?? 'Medium';

      caregiverSharing =
          prefs.getBool('caregiverSharing') ?? false;

      backgroundMusic =
          prefs.getBool('backgroundMusic') ?? false;

      isLoading = false;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: cream,
        title: Text(
          _tr('Settings', 'सेटिंग्स'),
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: forest,
          ),
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    _tr(
                      'Make Mindora Comfortable for You',
                      'Mindora को अपने अनुसार बनाएँ',
                    ),
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: forest,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    _tr(
                      'Choose the settings that work best for you.',
                      'अपने लिए उपयुक्त सेटिंग्स चुनें।',
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: Color(0xFF55584E),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // LANGUAGE SETTINGS
                  _sectionTitle(
                    _tr('App Language', 'ऐप की भाषा'),
                    Icons.language,
                  ),

                  _settingsCard(
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          value: 'English',
                          groupValue: selectedLanguage,
                          activeColor: forest,
                          title: const Text('English'),
                          onChanged: (value) {
                            if (value == null) return;

                            setState(() {
                              selectedLanguage = value;
                            });

                            AppSettings.instance.setLanguage(value);
                          },
                        ),

                        RadioListTile<String>(
                          value: 'Hindi',
                          groupValue: selectedLanguage,
                          activeColor: forest,
                          title: const Text('हिन्दी (Hindi)'),
                          onChanged: (value) {
                            if (value == null) return;

                            setState(() {
                              selectedLanguage = value;
                            });

                            AppSettings.instance.setLanguage(value);
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // TEXT SIZE SETTINGS
                  _sectionTitle(
                    _tr('Text Size', 'टेक्स्ट का आकार'),
                    Icons.text_fields,
                  ),

                  _settingsCard(
                    child: Column(
                      children: [
                        for (final size in [
                          'Small',
                          'Medium',
                          'Large',
                        ])
                          RadioListTile<String>(
                            value: size,
                            groupValue: selectedTextSize,
                            activeColor: forest,
                            title: Text(
                              selectedLanguage == 'Hindi'
                                  ? size == 'Small'
                                      ? 'छोटा'
                                      : size == 'Medium'
                                          ? 'मध्यम'
                                          : 'बड़ा'
                                  : size,
                              style: TextStyle(
                                fontSize: size == 'Small'
                                    ? 15
                                    : size == 'Large'
                                        ? 21
                                        : 18,
                              ),
                            ),
                            onChanged: (value) {
                              if (value == null) return;

                              setState(() {
                                selectedTextSize = value;
                              });

                              AppSettings.instance.setTextSize(value);
                            },
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // PRIVACY AND CAREGIVER SETTINGS
                  _sectionTitle(
                    _tr(
                      'Privacy & Caregiver Sharing',
                      'गोपनीयता और देखभालकर्ता के साथ साझा करना',
                    ),
                    Icons.shield_outlined,
                  ),

                  _settingsCard(
                    child: SwitchListTile(
                      value: caregiverSharing,
                      activeColor: forest,
                      title: Text(
                        _tr(
                          'Share my mood',
                          'अपना मूड साझा करें',
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _tr(
                            'Allow your mood check-ins to be shared '
                            'with your authorized caregiver.',
                            'अपने मूड चेक-इन को अधिकृत देखभालकर्ता '
                            'के साथ साझा करने की अनुमति दें।',
                          ),
                          style: const TextStyle(height: 1.5),
                        ),
                      ),
                      onChanged: (value) {
                        if (!value) {
                          setState(() {
                            caregiverSharing = false;
                          });

                          _saveBool('caregiverSharing', false);
                          return;
                        }

                        showDialog<void>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: Text(
                              _tr(
                                'Mood Sharing',
                                'मूड साझा करना',
                              ),
                            ),
                            content: Text(
                              _tr(
                                'Your mood check-ins may be visible '
                                'to your authorized caregiver. '
                                'Do you agree to share them?',
                                'आपके मूड चेक-इन आपके अधिकृत '
                                'देखभालकर्ता को दिखाई दे सकते हैं। '
                                'क्या आप इन्हें साझा करना चाहते हैं?',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                },
                                child: Text(
                                  _tr('Not now', 'अभी नहीं'),
                                ),
                              ),
                              FilledButton(
                                onPressed: () {
                                  setState(() {
                                    caregiverSharing = true;
                                  });

                                  _saveBool('caregiverSharing', true);
                                  Navigator.pop(dialogContext);
                                },
                                child: Text(
                                  _tr('Allow', 'अनुमति दें'),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 22),

                  // BACKGROUND MUSIC SETTINGS
                  _sectionTitle(
                    _tr('Background Music', 'बैकग्राउंड संगीत'),
                    Icons.music_note,
                  ),

                  _settingsCard(
                    child: SwitchListTile(
                      value: backgroundMusic,
                      activeColor: forest,
                      title: Text(
                        _tr(
                          'Gentle instrumental music',
                          'हल्का वाद्य संगीत',
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        _tr(
                          'Optional calming background music.',
                          'वैकल्पिक शांत बैकग्राउंड संगीत।',
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          backgroundMusic = value;
                        });

                        _saveBool('backgroundMusic', value);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              value
                                  ? _tr(
                                      'Music preference saved. Playback '
                                      'will be added next.',
                                      'संगीत की पसंद सहेजी गई है। '
                                      'संगीत चलाने की सुविधा बाद में '
                                      'जोड़ी जाएगी।',
                                    )
                                  : _tr(
                                      'Background music turned off.',
                                      'बैकग्राउंड संगीत बंद कर दिया गया।',
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  Center(
                    child: Text(
                      'Mindora • Cognitive Wellness Through Play',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF55584E),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFF496C52),
            size: 25,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: forest,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsCard({required Widget child}) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(
          color: Color(0xFFE7E5D9),
        ),
      ),
      child: child,
    );
  }
}
