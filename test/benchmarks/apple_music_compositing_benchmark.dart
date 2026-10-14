import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import '../apple_music_test_support.dart';
import '../test_support.dart' as support;

// flutter test test/benchmarks/apple_music_compositing_benchmark.dart --reporter expanded
// Includes the edge mask, blur, rasterization and RGBA readback at 3x DPR.
// Host-engine timings are comparative diagnostics, not mobile frame timings.
void main() {
  for (final simulated in [false, true]) {
    testWidgets('Apple Music compositing (simulated timing: $simulated)',
        (tester) async {
      const text = 'Floating words across a wrapped lyric line';
      final controller = LyricController(
          document: LyricDocument(
              lines: List.generate(100, (i) {
            final start = Duration(seconds: i * 4);
            return LyricLine(
                start: start,
                end: start + const Duration(seconds: 4),
                text: text,
                translation: 'Translation of the current lyric',
                words: simulated
                    ? null
                    : [
                        LyricWord(
                            text: text,
                            start: start,
                            end: start + const Duration(seconds: 4))
                      ]);
          })),
          initialPosition: const Duration(seconds: 200));
      addTearDown(controller.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(Center(
          child: SizedBox(
              width: 400,
              height: 360,
              child: RepaintBoundary(
                  key: key,
                  child:
                      host(controller, style: const AppleMusicLyricStyle())))));
      await tester.pump(const Duration(seconds: 1));
      final s = session(tester);
      final canvas = LayerCountingCanvas();
      s.painter!.paint(canvas, s.size);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      Future<void> frame(int i) async {
        controller.setPosition(Duration(milliseconds: 200000 + i * 40));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 3);
          expect(await image.toByteData(format: ui.ImageByteFormat.rawRgba),
              isNotNull);
          support.disposeNative(image);
        });
      }

      for (var i = 0; i < 10; i++) {
        await frame(i);
      }
      final times = <double>[];
      for (var i = 10; i < 70; i++) {
        final watch = Stopwatch()..start();
        await frame(i);
        times.add(watch.elapsedMicroseconds / 1000);
      }
      times.sort();
      // ignore: avoid_print
      print('simulated=$simulated: ${canvas.layers} Canvas layers, '
          'raster+readback median=${times[30].toStringAsFixed(2)} ms, '
          'p90=${times[54].toStringAsFixed(2)} ms');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
