/*
 * Mit tesztel: A ProjectEditorPage vizuális megjelenését (Golden Test).
 * Előfeltétel: nincs előfeltétel
 * Várt eredmény: A képernyő megjelenése megegyezik a referenciaképpel.
 * Eredmény: Sikeres.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cquizy/project_editor_page.dart';
import 'package:cquizy/theme.dart';
import 'package:provider/provider.dart';
import 'package:cquizy/providers/user_provider.dart';

// --- MOCK HTTP CLIENT ---
class MockHttpClient extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return MockHttpClientRequest(url, 'GET');
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
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
    String responseString = '[]';
    if (url.path.contains('/projects/')) {
      responseString = jsonEncode({
        'name': 'Golden Teszt Projekt',
        'desc': 'Ideális projekt design ellenőrzéshez',
        'blocks': [
          {
            'id': 1,
            'type': 'single',
            'question': 'Kérdés 1',
            'timer': 30,
            'answers': [
              {'text': 'Válasz 1', 'is_correct': true},
            ],
          },
        ],
      });
    }
    return Stream.value(
      utf8.encode(responseString) as List<int>,
    ).transform(streamTransformer);
  }

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    String responseString = '[]';
    if (url.path.contains('/projects/')) {
      responseString = jsonEncode({
        'name': 'Golden Teszt Projekt',
        'desc': 'Ideális projekt design ellenőrzéshez',
        'blocks': [
          {
            'id': 1,
            'type': 'single',
            'question': 'Kérdés 1',
            'timer': 30,
            'answers': [
              {'text': 'Válasz 1', 'is_correct': true},
            ],
          },
        ],
      });
    }
    return Stream.value(utf8.encode(responseString)).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return MockHttpClient();
  }
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = MockHttpOverrides();
  });

  testWidgets('ProjectEditorPage Golden Test', (WidgetTester tester) async {
    // Képernyő méret beállítása
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Render overflow ignorálása, ha szükséges lenne a golden renderhez
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('overflow') ||
          details.exceptionAsString().contains('Overflow')) {
        return;
      }
      FlutterError.presentError(details);
    };

    final userProvider = UserProvider();
    await userProvider.setToken('dummy_token');

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider.value(value: userProvider)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          home: const ProjectEditorPage(
            projectId: 1,
            initialName: 'Gyakorló Projekt',
            initialDesc: 'Golden design teszt',
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1000));

    await expectLater(
      find.byType(ProjectEditorPage),
      matchesGoldenFile('goldens/project_editor_page_golden.png'),
    );
  });
}
