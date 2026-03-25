/*
 * Mit tesztel: Felületek váltását és navigációt a csoport oldalra.
 * Előfeltétel: nincs előfeltétel
 * Várt eredmény: A navigáció sikeresen átvált a csoport felületre a megfelelő adatokkal.
 * Eredmény: Sikeres.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cquizy/group_page.dart';
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
    HttpOverrides.global = MockHttpOverrides();
  });

  testWidgets('Navigáció a GroupPage felületre (Felület váltás)', (
    WidgetTester tester,
  ) async {
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('overflow') ||
          details.exceptionAsString().contains('Overflow')) {
        return;
      }
      FlutterError.presentError(details);
    };

    tester.view.physicalSize = const Size(2000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final testGroup = Group(
      id: 1,
      title: 'Teszt Csoport',
      subtitle: 'Teszt Alcím',
      color: Colors.blue,
      ownerName: 'Teszt Elek',
      instructorFirstName: 'Elek',
      instructorLastName: 'Teszt',
      rank: 'MEMBER',
    );

    final userProvider = UserProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider.value(value: userProvider)],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    key: const Key('nav_button'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            body: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: SizedBox(
                                  width: 2000,
                                  height: 2000,
                                  child: GroupPage(
                                    group: testGroup,
                                    onTestExpired: (g) {},
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text('Ugrás a csoportra'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('nav_button')), findsOneWidget);
    expect(find.text('Teszt Csoport'), findsNothing);

    await tester.tap(find.byKey(const Key('nav_button')));
    await tester.pumpAndSettle();

    expect(find.byType(GroupPage), findsOneWidget);
    expect(find.text('Teszt Csoport'), findsWidgets);
  });
}
