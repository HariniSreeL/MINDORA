// Mindora – Widget smoke test
// Verified with mock preferences and the authentication gate.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/app_settings.dart';
import 'package:flutter_application_1/models/level_data.dart';
import 'package:flutter_application_1/services/audio_service.dart';

void main() {
  testWidgets('Mindora shows the auth gate and guest mode opens Home',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.loadSettings();
    await LevelProgressManager.instance.loadProgress();
    await AudioService.instance.initialize();

    await tester.pumpWidget(const MindoraApp());
    await tester.pumpAndSettle();

    // Signed-out users land on the authentication gate.
    expect(find.text('Sign In'), findsWidgets);

    await tester.tap(find.text('Continue as guest'));
    await tester.pumpAndSettle();

    // Guest mode opens the home screen with the app title.
    expect(find.text('Mindora'), findsOneWidget);
  });
}
