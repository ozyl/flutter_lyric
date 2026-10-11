import 'package:flutter/widgets.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_support.dart';

void main() {
  testWidgets('an unconfigured view uses Aurora and explicit tuning wins',
      (tester) async {
    final controller = LyricController(document: lines());
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller));
    await tester.pumpAndSettle();
    expect(session(tester).preset, same(LyricPresets.aurora));

    final custom = LyricPresets.moss.copyWith(
        activeTextStyle:
            LyricPresets.moss.activeTextStyle.copyWith(fontSize: 36),
        activeAnchor: const LyricAnchor.fraction(.25));
    await tester.pumpWidget(host(controller, preset: custom));
    controller.setPosition(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(session(tester).preset, same(custom));
    expect(session(tester).lineRect(5).center.dy, closeTo(60, .001));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final entry in const {
    'Moss': LyricPresets.moss,
    'Aurora': LyricPresets.aurora,
    'Cinema': LyricPresets.cinema,
  }.entries) {
    final preset = entry.value;
    testWidgets('${entry.key} wraps and follows on resize', (tester) async {
      final controller = LyricController()
        ..load(
            '[00:00.00]A long opening line that wraps on a phone\n'
            '[00:04.00]The next lyric follows the same playback clock',
            translation: '[00:00.00]An opening subtitle\n'
                '[00:04.00]The next subtitle');
      addTearDown(controller.dispose);
      for (final size in const [Size(280, 320), Size(640, 480)]) {
        await tester.pumpWidget(host(controller, preset: preset, size: size));
        controller.setPosition(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(session(tester).activeIndex, 1);
        expect(session(tester).following, isTrue);
        expect(tester.takeException(), isNull);
        if (preset.displayMode == LyricDisplayMode.activeLine) {
          expect(session(tester).layout!.metrics, hasLength(1));
          expect(session(tester).layout!.metrics.single.line,
              same(controller.activeLine));
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
