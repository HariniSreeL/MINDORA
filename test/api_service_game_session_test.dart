// Targeted tests for the shared game-session persistence flow.
// They use package:http's MockClient so no real backend is required.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/services/adaptive_difficulty.dart';
import 'package:flutter_application_1/services/api_service.dart';

http.Response _jsonResponse(int status, Map<String, dynamic> body) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

http.Response _startResponse(int sessionId) {
  return _jsonResponse(201, {
    'status': 'success',
    'data': {
      'session': {'id': sessionId, 'status': 'started'},
    },
  });
}

http.Response _resultResponse(int sessionId) {
  return _jsonResponse(201, {
    'status': 'success',
    'data': {
      'session': {'id': sessionId, 'status': 'completed'},
    },
  });
}

SessionMetrics _metrics({
  String gameId = 'memory_match',
  int level = 1,
  bool completed = true,
}) {
  return SessionMetrics(
    gameId: gameId,
    level: level,
    correctMatches: 4,
    incorrectAttempts: 1,
    hintsUsed: 0,
    totalAttempts: 5,
    elapsed: const Duration(seconds: 20),
    completed: completed,
  );
}

Map<String, dynamic> _body(http.Request request) {
  return jsonDecode(request.body) as Map<String, dynamic>;
}

String? _authHeader(http.Request request) {
  return request.headers['Authorization'] ?? request.headers['authorization'];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ApiService api;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    api = ApiService.instance;
    await api.debugReset();
    api.baseUrl = 'http://mindora.test/api';
  });

  test('start and result share one session id and idempotency key', () async {
    final requests = <http.Request>[];
    api.debugUseHttpClient(MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/sessions/start')) {
        return _startResponse(42);
      }
      if (request.url.path.endsWith('/sessions/42/result')) {
        return _resultResponse(42);
      }
      return _jsonResponse(404, {'message': 'unexpected path'});
    }));
    await api.debugSignIn();

    final sessionId = await api.beginGameSession('memory_match', 1);
    final saved = await api.recordGameSession(_metrics());

    expect(sessionId, 42);
    expect(saved, isNotNull);
    expect(api.lastGameSaveStatus, GameSaveStatus.saved);
    expect(requests, hasLength(2));
    expect(requests[0].url.path, '/api/games/sessions/start');
    expect(requests[1].url.path, '/api/games/sessions/42/result');

    final startBody = _body(requests[0]);
    final resultBody = _body(requests[1]);
    expect(startBody['client_session_id'], hasLength(32));
    expect(resultBody['client_session_id'], startBody['client_session_id']);
    expect(resultBody['completed'], isTrue);
    expect(_authHeader(requests[0]), 'Bearer test-token');
    expect(_authHeader(requests[1]), 'Bearer test-token');
  });

  test('starting the same level again reuses the open session', () async {
    var startCalls = 0;
    api.debugUseHttpClient(MockClient((request) async {
      if (request.url.path.endsWith('/sessions/start')) {
        startCalls++;
        return _startResponse(7);
      }
      return _jsonResponse(500, {'message': 'unexpected'});
    }));
    await api.debugSignIn();

    final first = await api.beginGameSession('word_recall', 1);
    final second = await api.beginGameSession('word_recall', 1);

    expect(first, 7);
    expect(second, 7);
    expect(startCalls, 1);
  });

  test('completion waits for an in-flight start before posting', () async {
    final gate = Completer<void>();
    String? resultPath;
    api.debugUseHttpClient(MockClient((request) async {
      if (request.url.path.endsWith('/sessions/start')) {
        await gate.future;
        return _startResponse(77);
      }
      resultPath = request.url.path;
      return _resultResponse(77);
    }));
    await api.debugSignIn();

    final begin = api.beginGameSession('pattern_match', 2);
    // Simulate a very fast completion while the start request is still pending.
    final saving = api.recordGameSession(_metrics(gameId: 'pattern_match', level: 2));
    gate.complete();

    final saved = await saving;
    await begin;

    expect(saved, isNotNull);
    expect(resultPath, '/api/games/sessions/77/result');
  });

  test('a server error queues the attempt and reports queued', () async {
    api.debugUseHttpClient(MockClient((request) async {
      if (request.url.path.endsWith('/sessions/start')) {
        return _startResponse(9);
      }
      return _jsonResponse(503, {'status': 'error', 'message': 'unavailable'});
    }));
    await api.debugSignIn();
    await api.beginGameSession('sound_recognition', 1);

    final status = await AdaptiveDifficulty.instance.recordSession(
      _metrics(gameId: 'sound_recognition'),
    );

    expect(status, GameSaveStatus.queued);
    expect(await api.pendingCount(), 1);
  });

  test('a failed start falls back to /games/session with the same key', () async {
    final paths = <String>[];
    Map<String, dynamic>? fallbackBody;
    api.debugUseHttpClient(MockClient((request) async {
      paths.add(request.url.path);
      if (request.url.path.endsWith('/sessions/start')) {
        return _jsonResponse(500, {'status': 'error', 'message': 'unavailable'});
      }
      fallbackBody = _body(request);
      return _jsonResponse(201, {
        'status': 'success',
        'data': {
          'session': {'id': 101, 'status': 'completed'},
        },
      });
    }));
    await api.debugSignIn();
    await api.beginGameSession('memory_match', 3);

    final saved = await api.recordGameSession(_metrics(level: 3));

    expect(saved, isNotNull);
    expect(paths, ['/api/games/sessions/start', '/api/games/session']);
    expect(fallbackBody!['client_session_id'], hasLength(32));
    expect(fallbackBody!['level'], 3);
  });

  test('recording one completed attempt twice sends one result', () async {
    var resultPosts = 0;
    api.debugUseHttpClient(MockClient((request) async {
      if (request.url.path.endsWith('/sessions/start')) {
        return _startResponse(15);
      }
      resultPosts++;
      return _resultResponse(15);
    }));
    await api.debugSignIn();
    await api.beginGameSession('memory_match', 1);

    await api.recordGameSession(_metrics());
    await api.recordGameSession(_metrics());

    expect(resultPosts, 1);
  });

  test('a rejected result reports failed and is not queued', () async {
    api.debugUseHttpClient(MockClient((request) async {
      if (request.url.path.endsWith('/sessions/start')) {
        return _startResponse(21);
      }
      return _jsonResponse(400, {'status': 'error', 'message': 'bad payload'});
    }));
    await api.debugSignIn();
    await api.beginGameSession('memory_match', 1);

    final status = await AdaptiveDifficulty.instance.recordSession(_metrics());

    expect(status, GameSaveStatus.failed);
    expect(await api.pendingCount(), 0);
  });

  test('guests are skipped without any network request', () async {
    var calls = 0;
    api.debugUseHttpClient(MockClient((request) async {
      calls++;
      return _jsonResponse(500, {'message': 'unexpected'});
    }));

    final status = await AdaptiveDifficulty.instance.recordSession(_metrics());

    expect(status, GameSaveStatus.skipped);
    expect(calls, 0);
  });
}
