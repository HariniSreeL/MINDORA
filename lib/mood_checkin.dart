
import 'package:flutter/material.dart';
import 'app_settings.dart';

class MoodCheckIn extends StatefulWidget {
  const MoodCheckIn({super.key});

  @override
  State<MoodCheckIn> createState() => _MoodCheckInState();
}

class _MoodCheckInState extends State<MoodCheckIn> {
  String? selectedMood;

  bool get isHindi => AppSettings.instance.isHindi;

  String tr(String english, String hindi) {
    return isHindi ? hindi : english;
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

                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          selectedMood = null;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: forest,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: const BorderSide(color: forest),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        tr('Skip for now', 'अभी छोड़ें'),
                        style: const TextStyle(fontSize: 17),
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
}
