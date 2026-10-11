import 'package:flutter/widgets.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/src/rendering/lyric_layout.dart';
import 'package:flutter_lyric/src/rendering/resolved_preset.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final activeSize in [10.0, 24.0]) {
    test('indexed layout equals linear geometry, active size $activeSize', () {
      final preset = quietPreset.copyWith(
          activeTextStyle: TextStyle(fontFamily: 'Ahem', fontSize: activeSize),
          activeTranslationTextStyle: TextStyle(fontSize: activeSize + 2));
      final layout = LyricLayout.compute(
          LyricDocument(
              lines: List.generate(
                  24,
                  (i) => LyricLine(
                      start: Duration(seconds: i),
                      text: i.isEven
                          ? 'Short'
                          : 'A long lyric that wraps onto multiple rows',
                      translation:
                          i % 3 == 0 ? 'Translation\nSecond row' : null))),
          ResolvedPreset(preset),
          const Size(160, 240));
      addTearDown(layout.dispose);
      for (final active in [-1, 0, 11, 23, 24]) {
        var top = 0.0;
        final bottoms = <double>[];
        for (var i = 0; i < layout.metrics.length; i++) {
          final metric = layout.metrics[i];
          final main = i == active ? metric.activeHeight : metric.height;
          final translation = i == active
              ? metric.activeTranslationHeight
              : metric.translationHeight;
          final height = main +
              (translation == 0 ? 0 : translation + preset.translationSpacing);
          expect(layout.lineTop(i, active), closeTo(top, .00001));
          expect(layout.getLineHeight(i == active, i), height);
          for (final target in LyricAnchorTarget.values) {
            final anchor =
                translation == 0 || target == LyricAnchorTarget.mainText
                    ? main / 2
                    : target == LyricAnchorTarget.translationText
                        ? main + preset.translationSpacing + translation / 2
                        : height / 2;
            expect(
                layout.lineOffsetY(
                    i, active, LyricAnchor.pixels(120, target: target)),
                closeTo(top + anchor - 120, .00001));
          }
          bottoms.add(top + height);
          top += height + preset.lineSpacing;
        }
        expect(layout.contentHeight(active),
            closeTo(top - preset.lineSpacing, .00001));
        for (final extension in [0.0, preset.lineSpacing / 2]) {
          for (final offset in [
            -100.0,
            ...bottoms.expand((b) =>
                [b + extension - .01, b + extension, b + extension + .01]),
            top + 100
          ]) {
            final expected = bottoms.indexWhere((b) => b + extension >= offset);
            expect(
                layout.lineAtOffset(offset, active, bottomExtension: extension),
                expected < 0 ? bottoms.length : expected);
          }
        }
      }
    });
  }
  test('spacing-only updates reuse paragraphs and rebuild prefixes', () {
    final layout = LyricLayout.compute(
        lines(), ResolvedPreset(quietPreset), const Size(200, 200));
    addTearDown(layout.dispose);
    final top = layout.lineTop(20, 0);
    final changed = layout.restyle(
        ResolvedPreset(quietPreset.copyWith(lineSpacing: 30)), layout.viewSize);
    expect(changed.metrics, same(layout.metrics));
    expect(changed.lineTop(20, 0), closeTo(top + 200, .0001));
    final empty = LyricLayout.compute(LyricDocument(lines: []),
        ResolvedPreset(quietPreset), const Size(200, 200));
    expect(empty.contentHeight(-1), 0);
    expect(empty.lineAtOffset(100, -1), 0);
    empty.dispose();
  });
}
