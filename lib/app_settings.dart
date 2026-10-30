
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  String selectedTextSize = 'Medium';
  String selectedLanguage = 'English';

  double get textScale {
    switch (selectedTextSize) {
      case 'Small':
        return 0.70;
      case 'Large':
        return 1.40;
      default:
        return 1.0;
    }
  }

  bool get isHindi => selectedLanguage == 'Hindi';

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    selectedTextSize =
        prefs.getString('selectedTextSize') ?? 'Medium';

    selectedLanguage =
        prefs.getString('selectedLanguage') ?? 'English';

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
}
