import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selam/main.dart';
import 'package:selam/services/mock_assistant.dart';
import 'package:selam/services/recorder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(SelamApp(
      backend: MockAssistant(latency: Duration.zero),
      recorder: RecorderService(),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows Amharic empty state with mic button', (tester) async {
    await pumpApp(tester);
    expect(find.text('ሰላም! ምን ልርዳዎት?'), findsOneWidget);
    expect(find.byKey(const Key('mic-button')), findsOneWidget);
  });

  testWidgets('typed message gets an intent-tagged reply', (tester) async {
    await pumpApp(tester);
    await tester.enterText(find.byKey(const Key('text-input')), 'ለ5 ደቂቃ ሰዓት ቆጣሪ');
    await tester.tap(find.byKey(const Key('send-button')));
    await tester.pumpAndSettle();
    expect(find.text('ለ5 ደቂቃ ሰዓት ቆጣሪ'), findsOneWidget);
    expect(find.text('የ5 ደቂቃ ሰዓት ቆጣሪ ጀምሬያለሁ።'), findsOneWidget);
    expect(find.text('ሰዓት ቆጣሪ'), findsOneWidget); // intent chip
  });

  testWidgets('English toggle switches UI chrome', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('lang-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Hi! How can I help?'), findsOneWidget);
    expect(find.text('Tap to speak'), findsOneWidget);
  });
}
