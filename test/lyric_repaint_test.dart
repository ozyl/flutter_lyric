// Inspect listener teardown to catch retained view state after unmounting.
// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/material.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/render/lyric_painter.dart';
import 'package:flutter_test/flutter_test.dart';

Finder get _paintFinder => find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter is LyricPainter);

void main() {
  for (final animate in [false, true]) {
    testWidgets(
        'progress, seeks and drag repaint without rebuilding (animation: $animate)',
        (tester) async {
      final controller = LyricController()
        ..loadLyric(List.generate(
                100, (i) => '[${i * 1000},1000]Line $i(${i * 1000},1000)')
            .join('\n'));
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
          home: LyricView(
        controller: controller,
        style: LyricStyles.default2.copyWith(enableSwitchAnimation: animate),
      )));
      await tester.pumpAndSettle();
      final widget = tester.widget<CustomPaint>(_paintFinder);
      final painter = widget.painter! as LyricPainter;
      for (final progress in [500, 85000, 6000, 99000, 8000]) {
        controller.setProgress(Duration(milliseconds: progress));
        await tester.pumpAndSettle();
        expect(tester.widget<CustomPaint>(_paintFinder), same(widget));
        expect(painter.playIndex, progress ~/ 1000);
      }
      final before = painter.scrollY;
      await tester.drag(find.byType(LyricView), const Offset(0, -100));
      await tester.pump(const Duration(milliseconds: 16));
      expect(painter.scrollY, greaterThan(before));
      expect(controller.isSelectingNotifier.value, isTrue);
      expect(tester.widget<CustomPaint>(_paintFinder), same(widget));
      controller.stopSelection();
      await tester.pumpAndSettle();
      expect(tester.widget<CustomPaint>(_paintFinder), same(widget));
      expect(controller.isSelectingNotifier.value, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(controller.activeIndexNotifiter.hasListeners, isFalse);
      expect(controller.selectedIndexNotifier.hasListeners, isFalse);
      expect(controller.progressNotifier.hasListeners, isFalse);
      expect(painter.layout.metrics.first.textPainter.debugDisposed, isTrue);
      // A retained controller must not keep the old view alive or call it.
      controller.setProgress(const Duration(seconds: 10));
      controller.loadLyric('[00:00.00]New song');
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('replacing lyrics disposes old paragraphs', (tester) async {
    final controller = LyricController()..loadLyric('[00:00.00]First');
    addTearDown(controller.dispose);
    await tester
        .pumpWidget(MaterialApp(home: LyricView(controller: controller)));
    await tester.pumpAndSettle();
    final old =
        (tester.widget<CustomPaint>(_paintFinder).painter! as LyricPainter)
            .layout;
    controller.loadLyric('[00:00.00]Second');
    await tester.pumpAndSettle();
    expect(old.metrics.first.textPainter.debugDisposed, isTrue);
    final current =
        (tester.widget<CustomPaint>(_paintFinder).painter! as LyricPainter)
            .layout;
    expect(current.metrics.single.line.text, 'Second');
    expect(current.metrics.first.textPainter.debugDisposed, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
