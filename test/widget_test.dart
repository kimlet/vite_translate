import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vibe_translate/app.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: VibeTranslateApp()),
    );

    // Verify the app title appears (onboarding screen)
    expect(find.text('vibeTranslate'), findsOneWidget);
  });
}
