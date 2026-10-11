// Run with: flutter test test/benchmarks/lyric_scroll_benchmark.dart --reporter expanded
// Add --platform chrome for a browser run. Kept outside the *_test.dart suite.
// Measures CPU picture recording only, not GPU rasterization or browser FPS.
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
  test('record a scrolling viewport near the end of long lyrics', () {
    const size = Size(400, 600);
    final style = LyricStyles.default1.copyWith(
      enableSwitchAnimation: false,
      activeHighlightColor: null,
    );
    for (final count in [100, 1000, 5000]) {
      final layout = LyricLayout.compute(
        LyricModel(
            lines: List.generate(
                count,
                (i) => LyricLine(
                      start: Duration(seconds: i),
                      text: 'A lyric line $i',
                      translation: 'Translation $i',
                    ))),
        style,
        size,
      );
      final active = count - 10;
      final scrollY = layout.lineOffsetY(
        active,
        active,
        300,
        MainAxisAlignment.center,
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
          onAnchorIndexChange: (_) {},
          onShowLineRectsChange: (_) {},
          style: style,
        ).paint(Canvas(recorder), size);
        recorder.endRecording().dispose();
      }

      for (var i = 0; i < 50; i++) {
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
