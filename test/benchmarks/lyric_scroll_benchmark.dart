import 'benchmark_support.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/src/rendering/resolved_preset.dart';
import 'package:flutter_lyric/src/rendering/lyric_layout.dart';
import 'package:flutter_lyric/src/rendering/lyric_painter.dart';
import 'package:flutter_lyric/src/rendering/line_transition.dart';
// Run with: flutter test test/benchmarks/lyric_scroll_benchmark.dart --reporter expanded
// Add --platform chrome for a browser run. Kept outside the *_test.dart suite.
// Measures CPU picture recording only, not GPU rasterization or browser FPS.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('record a scrolling viewport near the end of long lyrics', () {
    const size = Size(400, 600);
    final style = LyricPresets.centered.copyWith(
      textStyle: const TextStyle(fontSize: 14, color: Colors.white70),
      activeTextStyle: const TextStyle(fontSize: 16, color: Colors.white),
      translationTextStyle:
          const TextStyle(fontSize: 12, color: Colors.white70),
      activeTranslationTextStyle: const TextStyle(color: Colors.white70),
      lineSpacing: 26,
      translationSpacing: 10,
      padding: EdgeInsets.zero,
      lineTransition: const LyricLineTransition.none(),
      highlight: const LyricHighlight.none(),
    );
    for (final count in [100, 1000, 5000]) {
      final layout = LyricLayout.compute(
        LyricDocument(
            lines: List.generate(
                count,
                (i) => LyricLine(
                      start: Duration(seconds: i),
                      text: 'A lyric line $i',
                      translation: 'Translation $i',
                    ))),
        ResolvedPreset(style),
        size,
      );
      final active = count - 10;
      final scrollY = layout.lineOffsetY(
        active,
        active,
        const LyricAnchor.pixels(300),
      );
      void record(int frame) {
        final recorder = ui.PictureRecorder();
        LyricPainter(
          layout: layout,
          playIndex: active,
          scrollY: scrollY + frame % 30,
          activeHighlightWidth: 0,
          switchState: LyricLineSwitchState(
            enterAnimationValue: 1,
            exitAnimationValue: 1,
            enterIndex: -1,
            exitIndex: -1,
          ),
          isSelecting: false,
        ).paint(Canvas(recorder), size);
        disposeNative(recorder.endRecording());
      }

      for (var i = 0; i < 300; i++) {
        record(i);
      }
      final samples = <double>[];
      for (var run = 0; run < 5; run++) {
        final watch = Stopwatch()..start();
        for (var i = 0; i < 300; i++) {
          record(i);
        }
        watch.stop();
        samples.add(watch.elapsedMicroseconds / 300);
      }
      samples.sort();
      // ignore: avoid_print
      print(
          '$count lines: ${samples[2].toStringAsFixed(1)} us/frame (median of 5 x 300)');
      layout.dispose();
    }
  });
}
