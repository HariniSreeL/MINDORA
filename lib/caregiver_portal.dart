
import 'package:flutter/material.dart';
import 'app_settings.dart';

class CaregiverPortal extends StatelessWidget {
  const CaregiverPortal({super.key});

  static const Color cream = Color(0xFFF8F6EF);
  static const Color green = Color(0xFF52796F);
  static const Color dark = Color(0xFF344E41);
  static const Color lightGreen = Color(0xFFE4EDE5);

  String tr(String english, String hindi) {
    return AppSettings.instance.isHindi ? hindi : english;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: cream,
          appBar: AppBar(
            backgroundColor: cream,
            foregroundColor: dark,
            elevation: 0,
            title: Text(
              tr('Caregiver Portal', 'देखभालकर्ता पोर्टल'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                tr('Care & Connection 🌿', 'देखभाल और जुड़ाव 🌿'),
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: dark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr(
                  'A simple overview of your loved one’s wellbeing and daily activities.',
                  'आपके प्रियजन के स्वास्थ्य और दैनिक गतिविधियों की एक सरल जानकारी।',
                ),
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 24),

              _sectionTitle(
                tr('Today at a glance', 'आज की एक झलक'),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      icon: Icons.sports_esports_rounded,
                      title: tr('Games played', 'खेले गए खेल'),
                      value: '—',
                      subtitle: tr('Awaiting data', 'जानकारी उपलब्ध नहीं'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _summaryCard(
                      icon: Icons.schedule_rounded,
                      title: tr('Play time', 'खेलने का समय'),
                      value: '—',
                      subtitle: tr('Awaiting data', 'जानकारी उपलब्ध नहीं'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _sectionTitle(
                tr('Mood check-in', 'मूड की जानकारी'),
              ),
              const SizedBox(height: 12),

              _infoCard(
                icon: Icons.favorite_outline_rounded,
                title: tr('Mood summary', 'मूड का सारांश'),
                description: tr(
                  'Mood updates will appear here when the user chooses to share them.',
                  'उपयोगकर्ता की अनुमति से साझा की गई मनोदशा की जानकारी यहाँ दिखाई देगी।',
                ),
                color: lightGreen,
              ),

              const SizedBox(height: 24),

              _sectionTitle(
                tr('Recent activity', 'हाल की गतिविधियाँ'),
              ),
              const SizedBox(height: 12),

              _infoCard(
                icon: Icons.extension_rounded,
                title: tr('Game activity', 'खेल की गतिविधियाँ'),
                description: tr(
                  'Completed games, playing time and recent sessions will appear here.',
                  'पूरे किए गए खेल, खेलने का समय और हाल के सत्र यहाँ दिखाई देंगे।',
                ),
                color: Colors.white,
              ),

              const SizedBox(height: 24),

              _sectionTitle(
                tr('Support & reminders', 'सहायता और रिमाइंडर'),
              ),
              const SizedBox(height: 12),

              _infoCard(
                icon: Icons.notifications_none_rounded,
                title: tr('Reminders', 'रिमाइंडर'),
                description: tr(
                  'Daily reminders and support requests can be managed here in a future update.',
                  'भविष्य के अपडेट में दैनिक रिमाइंडर और सहायता अनुरोध यहाँ प्रबंधित किए जा सकेंगे।',
                ),
                color: Colors.white,
              ),

              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0E8D8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_outline_rounded, color: dark),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tr(
                          'Privacy matters. Personal mood and activity information should only be shared with the user’s permission.',
                          'गोपनीयता महत्वपूर्ण है। मनोदशा और गतिविधियों की व्यक्तिगत जानकारी उपयोगकर्ता की अनुमति से ही साझा की जानी चाहिए।',
                        ),
                        style: const TextStyle(
                          color: dark,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.bold,
        color: dark,
      ),
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: green, size: 25),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: dark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: dark,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: green, size: 26),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: dark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
