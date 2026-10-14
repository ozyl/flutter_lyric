import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/src/rendering/lyric_viewport.dart';
import 'apple_music_test_support.dart';
import 'test_support.dart' as support;

Future<Uint8List> pixels(
    WidgetTester tester, void Function(Canvas) paint) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final picture = recorder.endRecording();
  final result = await tester.runAsync(() async {
    final image = await picture.toImage(400, 360);
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
        .buffer
        .asUint8List();
    support.disposeNative(image);
    return data;
  });
  support.disposeNative(picture);
  return result!;
}

double centerY(Uint8List data, int left, int right,
    {int top = 0, int bottom = 360}) {
  var weight = 0.0;
  var sum = 0.0;
  for (var y = top; y < bottom; y++) {
    for (var x = left; x < right; x++) {
      final alpha = data[(y * 400 + x) * 4 + 3].toDouble();
      weight += alpha;
      sum += alpha * y;
    }
  }
  return sum / weight;
}

void main() {
  for (final wrapped in [false, true]) {
    for (final transparent in [false, true]) {
      testWidgets(
          'full highlight has one glyph edge (wrapped: $wrapped, transparent: $transparent)',
          (tester) async {
        final base =
            transparent ? const Color(0x00804020) : const Color(0x40804020);
        final content = wrapped ? 'AAAA AAAA AAAA AAAA' : 'AAAA';
        const highlight = Color(0x99A0D0F0);
        final controller = LyricController(
            document: LyricDocument(lines: [
              LyricLine(
                  start: Duration.zero,
                  text: content,
                  end: const Duration(seconds: 1)),
            ]),
            initialPosition: const Duration(seconds: 2));
        addTearDown(controller.dispose);
        final style = quiet.copyWith(
            inactiveScale: 1,
            textStyle:
                TextStyle(fontFamily: 'Ahem', fontSize: 27.5, color: base),
            highlight: const LyricHighlight.solid(highlight));
        await tester.pumpWidget(host(controller, style: style));
        await tester.pumpAndSettle();
        final s = session(tester);
        final actual = await pixels(tester, (c) => s.painter!.paint(c, s.size));
        final referencePainter = TextPainter(
            textDirection: TextDirection.ltr,
            text: TextSpan(
                text: content,
                style:
                    style.textStyle.copyWith(color: const Color(0xFFFFFFFF))))
          ..layout(maxWidth: 352);
        addTearDown(() => support.disposeNative(referencePainter));
        final expected = await pixels(tester, (c) {
          // Independent flat-color reference: one neutral glyph mask, then replace
          // its color once. Colored glyph rasterization can use different AA.
          const bounds = Rect.fromLTWH(0, 0, 400, 360);
          c.saveLayer(bounds, Paint());
          referencePainter.paint(c, Offset(24, s.lineTop(0)));
          c.drawRect(
              bounds,
              Paint()
                ..blendMode = BlendMode.srcIn
                ..color = Color.alphaBlend(highlight, base));
          c.restore();
        });
        var covered = 0;
        for (var i = 0; i < actual.length; i++) {
          final channel = i % 4;
          final a = channel == 3
              ? actual[i].toDouble()
              : actual[i] * actual[i - channel + 3] / 255;
          final e = channel == 3
              ? expected[i].toDouble()
              : expected[i] * expected[i - channel + 3] / 255;
          expect((a - e).abs(), lessThanOrEqualTo(2),
              reason:
                  'premultiplied channel $i: ${actual[i]} / ${expected[i]}');
          if (i % 4 == 3 && expected[i] > 0) covered++;
        }
        expect(covered, greaterThan(100));
      });
    }
  }

  testWidgets(
      'Word Pop rises and holds through playback pauses until seeking back',
      (tester) async {
    final controller = LyricController(
        document: LyricDocument(lines: [
      LyricLine(start: Duration.zero, text: 'AA BB', words: const [
        LyricWord(text: 'AA', start: Duration.zero, end: Duration(seconds: 2)),
        LyricWord(
            text: 'BB', start: Duration(seconds: 2), end: Duration(seconds: 4)),
      ]),
    ]));
    addTearDown(controller.dispose);
    final style = quiet.copyWith(
        wordLift: 8,
        wordPopDuration: const Duration(milliseconds: 500),
        inactiveScale: 1,
        highlight: const LyricHighlight.none(),
        textStyle: const TextStyle(
            fontFamily: 'Ahem', fontSize: 24, color: Color(0xFFFFFFFF)));
    await tester.pumpWidget(host(controller, style: style));
    await tester.pumpAndSettle();
    final s = session(tester);
    final before = await pixels(tester, (c) => s.painter!.paint(c, s.size));
    controller.setPosition(const Duration(milliseconds: 250));
    await tester.pump();
    final middle = await pixels(tester, (c) => s.painter!.paint(c, s.size));
    expect(centerY(middle, 24, 72), closeTo(centerY(before, 24, 72) - 4, .05));
    expect(centerY(middle, 96, 144), closeTo(centerY(before, 96, 144), .05));
    await tester.pump(const Duration(seconds: 3));
    final paused = await pixels(tester, (c) => s.painter!.paint(c, s.size));
    expect(paused, middle);
    controller.setPosition(const Duration(milliseconds: 600));
    await tester.pump();
    final raised = await pixels(tester, (c) => s.painter!.paint(c, s.size));
    expect(centerY(raised, 24, 72), closeTo(centerY(before, 24, 72) - 8, .05));
    expect(centerY(raised, 96, 144), closeTo(centerY(before, 96, 144), .05));
    controller.setPosition(const Duration(milliseconds: 1900));
    await tester.pump();
    expect(await pixels(tester, (c) => s.painter!.paint(c, s.size)), raised);
    controller.setPosition(Duration.zero);
    await tester.pump();
    expect(await pixels(tester, (c) => s.painter!.paint(c, s.size)), before);
  });

  testWidgets(
      'characters within one timed word float separately and add to Word Pop',
      (tester) async {
    final controller = LyricController(
        document: LyricDocument(lines: [
      LyricLine(start: Duration.zero, text: 'AAAA', words: const [
        LyricWord(
            text: 'AAAA', start: Duration.zero, end: Duration(seconds: 2)),
      ]),
    ]));
    addTearDown(controller.dispose);
    final style = quiet.copyWith(
        wordLift: 8,
        wordPopDuration: const Duration(milliseconds: 500),
        characterFloatAmplitude: 5.2,
        characterFloatMode: LyricFloatMode.all,
        characterFloatStagger: const Duration(milliseconds: 400),
        inactiveScale: 1,
        highlight: const LyricHighlight.none(),
        textStyle: const TextStyle(
            fontFamily: 'Ahem', fontSize: 24, color: Color(0xFFFFFFFF)));
    await tester.pumpWidget(host(controller, style: style));
    final s = session(tester);
    final before = await pixels(tester, (c) => s.painter!.paint(c, s.size));
    await tester.pump(const Duration(milliseconds: 1600));
    final floated = await pixels(tester, (c) => s.painter!.paint(c, s.size));
    final lifts = List.generate(
        4,
        (i) =>
            centerY(before, 24 + i * 24, 48 + i * 24) -
            centerY(floated, 24 + i * 24, 48 + i * 24));
    for (var i = 0; i < 4; i++) {
      expect(lifts[i], closeTo(s.characterFloatLift(0, i), .07));
    }
    expect((lifts.first - lifts.last).abs(), greaterThan(.1));
    controller.setPosition(const Duration(milliseconds: 500));
    await tester.pump();
    final combined = await pixels(tester, (c) => s.painter!.paint(c, s.size));
    for (var i = 0; i < 4; i++) {
      expect(centerY(combined, 24 + i * 24, 48 + i * 24),
          closeTo(centerY(floated, 24 + i * 24, 48 + i * 24) - 8, .07));
    }
    controller.setPosition(const Duration(milliseconds: 600));
    await tester.pump();
    // Once Pop finishes, its height remains the center of the float range.
    final afterPop = await pixels(tester, (c) => s.painter!.paint(c, s.size));
    expect(afterPop, combined);
    for (var cycle = 0; cycle < 3; cycle++) {
      await tester.pump(style.characterFloatPeriod);
      final held = await pixels(tester, (c) => s.painter!.paint(c, s.size));
      for (var i = 0; i < 4; i++) {
        final lift = centerY(before, 24 + i * 24, 48 + i * 24) -
            centerY(held, 24 + i * 24, 48 + i * 24);
        expect(
            lift,
            inInclusiveRange(style.wordLift - style.characterFloatAmplitude,
                style.wordLift + style.characterFloatAmplitude));
        expect(lift, closeTo(style.wordLift + s.characterFloatLift(0, i), .07));
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
    testWidgets(
        'untimed wrapped characters float with whole-line highlight ($direction)',
        (tester) async {
      final controller = LyricController(
          document: LyricDocument(lines: [
        LyricLine(start: Duration.zero, text: 'AAAA AAAA AAAA AAAA AAAA'),
      ]));
      addTearDown(controller.dispose);
      final style = quiet.copyWith(
          characterFloatAmplitude: 3,
          simulateWordTiming: false,
          inactiveScale: 1,
          textStyle: const TextStyle(
              fontFamily: 'Ahem',
              fontSize: 24,
              height: 1.25,
              color: Color(0x00000000)));
      await tester
          .pumpWidget(host(controller, style: style, direction: direction));
      final s = session(tester);
      expect(s.layout!.lines.single.segments, isEmpty);
      expect(s.layout!.lines.single.text.computeLineMetrics().length,
          greaterThan(1));
      final before = await pixels(tester, (c) => s.painter!.paint(c, s.size));
      await tester.pump(const Duration(milliseconds: 1600));
      final after = await pixels(tester, (c) => s.painter!.paint(c, s.size));
      double coverage(Uint8List data) {
        var sum = 0.0;
        for (var i = 3; i < data.length; i += 4) {
          sum += data[i];
        }
        return sum;
      }

      expect(coverage(before), greaterThan(100000));
      expect(
          coverage(after), closeTo(coverage(before), coverage(before) * .002));
      expect(after, isNot(before));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('browsing blur can be toggled until playback following resumes',
      (tester) async {
    final controller = LyricController(document: support.lines());
    addTearDown(controller.dispose);
    final style = quiet.copyWith(
        inactiveScale: 1,
        inactiveOpacity: 1,
        maxBlurSigma: 4,
        blurSigmaPerLine: 4,
        highlight: const LyricHighlight.none());
    await tester.pumpWidget(host(controller, style: style));
    await tester.pumpAndSettle();
    final s = session(tester);
    final layout = s.layout!;

    Future<void> expectBlur(bool enabled) async {
      final actual = await pixels(tester, (c) => s.painter!.paint(c, s.size));
      // Independent crisp reference, including translations, at the same
      // scroll offset. Scaling, opacity and text motion are disabled above.
      final crisp = await pixels(tester, (c) {
        for (final index in s.visibleIndices) {
          final line = layout.lines[index];
          line.text
              .paint(c, Offset(layout.style.padding.left, s.lineTop(index)));
          line.translation?.paint(
              c,
              Offset(layout.style.padding.left,
                  s.lineTop(index) + line.translationY));
        }
      });
      expect(actual, enabled ? isNot(equals(crisp)) : equals(crisp));
    }

    await expectBlur(true);
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(LyricViewport)));
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    expect(s.following, false);
    expect(s.dragging, true);
    await expectBlur(false);

    await tester.pumpWidget(
        host(controller, style: style.copyWith(blurWhenBrowsing: true)));
    expect(s.layout, same(layout));
    expect(s.dragging, true);
    await expectBlur(true);

    await tester.pumpWidget(host(controller, style: style));
    expect(s.layout, same(layout));
    expect(s.dragging, true);
    await expectBlur(false);
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(s.dragging, false);
    expect(s.following, false);
    expect(s.selectedIndex, isNotNull);
    await expectBlur(false);

    await controller.resumeFollow(animate: false);
    await tester.pumpAndSettle();
    expect(s.following, true);
    expect(s.selectedIndex, isNull);
    expect(controller.position, Duration.zero);
    await expectBlur(true);
  });

  testWidgets('blur spreads distant lines while leaving the focus crisp',
      (tester) async {
    final controller = LyricController(document: support.lines(count: 3));
    addTearDown(controller.dispose);
    final style = quiet.copyWith(
        inactiveScale: 1,
        inactiveOpacity: 1,
        highlight: const LyricHighlight.none());
    await tester.pumpWidget(host(controller, style: style));
    await tester.pumpAndSettle();
    var s = session(tester);
    final crisp = await pixels(tester, (c) => s.painter!.paint(c, s.size));
    final firstRect = s.lineRect(0);
    final secondRect = s.lineRect(1);
    await tester.pumpWidget(host(controller,
        style: style.copyWith(maxBlurSigma: 4, blurSigmaPerLine: 4)));
    await tester.pumpAndSettle();
    s = session(tester);
    final blurred = await pixels(tester, (c) => s.painter!.paint(c, s.size));
    int changed(Rect rect) {
      var count = 0;
      for (var y = rect.top.floor().clamp(0, 359);
          y < rect.bottom.ceil().clamp(0, 360);
          y++) {
        for (var x = 0; x < 400; x++) {
          final i = (y * 400 + x) * 4 + 3;
          if (crisp[i] != blurred[i]) count++;
        }
      }
      return count;
    }

    expect(changed(firstRect), 0);
    expect(changed(secondRect.inflate(8)), greaterThan(100));
  });
}
