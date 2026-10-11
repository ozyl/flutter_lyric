import 'package:flutter/widgets.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/src/rendering/lyric_viewport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_support.dart';

void main() {
  for (final animate in [false, true]) {
    testWidgets('progress and distant seeks retain viewport widget ($animate)',
        (tester) async {
      final controller = LyricController(document: lines(count: 100));
      addTearDown(controller.dispose);
      await tester.pumpWidget(host(controller,
          preset: quietPreset.copyWith(
              highlight: const LyricHighlight.solid(Color(0xFFFFFFFF)),
              lineTransition: animate
                  ? const LyricLineTransition()
                  : const LyricLineTransition.none())));
      await tester.pumpAndSettle();
      final viewport = tester.widget(find.byType(LyricViewport));
      final state = session(tester);
      final metrics = state.layout!.metrics;
      for (final milliseconds in [500, 85000, 6000, 99000, 8000]) {
        controller.setPosition(Duration(milliseconds: milliseconds));
        await tester.pumpAndSettle();
        expect(tester.widget(find.byType(LyricViewport)), same(viewport));
        expect(state.activeIndex, milliseconds ~/ 1000);
        expect(state.layout!.metrics, same(metrics));
      }
      final before = state.scrollY;
      await tester.drag(find.byType(LyricView), const Offset(0, -100));
      await tester.pump(const Duration(milliseconds: 16));
      expect(state.scrollY, greaterThan(before));
      expect(state.following, isFalse);
      await controller.resumeFollow(animate: false);
      await tester.pumpAndSettle();
      expect(state.following, isTrue);
      expect(tester.widget(find.byType(LyricViewport)), same(viewport));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(controller.hasClients, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
      controller.load('[00:00.00]New song');
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
