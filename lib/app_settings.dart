// Mindora - Enhanced Application Settings
// Global state management for language, accessibility, and background audio.
// Supports immediate UI update on language changes across all 8 NE state languages + English & Hindi.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'localization/app_localizations.dart';

class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  String selectedTextSize = 'Medium';
  String selectedLanguage = 'English';
  String caregiverLanguage = 'English';
  bool backgroundMusicEnabled = true;
  double musicVolume = 0.5;
  bool highContrastMode = false;

  double get textScale {
    switch (selectedTextSize) {
      case 'Small':
        return 0.85;
      case 'Large':
        return 1.35;
      default:
        return 1.0;
    }
  }

  bool get isHindi => selectedLanguage == 'Hindi' || selectedLanguage == 'hi';

  String get currentLanguageCode {
    switch (selectedLanguage) {
      case 'Hindi':
        return 'hi';
      case 'Assamese':
        return 'as';
      case 'Bengali':
        return 'bn';
      case 'Nepali':
        return 'ne';
      case 'Manipuri (Meitei)':
        return 'mni';
      case 'Khasi':
        return 'kha';
      case 'Mizo':
        return 'lus';
      case 'Nyishi':
        return 'nji';
      case 'English':
      default:
        return 'en';
    }
  }

  /// Core translation method that maps any translation key to the active regional language
  String tr(String key, [String? englishFallback]) {
    return MindoraLocalization.instance.translate(
      key,
      langCode: currentLanguageCode,
      defaultFallback: englishFallback,
    );
  }

  /// Helper for legacy / dual-string calls:
  /// If language is English, returns `english`.
  /// If language is Hindi, returns `hindi`.
  /// If another regional language is active, translates using localized key or returns language-appropriate copy.
  String trBilingual(String english, String hindi, {String? key}) {
    if (key != null) {
      return tr(key, english);
    }
    if (selectedLanguage == 'Hindi') return hindi;
    if (selectedLanguage == 'English') return english;

    // Map common phrases directly if key wasn't explicitly passed
    final matchedKey = _phraseToKey(english);
    if (matchedKey != null) {
      return tr(matchedKey, english);
    }

    return english;
  }

  String? _phraseToKey(String phrase) {
    final lower = phrase.toLowerCase().trim();
    if (lower.contains('good morning')) return 'good_morning';
    if (lower.contains('good afternoon')) return 'good_afternoon';
    if (lower.contains('good evening')) return 'good_evening';
    if (lower.contains('settings')) return 'settings';
    if (lower.contains("today's activity") || lower.contains('today activity')) return 'today_activity';
    if (lower.contains('choose your activity')) return 'choose_activity';
    if (lower.contains('cognitive games')) return 'cognitive_games';
    if (lower.contains('memory match')) return 'memory_match';
    if (lower.contains('pattern match')) return 'pattern_match';
    if (lower.contains('word recall')) return 'word_recall';
    if (lower.contains('picture puzzle')) return 'picture_puzzle';
    if (lower.contains('sound recognition')) return 'sound_recognition';
    if (lower.contains('mood check-in') || lower.contains('mood check in')) return 'mood_checkin';
    if (lower.contains('feel good')) return 'feel_good';
    if (lower.contains('my progress')) return 'my_progress';
    if (lower.contains('caregiver portal')) return 'caregiver_portal';
    if (lower.contains('caregiver access')) return 'caregiver_login';
    if (lower.contains('hint')) return 'hint';
    if (lower.contains('show hint')) return 'show_hint';
    if (lower.contains('hide hint')) return 'hide_hint';
    if (lower.contains('relaxed mode')) return 'relaxed_mode';
    if (lower.contains('replay')) return 'replay';
    if (lower.contains('reset')) return 'reset';
    if (lower.contains('next level')) return 'next_level';
    if (lower.contains('finished')) return 'finished';
    if (lower.contains('level')) return 'level';
    if (lower.contains('moves')) return 'moves';
    if (lower.contains('time')) return 'time';
    if (lower.contains('tap to listen')) return 'tap_to_listen';
    if (lower.contains('reference picture')) return 'reference_picture';
    if (lower.contains('start')) return 'start';
    if (lower.contains('pause')) return 'pause';
    if (lower.contains('resume')) return 'resume';
    if (lower.contains('stop')) return 'stop';
    if (lower.contains('small steps, brighter moments')) return 'footer_quote';
    return null;
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    selectedTextSize = prefs.getString('selectedTextSize') ?? 'Medium';
    selectedLanguage = prefs.getString('selectedLanguage') ?? 'English';
    caregiverLanguage = prefs.getString('caregiverLanguage') ?? 'English';
    backgroundMusicEnabled = prefs.getBool('backgroundMusic') ?? true;
    musicVolume = prefs.getDouble('musicVolume') ?? 0.5;
    highContrastMode = prefs.getBool('highContrastMode') ?? false;

    notifyListeners();
  }

  Future<void> setTextSize(String size) async {
    selectedTextSize = size;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedTextSize', size);
  }

  Future<void> setLanguage(String language) async {
    selectedLanguage = language;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedLanguage', language);
  }

  Future<void> setCaregiverLanguage(String language) async {
    caregiverLanguage = language;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('caregiverLanguage', language);
  }

  Future<void> setBackgroundMusic(bool enabled) async {
    backgroundMusicEnabled = enabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('backgroundMusic', enabled);
  }

  Future<void> setMusicVolume(double volume) async {
    musicVolume = volume.clamp(0.0, 1.0);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('musicVolume', musicVolume);
  }

  Future<void> setHighContrast(bool enabled) async {
    highContrastMode = enabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('highContrastMode', enabled);
  }
}
