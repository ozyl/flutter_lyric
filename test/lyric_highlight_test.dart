import 'package:flutter/material.dart';
import 'package:flutter_lyric/core/lyric_model.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/render/lyric_painter.dart';
import 'package:flutter_test/flutter_test.dart';

LyricPainter _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is LyricPainter,
    ))
    .painter! as LyricPainter;

void main() {
  for (final wrapped in [false, true]) {
    for (final fadeWidth in [0.0, 24.0, 200.0]) {
      testWidgets(
          'tail clears continuously at word end (fade: $fadeWidth, wrapped: $wrapped)',
          (tester) async {
        final lastText = wrapped ? 'BBBB\nB' : 'B';
        final controller = LyricController()
          ..loadLyricModel(LyricModel(lines: [
            LyricLine(
              text: 'AAAA$lastText',
              start: Duration.zero,
              words: [
                LyricWord(
                  text: 'AAAA',
                  start: Duration.zero,
                  end: const Duration(milliseconds: 500),
                ),
                LyricWord(
                  text: lastText,
                  start: const Duration(seconds: 1),
                  end: const Duration(seconds: 2),
                ),
              ],
            ),
          ]));
        addTearDown(controller.dispose);
        await tester.pumpWidget(MaterialApp(
          home: LyricView(
            controller: controller,
            width: 400,
            height: 200,
            style: LyricStyles.default1.copyWith(
              activeStyle: const TextStyle(
                  fontFamily: 'Ahem', fontSize: 16, color: Colors.white),
              activeHighlightTailGradientWidth: fadeWidth,
              scrollDuration: Duration.zero,
              scrollDurationMap: {},
            ),
          ),
        ));
        await tester.pumpAndSettle();

        final line = _painter(tester).layout.metrics.single;
        expect(line.activeMetrics.length, wrapped ? 2 : 1);
        final firstWidth = line.words!.first.highlightWidth;
        final textWidth = firstWidth + line.words!.last.highlightWidth;
        Future<double> widthAt(int milliseconds) async {
          controller.setProgress(Duration(milliseconds: milliseconds));
          await tester.pump();
          return _painter(tester).activeHighlightWidth;
        }

        expect(_painter(tester).activeHighlightWidth, 0);
        expect(await widthAt(250), closeTo(firstWidth / 2, 0.001));
        // The gap before the last word must not start clearing the tail.
        expect(await widthAt(750), closeTo(firstWidth, 0.001));
        expect(await widthAt(1000), closeTo(firstWidth, 0.001));
        final middle = await widthAt(1500);
        final beforeEnd = await widthAt(1998);
        final nearEnd = await widthAt(1999);
        final atEnd = await widthAt(2000);
        expect(atEnd, closeTo(textWidth + fadeWidth, 0.001));
        expect(nearEnd, greaterThan(middle));
        // Finishing the word must advance by one ordinary progress step,
        // rather than snapping the remaining fade width to fully highlighted.
        expect(atEnd - nearEnd, closeTo(nearEnd - beforeEnd, 0.001));
        expect(await widthAt(2500), closeTo(atEnd, 0.001));

        // Seeking and pausing use exactly the same progress-derived width.
        expect(await widthAt(1500), closeTo(middle, 0.001));
        await tester.pump(const Duration(milliseconds: 500));
        expect(_painter(tester).activeHighlightWidth, closeTo(middle, 0.001));
        expect(await widthAt(250), closeTo(firstWidth / 2, 0.001));
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets(
      'highlight follows progress immediately and stays put between updates',
      (tester) async {
    final controller = LyricController()
      ..loadLyric('[0,1000]aaaa(0,1000)\n[1000,1000]bbbbbbbb(1000,1000)');
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LyricView(
          controller: controller,
          width: 400,
          height: 200,
          style: LyricStyles.default1.copyWith(
            scrollDuration: Duration.zero,
            scrollDurationMap: {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    LyricPainter painter() => tester
        .widget<CustomPaint>(find.byWidgetPredicate(
          (widget) => widget is CustomPaint && widget.painter is LyricPainter,
        ))
        .painter! as LyricPainter;

    final firstWordWidth =
        painter().layout.metrics[0].words!.single.highlightWidth;
    final secondWordWidth =
        painter().layout.metrics[1].words!.single.highlightWidth;
    expect(firstWordWidth, greaterThan(0));
    expect(secondWordWidth, greaterThan(0));

    controller.setProgress(const Duration(milliseconds: 250));
    await tester.pump();
    expect(
        painter().activeHighlightWidth, closeTo(firstWordWidth * 0.25, 0.001));

    // No new player position means no internal animation or extrapolation.
    await tester.pump(const Duration(milliseconds: 500));
    expect(
        painter().activeHighlightWidth, closeTo(firstWordWidth * 0.25, 0.001));

    controller.setProgress(const Duration(milliseconds: 750));
    await tester.pump();
    expect(
        painter().activeHighlightWidth, closeTo(firstWordWidth * 0.75, 0.001));

    // A seek across a line boundary must use the new line's word timings.
    controller.setProgress(const Duration(milliseconds: 1250));
    await tester.pump();
    expect(painter().playIndex, 1);
    expect(
        painter().activeHighlightWidth, closeTo(secondWordWidth * 0.25, 0.001));

    controller.setProgress(const Duration(milliseconds: 100));
    await tester.pump();
    expect(painter().playIndex, 0);
    expect(
        painter().activeHighlightWidth, closeTo(firstWordWidth * 0.1, 0.001));

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
