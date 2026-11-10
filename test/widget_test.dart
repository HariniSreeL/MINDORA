// Mindora – Widget smoke test
// Verified with mock preferences

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/app_settings.dart';
import 'package:flutter_application_1/models/level_data.dart';
import 'package:flutter_application_1/services/audio_service.dart';

void main() {
  testWidgets('Mindora app launches without error', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.loadSettings();
    await LevelProgressManager.instance.loadProgress();
    await AudioService.instance.initialize();

    await tester.pumpWidget(const MindoraApp());
    await tester.pump();

    // Verify title appears on Home Screen
    expect(find.text('Mindora'), findsOneWidget);
  });
}
