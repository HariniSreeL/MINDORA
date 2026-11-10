// Mindora - Enhanced Feel Good Screen
// Guided 4-4-4 gentle breathing with start, pause, resume, reset controls;
// calming nature scenic prompts, positive regional memory cues, and sound chime simulation.

import 'package:flutter/material.dart';
import '../app_settings.dart';
import '../services/api_service.dart';
import '../theme/mindora_theme.dart';

class FeelGoodScreen extends StatefulWidget {
  const FeelGoodScreen({super.key});

  @override
  State<FeelGoodScreen> createState() => _FeelGoodScreenState();
}

class _FeelGoodScreenState extends State<FeelGoodScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _breatheController;
  late Animation<double> _breatheAnimation;
  bool _isBreathing = false;
  bool _isPaused = false;
  int _breathPhase = 0; // 0=idle, 1=inhale, 2=hold, 3=exhale
  bool _soundChimeOn = true;
  DateTime? _sessionStartedAt;

  String _currentMessage = '';
  bool _showMessage = false;

  static const _messages = [
    'You are safe, respected, and surrounded by care.',
    'Every moment of rest is a gentle gift to yourself.',
    'You are remembered and you are deeply loved.',
    'Small steps lead to peaceful and bright tomorrows.',
    'Take all the time you need. There is no hurry.',
    'Nature and the hills are always near to bring you calm.',
    'Your presence brings warmth to those around you.',
  ];

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _breatheAnimation = Tween<double>(begin: 0.75, end: 1.25).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _breatheController.dispose();
    super.dispose();
  }

  String tr(String english, String hindi, {String? key}) =>
      AppSettings.instance.trBilingual(english, hindi, key: key);

  Future<void> _startBreathingCycle() async {
    if (!_isBreathing) {
      _sessionStartedAt = DateTime.now();
    }
    setState(() {
      _isBreathing = true;
      _isPaused = false;
    });

    while (_isBreathing && mounted) {
      // Inhale
      if (!mounted || !_isBreathing || _isPaused) break;
      setState(() => _breathPhase = 1);
      _breatheController.forward();
      await Future.delayed(const Duration(seconds: 4));

      // Hold
      if (!mounted || !_isBreathing || _isPaused) break;
      setState(() => _breathPhase = 2);
      await Future.delayed(const Duration(seconds: 4));

      // Exhale
      if (!mounted || !_isBreathing || _isPaused) break;
      setState(() => _breathPhase = 3);
      _breatheController.reverse();
      await Future.delayed(const Duration(seconds: 4));
    }
  }

  void _pauseBreathing() {
    setState(() {
      _isPaused = true;
    });
    _breatheController.stop();
  }

  Future<void> _stopBreathing() async {
    final started = _sessionStartedAt;
    final elapsed = started == null
        ? 0
        : DateTime.now().difference(started).inSeconds;
    setState(() {
      _isBreathing = false;
      _isPaused = false;
      _breathPhase = 0;
      _sessionStartedAt = null;
    });
    _breatheController.reset();

    if (elapsed < 5) return;
    final synced = await ApiService.instance.logFeelGood(
      'breathing',
      title: 'Gentle Breathing',
      durationSeconds: elapsed.toDouble(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          synced
              ? tr('Breathing session saved and synced.',
                  'श्वास सत्र सहेजा और सिंक किया गया।')
              : tr(
                  'Breathing session saved on this device. It will sync when you are signed in and online.',
                  'श्वास सत्र इस डिवाइस पर सहेजा गया। साइन इन और ऑनलाइन होने पर यह सिंक हो जाएगा।',
                ),
        ),
      ),
    );
  }

  Future<void> _showEncouragement() async {
    final index = DateTime.now().second % _messages.length;
    setState(() {
      _currentMessage = _messages[index];
      _showMessage = true;
    });
    await ApiService.instance.logFeelGood(
      'encouragement',
      title: 'Kind Message',
    );
  }

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
              tr('Feel Good', 'अच्छा महसूस करें'),
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
                      'Take a peaceful moment for your breath and heart.',
                      'अपनी सांसों और मन की शांति के लिए एक सुखद पल लें।',
                    ),
                    style: MindoraTextStyles.bodyLarge,
                  ),

                  const SizedBox(height: 24),

                  // ── Guided Breathing Exercise ──────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: mindoraCard(color: Colors.white, radius: 24),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              tr('Gentle Breathing', 'शांत श्वास अभ्यास'),
                              style: MindoraTextStyles.titleLarge,
                            ),
                            IconButton(
                              tooltip: _soundChimeOn ? tr('Chime Sound On', 'ध्वनि संकेत चालू') : tr('Muted', 'मूक'),
                              icon: Icon(
                                _soundChimeOn ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
                                color: _soundChimeOn ? MindoraColors.sageGreen : MindoraColors.textMuted,
                              ),
                              onPressed: () {
                                setState(() => _soundChimeOn = !_soundChimeOn);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tr(
                            'Follow the circle: Inhale as it gently expands, rest, and exhale as it softens.',
                            'वृत्त का अनुसरण करें: इसके फैलने पर सांस अंदर लें, रुकें, और सिकुड़ने पर धीरे से छोड़ें।',
                          ),
                          textAlign: TextAlign.center,
                          style: MindoraTextStyles.bodyMedium,
                        ),

                        const SizedBox(height: 28),

                        // Animated breathing circle
                        AnimatedBuilder(
                          animation: _breatheAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _isBreathing ? _breatheAnimation.value : 1.0,
                              child: Container(
                                width: 170,
                                height: 170,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      MindoraColors.sageGreen.withValues(alpha: 0.35),
                                      MindoraColors.sageGreen.withValues(alpha: 0.08),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: MindoraColors.sageGreen,
                                    width: 3.5,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.spa_rounded,
                                    size: 58,
                                    color: MindoraColors.forestGreen,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 20),

                        // Phase Text
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            !_isBreathing
                                ? tr('Press Start below', 'शुरू करने के लिए नीचे दबाएं')
                                : _breathPhase == 1
                                    ? tr('Breathe in gently…', 'धीरे से सांस अंदर लें…')
                                    : _breathPhase == 2
                                        ? tr('Hold calmly…', 'शांत भाव से रोकें…')
                                        : tr('Breathe out smoothly…', 'सहजता से सांस बाहर छोड़ें…'),
                            key: ValueKey(_breathPhase),
                            style: MindoraTextStyles.titleMedium.copyWith(
                              color: MindoraColors.forestGreen,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Controls: Start / Pause / Stop
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!_isBreathing || _isPaused)
                              ElevatedButton.icon(
                                onPressed: _startBreathingCycle,
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: Text(_isPaused ? tr('Resume', 'जारी रखें') : tr('Start', 'शुरू करें')),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: MindoraColors.sageGreen,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            if (_isBreathing && !_isPaused)
                              ElevatedButton.icon(
                                onPressed: _pauseBreathing,
                                icon: const Icon(Icons.pause_rounded),
                                label: Text(tr('Pause', 'रोकें')),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: MindoraColors.terracotta,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            if (_isBreathing || _isPaused) ...[
                              const SizedBox(width: 14),
                              OutlinedButton.icon(
                                onPressed: _stopBreathing,
                                icon: const Icon(Icons.stop_rounded),
                                label: Text(tr('Reset', 'समाप्त')),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: MindoraColors.forestGreen,
                                  side: const BorderSide(color: MindoraColors.borderMedium),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // ── Calming Nature Prompts ──────────────────────────
                  Text(
                    tr('Peaceful Nature Moments', 'प्रकृति के शांत दृश्य'),
                    style: MindoraTextStyles.titleLarge,
                  ),
                  const SizedBox(height: 12),

                  _natureCard(
                    icon: Icons.wb_twilight_rounded,
                    title: tr('Early Morning in the Valley', 'घाटी की भोर'),
                    body: tr(
                      'Picture the cool mountain mist clearing as the warm sun touches the emerald tea bushes.',
                      'कल्पना करें कि ठंडी पहाड़ी धुंध छंट रही है और सूरज की पहली किरणें चाय के बागानों को छू रही हैं।',
                    ),
                    color: MindoraColors.cardAmber,
                  ),
                  const SizedBox(height: 10),

                  _natureCard(
                    icon: Icons.water_rounded,
                    title: tr('Living Stream Water', 'पहाड़ी सोता'),
                    body: tr(
                      'Listen in your mind to the gentle sound of clear fresh river water washing over round river stones.',
                      'अपने मन में गोल पत्थरों के ऊपर से बहती हुई स्वच्छ पहाड़ी नदी की कलकल ध्वनि का अनुभव करें।',
                    ),
                    color: MindoraColors.cardBlue,
                  ),

                  const SizedBox(height: 30),

                  // ── Kind Encouragement ──────────────────────────────
                  Text(
                    tr('A Loving Word for You', 'आपके लिए स्नेह भरा संदेश'),
                    style: MindoraTextStyles.titleLarge,
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showEncouragement,
                      icon: const Icon(Icons.favorite_rounded, size: 22),
                      label: Text(
                        tr('Receive a Kind Message', 'एक स्नेह भरा संदेश देखें'),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MindoraColors.sageGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),

                  if (_showMessage) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: mindoraGradientCard(
                        colors: [
                          MindoraColors.cardGreen,
                          MindoraColors.cardAmber.withValues(alpha: 0.5),
                        ],
                      ),
                      child: Text(
                        _currentMessage,
                        textAlign: TextAlign.center,
                        style: MindoraTextStyles.titleMedium.copyWith(
                          fontSize: 18,
                          fontStyle: FontStyle.italic,
                          color: MindoraColors.forestGreen,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _natureCard({
    required IconData icon,
    required String title,
    required String body,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: mindoraCard(color: color),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 30, color: MindoraColors.forestGreen),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: MindoraTextStyles.titleMedium),
                const SizedBox(height: 4),
                Text(body, style: MindoraTextStyles.bodyMedium.copyWith(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
