import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class WidgetTestHelper {
  static Future<void> pumpWidgetWithProviders(
    WidgetTester tester,
    Widget widget,
    List<Provider> providers,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: providers,
          child: widget,
        ),
      ),
    );
  }

  static Future<void> pumpDialog(
    WidgetTester tester,
    Widget dialog,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => dialog,
              ),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();
  }

  static Finder findByText(String text) => find.text(text);
  static Finder findByType<T>() => find.byType(T);
  static Finder findByKey(Key key) => find.byKey(key);
}