import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lyric/flutter_lyric.dart';

import '../apple_music_test_support.dart';
import '../test_support.dart' as support;

// flutter test test/benchmarks/apple_music_switch_benchmark.dart \
//   --concurrency=1 --reporter expanded
// Add --dart-define=APPLE_MUSIC_RASTER=true for 3x raster + RGBA readback.
// Host test-engine timings are comparative diagnostics, not mobile FPS.
// pump includes position updates, animation ticks, layout and picture recording;
// record measures an additional warm picture recording without rasterization.
void main() {
  const raster = bool.fromEnvironment('APPLE_MUSIC_RASTER');
  for (final length in [24, 48, 72]) {
    for (final simulated in [false, true]) {
      testWidgets('Apple Music $length characters (simulated: $simulated)',
          (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final text = List.filled(length, 'A').join();
        final controller = LyricController(
            document: LyricDocument(
                lines: List.generate(40, (i) {
              final start = Duration(seconds: i * 4);
              return LyricLine(
                  start: start,
                  end: start + const Duration(seconds: 4),
                  text: text,
                  translation: 'Translation of this lyric',
                  words: simulated
                      ? null
                      : [
                          LyricWord(
                              text: text,
                              start: start,
                              end: start + const Duration(seconds: 4)),
                        ]);
            })),
            initialPosition: const Duration(seconds: 42));
        addTearDown(controller.dispose);
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(MediaQuery(
            data: const MediaQueryData(devicePixelRatio: 3),
            child: Directionality(
                textDirection: TextDirection.ltr,
                child: Center(
                    child: SizedBox(
                        width: 400,
                        height: 640,
                        child: RepaintBoundary(
                            key: boundaryKey,
                            child: AppleMusicLyricView(
                                controller: controller)))))));
        await tester.pump(const Duration(seconds: 1));
        final state = session(tester);
        final layout = state.layout;
        final boundary = boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final results = <String, _Samples>{};

        Future<void> sample(String phase, int positionMs, int deltaMs) async {
          final samples = results.putIfAbsent(phase, () => _Samples());
          final watch = Stopwatch()..start();
          controller.setPosition(Duration(milliseconds: positionMs));
          await tester.pump(Duration(milliseconds: deltaMs));
          watch.stop();
          samples.pumpUs.add(watch.elapsedMicroseconds.toDouble());

          final recorder = ui.PictureRecorder();
          watch
            ..reset()
            ..start();
          state.painter!.paint(Canvas(recorder), state.size);
          final picture = recorder.endRecording();
          watch.stop();
          samples.recordUs.add(watch.elapsedMicroseconds.toDouble());
          support.disposeNative(picture);

          final counts = _CountingCanvas();
          state.painter!.paint(counts, state.size);
          samples.layers.add(counts.layers);
          samples.paragraphs.add(counts.paragraphs);
          samples.images.add(counts.images);
          if (raster) {
            watch
              ..reset()
              ..start();
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 3);
              expect(await image.toByteData(format: ui.ImageByteFormat.rawRgba),
                  isNotNull);
              support.disposeNative(image);
            });
            watch.stop();
            samples.rasterMs.add(watch.elapsedMicroseconds / 1000);
          }
        }

        // Each switch enters a previously inactive line, preserving its cold
        // character geometry work in the pump measurement. Later samples retain
        // both the entering and exiting lines during their 250 ms crossfade.
        for (var current = 10; current < 16; current++) {
          for (var frame = 0; frame < 4; frame++) {
            await sample('steady', current * 4000 + 2000 + frame * 16, 16);
          }
          final nextStart = (current + 1) * 4000;
          var previousMs = 0;
          for (final elapsedMs in [0, 16, 64, 128, 240]) {
            await sample('switch+$elapsedMs', nextStart + elapsedMs,
                elapsedMs - previousMs);
            previousMs = elapsedMs;
          }
          await tester.pump(const Duration(seconds: 1));
        }
        expect(state.layout, same(layout));
        final rows = layout!.metric(10).activeMetrics.length;
        expect(rows, greaterThan(1));
        for (final entry in results.entries) {
          // ignore: avoid_print
          print('chars=$length rows=$rows simulated=$simulated '
              '${entry.key}: ${entry.value}');
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}

class _CountingCanvas implements Canvas {
  int layers = 0;
  int paragraphs = 0;
  int images = 0;

  @override
  void saveLayer(Rect? bounds, Paint paint) => layers++;

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) => paragraphs++;

  @override
  void drawImage(ui.Image image, Offset offset, Paint paint) => images++;

  @override
  void drawImageRect(ui.Image image, Rect src, Rect dst, Paint paint) =>
      images++;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Samples {
  final pumpUs = <double>[];
  final recordUs = <double>[];
  final rasterMs = <double>[];
  final layers = <int>[];
  final paragraphs = <int>[];
  final images = <int>[];

  static String _timing(List<double> values) {
    final sorted = values.toList()..sort();
    return '${sorted[sorted.length ~/ 2].toStringAsFixed(1)}/'
        '${sorted[((sorted.length - 1) * .9).round()].toStringAsFixed(1)}';
  }

  static String _range(List<int> values) {
    final sorted = values.toList()..sort();
    return '${sorted.first}-${sorted.last}';
  }

  @override
  String toString() => 'pump p50/p90=${_timing(pumpUs)} us, '
      'record p50/p90=${_timing(recordUs)} us, '
      'saveLayer=${_range(layers)}, drawParagraph=${_range(paragraphs)}, '
      'imageDraws=${_range(images)}'
      '${rasterMs.isEmpty ? '' : ', raster+readback p50/p90=${_timing(rasterMs)} ms'}';
}
