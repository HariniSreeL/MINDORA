
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';
import 'services/api_service.dart';

class MoodCheckIn extends StatefulWidget {
  const MoodCheckIn({super.key});

  @override
  State<MoodCheckIn> createState() => _MoodCheckInState();
}

class _MoodCheckInState extends State<MoodCheckIn> {
  String? selectedMood;
  int _energyLevel = 3;
  final TextEditingController _noteController = TextEditingController();
  bool _saving = false;
  bool _saved = false;
  String? _saveMessage;

  bool get isHindi => AppSettings.instance.isHindi;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveMood() async {
    final mood = selectedMood;
    if (mood == null || _saving) return;
    setState(() {
      _saving = true;
      _saveMessage = null;
    });

    final synced = await ApiService.instance.logMood(
      mood,
      energyLevel: _energyLevel,
      note: _noteController.text,
    );

    // Always keep a local record so the check-in is not lost while offline
    // or while using guest mode.
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('mindora_local_moods');
      final entries = raw == null ? <dynamic>[] : jsonDecode(raw) as List<dynamic>;
      entries.add({
        'mood': mood,
        'energy_level': _energyLevel,
        'note': _noteController.text.trim(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'synced': synced,
      });
      while (entries.length > 100) {
        entries.removeAt(0);
      }
      await prefs.setString('mindora_local_moods', jsonEncode(entries));
    } catch (_) {
      // Local notebook failure must not block the check-in confirmation.
    }

    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = true;
      _saveMessage = synced
          ? tr('Your check-in has been saved and synced securely.',
              'आपकी जानकारी सुरक्षित रूप से सहेजी और सिंक की गई है।')
          : tr(
              'Your check-in is saved on this device. It will sync when you are signed in and online.',
              'आपकी जानकारी इस डिवाइस पर सहेजी गई है। साइन इन होने और ऑनलाइन होने पर यह सिंक हो जाएगी।',
            );
    });
  }

  String tr(String english, String hindi, {String? key}) {
    return AppSettings.instance.trBilingual(english, hindi, key: key);
  }

  final List<Map<String, dynamic>> moods = [
    {
      'name': 'Happy',
      'icon': Icons.sentiment_very_satisfied_rounded,
      'color': const Color(0xFFFFE7B5),
    },
    {
      'name': 'Calm',
      'icon': Icons.spa_rounded,
      'color': const Color(0xFFDCEBDD),
    },
    {
      'name': 'Okay',
      'icon': Icons.sentiment_neutral_rounded,
      'color': const Color(0xFFDDE8F8),
    },
    {
      'name': 'Sad',
      'icon': Icons.sentiment_dissatisfied_rounded,
      'color': const Color(0xFFE5DDF5),
    },
    {
      'name': 'Worried',
      'icon': Icons.sentiment_dissatisfied_rounded,
      'color': const Color(0xFFF8DDCE),
    },
    {
      'name': 'Confused',
      'icon': Icons.help_outline_rounded,
      'color': const Color(0xFFE9E3D8),
    },
    {
      'name': "I don't know",
      'icon': Icons.psychology_outlined,
      'color': const Color(0xFFE8E8E8),
    },
  ];

  String moodLabel(String mood) {
    switch (mood) {
      case 'Happy':
        return tr('Happy', 'खुश');
      case 'Calm':
        return tr('Calm', 'शांत');
      case 'Okay':
        return tr('Okay', 'ठीक');
      case 'Sad':
        return tr('Sad', 'उदास');
      case 'Worried':
        return tr('Worried', 'चिंतित');
      case 'Confused':
        return tr('Confused', 'उलझन में');
      case "I don't know":
        return tr("I don't know", 'मुझे नहीं पता');
      default:
        return mood;
    }
  }

  @override
  Widget build(BuildContext context) {
    const forest = Color(0xFF354C3C);

    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFFAF8F0),
          appBar: AppBar(
            title: Text(
              tr('Mood Check-in', 'मूड की जानकारी'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: forest,
              ),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(
                      'How are you feeling today?',
                      'आज आप कैसा महसूस कर रहे हैं?',
                    ),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: forest,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      'Choose the picture that feels right for you.',
                      'वह चित्र चुनें जो आपकी भावना से मेल खाता है।',
                    ),
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.5,
                      color: Color(0xFF55584E),
                    ),
                  ),
                  const SizedBox(height: 22),

                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: moods.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 5.05,
                    ),
                    itemBuilder: (context, index) {
                      final mood = moods[index];
                      final name = mood['name'] as String;
                      final isSelected = selectedMood == name;

                      return Semantics(
                        button: true,
                        selected: isSelected,
                        label: moodLabel(name),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            setState(() {
                              selectedMood = name;
                              _saved = false;
                              _saveMessage = null;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: mood['color'] as Color,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? forest
                                    : const Color(0xFFE7E5D9),
                                width: isSelected ? 3 : 1,
                              ),
                            ),
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  mood['icon'] as IconData,
                                  size: 43,
                                  color: forest,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  moodLabel(name),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: forest,
                                  ),
                                ),
                                if (isSelected)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 5),
                                    child: Icon(
                                      Icons.check_circle,
                                      size: 20,
                                      color: forest,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  if (selectedMood != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCEBDD),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        selectedMood == "I don't know"
                            ? tr(
                                "That's okay. You don't have to know.",
                                'कोई बात नहीं। आपको जानना ज़रूरी नहीं है।',
                              )
                            : tr(
                                'Thank you for sharing how you feel.',
                                'अपनी भावना साझा करने के लिए धन्यवाद।',
                              ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17,
                          color: forest,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  Text(
                    tr('Energy level (optional)', 'ऊर्जा स्तर (वैकल्पिक)'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: forest,
                    ),
                  ),
                  Row(
                    children: [
                      Text(tr('Low', 'कम'),
                          style: const TextStyle(fontSize: 13, color: Color(0xFF55584E))),
                      Expanded(
                        child: Slider(
                          value: _energyLevel.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          label: '$_energyLevel / 5',
                          activeColor: forest,
                          onChanged: _saved
                              ? null
                              : (value) =>
                                  setState(() => _energyLevel = value.round()),
                        ),
                      ),
                      Text(tr('High', 'अधिक'),
                          style: const TextStyle(fontSize: 13, color: Color(0xFF55584E))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteController,
                    enabled: !_saved,
                    maxLines: 2,
                    maxLength: 300,
                    decoration: InputDecoration(
                      labelText: tr('A short note (optional)', 'एक छोटा नोट (वैकल्पिक)'),
                      hintText: tr('Anything you would like to remember',
                          'जो आप याद रखना चाहें'),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5EBD4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lock_outline_rounded,
                            size: 18, color: forest),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tr(
                              'Mood is private by default. A family caregiver can see it only if you turn on mood sharing in Settings.',
                              'मनोदशा डिफ़ॉल्ट रूप से निजी है। परिवार का देखभालकर्ता इसे केवल तब देख सकता है जब आप सेटिंग्स में मनोदशा साझा करना चालू करें।',
                            ),
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF55584E)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (_saveMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCEBDD),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _saveMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 15,
                            color: forest,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedMood == null || _saving
                          ? null
                          : (_saved ? () => Navigator.pop(context) : _saveMood),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: forest,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text(
                              _saved
                                  ? tr('Done', 'पूर्ण')
                                  : tr('Save my check-in', 'मेरी जानकारी सहेजें'),
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  if (selectedMood != null && !_saved)
                    Center(
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            selectedMood = null;
                            _saveMessage = null;
                          });
                        },
                        child: Text(tr('Choose another mood', 'दूसरी भावना चुनें')),
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
}
