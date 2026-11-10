// Live Flutter -> Flask integration check.
// Skipped unless run explicitly with:
//   flutter test --dart-define=MINDORA_LIVE_BACKEND=true test/live_backend_test.dart
// Requires the backend to be running on http://127.0.0.1:5000.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/services/adaptive_difficulty.dart';
import 'package:flutter_application_1/services/api_service.dart';

const bool _live = bool.fromEnvironment('MINDORA_LIVE_BACKEND');

void main() {
  test(
    'Flutter ApiService completes a real user and caregiver journey',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = ApiService.instance;
      await api.setBaseUrl('http://127.0.0.1:5000/api');

      expect(await api.checkHealth(), isTrue,
          reason: 'Backend health check failed');

      final user = await api.login(
        email: 'user@mindora.org',
        password: 'MindoraUser2026',
      );
      expect(user, isNotNull, reason: api.lastError);
      expect(api.isAuthenticated, isTrue);
      expect(api.isUser, isTrue);

      expect(await api.setMoodShareConsent(true), isTrue);

      await api.beginGameSession('memory_match', 1);
      final recorded = await api.recordGameSession(
        SessionMetrics(
          gameId: 'memory_match',
          level: 1,
          correctMatches: 3,
          incorrectAttempts: 1,
          hintsUsed: 0,
          totalAttempts: 4,
          elapsed: const Duration(seconds: 25),
          completed: true,
        ),
        moves: 4,
        score: 75,
      );
      expect(recorded, isNotNull, reason: api.lastError);

      final history = await api.fetchGameHistory(limit: 10);
      expect(history, isNotNull);
      expect(history!.isNotEmpty, isTrue);

      expect(
        await api.logMood('Calm', energyLevel: 4, note: 'live verification'),
        isTrue,
        reason: api.lastError,
      );
      expect(
        await api.logFeelGood('breathing', durationSeconds: 30),
        isTrue,
        reason: api.lastError,
      );

      final code = await api.generatePairingCode();
      expect(code, isNotNull, reason: api.lastError);
      expect(code, matches(RegExp(r'^MIND-[A-Z0-9]{4}-[A-Z0-9]{4}$')));

      await api.logout();
      expect(api.isAuthenticated, isFalse);

      final caregiver = await api.caregiverLogin(
        email: 'caregiver@mindora.org',
        password: 'MindoraCare2026',
      );
      expect(caregiver, isNotNull, reason: api.lastError);
      expect(api.isCaregiver, isTrue);

      final lovedOnes = await api.fetchLovedOnes();
      expect(lovedOnes, isNotNull);
      expect(lovedOnes!.isNotEmpty, isTrue);

      final dashboard = await api.fetchCaregiverDashboard();
      expect(dashboard, isNotNull, reason: api.lastError);
      expect(dashboard!['summary'], isNotNull);
      expect(dashboard['weekly_trend'], isA<List<dynamic>>());
      expect(dashboard['mood_shared'], isTrue);

      await api.logout();
    },
    skip: _live ? false : 'Set MINDORA_LIVE_BACKEND=true to run.',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
