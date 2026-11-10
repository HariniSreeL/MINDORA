// Mindora REST API client for the Flask backend.
// Centralizes HTTP, JSON, auth token storage, timeouts and offline queueing.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'adaptive_difficulty.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
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

  final http.Client _client = http.Client();
  final Map<String, Future<int?>> _pendingSessionStarts = {};

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
        await flushPending();
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
    _pendingSessionStarts.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userRoleKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userIdKey);
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
  Future<int?> _startGameSession(String gameId, int level, {bool relaxedMode = false}) async {
    if (!isAuthenticated || !isUser) return null;
    final response = await _send(
      'POST',
      '/games/sessions/start',
      body: {'game_id': gameId, 'level': level, 'relaxed_mode': relaxedMode},
      timeout: const Duration(seconds: 6),
    );
    if (response.statusCode == 201) {
      return response.data?['session']?['id'] as int?;
    }
    return null;
  }

  /// Begins a backend session. Safe to call for guests (it is a no-op).
  Future<void> beginGameSession(String gameId, int level, {bool relaxedMode = false}) async {
    if (!isAuthenticated || !isUser) return;
    final key = '$gameId:$level';
    final future = _startGameSession(gameId, level, relaxedMode: relaxedMode);
    _pendingSessionStarts[key] = future;
    await future;
  }

  Future<int?> _takeSessionId(String key) async {
    final future = _pendingSessionStarts.remove(key);
    if (future == null) return null;
    try {
      return await future;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> recordGameSession(
    SessionMetrics metrics, {
    int moves = 0,
    double score = 100.0,
    String domain = 'general',
  }) async {
    if (!isAuthenticated || !isUser) return null;
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
    };

    final sessionId = await _takeSessionId('${metrics.gameId}:${metrics.level}');
    final path = sessionId != null ? '/games/sessions/$sessionId/result' : '/games/session';
    final response = await _send('POST', path, body: payload, timeout: const Duration(seconds: 6));
    if (response.ok) {
      _lastError = null;
      return response.data;
    }
    if (response.networkError || (response.statusCode ?? 500) >= 500) {
      await _queueRequest(path, payload);
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
