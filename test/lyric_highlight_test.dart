import 'package:flutter/material.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/render/lyric_painter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
