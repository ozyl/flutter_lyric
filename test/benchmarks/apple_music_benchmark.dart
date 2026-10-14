import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import '../apple_music_test_support.dart';
import '../test_support.dart' as support;

// CPU picture recording only; this does not measure GPU blur/rasterization.
// flutter test test/benchmarks/apple_music_benchmark.dart --reporter expanded
void main() {
  for (final count in [100, 1000, 5000]) {
    testWidgets('$count lines keep animated painting bounded', (tester) async {
      final controller = LyricController(
          document: support.lines(count: count),
          initialPosition: Duration(seconds: count - 10));
      addTearDown(controller.dispose);
      await tester
          .pumpWidget(host(controller, style: const AppleMusicLyricStyle()));
      await tester.pump(const Duration(seconds: 1));
      final s = session(tester);
      final originalLayout = s.layout;
      void record(int frame) {
        controller.setPosition(
            Duration(milliseconds: (count - 10) * 1000 + frame % 100 * 5));
        final recorder = ui.PictureRecorder();
        s.painter!.paint(Canvas(recorder), s.size);
        support.disposeNative(recorder.endRecording());
      }

      for (var i = 0; i < 100; i++) {
        record(i);
      }
      final times = <double>[];
      for (var run = 0; run < 5; run++) {
        final watch = Stopwatch()..start();
        for (var i = 0; i < 100; i++) {
          record(i);
        }
        watch.stop();
        times.add(watch.elapsedMicroseconds / 100);
      }
      times.sort();
      expect(s.layout, same(originalLayout));
      expect(s.visibleIndices.length, lessThan(25));
      // ignore: avoid_print
      print(
          '$count lines: ${times[2].toStringAsFixed(1)} us/frame, ${s.visibleIndices.length} candidates');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
