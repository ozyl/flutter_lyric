import 'benchmark_support.dart';
import 'package:flutter_lyric/src/rendering/edge_fade.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/src/rendering/resolved_preset.dart';
import 'package:flutter_lyric/src/rendering/lyric_layout.dart';
import 'package:flutter_lyric/src/rendering/line_transition.dart';
// flutter test test/benchmarks/lyric_compositing_benchmark.dart --reporter expanded
// Add --platform chrome for CanvasKit. This includes scene rasterization and
// RGBA readback, NOT just picture recording and NOT presentation/frame timing.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('scroll/seek compositing including raster and readback',
      (tester) async {
    const size = Size(400, 600);
    for (final highlight in [false, true]) {
      for (final fade in [0.0, 80.0]) {
        final style = LyricPresets.leading.copyWith(
          lineTransition: const LyricLineTransition.none(),
          highlight: highlight
              ? LyricPresets.leading.highlight
              : const LyricHighlight.none(),
          edgeFade: LyricEdgeFade.pixels(top: fade, bottom: fade),
        );
        final layout = LyricLayout.compute(
          LyricDocument(
              lines: List.generate(1000, (i) {
            final text = 'A scrolling lyric with wrapped words $i';
            return LyricLine(
              start: Duration(seconds: i),
              text: text,
              translation: 'Translation for line $i',
              words: [
                LyricWord(
                    text: text,
                    start: Duration.zero,
                    end: const Duration(seconds: 1)),
              ],
            );
          })),
          ResolvedPreset(style),
          size,
        );
        final play = ValueNotifier<int>(500);
        final scroll = ValueNotifier<double>(0);
        final width = ValueNotifier<double>(0);
        final selection = ValueNotifier<bool>(false);
        final switching = ValueNotifier(LyricLineSwitchState(
          enterIndex: -1,
          exitIndex: -1,
          enterAnimationValue: 1,
          exitAnimationValue: 1,
        ));
        final key = GlobalKey();
        await tester.pumpWidget(Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
              child: SizedBox.fromSize(
            size: size,
            child: RepaintBoundary(
              key: key,
              child: LyricEdgeMask(
                  fade: style.edgeFade,
                  cache: EdgeFade(),
                  child: CustomPaint(
                    painter: BenchmarkPainter(
                      layout: layout,
                      state: BenchmarkPaintState(
                          playIndex: play,
                          scrollY: scroll,
                          activeHighlightWidth: width,
                          switchState: switching,
                          isSelecting: selection),
                    ),
                    size: size,
                  )),
            ),
          )),
        ));
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        Future<void> frame(int i) async {
          play.value = 100 + (i ~/ 30 * 71) % 800;
          scroll.value =
              layout.lineTop(play.value, play.value) - 250 + i % 30 * 3.35;
          width.value = 20 + i % 30 * 12.35;
          selection.value = i % 60 < 30;
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData();
            expect(bytes, isNotNull);
            disposeNative(image);
          });
        }

        for (var i = 0; i < 20; i++) {
          await frame(i);
        }
        final samples = <double>[];
        for (var run = 0; run < 5; run++) {
          final watch = Stopwatch()..start();
          for (var i = 0; i < 60; i++) {
            await frame(i);
          }
          samples.add(watch.elapsedMicroseconds / 60 / 1000);
        }
        samples.sort();
        // ignore: avoid_print
        print('highlight=$highlight fade=$fade: '
            '${samples[2].toStringAsFixed(3)} ms '
            '(median of 5 x 60, 400x600 @2x, raster + readback)');
        await tester.pumpWidget(const SizedBox.shrink());
        layout.dispose();
        play.dispose();
        scroll.dispose();
        width.dispose();
        selection.dispose();
        switching.dispose();
      }
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
