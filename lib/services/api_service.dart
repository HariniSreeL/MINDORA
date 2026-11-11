// Mindora REST API client for the Flask backend.
// Centralizes HTTP, JSON, auth token storage, timeouts and offline queueing.
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'adaptive_difficulty.dart';
import 'audio_service.dart';
import '../game_progress.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Outcome of the most recent game-session save attempt.
enum GameSaveStatus {
  /// The backend confirmed the write.
  saved,

  /// The request failed with a retryable error and is stored for later sync.
  queued,

  /// The backend rejected the request; retrying the same payload will not help.
  failed,

  /// Nothing was sent because the player is a guest or not signed in.
  skipped,
}

/// Per-game in-flight session start. One tracker keeps the started session id
/// tied to the result that belongs to it, so overlapping level starts can never
/// steal or duplicate the association.
class _GameSessionTracker {
  _GameSessionTracker({
    required this.gameId,
    required this.level,
    required this.clientSessionId,
    required this.start,
  });

  final String gameId;
  final int level;
  final String clientSessionId;
  final Future<int?> start;

  bool completed = false;
  Map<String, dynamic>? response;
}

class ApiResponse {
  ApiResponse({this.statusCode, this.body, this.networkError = false});

  final int? statusCode;
  final Map<String, dynamic>? body;
  final bool networkError;

  bool get ok => statusCode != null && statusCode! >= 200 && statusCode! < 300;
  Map<String, dynamic>? get data => body?['data'] as Map<String, dynamic>?;
  String get message =>
      (body?['message'] as String?) ??
      (networkError ? 'Could not reach Mindora. Check your connection.' : 'Something went wrong.');
}

class ApiService extends ChangeNotifier {
  ApiService._();
  static final ApiService instance = ApiService._();

  static const String _tokenKey = 'mindora_jwt_token';
  static const String _userRoleKey = 'mindora_user_role';
  static const String _userNameKey = 'mindora_user_name';
  static const String _userEmailKey = 'mindora_user_email';
  static const String _userIdKey = 'mindora_user_id';
  static const String _baseUrlKey = 'mindora_api_base_url';
  static const String _pendingKey = 'mindora_pending_requests';
  static const String _compileTimeBaseUrl = String.fromEnvironment('MINDORA_API_BASE_URL');

  String? _token;
  String? _role;
  String? _userName;
  String? _userEmail;
  int? _userId;
  bool _isOnline = false;
  String? _lastError;
  int? _lastStatusCode;
  bool _initialized = false;

  http.Client _client = http.Client();
  final Map<String, _GameSessionTracker> _gameSessions = {};
  GameSaveStatus _lastGameSaveStatus = GameSaveStatus.skipped;
  Future<void>? _pendingGameSave;
  static final Random _random = Random.secure();

  String get defaultBaseUrl {
    if (_compileTimeBaseUrl.isNotEmpty) return _normalizeBaseUrl(_compileTimeBaseUrl);
    if (kIsWeb) return 'http://127.0.0.1:5000/api';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Android emulator loopback alias. Use --dart-define for real devices.
        return 'http://10.0.2.2:5000/api';
      default:
        return 'http://127.0.0.1:5000/api';
    }
  }

  String baseUrl = 'http://127.0.0.1:5000/api';

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  bool get isCaregiver => _role == 'caregiver';
  bool get isUser => _role == 'user';
  bool get isOnline => _isOnline;
  bool get initialized => _initialized;
  String? get token => _token;
  String? get role => _role;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  int? get userId => _userId;
  String? get lastError => _lastError;
  int? get lastStatusCode => _lastStatusCode;
  GameSaveStatus get lastGameSaveStatus => _lastGameSaveStatus;

  /// Test-only hooks. Production code always uses the shared singleton client.
  @visibleForTesting
  void debugUseHttpClient(http.Client client) {
    _client = client;
  }

  @visibleForTesting
  Future<void> debugSignIn({
    String token = 'test-token',
    String role = 'user',
    int userId = 1,
  }) =>
      _persistSession(token: token, role: role, userId: userId);

  /// Clears in-memory session state and stored preferences without any network
  /// call, so each widget/unit test starts from a known signed-out state.
  @visibleForTesting
  Future<void> debugReset() async {
    _token = null;
    _role = null;
    _userName = null;
    _userEmail = null;
    _userId = null;
    _lastError = null;
    _lastStatusCode = null;
    _lastGameSaveStatus = GameSaveStatus.skipped;
    _gameSessions.clear();
    _pendingGameSave = null;
    _initialized = false;
    GameProgress.instance.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static String _normalizeBaseUrl(String url) {
    var value = url.trim();
    if (value.isEmpty) return value;
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'http://$value';
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (!value.endsWith('/api')) {
      value = '$value/api';
    }
    return value;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenKey);
      _role = prefs.getString(_userRoleKey);
      _userName = prefs.getString(_userNameKey);
      _userEmail = prefs.getString(_userEmailKey);
      _userId = prefs.getInt(_userIdKey);
      baseUrl = prefs.getString(_baseUrlKey) ?? defaultBaseUrl;
      await checkHealth();
      if (isAuthenticated) {
        // Confirm the restored token is still valid before any protected screen
        // is shown. Network failures keep the local session so the app still
        // works offline; a rejected token returns the user to role selection.
        final valid = await validateSession();
        if (valid) {
          await flushPending();
        }
      }
    } catch (e) {
      debugPrint('ApiService init error: $e');
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> setBaseUrl(String url) async {
    final normalized = _normalizeBaseUrl(url);
    if (normalized.isEmpty) return;
    baseUrl = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, baseUrl);
    await checkHealth();
  }

  Map<String, String> _headers({bool needsAuth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (needsAuth && _token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Future<ApiResponse> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      late http.Response response;
      switch (method) {
        case 'GET':
          response = await _client
              .get(uri, headers: _headers(needsAuth: auth))
              .timeout(timeout);
          break;
        case 'POST':
          response = await _client
              .post(uri, headers: _headers(needsAuth: auth), body: body == null ? null : jsonEncode(body))
              .timeout(timeout);
          break;
        case 'PUT':
          response = await _client
              .put(uri, headers: _headers(needsAuth: auth), body: body == null ? null : jsonEncode(body))
              .timeout(timeout);
          break;
        case 'DELETE':
          response = await _client
              .delete(uri, headers: _headers(needsAuth: auth))
              .timeout(timeout);
          break;
        default:
          throw ArgumentError('Unsupported method $method');
      }

      Map<String, dynamic>? decoded;
      if (response.body.isNotEmpty) {
        try {
          final value = jsonDecode(response.body);
          if (value is Map<String, dynamic>) decoded = value;
        } catch (_) {
          decoded = null;
        }
      }

      _lastStatusCode = response.statusCode;
      _isOnline = true;
      if (response.statusCode == 401 && auth) {
        await _clearSession();
        _lastError = decoded?['message'] as String? ?? 'Your session has expired. Please sign in again.';
      } else if (response.statusCode < 200 || response.statusCode >= 300) {
        _lastError = decoded?['message'] as String? ?? 'Request failed (${response.statusCode}).';
        if (kDebugMode) {
          // Never log tokens, headers or request bodies: only method, path, status.
          debugPrint('API $method $path -> ${response.statusCode}');
        }
      }
      return ApiResponse(statusCode: response.statusCode, body: decoded);
    } on TimeoutException {
      _isOnline = false;
      _lastError = 'Mindora is taking too long to respond. Please try again.';
      return ApiResponse(networkError: true);
    } catch (e) {
      _isOnline = false;
      _lastError = 'Could not reach Mindora. Check your connection.';
      debugPrint('API $method $path failed: $e');
      return ApiResponse(networkError: true);
    }
  }

  Future<bool> checkHealth() async {
    final response = await _send(
      'GET',
      '/health',
      auth: false,
      timeout: const Duration(seconds: 3),
    );
    _isOnline = response.statusCode == 200;
    notifyListeners();
    return _isOnline;
  }

  Future<void> _persistSession({
    required String token,
    required String role,
    String? name,
    String? email,
    int? userId,
  }) async {
    // Switching accounts must never keep the previous Loved One's history or
    // replay their queued offline writes under the new account.
    final identityChanged = role != _role || (userId != null && userId != _userId);
    if (identityChanged) {
      GameProgress.instance.clear();
    }
    _token = token;
    _role = role;
    _userName = name;
    _userEmail = email;
    _userId = userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userRoleKey, role);
    if (name != null && name.isNotEmpty) await prefs.setString(_userNameKey, name);
    if (email != null && email.isNotEmpty) await prefs.setString(_userEmailKey, email);
    if (userId != null) await prefs.setInt(_userIdKey, userId);
    _isOnline = true;
    notifyListeners();
  }

  Future<void> _clearSession() async {
    _token = null;
    _role = null;
    _userName = null;
    _userEmail = null;
    _userId = null;
    _gameSessions.clear();
    _pendingGameSave = null;
    GameProgress.instance.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userRoleKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userIdKey);
    // Queued writes belong to the account that created them. Dropping them on
    // sign-out keeps the next person from syncing someone else's activity.
    await prefs.remove(_pendingKey);
    notifyListeners();
  }

  Future<Map<String, dynamic>?> register({
    required String name,
    required String email,
    required String password,
    String role = 'user',
    String preferredLanguage = 'English',
  }) async {
    final response = await _send(
      'POST',
      '/auth/register',
      auth: false,
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'role': role,
        'preferred_language': preferredLanguage,
      },
    );
    if (response.statusCode == 201) {
      final data = response.data;
      final account = (data?['user'] as Map?)?.cast<String, dynamic>() ??
          (data?['caregiver'] as Map?)?.cast<String, dynamic>();
      if (data?['token'] is String) {
        await _persistSession(
          token: data!['token'] as String,
          role: (data['role'] as String?) ?? role,
          name: account?['name'] as String? ?? name,
          email: account?['email'] as String? ?? email,
          userId: account?['id'] as int?,
        );
        _lastError = null;
        return data;
      }
    }
    notifyListeners();
    return null;
  }

  Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
    String role = 'user',
  }) async {
    final response = await _send(
      'POST',
      '/auth/login',
      auth: false,
      body: {
        'email': email.trim(),
        'password': password,
        'role': role,
      },
    );
    if (response.statusCode == 200) {
      final data = response.data;
      final account = (data?['user'] as Map?)?.cast<String, dynamic>();
      if (data?['token'] is String) {
        await _persistSession(
          token: data!['token'] as String,
          role: (data['role'] as String?) ?? role,
          name: account?['name'] as String?,
          email: account?['email'] as String? ?? email,
          userId: account?['id'] as int?,
        );
        _lastError = null;
        await flushPending();
        return data;
      }
    }
    notifyListeners();
    return null;
  }

  Future<Map<String, dynamic>?> caregiverLogin({
    required String email,
    required String password,
  }) async {
    final response = await _send(
      'POST',
      '/auth/caregiver/login',
      auth: false,
      body: {'email': email.trim(), 'password': password},
    );
    if (response.statusCode == 200) {
      final data = response.data;
      final account = (data?['caregiver'] as Map?)?.cast<String, dynamic>() ??
          (data?['user'] as Map?)?.cast<String, dynamic>();
      if (data?['token'] is String) {
        await _persistSession(
          token: data!['token'] as String,
          role: 'caregiver',
          name: account?['name'] as String?,
          email: account?['email'] as String? ?? email,
          userId: account?['id'] as int?,
        );
        _lastError = null;
        return data;
      }
    }
    notifyListeners();
    return null;
  }

  Future<void> logout() async {
    if (_token != null) {
      await _send('POST', '/auth/logout', timeout: const Duration(seconds: 4));
    }
    await _clearSession();
    // The next person starts in silence rather than inheriting this session's
    // background music.
    await AudioService.instance.stopMusic();
  }

  /// Verifies the persisted token with the backend and refreshes the cached
  /// role/name/email from the authoritative profile.
  ///
  /// Returns `true` when the session is usable. Network failures keep the
  /// session (offline-friendly); rejected or missing profiles clear it.
  Future<bool> validateSession() async {
    if (!isAuthenticated) return false;
    final response = await _send('GET', '/auth/me');
    if (response.networkError) return true;
    if (!response.ok) {
      await _clearSession();
      return false;
    }
    final data = response.data;
    final profile =
        (data?['profile'] as Map?)?.cast<String, dynamic>();
    final role = (data?['role'] as String?) ?? _role ?? 'user';
    await _persistSession(
      token: _token!,
      role: role,
      name: profile?['name'] as String? ?? _userName,
      email: profile?['email'] as String? ?? _userEmail,
      userId: profile?['id'] as int? ?? _userId,
    );
    return true;
  }

  Future<Map<String, dynamic>?> fetchProfile() async {
    if (!isAuthenticated) return null;
    final response = await _send('GET', '/auth/me');
    return response.ok ? response.data : null;
  }

  Future<bool> syncLanguage(String language) async {
    if (!isAuthenticated || !isUser) return false;
    final response = await _send('PUT', '/auth/language', body: {'language': language});
    return response.ok;
  }

  Future<Map<String, dynamic>?> fetchPreferences() async {
    if (!isAuthenticated || !isUser) return null;
    final response = await _send('GET', '/auth/preferences');
    return response.ok ? (response.data?['preferences'] as Map<String, dynamic>?) : null;
  }

  Future<bool> syncPreferences({
    String? language,
    String? textSize,
    bool? backgroundMusic,
    double? musicVolume,
  }) async {
    if (!isAuthenticated || !isUser) return false;
    final body = <String, dynamic>{};
    if (language != null) body['preferred_language'] = language;
    if (textSize != null) body['text_size'] = textSize;
    if (backgroundMusic != null) body['background_music'] = backgroundMusic;
    if (musicVolume != null) body['music_volume'] = musicVolume;
    final response = await _send('PUT', '/auth/preferences', body: body);
    return response.ok;
  }

  // ---------------------------------------------------------------- games
  /// Random, non-guessable idempotency key for one completed game attempt.
  /// The backend stores it so retries and offline flushes cannot create a
  /// second session or a second result row.
  String _newClientSessionId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<int?> _startGameSession(
    String gameId,
    int level, {
    bool relaxedMode = false,
    String? clientSessionId,
  }) async {
    if (!isAuthenticated || !isUser) return null;
    final response = await _send(
      'POST',
      '/games/sessions/start',
      body: {
        'game_id': gameId,
        'level': level,
        'relaxed_mode': relaxedMode,
        'client_session_id': ?clientSessionId,
      },
      timeout: const Duration(seconds: 12),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return response.data?['session']?['id'] as int?;
    }
    if (kDebugMode) {
      debugPrint(
        'Game session start failed: game=$gameId level=$level '
        'status=${response.statusCode ?? 'network'}',
      );
    }
    return null;
  }

  /// Begins a backend session and keeps its id available for the matching
  /// result. Safe to call for guests (it is a no-op).
  ///
  /// Calling this again for the same game and level while a session is still
  /// open reuses that session instead of creating a duplicate.
  Future<int?> beginGameSession(
    String gameId,
    int level, {
    bool relaxedMode = false,
  }) async {
    if (!isAuthenticated || !isUser) return null;
    final existing = _gameSessions[gameId];
    if (existing != null && !existing.completed && existing.level == level) {
      return existing.start;
    }

    final clientSessionId = _newClientSessionId();
    final tracker = _GameSessionTracker(
      gameId: gameId,
      level: level,
      clientSessionId: clientSessionId,
      start: _startGameSession(
        gameId,
        level,
        relaxedMode: relaxedMode,
        clientSessionId: clientSessionId,
      ),
    );
    _gameSessions[gameId] = tracker;
    return tracker.start;
  }

  /// Returns the started session id for this completed attempt.
  /// The start request is always awaited, so a fast completion can never race
  /// ahead of its own session creation. A tracker for a different level is not
  /// reused, because its session belongs to another attempt.
  Future<int?> _resolveSessionId(SessionMetrics metrics) async {
    final tracker = _gameSessions[metrics.gameId];
    if (tracker == null || tracker.level != metrics.level) return null;
    try {
      return await tracker.start;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Game session start could not be awaited: $e');
      }
      return null;
    }
  }

  /// Records the completed attempt and tracks the write so My Progress can wait
  /// for it before reading the server back.
  Future<Map<String, dynamic>?> recordGameSession(
    SessionMetrics metrics, {
    int moves = 0,
    double score = 100.0,
    String domain = 'general',
  }) {
    final future = _recordGameSession(
      metrics,
      moves: moves,
      score: score,
      domain: domain,
    );
    _pendingGameSave = future.then<void>((_) {}, onError: (Object _) {});
    return future;
  }

  /// Waits for the most recent game result write to finish (saved, queued or
  /// failed) so a page opened immediately after a game sees the latest data.
  Future<void> waitForPendingGameSave() async {
    final pending = _pendingGameSave;
    if (pending != null) await pending;
  }

  Future<Map<String, dynamic>?> _recordGameSession(
    SessionMetrics metrics, {
    int moves = 0,
    double score = 100.0,
    String domain = 'general',
  }) async {
    if (!isAuthenticated || !isUser) {
      _lastGameSaveStatus = GameSaveStatus.skipped;
      return null;
    }

    final tracker = _gameSessions[metrics.gameId];
    // Only the tracker created for this exact level may supply its session id
    // and idempotency key.
    final activeTracker =
        tracker != null && tracker.level == metrics.level ? tracker : null;
    // A session can only produce one result. This blocks double taps, duplicate
    // completion callbacks and replay races from submitting twice.
    if (activeTracker != null && activeTracker.completed) {
      return activeTracker.response;
    }

    final clientSessionId =
        activeTracker?.clientSessionId ?? _newClientSessionId();
    final payload = {
      ...metrics.toFeatureMap(),
      'game_id': metrics.gameId,
      'level': metrics.level,
      'mistakes': metrics.incorrectAttempts,
      'incorrect_answers': metrics.incorrectAttempts,
      'correct_answers': metrics.correctMatches,
      'moves': moves == 0 ? metrics.totalAttempts : moves,
      'score': score,
      'cognitive_domain': domain,
      'client_session_id': clientSessionId,
      // toFeatureMap encodes this as 0/1 for the ML feature vector; the API
      // expects a boolean, so restore the real flag here.
      'completed': metrics.completed,
    };

    final sessionId = await _resolveSessionId(metrics);
    final path = sessionId != null ? '/games/sessions/$sessionId/result' : '/games/session';
    final response = await _send(
      'POST',
      path,
      body: payload,
      timeout: const Duration(seconds: 12),
    );

    if (activeTracker != null) activeTracker.completed = true;

    if (response.ok) {
      _lastError = null;
      _lastGameSaveStatus = GameSaveStatus.saved;
      if (activeTracker != null) activeTracker.response = response.data;
      return response.data;
    }

    final retryable = response.networkError || (response.statusCode ?? 500) >= 500;
    if (retryable) {
      await _queueRequest(path, payload);
      _lastGameSaveStatus = GameSaveStatus.queued;
    } else {
      _lastGameSaveStatus = GameSaveStatus.failed;
      if (kDebugMode) {
        debugPrint(
          'Game session result rejected: game=${metrics.gameId} '
          'level=${metrics.level} path=$path '
          'status=${response.statusCode ?? 'network'}',
        );
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchProgress() async {
    if (!isAuthenticated || !isUser) return null;
    final response = await _send('GET', '/games/progress');
    return response.ok ? response.data : null;
  }

  Future<Map<String, dynamic>?> fetchProgression() async {
    if (!isAuthenticated || !isUser) return null;
    final response = await _send('GET', '/games/progression');
    return response.ok ? (response.data?['progression'] as Map<String, dynamic>?) : null;
  }

  /// Returns null on failure so callers can distinguish empty history from offline.
  Future<List<dynamic>?> fetchGameHistory({int limit = 100, int offset = 0}) async {
    if (!isAuthenticated || !isUser) return null;
    final response = await _send('GET', '/games/sessions?limit=$limit&offset=$offset');
    if (!response.ok) return null;
    return (response.data?['sessions'] as List?) ?? const [];
  }

  Future<bool> updateProgression({
    required String gameId,
    required int unlockedLevel,
    int? completedLevel,
    int? stars,
  }) async {
    if (!isAuthenticated || !isUser) return false;
    final body = <String, dynamic>{
      'game_id': gameId,
      'unlocked_level': unlockedLevel,
    };
    if (completedLevel != null) body['completed_level'] = completedLevel;
    if (stars != null) body['stars'] = stars;
    final response = await _send('PUT', '/games/progression', body: body);
    return response.ok;
  }

  // -------------------------------------------------------------- wellness
  Future<bool> logMood(String mood, {int energyLevel = 3, String? note}) async {
    final payload = {
      'mood': mood,
      'energy_level': energyLevel.clamp(1, 5),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    };
    if (!isAuthenticated || !isUser) {
      await _queueRequest('/wellness/mood', payload);
      return false;
    }
    final response = await _send('POST', '/wellness/mood', body: payload);
    if (response.ok) {
      _lastError = null;
      return true;
    }
    if (response.networkError || (response.statusCode ?? 500) >= 500) {
      await _queueRequest('/wellness/mood', payload);
    }
    return false;
  }

  Future<List<dynamic>?> fetchMoodHistory({int limit = 30}) async {
    if (!isAuthenticated || !isUser) return null;
    final response = await _send('GET', '/wellness/mood?limit=$limit');
    return response.ok ? (response.data?['history'] as List?) ?? const [] : null;
  }

  Future<bool> logFeelGood(
    String activityType, {
    String? title,
    double durationSeconds = 0.0,
    bool completed = true,
  }) async {
    final payload = {
      'activity_type': activityType,
      'title': title,
      'duration_seconds': durationSeconds,
      'completed': completed,
    };
    if (!isAuthenticated || !isUser) {
      await _queueRequest('/wellness/feel-good', payload);
      return false;
    }
    final response = await _send('POST', '/wellness/feel-good', body: payload);
    if (response.ok) return true;
    if (response.networkError || (response.statusCode ?? 500) >= 500) {
      await _queueRequest('/wellness/feel-good', payload);
    }
    return false;
  }

  Future<List<dynamic>?> fetchFeelGoodHistory({int limit = 20}) async {
    if (!isAuthenticated || !isUser) return null;
    final response = await _send('GET', '/wellness/feel-good?limit=$limit');
    return response.ok ? (response.data?['history'] as List?) ?? const [] : null;
  }

  Future<bool> setMoodShareConsent(bool share) async {
    if (!isAuthenticated || !isUser) return false;
    final response = await _send('PUT', '/wellness/consent', body: {'share_mood_with_caregiver': share});
    return response.ok;
  }

  // -------------------------------------------------------------- caregiver
  Future<String?> generatePairingCode() async {
    if (!isAuthenticated || !isUser) return null;
    final response = await _send('POST', '/caregiver/generate-code');
    return response.ok ? (response.data?['pairing_code'] as String?) : null;
  }

  Future<bool> pairCaregiver(String pairingCode, {String relationship = 'Family Member'}) async {
    if (!isAuthenticated) return false;
    final response = await _send(
      'POST',
      '/caregiver/pair',
      body: {'pairing_code': pairingCode.trim(), 'relationship': relationship},
    );
    return response.ok;
  }

  Future<List<dynamic>?> fetchLovedOnes() async {
    if (!isAuthenticated || !isCaregiver) return null;
    final response = await _send('GET', '/caregiver/loved-ones');
    return response.ok ? (response.data?['loved_ones'] as List?) ?? const [] : null;
  }

  Future<Map<String, dynamic>?> fetchCaregiverDashboard({int? userId}) async {
    if (!isAuthenticated || !isCaregiver) return null;
    final path = userId != null ? '/caregiver/dashboard/$userId' : '/caregiver/dashboard';
    final response = await _send('GET', path, timeout: const Duration(seconds: 10));
    return response.ok ? response.data : null;
  }

  Future<bool> unpairLovedOne(int userId) async {
    if (!isAuthenticated || !isCaregiver) return false;
    final response = await _send('DELETE', '/caregiver/pair/$userId');
    return response.ok;
  }

  Future<bool> revokeCaregiverAccess() async {
    if (!isAuthenticated || !isUser) return false;
    final response = await _send('DELETE', '/caregiver/pairings');
    return response.ok;
  }

  // ----------------------------------------------------------- offline queue
  Future<void> _queueRequest(String path, Map<String, dynamic> payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingKey);
      final List<dynamic> entries = raw == null ? [] : (jsonDecode(raw) as List<dynamic>);
      final clientSessionId = payload['client_session_id'];
      final duplicate = clientSessionId != null &&
          entries.any((e) =>
              e is Map &&
              e['path'] == path &&
              (e['payload'] as Map?)?['client_session_id'] == clientSessionId);
      if (duplicate) return;
      entries.add({
        'path': path,
        'payload': payload,
        'queued_at': DateTime.now().toUtc().toIso8601String(),
      });
      while (entries.length > 100) {
        entries.removeAt(0);
      }
      await prefs.setString(_pendingKey, jsonEncode(entries));
    } catch (e) {
      debugPrint('Offline queue error: $e');
    }
  }

  Future<int> pendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingKey);
    if (raw == null) return 0;
    try {
      return (jsonDecode(raw) as List<dynamic>).length;
    } catch (_) {
      return 0;
    }
  }

  /// Retries queued mood/game records. Called after sign-in and app start.
  Future<int> flushPending() async {
    if (!isAuthenticated || !isUser) return 0;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingKey);
    if (raw == null) return 0;

    List<dynamic> entries;
    try {
      entries = jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      await prefs.remove(_pendingKey);
      return 0;
    }

    final remaining = <dynamic>[];
    var flushed = 0;
    for (final entry in entries) {
      if (entry is! Map) continue;
      final path = entry['path'] as String?;
      final payload = (entry['payload'] as Map?)?.cast<String, dynamic>();
      if (path == null || payload == null) continue;
      final response = await _send(
        'POST',
        path,
        body: payload,
        timeout: const Duration(seconds: 6),
      );
      if (response.ok) {
        flushed++;
      } else if (response.networkError || (response.statusCode ?? 500) >= 500) {
        remaining.add(entry);
      }
    }
    if (remaining.isEmpty) {
      await prefs.remove(_pendingKey);
    } else {
      await prefs.setString(_pendingKey, jsonEncode(remaining));
    }
    if (flushed > 0) notifyListeners();
    return flushed;
  }
}
