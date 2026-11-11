// Mindora – Widget smoke test
// Verified with mock preferences and the role-selection authentication gate.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/app_settings.dart';
import 'package:flutter_application_1/models/level_data.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/services/audio_service.dart';

void main() {
  testWidgets('Mindora shows role selection and guest mode opens Home',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await ApiService.instance.debugReset();
    await AppSettings.instance.loadSettings();
    await LevelProgressManager.instance.loadProgress();
    await AudioService.instance.initialize();

    await tester.pumpWidget(const MindoraApp());
    await tester.pumpAndSettle();

    // Signed-out users land on the separated role-selection gate.
    expect(find.text('Who is using Mindora today?'), findsOneWidget);
    expect(find.text('Loved One'), findsOneWidget);
    expect(find.text('Caregiver'), findsOneWidget);

    final guest = find.text('Continue as guest');
    await tester.ensureVisible(guest);
    await tester.pumpAndSettle();
    await tester.tap(guest);
    await tester.pumpAndSettle();

    // Guest mode opens the home screen with the app title.
    expect(find.text('Mindora'), findsWidgets);
    expect(find.text('Who is using Mindora today?'), findsNothing);
  });
}
