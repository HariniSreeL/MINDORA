// Mindora - Role selection entry screen
// Shown whenever there is no valid signed-in session. Keeps Loved One and
// Caregiver entry completely separate so neither can drift into the other's
// authentication flow.

import 'package:flutter/material.dart';

import '../app_settings.dart';
import 'caregiver_login_screen.dart';
import 'user_auth_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key, this.onGuest});

  /// Optional guest entry, supplied by the auth gate. Guests stay local-only.
  final VoidCallback? onGuest;

  // Requested Mindora lavender identity for the role entry screen.
  static const Color primary = Color(0xFF7566C9);
  static const Color background = Color(0xFFF7F5FF);

  String tr(String en, String hi) => AppSettings.instance.trBilingual(en, hi);

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: background,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Brand mark ───────────────────────────────
                      Center(
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.spa_rounded,
                            size: 40,
                            color: primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Mindora',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: primary.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        tr(
                          'Who is using Mindora today?',
                          'आज Mindora किसका उपयोग कर रहा है?',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          height: 1.3,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E2A45),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr(
                          'Choose your role to continue.',
                          'जारी रखने के लिए अपनी भूमिका चुनें।',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF6D6885),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Loved One ────────────────────────────────
                      _RoleCard(
                        icon: Icons.favorite_rounded,
                        title: tr('Loved One', 'प्रियजन'),
                        description: tr(
                          'Play gentle cognitive games and track your progress.',
                          'सौम्य संज्ञानात्मक खेल खेलें और अपनी प्रगति देखें।',
                        ),
                        onTap: () =>
                            _open(context, const UserAuthScreen()),
                      ),

                      const SizedBox(height: 16),

                      // ── Caregiver ────────────────────────────────
                      _RoleCard(
                        icon: Icons.volunteer_activism_rounded,
                        title: tr('Caregiver', 'देखभालकर्ता'),
                        description: tr(
                          "Stay connected and monitor your loved one's progress.",
                          'जुड़े रहें और अपने प्रियजन की प्रगति देखें।',
                        ),
                        onTap: () =>
                            _open(context, const CaregiverLoginScreen()),
                      ),

                      if (onGuest != null) ...[
                        const SizedBox(height: 26),
                        Center(
                          child: TextButton.icon(
                            onPressed: onGuest,
                            icon: const Icon(Icons.person_outline_rounded),
                            label: Text(
                              tr(
                                'Continue as guest',
                                'अतिथि के रूप में जारी रखें',
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          tr(
                            'Guest activity stays on this device only.',
                            'अतिथि गतिविधि केवल इस डिवाइस पर रहती है।',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6D6885),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $description',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: RoleSelectionScreen.primary.withValues(alpha: 0.22),
              ),
              boxShadow: [
                BoxShadow(
                  color: RoleSelectionScreen.primary.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color:
                        RoleSelectionScreen.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: RoleSelectionScreen.primary,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E2A45),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 15.5,
                          height: 1.4,
                          color: Color(0xFF5F5A78),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: RoleSelectionScreen.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
