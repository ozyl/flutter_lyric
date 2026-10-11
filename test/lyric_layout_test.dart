import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_lyric/core/lyric_model.dart';
import 'package:flutter_lyric/core/lyric_styles.dart';
import 'package:flutter_lyric/render/lyric_layout.dart';
import 'package:flutter_lyric/render/lyric_painter.dart';
import 'package:flutter_lyric/widgets/mixins/lyric_line_switch_mixin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final activeFontSize in [10.0, 24.0]) {
    test(
        'indexed layout matches linear geometry with active size $activeFontSize',
        () {
      final style = LyricStyles.default1.copyWith(
        activeStyle: TextStyle(
            fontFamily: 'Ahem', fontSize: activeFontSize, color: Colors.white),
        textStyle: const TextStyle(
            fontFamily: 'Ahem', fontSize: 16, color: Colors.grey),
      );
      final layout = LyricLayout.compute(
        LyricModel(
            lines: List.generate(
                24,
                (i) => LyricLine(
                      start: Duration(seconds: i),
                      text: i.isEven
                          ? 'Short'
                          : 'A long lyric that wraps onto multiple rows',
                      translation:
                          i % 3 == 0 ? 'Translation\nSecond row' : null,
                    ))),
        style,
        const Size(160, 240),
      );
      addTearDown(layout.dispose);
      for (final active in [-1, 0, 11, 23, 24]) {
        var top = 0.0;
        final tops = <double>[];
        final bottoms = <double>[];
        for (var i = 0; i < layout.metrics.length; i++) {
          tops.add(top);
          expect(layout.lineTop(i, active), closeTo(top, 0.00001));
          final height = layout.getLineHeight(i == active, i);
          bottoms.add(top + height);
          for (final alignment in [
            MainAxisAlignment.start,
            MainAxisAlignment.center,
            MainAxisAlignment.end
          ]) {
            final anchor =
                top + layout.anchorOffsetY(i, i == active, height, alignment);
            expect(
                layout.lineOffsetY(i, active, 120, alignment),
                closeTo(
                    120 < anchor + style.contentPadding.top
                        ? anchor - 120
                        : -style.contentPadding.top,
                    0.00001));
          }
          top += height + style.lineGap;
        }
        expect(
            layout.contentHeight(active),
            closeTo(
                top - style.lineGap + style.contentPadding.vertical, 0.00001));
        for (final extension in [0.0, style.lineGap / 2]) {
          for (final offset in [
            -100.0,
            ...bottoms.expand((bottom) => [
                  bottom + extension - 0.01,
                  bottom + extension,
                  bottom + extension + 0.01
                ]),
            top + 100
          ]) {
            final expected =
                bottoms.indexWhere((bottom) => bottom + extension >= offset);
            expect(
                layout.lineAtOffset(offset, active, bottomExtension: extension),
                expected < 0 ? bottoms.length : expected);
          }
        }

        for (final scroll in [-200.0, tops[12] + 2, tops.last, top + 100]) {
          Map<int, Rect>? visible;
          var selected = -1;
          final recorder = ui.PictureRecorder();
          LyricPainter(
            layout: layout,
            playIndex: active,
            scrollY: scroll,
            activeHighlightWidth: 0,
            switchState: LyricLineSwitchState(
                enterAnimationValue: 1,
                exitAnimationValue: 1,
                enterIndex: -1,
                exitIndex: -1),
            isSelecting: true,
            style: style,
            onAnchorIndexChange: (index) => selected = index,
            onShowLineRectsChange: (rects) => visible = rects,
          ).paint(Canvas(recorder), layout.viewSize);
          recorder.endRecording().dispose();
          final expectedIndices = <int>[];
          for (var i = 0; i < tops.length; i++) {
            if (bottoms[i] > scroll && tops[i] < scroll + 240) {
              expectedIndices.add(i);
            }
          }
          expect(visible!.keys, expectedIndices);
          for (final i in expectedIndices) {
            expect(visible![i]!.top, closeTo(tops[i] - scroll, 0.00001));
            expect(visible![i]!.height, closeTo(bottoms[i] - tops[i], 0.00001));
          }
          expect(
              selected,
              bottoms.indexWhere((bottom) =>
                  bottom + style.lineGap / 2 >=
                  scroll + layout.selectionAnchorPosition));
        }
      }
    });
  }

  test('empty layout and changed spacing keep a valid index', () {
    final empty = LyricLayout.compute(
        LyricModel(lines: []), LyricStyles.default1, const Size(200, 200));
    addTearDown(empty.dispose);
    expect(empty.lineAtOffset(100, 0), 0);
    expect(empty.lineTop(0, 0), 0);
    expect(empty.contentHeight(0), empty.style.contentPadding.vertical);
    final layout = LyricLayout.compute(
        LyricModel(lines: [
          LyricLine(start: Duration.zero, text: 'A'),
          LyricLine(start: const Duration(seconds: 1), text: 'B'),
        ]),
        LyricStyles.default1,
        const Size(200, 200));
    addTearDown(layout.dispose);
    final oldTop = layout.lineTop(1, 0);
    final changed = layout.copyWith(layout.style
        .copyWith(lineGap: layout.style.lineGap + 10, anchorPosition: 0.25));
    expect(changed.lineTop(1, 0), oldTop + 10);
    expect(changed.selectionAnchorPosition, 50);
  });
}
