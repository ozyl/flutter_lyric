import 'package:flutter/material.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric_example/show_lyric.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('example can switch and customize presets', (tester) async {
    final controller = LyricController()
      ..load('[00:00.00]First\n[00:01.00]Second');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShowLyric(
            controller: controller,
            initialPreset: LyricPresets.centered,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LyricView), findsOneWidget);
    await tester.tap(find.byTooltip('Customize preset'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Single line'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<LyricView>(find.byType(LyricView)).preset!.displayMode,
      LyricDisplayMode.activeLine,
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(controller.position, Duration.zero);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
