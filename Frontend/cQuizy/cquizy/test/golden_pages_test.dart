import 'dart:async'; // Added
import 'dart:convert';
import 'dart:io';

import 'package:cquizy/home_page.dart';
import 'package:cquizy/project_editor_page.dart';
import 'package:cquizy/theme.dart';
import 'package:cquizy/providers/user_provider.dart'; // Added
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Fixed location

// --- MOCK HTTP CLIENT ---
class MockHttpClient extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return MockHttpClientRequest(url, 'GET');
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    // For auto-login or other posts
    return MockHttpClientRequest(url, 'POST');
  }
}

class MockHttpClientRequest extends Fake implements HttpClientRequest {
  final Uri url;
  final String method;

  MockHttpClientRequest(this.url, this.method);

  @override
  void add(List<int> data) {}

  @override
  void write(Object? obj) {}

  @override
  Future<HttpClientResponse> close() async {
    return MockHttpClientResponse(url, method);
  }

  @override
  HttpHeaders get headers => MockHttpHeaders();

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  Future<HttpClientResponse> get done =>
      Future.value(MockHttpClientResponse(url, method));
}

class MockHttpHeaders extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  String? value(String name) => null;
}

class MockHttpClientResponse extends Fake implements HttpClientResponse {
  final Uri url;
  final String method;

  MockHttpClientResponse(this.url, this.method);

  @override
  int get statusCode => 200;

  @override
  Stream<S> transform<S>(StreamTransformer<List<int>, S> streamTransformer) {
    // Cast to List<int> to match the transformer's expected input type
    return Stream.value(
      utf8.encode(_getBody()) as List<int>,
    ).transform(streamTransformer);
  }

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream.value(utf8.encode(_getBody())).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  String _getBody() {
    final path = url.path;

    // 0. User Profile (Login/Auto-login)
    // ApiService calls /users/me with token
    if (path.contains('/users/me')) {
      return jsonEncode({
        'id': 999,
        'username': 'golden_user',
        'is_superuser': false,
        'first_name': 'Golden',
        'last_name': 'User',
        'email': 'golden@example.com',
        'is_staff': false,
        'is_active': true,
        'date_joined': '2025-01-01T12:00:00Z',
        'nickname': 'Goldie',
        'pfp_url': '',
      });
    }

    // 1. User Groups
    if (path.contains('/users/groups')) {
      return jsonEncode([
        {
          'id': 1,
          'name': 'Golden Group 1',
          'color': '0xFF2196F3',
          'rank': 'ADMIN',
          'members_count': 5,
        },
        {
          'id': 2,
          'name': 'Golden Group 2',
          'color': '0xFF4CAF50',
          'rank': 'MEMBER',
          'members_count': 12,
        },
      ]);
    }

    // 2. User Projects
    if (path.contains('/users/projects')) {
      return jsonEncode([
        {
          'id': 101,
          'name': 'Math Quiz Project',
          'desc': 'Calculus basics',
          'created_at': '2025-01-01',
          'is_owner': true,
        },
        {
          'id': 102,
          'name': 'History Trivia',
          'desc': 'World War II',
          'created_at': '2025-02-01',
          'is_owner': true,
        },
      ]);
    }

    // 3. Project Details
    if (path.contains('/projects/') && method == 'GET') {
      return jsonEncode({
        'id': 101,
        'name': 'Math Quiz Project',
        'desc': 'Calculus basics',
        'blocks': [
          {
            'type': 'single',
            'id': 1001,
            'question': '1+1?',
            'timer': 30,
            'answers': [
              {'text': '2', 'is_correct': true},
              {'text': '3', 'is_correct': false},
            ],
          },
        ],
      });
    }

    // Default empty object
    return jsonEncode({});
  }
}

class MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return MockHttpClient();
  }
}

// ... (imports)

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues(
      {},
    ); // Fix: Initialize Mock SharedPreferences
    HttpOverrides.global = MockHttpOverrides();
  });

  // Common wrapper
  Widget buildTestableWidget(
    Widget child, {
    required UserProvider userProvider,
  }) {
    return MultiProvider(
      providers: [ChangeNotifierProvider.value(value: userProvider)],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        home: child,
      ),
    );
  }

  testWidgets('HomePage Golden Test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;

    // Create provider and set token to trigger fetchUser
    final up = UserProvider();
    await up.setToken('fake_token');
    // Since setToken calls fetchUser which calls HTTP (Mock), we wait a bit or pump.

    await tester.pumpWidget(
      buildTestableWidget(
        const HomePage(onLogout: _dummyLogout),
        userProvider: up,
      ),
    );

    // Allow futures to complete (API calls)
    await tester.pump(const Duration(milliseconds: 2000));
    // await tester.pumpAndSettle(); // Caused hang due to infinite animation

    await expectLater(
      find.byType(HomePage),
      matchesGoldenFile('goldens/home_page.png'),
    );

    addTearDown(tester.view.resetPhysicalSize);
  });

  testWidgets('ProjectEditorPage Golden Test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;

    // Needs user provider for token access often
    final up = UserProvider();
    await up.setToken('fake_token');

    await tester.pumpWidget(
      buildTestableWidget(
        const ProjectEditorPage(
          projectId: 101,
          initialName: 'Math Quiz Project',
          initialDesc: 'Calculus basics',
        ),
        userProvider: up,
      ),
    );

    await tester.pump(const Duration(milliseconds: 2000));
    // await tester.pumpAndSettle();

    await expectLater(
      find.byType(ProjectEditorPage),
      matchesGoldenFile('goldens/project_editor_page.png'),
    );

    addTearDown(tester.view.resetPhysicalSize);
  });
}

void _dummyLogout() {}
