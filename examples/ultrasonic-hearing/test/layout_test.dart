import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultrasonic_hearing/screens/listening_screen.dart';

/// Viewport sizes that previously produced RenderFlex overflow.
const _viewports = <Size>[
  Size(320, 380),
  Size(320, 568),
  Size(360, 480),
  Size(375, 667),
  Size(430, 860),
  Size(800, 400),
];

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    const MaterialApp(home: ListeningScreen()),
  );
}

void main() {
  for (final size in _viewports) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('idle layout has no overflow at $label', (tester) async {
      await _pumpAt(tester, size);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('active layout has no overflow at $label', (tester) async {
      await _pumpAt(tester, size);

      await tester.tap(
        find.text('No microphone? Run demo'),
        warnIfMissed: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(tester.takeException(), isNull);
    });

    testWidgets('recording layout has no overflow at $label', (tester) async {
      await _pumpAt(tester, size);

      await tester.tap(
        find.text('No microphone? Run demo'),
        warnIfMissed: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      await tester.tap(find.text('RECORD'), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(tester.takeException(), isNull);
    });
  }
}
