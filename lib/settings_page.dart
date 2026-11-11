// Mindora - Enhanced Application Settings Page
// Manages regional language selection for all 8 North-Eastern states,
// background instrumental music toggle & volume, accessibility text sizing,
// high contrast, and independent caregiver language preference.

import 'package:flutter/material.dart';
import 'app_settings.dart';
import 'theme/mindora_theme.dart';
import 'localization/app_localizations.dart';
import 'screens/user_auth_screen.dart';
import 'services/api_service.dart';
import 'services/audio_service.dart';
import 'widgets/logout_button.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _moodSharing = false;
  bool _loadingConsent = false;

  String tr(String en, String hi, {String? key}) =>
      AppSettings.instance.trBilingual(en, hi, key: key);

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final api = ApiService.instance;
    if (!api.isAuthenticated || !api.isUser) return;
    setState(() => _loadingConsent = true);
    final prefs = await api.fetchPreferences();
    if (!mounted) return;
    setState(() {
      _loadingConsent = false;
      if (prefs != null) {
        _moodSharing = prefs['share_mood_with_caregiver'] == true ||
            prefs['share_mood_with_caregiver'] == 1;
      }
    });
  }

  Future<void> _toggleMoodSharing(bool value) async {
    setState(() => _moodSharing = value);
    final ok = await ApiService.instance.setMoodShareConsent(value);
    if (!mounted) return;
    if (!ok) {
      setState(() => _moodSharing = !value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiService.instance.lastError ??
              tr('Could not update mood sharing. Please try again.',
                  'मनोदशा साझा करने की सेटिंग अपडेट नहीं हो सकी।')),
        ),
      );
    }
  }

  Future<void> _showPairingCode() async {
    final code = await ApiService.instance.generatePairingCode();
    if (!mounted) return;
    if (code == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiService.instance.lastError ??
              tr('Could not generate a pairing code.',
                  'पेयरिंग कोड बनाया नहीं जा सका।')),
        ),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MindoraColors.cream,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tr('One-time Pairing Code', 'एक बार उपयोग होने वाला कोड'),
            style: MindoraTextStyles.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(
              code,
              style: MindoraTextStyles.displayMedium.copyWith(
                fontSize: 28,
                letterSpacing: 2,
                color: MindoraColors.forestGreen,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              tr(
                'Share this code with your family caregiver. It can be used once and expires in 15 minutes. You can withdraw access at any time.',
                'यह कोड अपने परिवार के देखभालकर्ता के साथ साझा करें। यह एक बार उपयोग हो सकता है और 15 मिनट में समाप्त हो जाता है। आप कभी भी पहुँच वापस ले सकते हैं।',
              ),
              textAlign: TextAlign.center,
              style: MindoraTextStyles.caption,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('Close', 'बंद करें')),
          ),
        ],
      ),
    );
  }

  Future<void> _showApiUrlDialog() async {
    final controller =
        TextEditingController(text: ApiService.instance.baseUrl);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MindoraColors.cream,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tr('Server Address', 'सर्वर पता'),
            style: MindoraTextStyles.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'API base URL',
                hintText: 'https://your-server.example.com/api',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              tr(
                'For local development the default is http://127.0.0.1:5000/api. On a physical Android phone use your computer\'s LAN address.',
                'स्थानीय विकास के लिए डिफ़ॉल्ट http://127.0.0.1:5000/api है। वास्तविक Android फ़ोन पर अपने कंप्यूटर का LAN पता उपयोग करें।',
              ),
              style: MindoraTextStyles.caption,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('Cancel', 'रद्द करें')),
          ),
          ElevatedButton(
            onPressed: () async {
              await ApiService.instance.setBaseUrl(controller.text);
              if (!mounted || !ctx.mounted) return;
              Navigator.pop(ctx);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ApiService.instance.isOnline
                        ? tr('Server reachable.', 'सर्वर उपलब्ध है।')
                        : tr('Server not reachable. Check the address and backend.',
                            'सर्वर उपलब्ध नहीं है। पता और बैकएंड जाँचें।'),
                  ),
                ),
              );
            },
            child: Text(tr('Save', 'सहेजें')),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
          [AppSettings.instance, AudioService.instance, ApiService.instance]),
      builder: (context, _) {
        final settings = AppSettings.instance;
        final audio = AudioService.instance;
        final api = ApiService.instance;

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

                // ── Account & privacy ──────────────────────────────────
                _sectionTitle(tr('Account & Privacy', 'खाता और गोपनीयता'),
                    Icons.person_outline_rounded),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: mindoraCard(color: Colors.white),
                  child: api.isAuthenticated
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: MindoraColors.cardGreen,
                                  child: Icon(
                                    api.isCaregiver
                                        ? Icons.volunteer_activism_rounded
                                        : Icons.person_rounded,
                                    color: MindoraColors.forestGreen,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        api.userName?.isNotEmpty == true
                                            ? api.userName!
                                            : tr('Signed in',
                                                'साइन इन किया गया'),
                                        style: MindoraTextStyles.titleMedium,
                                      ),
                                      Text(
                                        api.userEmail ?? '',
                                        style: MindoraTextStyles.caption,
                                      ),
                                      Text(
                                        api.isCaregiver
                                            ? tr('Caregiver account',
                                                'देखभालकर्ता खाता')
                                            : tr('Personal account',
                                                'व्यक्तिगत खाता'),
                                        style: MindoraTextStyles.caption,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (api.isUser) ...[
                              const Divider(height: 24),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                activeThumbColor: MindoraColors.sageGreen,
                                title: Text(
                                  tr('Share mood with caregiver',
                                      'देखभालकर्ता के साथ मनोदशा साझा करें'),
                                  style: MindoraTextStyles.titleMedium,
                                ),
                                subtitle: Text(
                                  tr(
                                    'Off by default. Activity can be shared without mood.',
                                    'डिफ़ॉल्ट रूप से बंद। मनोदशा के बिना भी गतिविधि साझा की जा सकती है।',
                                  ),
                                  style: MindoraTextStyles.caption,
                                ),
                                value: _moodSharing,
                                onChanged: _loadingConsent
                                    ? null
                                    : _toggleMoodSharing,
                              ),
                              const Divider(height: 16),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.qr_code_2_rounded,
                                    color: MindoraColors.forestGreen),
                                title: Text(
                                  tr('Generate one-time pairing code',
                                      'एक बार उपयोग होने वाला पेयरिंग कोड बनाएँ'),
                                  style: MindoraTextStyles.bodyMedium,
                                ),
                                subtitle: Text(
                                  tr('Expires in 15 minutes and can be used once.',
                                      '15 मिनट में समाप्त और एक बार उपयोग योग्य।'),
                                  style: MindoraTextStyles.caption,
                                ),
                                onTap: _showPairingCode,
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.link_off_rounded,
                                    color: MindoraColors.terracotta),
                                title: Text(
                                  tr('Withdraw all caregiver access',
                                      'सभी देखभालकर्ता पहुँच वापस लें'),
                                  style: MindoraTextStyles.bodyMedium,
                                ),
                                onTap: () async {
                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: MindoraColors.cream,
                                      title: Text(tr('Withdraw access?',
                                          'पहुँच वापस लें?')),
                                      content: Text(
                                        tr(
                                          'All connected family caregivers will lose access to your shared activity immediately.',
                                          'सभी जुड़े परिवार के देखभालकर्ता तुरंत आपकी साझा गतिविधि तक पहुँच खो देंगे।',
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: Text(tr('Cancel', 'रद्द करें')),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: Text(
                                              tr('Withdraw', 'वापस लें')),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed != true) return;
                                  final ok = await ApiService.instance
                                      .revokeCaregiverAccess();
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(ok
                                          ? tr('Caregiver access withdrawn.',
                                              'देखभालकर्ता पहुँच वापस ली गई।')
                                          : ApiService.instance.lastError ??
                                              tr('Could not withdraw access.',
                                                  'पहुँच वापस नहीं ली जा सकी।')),
                                    ),
                                  );
                                },
                              ),
                            ],
                            const SizedBox(height: 10),
                            const LogoutButton(),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr(
                                'You are browsing as a guest. Activity stays on this device and caregiver sharing is unavailable.',
                                'आप अतिथि के रूप में देख रहे हैं। गतिविधि इस डिवाइस पर रहती है और देखभालकर्ता साझा करना उपलब्ध नहीं है।',
                              ),
                              style: MindoraTextStyles.bodyMedium,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => UserAuthScreen(
                                        onAuthenticated: () {
                                          if (!mounted) return;
                                          setState(() {});
                                          _loadPreferences();
                                          Navigator.of(context).maybePop();
                                        },
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.login_rounded),
                                label: Text(tr('Sign in or create account',
                                    'साइन इन करें या खाता बनाएँ')),
                              ),
                            ),
                          ],
                        ),
                ),

                if (api.isUser) ...[
                  const SizedBox(height: 24),
                  _sectionTitle(tr('Caregiver Sharing', 'देखभालकर्ता साझा करना'),
                      Icons.family_restroom_rounded),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: mindoraCard(color: MindoraColors.cardAmber),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(
                            'Pairing is needed before a family member can see your shared activity. Generate a one-time code and give it to them directly.',
                            'परिवार का सदस्य आपकी साझा गतिविधि देख सके, इसके लिए पेयरिंग आवश्यक है। एक बार उपयोग होने वाला कोड बनाएँ और सीधे उन्हें दें।',
                          ),
                          style: MindoraTextStyles.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _showPairingCode,
                            icon: const Icon(Icons.qr_code_2_rounded),
                            label: Text(tr('Generate pairing code',
                                'पेयरिंग कोड बनाएँ')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ── Server connection ──────────────────────────────────
                _sectionTitle(tr('Server Connection', 'सर्वर कनेक्शन'),
                    Icons.dns_outlined),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: mindoraCard(color: Colors.white),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            api.isOnline
                                ? Icons.cloud_done_rounded
                                : Icons.cloud_off_rounded,
                            color: api.isOnline
                                ? MindoraColors.sageGreen
                                : MindoraColors.terracotta,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              api.isOnline
                                  ? tr('Backend reachable', 'बैकएंड उपलब्ध है')
                                  : tr('Backend not reachable',
                                      'बैकएंड उपलब्ध नहीं है'),
                              style: MindoraTextStyles.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(api.baseUrl, style: MindoraTextStyles.caption),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _showApiUrlDialog,
                          icon: const Icon(Icons.settings_ethernet_rounded),
                          label: Text(tr('Change server address',
                              'सर्वर पता बदलें')),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── 1. Regional Languages (8 NE States + National) ─────
                _sectionTitle(tr('Language', 'भाषा'), Icons.language_rounded),
                Card(
                  color: Colors.white,
                  elevation: 1.5,
                  shadowColor: const Color(0x10000000),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: MindoraColors.borderLight),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
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
                            ApiService.instance.syncLanguage(lang.name);
                            ApiService.instance
                                .syncPreferences(language: lang.name);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── 2. Background Instrumental Music ────────────────────
                _sectionTitle(tr('Background Instrumental Music', 'शांत वाद्य संगीत'), Icons.music_note_rounded),
                Card(
                  color: Colors.white,
                  elevation: 1.5,
                  shadowColor: const Color(0x10000000),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: MindoraColors.borderLight),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
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
                            ApiService.instance.syncPreferences(
                              backgroundMusic: val,
                              musicVolume: audio.volume,
                            );
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
                                  value: audio.volume.clamp(
                                      0.0, AudioService.maxBackgroundVolume),
                                  min: 0.0,
                                  max: AudioService.maxBackgroundVolume,
                                  activeColor: MindoraColors.sageGreen,
                                  inactiveColor: MindoraColors.borderLight,
                                  onChanged: (val) {
                                    final soft = AudioService.normalizeVolume(val);
                                    audio.setVolume(soft);
                                    settings.setMusicVolume(soft);
                                    ApiService.instance
                                        .syncPreferences(musicVolume: soft);
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
                        onSelected: (_) {
                          settings.setTextSize(size);
                          ApiService.instance.syncPreferences(textSize: size);
                        },
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
