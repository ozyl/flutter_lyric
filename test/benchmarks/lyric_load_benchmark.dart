// flutter test test/benchmarks/lyric_load_benchmark.dart --reporter expanded
// CPU layout + first picture recording in the Flutter test engine; not GPU
// raster time or a profile-mode frame measurement. Model generation is excluded.
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
  test('initial layout and first viewport of long word-timed lyrics', () {
    const size = Size(400, 600);
    final style = LyricStyles.default2;
    for (final count in [100, 1000, 5000]) {
      final model = LyricModel(
        lines: List.generate(count, (i) {
          final tokens = [
            'A ',
            'lyric ',
            'with ',
            'several ',
            'timed ',
            'words $i'
          ];
          return LyricLine(
            start: Duration(seconds: i),
            text: tokens.join(),
            translation: 'Translation for lyric $i',
            words: List.generate(
                tokens.length,
                (j) => LyricWord(
                      text: tokens[j],
                      start: Duration(milliseconds: i * 1000 + j * 100),
                      end: Duration(milliseconds: i * 1000 + (j + 1) * 100),
                    )),
          );
        }),
      );
      final samples = <double>[];
      for (var run = 0; run < 7; run++) {
        final watch = Stopwatch()..start();
        final layout = LyricLayout.compute(model, style, size);
        // Exercise the same geometry/highlight work as LyricView's first load.
        layout.contentHeight(0);
        final scrollY = layout.lineOffsetY(
            0, 0, layout.activeAnchorPosition, style.activeAlignment);
        final width = layout.metrics.first.words!.first.highlightWidth / 2;
        final recorder = ui.PictureRecorder();
        LyricPainter(
          layout: layout,
          playIndex: 0,
          scrollY: scrollY,
          activeHighlightWidth: width,
          switchState: LyricLineSwitchState(
            enterAnimationValue: 1,
            exitAnimationValue: 1,
            enterIndex: -1,
            exitIndex: -1,
          ),
          isSelecting: false,
          onAnchorIndexChange: (_) {},
          onShowLineRectsChange: (_) {},
          style: style,
        ).paint(Canvas(recorder), size);
        recorder.endRecording().dispose();
        watch.stop();
        if (run >= 2) samples.add(watch.elapsedMicroseconds / 1000);
        layout.dispose();
      }
      samples.sort();
      // ignore: avoid_print
      print('$count lines: ${samples[2].toStringAsFixed(2)} ms '
          '(median of 5, layout + first picture)');
    }
  });
}
