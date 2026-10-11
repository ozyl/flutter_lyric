import 'benchmark_support.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/src/rendering/resolved_preset.dart';
import 'package:flutter_lyric/src/rendering/lyric_layout.dart';
import 'package:flutter_lyric/src/rendering/lyric_painter.dart';
import 'package:flutter_lyric/src/rendering/line_transition.dart';
// flutter test test/benchmarks/lyric_load_benchmark.dart --reporter expanded
// CPU layout + first picture recording in the Flutter test engine; not GPU
// raster time or a profile-mode frame measurement. Model generation is excluded.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('initial layout and first viewport of long word-timed lyrics', () {
    const size = Size(400, 600);
    final style = LyricPresets.moss.copyWith(
      textStyle:
          const TextStyle(fontSize: 12, color: Colors.white70, height: 1.2),
      activeTextStyle: const TextStyle(
          fontSize: 18,
          height: 1.2,
          color: Colors.white,
          fontWeight: FontWeight.w600),
      translationTextStyle:
          const TextStyle(inherit: false, fontSize: 12, color: Colors.white70),
      activeTranslationTextStyle: const TextStyle(color: Colors.white),
      textAlign: TextAlign.left,
      padding: const EdgeInsets.only(top: 100),
      activeAnchor:
          const LyricAnchor.pixels(100, target: LyricAnchorTarget.mainText),
      highlight: const LyricHighlight.gradient(
          LinearGradient(colors: [Color(0xFF3bb2b8), Color(0xFF42e695)]),
          tailFadeWidth: 40),
    );
    for (final count in [100, 1000, 5000]) {
      final model = LyricDocument(
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
      for (var run = 0; run < 15; run++) {
        final watch = Stopwatch()..start();
        final layout = LyricLayout.compute(model, ResolvedPreset(style), size);
        // Exercise the same geometry/highlight work as LyricView's first load.
        layout.contentHeight(0);
        final scrollY = layout.lineOffsetY(0, 0, style.activeAnchor);
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
        ).paint(Canvas(recorder), size);
        disposeNative(recorder.endRecording());
        watch.stop();
        if (run >= 10) samples.add(watch.elapsedMicroseconds / 1000);
        layout.dispose();
      }
      samples.sort();
      // ignore: avoid_print
      print('$count lines: ${samples[2].toStringAsFixed(2)} ms '
          '(median of 5, layout + first picture)');
    }
  });
}
