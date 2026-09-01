import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultrasonic_hearing/screens/listening_screen.dart';

void main() {
  testWidgets('Listening screen renders idle controls', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ListeningScreen()),
    );

    expect(find.text('ULTRASONIC HEARING'), findsOneWidget);
    expect(find.text('STANDBY'), findsOneWidget);
    expect(find.text('Tap LISTEN to begin'), findsOneWidget);
    expect(find.text('LISTEN'), findsOneWidget);
    expect(find.text('RECORD'), findsOneWidget);
  });

  testWidgets('Amplification slider updates its readout', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ListeningScreen()),
    );

    expect(find.text('3.0x'), findsOneWidget);

    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(7.5);
    await tester.pump();

    expect(find.text('7.5x'), findsOneWidget);
  });

  testWidgets('Demo mode renders the analyzer without a microphone', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ListeningScreen()),
    );

    await tester.tap(find.text('No microphone? Run demo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.text('DEMO'), findsOneWidget);
    expect(find.text('SIGNAL STRENGTH'), findsOneWidget);
    expect(find.text('FREQUENCY ANALYSIS'), findsOneWidget);
  });

  testWidgets('Noise gate toggle logs a state change', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ListeningScreen()),
    );

    final toggle = tester.widget<Switch>(find.byType(Switch));
    expect(toggle.value, isTrue);

    toggle.onChanged!(false);
    await tester.pump();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });
}
