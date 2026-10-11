import 'package:flutter/widgets.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/src/rendering/lyric_layout.dart';
import 'package:flutter_lyric/src/rendering/resolved_preset.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('offscreen lines defer active, translation, mask and word paragraphs',
      () {
    final layout = LyricLayout.compute(
        lines(), ResolvedPreset(quietPreset), const Size(160, 240));
    expect(layout.metrics.every((m) => m.debugPainterCount == 2), isTrue);
    final height = layout.contentHeight(-1);
    final last = layout.metrics.last;
    expect(
        layout.contentHeight(29),
        height +
            last.activeHeight -
            last.height +
            last.activeTranslationHeight -
            last.translationHeight);
    expect(last.debugPainterCount, 4);
    expect(
        layout.metrics.take(29).every((m) => m.debugPainterCount == 2), isTrue);
    final words = last.words;
    final mask = last.activeMaskPainter;
    expect(last.words, same(words));
    expect(last.activeMaskPainter, same(mask));
    expect(last.debugPainterCount, 5);
    layout.dispose();
    expect(layout.metrics.first.debugPainterCount, 2);
    expect(layout.metrics.first.debugWordMetricsComputed, isFalse);
  });
  test('lazy paragraph and word widths match independent layout', () {
    for (final fontSize in [10.0, 24.0]) {
      const text = 'word word\nA long wrapped word';
      final preset = quietPreset.copyWith(
          padding: EdgeInsets.zero,
          activeTextStyle: TextStyle(fontFamily: 'Ahem', fontSize: fontSize),
          textAlign: TextAlign.right);
      final resolved = ResolvedPreset(preset);
      final layout = LyricLayout.compute(
          LyricDocument(lines: [
            LyricLine(start: Duration.zero, text: text, words: [
              for (final token in [
                'word',
                'word',
                'missing',
                'A long wrapped word'
              ])
                LyricWord(text: token, start: Duration.zero)
            ])
          ]),
          resolved,
          const Size(120, 240));
      addTearDown(layout.dispose);
      final normal = TextPainter(
          text: TextSpan(text: text, style: resolved.textStyle),
          textDirection: TextDirection.ltr,
          textAlign: preset.textAlign)
        ..layout(maxWidth: 120);
      final active = TextPainter(
          text: TextSpan(text: text, style: resolved.activeTextStyle),
          textDirection: TextDirection.ltr,
          textAlign: preset.textAlign)
        ..layout(maxWidth: 120);
      addTearDown(() {
        disposeNative(normal);
        disposeNative(active);
      });
      final metric = layout.metrics.single;
      expect(metric.height, normal.height);
      expect(metric.width, normal.width);
      expect(metric.activeHeight, active.height);
      expect(metric.activeWidth, active.width);
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
            .fold(0.0, (sum, box) => sum + box.right - box.left);
        expect(word.width, width(normal));
        expect(word.highlightWidth, width(active));
      }
      expect(metric.textMaskPainter.size, normal.size);
      expect(metric.activeMaskPainter.size, active.size);
    }
  });
  testWidgets(
      'color-only updates reuse metrics; typography and alignment invalidate',
      (tester) async {
    final controller = LyricController(document: lines(count: 100));
    addTearDown(controller.dispose);
    var preset = quietPreset.copyWith(
        highlight: const LyricHighlight.solid(Color(0xFFFFFFFF)));
    Future<void> show() async {
      await tester.pumpWidget(host(controller, preset: preset));
      await tester.pumpAndSettle();
    }

    await show();
    final initial = session(tester).layout!.metrics;
    final words = initial.first.words;
    final mask = initial.first.activeMaskPainter;
    preset = preset.copyWith(
        activeTextStyle:
            preset.activeTextStyle.copyWith(color: const Color(0xFF00FF00)));
    await show();
    expect(session(tester).layout!.metrics, same(initial));
    expect(initial.first.words, same(words));
    expect(initial.first.activeMaskPainter, same(mask));
    expect(initial[50].debugPainterCount, 2);
    // A paint-only difference must not hide a layout difference in a later style.
    preset = preset.copyWith(
        textStyle: preset.textStyle.copyWith(color: const Color(0xFFFF0000)),
        activeTranslationTextStyle: const TextStyle(fontSize: 40));
    await show();
    expect(session(tester).layout!.metrics, isNot(same(initial)));
    final translated = session(tester).layout!.metrics;
    preset = preset.copyWith(textAlign: TextAlign.end);
    await show();
    expect(session(tester).layout!.metrics, isNot(same(translated)));
    controller.setPosition(const Duration(milliseconds: 99500));
    await tester.pumpAndSettle();
    expect(session(tester).layout!.metrics[50].debugPainterCount, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
