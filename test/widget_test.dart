import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Test Lottie animation asset loading and parsing', (WidgetTester tester) async {
    FlutterErrorDetails? caughtError;

    FlutterError.onError = (details) {
      caughtError = details;
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Lottie.asset(
            'assets/animations/not_found.json',
            width: 200,
            height: 200,
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(Lottie), findsOneWidget);
    expect(caughtError, isNull);
  });

  testWidgets('Test all Lottie animations load without errors', (WidgetTester tester) async {
    final animations = [
      'assets/animations/laughing_cat.json',
      'assets/animations/sad_no_result.json',
      'assets/animations/not_found.json',
      'assets/animations/no_results.json',
    ];

    for (final anim in animations) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Lottie.asset(anim),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(Lottie), findsOneWidget);
    }
  });
}
