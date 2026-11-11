// Tests for the My Progress lifecycle: the backend is the source of truth and
// a page (re)open, refresh, reload or account change must restore from it.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/game_progress.dart';
import 'package:flutter_application_1/progress_page.dart';
import 'package:flutter_application_1/services/api_service.dart';

http.Response _json(int status, Map<String, dynamic> body) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

Map<String, dynamic> _memoryRow() => {
      'id': 11,
      'user_id': 3,
      'game_id': 'memory_match',
      'game_name': 'Memory Match',
      'level': 2,
      'status': 'completed',
      'completed': 1,
      'duration_seconds': 75,
      'moves': 8,
      'correct_matches': 4,
      'mistakes': 1,
      'score': 92.5,
      'created_at': '2026-11-11 05:00:00',
    };

Map<String, dynamic> _wordRow() => {
      'id': 12,
      'user_id': 3,
      'game_id': 'word_recall',
      'game_name': 'Word Recall',
      'level': 1,
      'status': 'completed',
      'completed': 1,
      'duration_seconds': 40,
      'moves': 4,
      'correct_matches': 3,
      'mistakes': 0,
      'score': 80,
      'created_at': '2026-11-11 06:00:00',
    };

/// Small in-memory stand-in for the Flask game-history endpoint.
class _Backend {
  _Backend(this.rows);

  List<Map<String, dynamic>> rows;
  bool failHistory = false;
  int historyCalls = 0;
  final List<http.Request> requests = [];

  http.Client get client => MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (path.endsWith('/health')) {
          return _json(200, {
            'status': 'success',
            'data': {'status': 'healthy'},
          });
        }
        if (path.endsWith('/games/sessions')) {
          historyCalls++;
          if (failHistory) {
            return _json(503, {
              'status': 'error',
              'message': 'temporarily unavailable',
            });
          }
          return _json(200, {
            'status': 'success',
            'data': {'sessions': rows, 'limit': 100, 'offset': 0},
          });
        }
        if (path.endsWith('/auth/logout')) {
          return _json(200, {'status': 'success', 'data': {}});
        }
        return _json(404, {'status': 'error', 'message': 'not found'});
      });
}

Future<void> _pumpPage(WidgetTester tester, {Key? key}) async {
  await tester.pumpWidget(
    MaterialApp(home: ProgressPage(key: key)),
  );
  await tester.pumpAndSettle();
}

/// The Recent Activity list sits below the fold and is built lazily, so drag
/// the page until the widget exists in the tree.
Future<void> _expectOnScreen(WidgetTester tester, String text) async {
  final finder = find.textContaining(text);
  for (var i = 0; i < 12 && finder.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
  }
  expect(finder, findsWidgets);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ApiService api;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    api = ApiService.instance;
    await api.debugReset();
    api.baseUrl = 'http://mindora.test/api';
  });

  testWidgets('loads persisted sessions from the backend with the restored token',
      (tester) async {
    final backend = _Backend([_memoryRow()]);
    api.debugUseHttpClient(backend.client);
    await api.debugSignIn();

    await _pumpPage(tester);

    expect(backend.historyCalls, 1);
    expect(api.isAuthenticated, isTrue);
    expect(api.isUser, isTrue);

    final historyRequest = backend.requests
        .firstWhere((request) => request.url.path.endsWith('/games/sessions'));
    expect(historyRequest.headers['Authorization'], 'Bearer test-token');

    await _expectOnScreen(tester, '8 moves');
    await _expectOnScreen(tester, 'Level 2');
    expect(find.textContaining('Score 93'), findsOneWidget);
  });

  testWidgets('restores the same progress after a full reload (cache dropped)',
      (tester) async {
    final backend = _Backend([_memoryRow()]);
    api.debugUseHttpClient(backend.client);
    await api.debugSignIn();

    await _pumpPage(tester);
    await _expectOnScreen(tester, '8 moves');

    // Simulate closing and reopening the application: every in-memory cache is
    // gone, so the next page can only show what the backend returns.
    GameProgress.instance.clear();
    expect(GameProgress.instance.sessions, isEmpty);

    await _pumpPage(tester, key: const ValueKey('reloaded-page'));

    expect(backend.historyCalls, 2);
    expect(GameProgress.instance.sessions, isNotEmpty);
    await _expectOnScreen(tester, '8 moves');
  });

  testWidgets('reopening the page after navigating away fetches fresh data',
      (tester) async {
    final backend = _Backend([_memoryRow()]);
    api.debugUseHttpClient(backend.client);
    await api.debugSignIn();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProgressPage()),
                ),
                child: const Text('open progress'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open progress'));
    await tester.pumpAndSettle();
    await _expectOnScreen(tester, '8 moves');
    expect(backend.historyCalls, 1);

    // A new game is completed while the page is closed.
    backend.rows = [_wordRow(), _memoryRow()];
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('open progress'));
    await tester.pumpAndSettle();

    expect(backend.historyCalls, 2);
    await _expectOnScreen(tester, 'Word Recall');
    expect(GameProgress.instance.sessions, hasLength(2));
  });

  testWidgets('a failed refresh keeps the data already on screen', (tester) async {
    final backend = _Backend([_memoryRow()]);
    api.debugUseHttpClient(backend.client);
    await api.debugSignIn();

    await _pumpPage(tester);
    expect(GameProgress.instance.sessions, isNotEmpty);

    backend.failHistory = true;
    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(backend.historyCalls, greaterThanOrEqualTo(2));
    // The failure is reported instead of a silent empty state...
    expect(find.textContaining('temporarily unavailable'), findsOneWidget);
    // ...and existing valid progress is still displayed.
    expect(GameProgress.instance.sessions, isNotEmpty);
    await _expectOnScreen(tester, '8 moves');
  });

  testWidgets('a successful empty response clears stale progress', (tester) async {
    final backend = _Backend([_memoryRow()]);
    api.debugUseHttpClient(backend.client);
    await api.debugSignIn();

    await _pumpPage(tester);
    await _expectOnScreen(tester, '8 moves');

    backend.rows = [];
    await _pumpPage(tester, key: const ValueKey('empty-account-page'));

    expect(GameProgress.instance.sessions, isEmpty);
    expect(find.textContaining('8 moves'), findsNothing);
  });

  test('signing out clears cached progress', () async {
    final backend = _Backend([_memoryRow()]);
    api.debugUseHttpClient(backend.client);
    await api.debugSignIn();

    GameProgress.instance.replaceFromServer([_memoryRow()]);
    expect(GameProgress.instance.sessions, isNotEmpty);

    await api.logout();

    expect(GameProgress.instance.sessions, isEmpty);
  });

  test('in-flight sessions are not shown as progress', () {
    final updated = GameProgress.instance.replaceFromServer([
      {
        'id': 1,
        'game_id': 'memory_match',
        'status': 'started',
        'created_at': '2026-11-11 05:00:00',
      },
      _wordRow(),
    ]);

    expect(updated, isTrue);
    expect(GameProgress.instance.sessions, hasLength(1));
    expect(GameProgress.instance.sessions.single.gameName, 'Word Recall');
  });

  test('an unreadable non-empty payload keeps the last known-good data', () {
    GameProgress.instance.replaceFromServer([_memoryRow()]);
    final before = GameProgress.instance.sessions.length;

    final updated = GameProgress.instance.replaceFromServer(['not-a-row']);

    expect(updated, isFalse);
    expect(GameProgress.instance.sessions, hasLength(before));
  });
}
