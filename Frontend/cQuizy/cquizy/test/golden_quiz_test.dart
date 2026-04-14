/*
 * Mit tesztel: A TestTakingPage (Kvíz kitöltése) vizuális megjelenését (Golden Test).
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
import 'package:cquizy/test_taking_page.dart';
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
    return Stream.value(
      utf8.encode('[]') as List<int>,
    ).transform(streamTransformer);
  }

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream.value(utf8.encode('[]')).listen(
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

  testWidgets('TestTakingPage Golden Test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('overflow') ||
          details.exceptionAsString().contains('Overflow')) {
        return;
      }
      FlutterError.presentError(details);
    };

    final userProvider = UserProvider();
    await userProvider.setToken('dummy_token');

    final Map<String, dynamic> fakeQuiz = {
      'id': 100,
      'project_name': 'Golden Kvíz Teszt',
      'project_desc': 'Ez egy példa kvíz',
      'blocks': [
        {
          'id': 1,
          'type': 'single',
          'question': 'Mi Pitypang igazi neve?',
          'answers': [
            {'text': 'Kutya', 'is_correct': false},
            {'text': 'Macska', 'is_correct': false},
            {'text': 'Virág', 'is_correct': true},
          ],
        },
      ],
    };

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider.value(value: userProvider)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          home: Scaffold(
            body: TestTakingPage(quiz: fakeQuiz, groupName: 'Golden Csoport'),
          ),
        ),
      ),
    );

    // Várjuk meg, amíg leutaznak az animációk
    await tester.pump(const Duration(milliseconds: 1000));

    // A teszt kép készítése
    await expectLater(
      find.byType(TestTakingPage),
      matchesGoldenFile('goldens/quiz_page_golden.png'),
    );
  });
}
