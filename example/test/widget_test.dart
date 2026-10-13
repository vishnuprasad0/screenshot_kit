import 'package:flutter_test/flutter_test.dart';

import 'package:screenshot_kit_example/main.dart';

void main() {
  testWidgets('home lists the five demos', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    expect(find.text('screenshot_kit'), findsOneWidget);
    for (final title in [
      'Widget capture',
      'Off-screen widget',
      'Long list',
      'Long widget',
      'Screen with WebView',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
  });

  testWidgets('opens the widget capture demo', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    await tester.tap(find.text('Widget capture'));
    await tester.pumpAndSettle();

    expect(find.text('Rocket Pro'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Capture'), 200);
    expect(find.text('Capture'), findsOneWidget);
  });
}
