import 'package:flutter/material.dart';
import 'package:flutter_lyric/core/lyric_model.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/render/lyric_layout.dart';
import 'package:flutter_lyric/render/lyric_painter.dart';
import 'package:flutter_test/flutter_test.dart';

Finder get _paintFinder => find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter is LyricPainter);

LyricLayout _layout() => LyricLayout.compute(
      LyricModel(
          lines: List.generate(30, (i) {
        const text = 'Repeated words repeated words wrapping onto another row';
        return LyricLine(
          start: Duration(seconds: i),
          text: text,
          translation: i.isEven ? 'A translated lyric' : null,
          words: [
            LyricWord(text: text, start: Duration(seconds: i)),
          ],
        );
      })),
      LyricStyles.default2,
      const Size(160, 240),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('geometry measures only the requested active line; disposal stays lazy',
      () {
    final layout = _layout();
    addTearDown(layout.dispose);
    expect(layout.toString(), contains('LineMetrics'));
    expect(layout.metrics.every((m) => m.debugPainterCount == 2), isTrue);
    final normalHeight = layout.contentHeight(-1);
    final top = layout.lineTop(29, -1);
    expect(layout.lineAtOffset(top + 1, -1), 29);
    expect(layout.metrics.every((m) => m.debugPainterCount == 2), isTrue);

    final active = layout.metrics[29];
    expect(layout.contentHeight(29),
        normalHeight + active.activeHeight - active.height);
    expect(active.debugPainterCount, 3);
    expect(active.debugWordMetricsComputed, isFalse);
    expect(
        layout.metrics.take(29).every((m) => m.debugPainterCount == 2), isTrue);
    final words = active.words;
    expect(active.words, same(words));
    final mask = active.activeMaskPainter;
    expect(active.activeMaskPainter, same(mask));
    expect(active.debugPainterCount, 4);
    layout.dispose();
    expect(mask.debugDisposed, isTrue);
    expect(active.textPainter.debugDisposed, isTrue);
    expect(active.debugPainterCount, 4);
    expect(layout.metrics.first.debugPainterCount, 2);
    expect(layout.metrics.first.debugWordMetricsComputed, isFalse);
  });

  test('deferred metrics match independently laid out wrapped text and words',
      () {
    for (final activeSize in [10.0, 24.0]) {
      final style = LyricStyles.default1.copyWith(
        textStyle: const TextStyle(fontFamily: 'Ahem', fontSize: 16),
        activeStyle: TextStyle(fontFamily: 'Ahem', fontSize: activeSize),
        textAlign: TextAlign.right,
      );
      const text = 'word word\nA long wrapped word';
      final line = LyricLine(start: Duration.zero, text: text, words: [
        for (final token in ['word', 'word', 'missing', 'A long wrapped word'])
          LyricWord(text: token, start: Duration.zero),
      ]);
      final layout = LyricLayout.compute(
          LyricModel(lines: [line]), style, const Size(120, 240));
      addTearDown(layout.dispose);
      final normal = TextPainter(
        text: TextSpan(text: text, style: style.textStyle),
        textDirection: TextDirection.ltr,
        textAlign: style.lineTextAlign,
      )..layout(maxWidth: 120);
      final active = TextPainter(
        text: TextSpan(text: text, style: style.activeStyle),
        textDirection: TextDirection.ltr,
        textAlign: style.lineTextAlign,
      )..layout(maxWidth: 120);
      addTearDown(normal.dispose);
      addTearDown(active.dispose);
      final metric = layout.metrics.single;
      expect(metric.height, normal.height);
      expect(metric.width, normal.width);
      expect(metric.activeHeight, active.height);
      expect(metric.activeWidth, active.width);
      expect(metric.metrics.map((row) => row.width),
          normal.computeLineMetrics().map((row) => row.width));
      expect(metric.activeMetrics.map((row) => row.width),
          active.computeLineMetrics().map((row) => row.width));
      var offset = 0;
      for (final word in metric.words!) {
        final start = text.indexOf(word.word.text, offset);
        if (start < 0) {
          expect(word.width, 0);
          expect(word.highlightWidth, 0);
          continue;
        }
        offset = start + word.word.text.length;
        final selection =
            TextSelection(baseOffset: start, extentOffset: offset);
        double width(TextPainter painter) => painter
            .getBoxesForSelection(selection)
            .fold(0.0, (width, box) => width + box.right - box.left);
        expect(word.width, width(normal));
        expect(word.highlightWidth, width(active));
      }
      expect(metric.textMaskPainter.size, normal.size);
      expect(metric.activeMaskPainter.size, active.size);
    }
  });

  test(
      'paint and font changes preserve laziness and invalidate cached geometry',
      () {
    final layout = _layout();
    addTearDown(layout.dispose);
    final first = layout.metrics.first;
    final oldWords = first.words;
    final mask = first.activeMaskPainter;
    final oldTop = layout.lineTop(1, -1);
    for (final metric in layout.metrics) {
      metric.updatePaintStyles(
        textStyle: layout.style.textStyle.copyWith(color: Colors.red),
        activeStyle: layout.style.activeStyle.copyWith(color: Colors.blue),
        translationStyle:
            layout.style.translationStyle.copyWith(color: Colors.green),
      );
    }
    expect(first.words, same(oldWords));
    expect(first.activeMaskPainter, same(mask));
    expect(
        layout.metrics.skip(1).every((m) => m.debugPainterCount == 2), isTrue);
    expect(layout.metrics[1].translationTextPainter.text, isNull);
    expect(
        layout.metrics.last.activeTextPainter.text!.style!.color, Colors.blue);

    // Simulate changed font metrics, then take the system-font update path.
    first.textPainter.text = TextSpan(
        text: first.line.text,
        style: layout.style.textStyle.copyWith(fontSize: 40));
    final updated = LyricLayout.updatePainters(layout);
    expect(updated.lineTop(1, -1), greaterThan(oldTop));
    expect(first.debugWordMetricsComputed, isFalse);
    expect(first.words, isNot(same(oldWords)));
    expect(first.activeMaskPainter, same(mask));
    expect(layout.metrics[1].debugPainterCount, 2);
    expect(layout.metrics[1].translationHeight, 0);
    expect(layout.metrics[1].debugWordMetricsComputed, isFalse);
  });

  testWidgets('initial paint, restyle and distant seeks keep other lines lazy',
      (tester) async {
    final controller = LyricController()
      ..loadLyric(List.generate(
              100, (i) => '[${i * 1000},1000]Line $i(${i * 1000},1000)')
          .join('\n'));
    addTearDown(controller.dispose);
    var style = LyricStyles.default2.copyWith(enableSwitchAnimation: false);
    Future<void> show() async {
      await tester.pumpWidget(
          MaterialApp(home: LyricView(controller: controller, style: style)));
      await tester.pumpAndSettle();
    }

    await show();
    LyricPainter painter() =>
        tester.widget<CustomPaint>(_paintFinder).painter! as LyricPainter;
    final initial = painter().layout;
    expect(initial.metrics[50].debugPainterCount, 2);
    expect(initial.metrics[50].debugWordMetricsComputed, isFalse);
    style = style.copyWith(
        activeStyle: style.activeStyle.copyWith(color: Colors.pink));
    await show();
    expect(painter().layout.metrics, same(initial.metrics));
    expect(initial.metrics[50].debugPainterCount, 2);
    controller.setProgress(const Duration(milliseconds: 99500));
    await tester.pumpAndSettle();
    final last = painter().layout.metrics.last;
    expect(last.activeTextPainter.text!.style!.color, Colors.pink);
    expect(last.debugWordMetricsComputed, isTrue);
    expect(initial.metrics[50].debugPainterCount, 2);
    expect(initial.metrics[50].debugWordMetricsComputed, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(last.textPainter.debugDisposed, isTrue);
    expect(initial.metrics[50].debugPainterCount, 2);
    expect(tester.takeException(), isNull);
  });
}
