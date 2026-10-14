import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/src/compat/painting.dart';
import 'package:flutter_lyric/src/rendering/lyric_word_layout.dart';
import 'package:flutter_lyric/src/rendering/lyric_word_painter.dart';
import 'apple_music_test_support.dart';
import 'test_support.dart' as support;

// Independent grouped-color reference. A neutral mask receives the complete
// base/highlight color field, then a separate layer resamples the float. This
// deliberately retains the expensive composition to check the fused path.
void reference(Canvas canvas, LyricWordLine line, LyricHighlight highlight,
    Color base, double progress, double activity, double Function(int) lift,
    {bool floating = true}) {
  final segment = line.segments.single;
  final slices = floating
      ? line.characters
      : [
          LyricWordCharacter(
              0, 0, line.source.text.length, segment.clips, segment)
        ];
  final bounds =
      (Offset.zero & line.text.size).inflate(line.text.preferredLineHeight);
  final cutouts = Path()..fillType = PathFillType.evenOdd;
  cutouts.addRect(bounds);
  for (final character in slices) {
    for (final clip in character.clips) {
      cutouts.addRect(clip);
    }
  }
  canvas.save();
  canvas.clipPath(cutouts, doAntiAlias: false);
  line.text.paint(canvas, Offset.zero);
  canvas.restore();
  for (final character in slices) {
    if (character.clips.isEmpty) continue;
    final path = Path();
    for (final clip in character.clips) {
      path.addRect(clip);
    }
    final slice = character.clips.reduce((a, b) => a.expandToInclude(b));
    final dy = lift(character.ordinal);
    if (floating) {
      canvas.saveLayer(
          slice.expandToInclude(slice.translate(0, -dy)).inflate(1),
          Paint()
            ..imageFilter = ui.ImageFilter.matrix(
                Matrix4.translationValues(0, -dy, 0).storage,
                filterQuality: FilterQuality.low));
    } else {
      canvas.save();
      canvas.translate(0, -dy);
    }
    canvas.clipPath(path, doAntiAlias: false);
    canvas.saveLayer(bounds, Paint());
    line.mask.paint(canvas, Offset.zero);
    canvas.saveLayer(bounds, Paint()..blendMode = BlendMode.srcIn);
    canvas.drawRect(
        bounds,
        Paint()
          ..isAntiAlias = false
          ..color = base);
    final gradient = highlight.gradient ??
        LinearGradient(colors: [highlight.color!, highlight.color!]);
    final shader = LinearGradient(
      colors: gradient.colors
          .map((c) => colorWithOpacity(c, colorOpacity(c) * activity))
          .toList(),
      stops: gradient.stops,
      begin: gradient.begin,
      end: gradient.end,
      tileMode: gradient.tileMode,
      transform: gradient.transform,
    ).createShader(segment.bounds);
    final paint = Paint()
      ..isAntiAlias = false
      ..shader = shader;
    if (progress >= 1) {
      canvas.drawRect(bounds, paint);
    } else if (progress > 0) {
      var remaining = progress *
          (segment.boxes.fold<double>(0, (v, b) => v + b.right - b.left) +
              highlight.tailFadeWidth);
      for (var i = 0; i < segment.boxes.length; i++) {
        final box = segment.boxes[i];
        final clip = segment.clips[i];
        final rtl = box.direction == TextDirection.rtl;
        if (highlight.tailFadeWidth == 0) {
          final width = box.right - box.left;
          final cutoff = remaining.clamp(0.0, width);
          if (cutoff > 0) {
            canvas.drawRect(
                Rect.fromLTRB(
                    rtl && cutoff < width ? box.right - cutoff : clip.left,
                    clip.top,
                    !rtl && cutoff < width ? box.left + cutoff : clip.right,
                    clip.bottom),
                paint);
          }
          remaining -= width;
          continue;
        }
        canvas.saveLayer(clip, Paint());
        canvas.clipRect(clip, doAntiAlias: false);
        canvas.drawRect(clip, paint);
        if (highlight.tailFadeWidth > 0) {
          final begin = remaining - highlight.tailFadeWidth;
          final fade = Rect.fromLTRB(
              rtl ? box.right - remaining : box.left + begin,
              clip.top,
              rtl ? box.right - begin : box.left + remaining,
              clip.bottom);
          canvas.drawRect(
              clip,
              Paint()
                ..isAntiAlias = false
                ..blendMode = BlendMode.dstIn
                ..shader = LinearGradient(
                  begin: rtl ? Alignment.centerRight : Alignment.centerLeft,
                  end: rtl ? Alignment.centerLeft : Alignment.centerRight,
                  colors: const [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
                ).createShader(fade));
        }
        canvas.restore();
        remaining -= box.right - box.left;
      }
    }
    canvas.restore();
    canvas.restore();
    canvas.restore();
  }
}

Future<Uint8List> render(
    WidgetTester tester, void Function(Canvas) paint, double scale) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..scale(scale)
    ..translate(32.35, 36.65);
  paint(canvas);
  final picture = recorder.endRecording();
  final pixels = await tester.runAsync(() async {
    final image =
        await picture.toImage((400 * scale).ceil(), (300 * scale).ceil());
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    support.disposeNative(image);
    return data!.buffer.asUint8List();
  });
  support.disposeNative(picture);
  return pixels!;
}

void expectCoverage(Uint8List actual, Uint8List expected, String context) {
  var differences = 0;
  var maximum = 0.0;
  for (var i = 0; i < actual.length; i++) {
    final channel = i % 4;
    final a = channel == 3
        ? actual[i].toDouble()
        : actual[i] * actual[i - channel + 3] / 255;
    final e = channel == 3
        ? expected[i].toDouble()
        : expected[i] * expected[i - channel + 3] / 255;
    final difference = (a - e).abs();
    if (difference > 2) differences++;
    if (difference > maximum) maximum = difference;
  }
  expect(differences, 0,
      reason: '$context: $differences channels differ, max=$maximum');
}

void main() {
  for (final text in ['AAAA AAAA AAAA AAAA', 'אבגד אבגד אבגד אבגד']) {
    for (final gradient in [false, true]) {
      for (final floating in [false, true]) {
        for (final tail in [0.0, 17.3]) {
          testWidgets(
              'fused highlight: $text, gradient=$gradient, floating=$floating, tail=$tail',
              (tester) async {
            final controller = LyricController(
                document: LyricDocument(lines: [
              LyricLine(start: Duration.zero, text: text, words: [
                LyricWord(
                    text: text,
                    start: Duration.zero,
                    end: const Duration(seconds: 1)),
              ]),
            ]));
            addTearDown(controller.dispose);
            final highlight = gradient
                ? LyricHighlight.gradient(
                    const LinearGradient(
                        colors: [Color(0x3099DD22), Color(0xD03311EE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        transform: GradientRotation(.3)),
                    tailFadeWidth: tail)
                : LyricHighlight.solid(const Color(0x9933DDEE),
                    tailFadeWidth: tail);
            for (final base in [
              const Color(0x00408020),
              const Color(0x70408020),
              const Color(0xFF408020)
            ]) {
              await tester.pumpWidget(host(controller,
                  style: quiet.copyWith(
                      inactiveScale: 1,
                      wordLift: 2.5,
                      characterFloatAmplitude: floating ? 2.7 : 0,
                      textStyle: TextStyle(
                          fontFamily: 'Ahem',
                          fontSize: 27.5,
                          height: 1.25,
                          color: base),
                      highlight: highlight)));
              await tester.pump(const Duration(milliseconds: 1370));
              final s = session(tester);
              final line = s.layout!.wordLine(0, true);
              expect(line.text.computeLineMetrics().length, greaterThan(1));
              if (text.startsWith('א')) {
                expect(
                    line.segments.single.boxes
                        .any((box) => box.direction == TextDirection.rtl),
                    isTrue);
              }
              for (final position in [0, 77, 351, 690, 1000]) {
                controller.setPosition(Duration(milliseconds: position));
                await tester.pump();
                for (final scale in [1.0, 2.75]) {
                  const activity = .65;
                  final actual = await render(
                      tester,
                      (c) => LyricWordPainter(s, baseColor: base)
                          .paint(c, line, 0, activity),
                      scale);
                  final expected = await render(
                      tester,
                      (c) => reference(
                          c,
                          line,
                          highlight,
                          base,
                          position / 1000,
                          activity,
                          (i) =>
                              s.wordPopLift(0, line.segments.single) +
                              s.characterFloatLift(0, i),
                          floating: floating),
                      scale);
                  expectCoverage(actual, expected,
                      'base=$base, position=$position, scale=$scale');
                }
              }
            }
            await tester.pumpWidget(const SizedBox.shrink());
          });
        }
      }
    }
  }

  testWidgets('solid float uses one offscreen surface per grapheme',
      (tester) async {
    const text = 'AAAA AAAA AAAA AAAA';
    final controller = LyricController(
        document: LyricDocument(lines: [
      LyricLine(start: Duration.zero, text: text, words: const [
        LyricWord(text: text, start: Duration.zero, end: Duration(seconds: 1)),
      ]),
    ]));
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller,
        style: quiet.copyWith(
            characterFloatAmplitude: 1.4,
            highlight: const LyricHighlight.solid(Color(0xFFFFFFFF),
                tailFadeWidth: 16))));
    final s = session(tester);
    final line = s.layout!.wordLine(0, true);
    for (final position in [0, 170, 750, 1000]) {
      controller.setPosition(Duration(milliseconds: position));
      final canvas = LayerCountingCanvas();
      LyricWordPainter(s).paint(canvas, line, 0, 1);
      expect(canvas.layers,
          line.characters.where((c) => c.clips.isNotEmpty).length);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
