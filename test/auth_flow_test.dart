// Focused tests for the separated role entry, session restoration and logout.
// These exercise the real AuthGate, role-selection screen, authentication
// screens, shared LogoutButton and ApiService session validation.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/app_settings.dart';
import 'package:flutter_application_1/caregiver_portal.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/models/level_data.dart';
import 'package:flutter_application_1/screens/caregiver_login_screen.dart';
import 'package:flutter_application_1/screens/role_selection_screen.dart';
import 'package:flutter_application_1/screens/user_auth_screen.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/services/audio_service.dart';
import 'package:flutter_application_1/widgets/logout_button.dart';

http.Response _json(int status, Map<String, dynamic> body) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

/// Backend double that understands the endpoints AuthGate and the portals use.
http.Client _backend({
  String? role,
  bool rejectMe = false,
  Map<String, dynamic>? prefs,
}) {
  return MockClient((request) async {
    final path = request.url.path;
    if (path.endsWith('/health')) {
      return _json(200, {
        'status': 'success',
        'data': {'status': 'healthy'},
      });
    }
    if (path.endsWith('/auth/me')) {
      if (rejectMe || role == null) {
        return _json(401, {
          'status': 'error',
          'message': 'Session expired.',
        });
      }
      return _json(200, {
        'status': 'success',
        'data': {
          'role': role,
          'profile': {
            'id': role == 'caregiver' ? 7 : 3,
            'name': role == 'caregiver' ? 'Care Giver' : 'Loved One',
            'email': role == 'caregiver'
                ? 'care@example.com'
                : 'loved@example.com',
          },
        },
      });
    }
    if (path.endsWith('/caregiver/loved-ones')) {
      return _json(200, {
        'status': 'success',
        'data': {'loved_ones': <dynamic>[]},
      });
    }
    if (path.endsWith('/auth/logout')) {
      return _json(200, {'status': 'success', 'data': {}});
    }
    if (path.endsWith('/auth/preferences')) {
      return _json(200, {
        'status': 'success',
        'data': {'preferences': prefs ?? <String, dynamic>{}},
      });
    }
    return _json(404, {'status': 'error', 'message': 'not found'});
  });
}

Future<void> _boot(
  WidgetTester tester, {
  String? token,
  String? role,
  bool rejectMe = false,
}) async {
  final api = ApiService.instance;
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await api.debugReset();
  SharedPreferences.setMockInitialValues(<String, Object>{
    if (token != null) 'mindora_jwt_token': token,
    if (role != null) 'mindora_user_role': role,
    if (token != null) 'mindora_user_name': 'Restored User',
    if (token != null) 'mindora_user_email': 'restored@example.com',
    if (token != null) 'mindora_user_id': role == 'caregiver' ? 7 : 3,
    'mindora_api_base_url': 'http://mindora.test/api',
  });
  api.debugUseHttpClient(_backend(role: role, rejectMe: rejectMe));
  await AppSettings.instance.loadSettings();
  await LevelProgressManager.instance.loadProgress();
  await AudioService.instance.initialize();
  await api.initialize();
  await tester.pumpWidget(const MindoraApp());
  await tester.pumpAndSettle();
}

Future<void> _openLogoutDialog(WidgetTester tester, Finder button) async {
  await tester.tap(button);
  await tester.pumpAndSettle();
  expect(
    find.text('Are you sure you want to log out?'),
    findsOneWidget,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fresh opening shows role selection and keeps roles separated',
      (tester) async {
    await _boot(tester);

    expect(find.byType(RoleSelectionScreen), findsOneWidget);
    expect(find.text('Who is using Mindora today?'), findsOneWidget);
    expect(find.text('Loved One'), findsOneWidget);
    expect(find.text('Caregiver'), findsOneWidget);
    expect(
      find.text('Play gentle cognitive games and track your progress.'),
      findsOneWidget,
    );
    expect(
      find.text("Stay connected and monitor your loved one's progress."),
      findsOneWidget,
    );

    // Loved One entry opens only the Loved One auth screen.
    await tester.tap(find.text('Loved One'));
    await tester.pumpAndSettle();
    expect(find.byType(UserAuthScreen), findsOneWidget);
    expect(find.text('Sign In'), findsWidgets);
    expect(find.text('Caregiver Access'), findsNothing);

    // Back returns to role selection.
    await tester.tap(find.byTooltip('Back to role selection'));
    await tester.pumpAndSettle();
    expect(find.text('Who is using Mindora today?'), findsOneWidget);

    // Caregiver entry opens only the Caregiver auth screen.
    await tester.tap(find.text('Caregiver'));
    await tester.pumpAndSettle();
    expect(find.byType(CaregiverLoginScreen), findsOneWidget);
    expect(find.text('Caregiver Access'), findsOneWidget);
    expect(find.text('Sign In'), findsNothing);
    expect(find.text('Create a new account'), findsNothing);

    await tester.tap(find.byTooltip('Back to role selection'));
    await tester.pumpAndSettle();
    expect(find.text('Who is using Mindora today?'), findsOneWidget);
  });

  testWidgets('valid Loved One session restores the Loved One home directly',
      (tester) async {
    await _boot(tester, token: 'user-token', role: 'user');

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(RoleSelectionScreen), findsNothing);
    expect(find.text('Who is using Mindora today?'), findsNothing);
    expect(find.byType(LogoutButton), findsOneWidget);
  });

  testWidgets('valid Caregiver session restores the caregiver dashboard',
      (tester) async {
    await _boot(tester, token: 'care-token', role: 'caregiver');

    expect(find.byType(CaregiverPortal), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(RoleSelectionScreen), findsNothing);
    expect(find.byKey(const Key('caregiver-logout-button')), findsOneWidget);
  });

  testWidgets('invalid or expired session returns to role selection',
      (tester) async {
    await _boot(
      tester,
      token: 'expired-token',
      role: 'user',
      rejectMe: true,
    );

    expect(ApiService.instance.isAuthenticated, isFalse);
    expect(find.byType(RoleSelectionScreen), findsOneWidget);
    expect(find.text('Who is using Mindora today?'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('Cancel on logout confirmation keeps the Loved One session',
      (tester) async {
    await _boot(tester, token: 'user-token', role: 'user');
    expect(find.byType(HomeScreen), findsOneWidget);

    await _openLogoutDialog(tester, find.byType(LogoutButton));
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Cancel'),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(RoleSelectionScreen), findsNothing);
    expect(ApiService.instance.isAuthenticated, isTrue);
  });

  testWidgets('Logout from the Loved One portal returns to role selection',
      (tester) async {
    await _boot(tester, token: 'user-token', role: 'user');

    await _openLogoutDialog(tester, find.byType(LogoutButton));
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Logout'),
    ));
    await tester.pumpAndSettle();

    expect(ApiService.instance.isAuthenticated, isFalse);
    expect(find.byType(RoleSelectionScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.text('Who is using Mindora today?'), findsOneWidget);
  });

  testWidgets('Logout from the Caregiver portal returns to role selection',
      (tester) async {
    await _boot(tester, token: 'care-token', role: 'caregiver');
    expect(find.byType(CaregiverPortal), findsOneWidget);

    await _openLogoutDialog(
      tester,
      find.byKey(const Key('caregiver-logout-button')),
    );
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Logout'),
    ));
    await tester.pumpAndSettle();

    expect(ApiService.instance.isAuthenticated, isFalse);
    expect(find.byType(RoleSelectionScreen), findsOneWidget);
    expect(find.byType(CaregiverPortal), findsNothing);
  });

  testWidgets('account switch clears cached progress and queued writes',
      (tester) async {
    final api = ApiService.instance;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await api.debugReset();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'mindora_pending_requests': jsonEncode([
        {
          'path': '/mood',
          'payload': {'mood': 'happy'},
        }
      ]),
    });
    api.debugUseHttpClient(_backend(role: 'user'));
    await api.debugSignIn(token: 'first', role: 'user', userId: 3);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('mindora_pending_requests'), isNotNull);

    await api.logout();

    expect(api.isAuthenticated, isFalse);
    expect(prefs.getString('mindora_jwt_token'), isNull);
    expect(prefs.getString('mindora_user_role'), isNull);
    expect(prefs.getString('mindora_pending_requests'), isNull);
  });
}
