import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_lyric/core/lyric_model.dart';
import 'package:flutter_lyric/core/lyric_style.dart';
import 'package:flutter_lyric/core/lyric_styles.dart';
import 'package:flutter_lyric/render/lyric_layout.dart';
import 'package:flutter_lyric/render/lyric_painter.dart';
import 'package:flutter_lyric/widgets/mixins/lyric_line_switch_mixin.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = Size(180, 100);
const _offset = Offset(8.35, 8.65);
const _text = 'AAAA';

LyricStyle _style({
  Color baseColor = const Color(0x40FF0000),
  Color? highlightColor = const Color(0xFF00FF00),
  LinearGradient? gradient,
  double fadeWidth = 0,
  bool animate = false,
}) {
  final textStyle = TextStyle(
    fontFamily: 'Ahem',
    fontSize: 24,
    color: baseColor,
  );
  return LyricStyles.default1.copyWith(
    textStyle: textStyle,
    activeStyle: textStyle,
    activeHighlightColor: highlightColor,
    activeHighlightGradient: gradient,
    activeHighlightTailGradientWidth: fadeWidth,
    enableSwitchAnimation: animate,
    contentAlignment: CrossAxisAlignment.start,
    textAlign: TextAlign.left,
  );
}

LyricLayout _layout(LyricStyle style,
    {String text = _text, bool words = false}) {
  final layout = LyricLayout.compute(
    LyricModel(lines: [
      LyricLine(
        text: text,
        start: Duration.zero,
        words: words
            ? [
                LyricWord(
                  text: text,
                  start: Duration.zero,
                  end: const Duration(seconds: 1),
                ),
              ]
            : null,
      ),
    ]),
    style,
    _size,
  );
  addTearDown(() {
    for (final metric in layout.metrics) {
      metric.textPainter.dispose();
      metric.activeTextPainter.dispose();
      metric.textMaskPainter.dispose();
      metric.activeMaskPainter.dispose();
      metric.translationTextPainter.dispose();
    }
  });
  return layout;
}

Future<Uint8List> _render(
  void Function(Canvas) paint, {
  double scale = 1,
  Color? background,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  if (background != null) {
    canvas.drawPaint(Paint()..color = background);
  }
  canvas.scale(scale);
  canvas.translate(_offset.dx, _offset.dy);
  paint(canvas);
  final picture = recorder.endRecording();
  final image = picture.toImageSync(
    (_size.width * scale).ceil(),
    (_size.height * scale).ceil(),
  );
  final bytes = await image.toByteData();
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}

void _paintLyric(
  Canvas canvas,
  LyricLayout layout, {
  double progress = 0,
  bool active = true,
  bool selecting = false,
  LyricLineSwitchState? switchState,
}) {
  LyricPainter(
    layout: layout,
    playIndex: active ? 0 : -1,
    scrollY: 0,
    onAnchorIndexChange: (_) {},
    activeHighlightWidth: progress,
    switchState: switchState ??
        LyricLineSwitchState(
          exitAnimationValue: 1,
          enterAnimationValue: 1,
          exitIndex: -1,
          enterIndex: -1,
        ),
    isSelecting: selecting,
    onShowLineRectsChange: (_) {},
    style: layout.style,
  ).drawLine(canvas, layout.metrics.single, _size, 0, selecting);
}

void _expectPixelsClose(Uint8List actual, Uint8List expected) {
  expect(actual.length, expected.length);
  var differences = 0;
  var maxDifference = 0;
  for (var i = 0; i < actual.length; i++) {
    final difference = (actual[i] - expected[i]).abs();
    if (difference > 2) differences++;
    if (difference > maxDifference) maxDifference = difference;
  }
  expect(differences, 0,
      reason:
          '$differences channels differ; largest difference: $maxDifference');
}

// Derive the expected premultiplied pixels from a single neutral glyph's
// coverage, independently of the painter's layer/blend implementation.
Future<Uint8List> _coloredCoverage(
  String text,
  Color Function(double x, double y) colorAt, {
  Color background = Colors.transparent,
}) async {
  final reference = _layout(_style(baseColor: Colors.white), text: text);
  final coverage = await _render((canvas) =>
      reference.metrics.single.activeTextPainter.paint(canvas, Offset.zero));
  final result = Uint8List(coverage.length);
  for (var i = 0; i < coverage.length; i += 4) {
    final pixel = i ~/ 4;
    final x = pixel % _size.width.toInt() + 0.5 - _offset.dx;
    final y = pixel ~/ _size.width.toInt() + 0.5 - _offset.dy;
    final color = colorAt(x, y);
    final alpha = color.a * coverage[i + 3] / 255;
    final remaining = background.a * (1 - alpha);
    result[i] = ((color.r * alpha + background.r * remaining) * 255).round();
    result[i + 1] =
        ((color.g * alpha + background.g * remaining) * 255).round();
    result[i + 2] =
        ((color.b * alpha + background.b * remaining) * 255).round();
    result[i + 3] = ((alpha + remaining) * 255).round();
  }
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final scale in [1.0, 1.5, 2.75]) {
    test('full highlight has one glyph edge at scale $scale', () async {
      final layout = _layout(_style(highlightColor: Colors.white));
      final reference = _layout(_style(baseColor: Colors.white));
      final expected = await _render(
        (canvas) => reference.metrics.single.activeTextPainter
            .paint(canvas, Offset.zero),
        scale: scale,
      );
      // Fractional positioning ensures the test actually exercises AA pixels.
      expect(
        [for (var i = 3; i < expected.length; i += 4) expected[i]]
            .any((alpha) => alpha > 0 && alpha < 255),
        isTrue,
      );
      final actual = await _render(
        (canvas) => _paintLyric(canvas, layout),
        scale: scale,
      );
      _expectPixelsClose(actual, expected);
    });
  }

  test('opaque gradient is independent of active text alpha', () async {
    const gradient = LinearGradient(
      colors: [Color(0xFFFFEB3B), Color(0xFFFF9800)],
    );
    final transparent =
        _layout(_style(baseColor: Colors.transparent, gradient: gradient));
    final translucent = _layout(_style(gradient: gradient));
    final opaque = _layout(_style(baseColor: Colors.red, gradient: gradient));
    final expected =
        await _render((canvas) => _paintLyric(canvas, transparent));
    for (final layout in [translucent, opaque]) {
      final actual = await _render((canvas) => _paintLyric(canvas, layout));
      _expectPixelsClose(actual, expected);
    }
  });

  test('translucent highlight blends colors before glyph coverage', () async {
    const base = Color(0x40FF0000);
    const highlight = Color(0x8000FF00);
    final layout = _layout(_style(baseColor: base, highlightColor: highlight));
    for (final background in [Colors.transparent, Colors.black, Colors.white]) {
      final expected = await _coloredCoverage(
        _text,
        (_, __) => Color.alphaBlend(highlight, base),
        background: background,
      );
      final actual = await _render(
        (canvas) => _paintLyric(canvas, layout),
        background: background,
      );
      _expectPixelsClose(actual, expected);
    }
  });

  test('word progress and fractional fade boundary have no seam', () async {
    const base = Color(0x40FF0000);
    const highlight = Color(0xFF00FF00);
    const fadeWidth = 24.0;
    final layout = _layout(_style(fadeWidth: fadeWidth), words: true);
    // Exercise the start, solid/fade join, and completion of a syllable.
    for (final progress in [8.0, 60.35, 120.0]) {
      final expected = await _coloredCoverage(_text, (x, _) {
        final opacity = ((progress - x) / fadeWidth).clamp(0.0, 1.0);
        return Color.alphaBlend(highlight.withValues(alpha: opacity), base);
      });
      final actual = await _render(
        (canvas) => _paintLyric(canvas, layout, progress: progress),
      );
      _expectPixelsClose(actual, expected);
    }
  });

  test('wrapped word progress uses the correct row and clears its tail',
      () async {
    const text = 'AAAA\nAAAA';
    const base = Color(0x40FF0000);
    const highlight = Color(0xFF00FF00);
    const fadeWidth = 24.0;
    final layout =
        _layout(_style(fadeWidth: fadeWidth), text: text, words: true);
    final metrics = layout.metrics.single.activeMetrics;
    expect(metrics.length, 2);
    final firstWidth = metrics.first.width;
    final rowBoundary = metrics[1].baseline - metrics[1].ascent;
    for (final progress in [
      firstWidth + 8,
      firstWidth + 60.35,
      firstWidth * 2 + fadeWidth
    ]) {
      final expected = await _coloredCoverage(text, (x, y) {
        final rowOffset = y < rowBoundary ? 0 : firstWidth;
        final opacity =
            ((progress - rowOffset - x) / fadeWidth).clamp(0.0, 1.0);
        return Color.alphaBlend(highlight.withValues(alpha: opacity), base);
      });
      final actual = await _render(
        (canvas) => _paintLyric(canvas, layout, progress: progress),
      );
      _expectPixelsClose(actual, expected);
    }
  });

  for (final active in [true, false]) {
    test('${active ? 'enter' : 'exit'} animation applies opacity once',
        () async {
      const base = Color(0x40FF0000);
      const highlight = Color(0xFF00FF00);
      final layout = _layout(_style(animate: true));
      final originalSpan = layout.metrics.single.activeTextPainter.text;
      for (final value in [0.25, 0.5, 0.75]) {
        final state = LyricLineSwitchState(
          exitAnimationValue: active ? 1 : value,
          enterAnimationValue: active ? value : 1,
          exitIndex: active ? -1 : 0,
          enterIndex: active ? 0 : -1,
        );
        final opacity = active ? value : 1 - value;
        final expected = await _coloredCoverage(
          _text,
          (_, __) =>
              Color.alphaBlend(highlight.withValues(alpha: opacity), base),
        );
        final actual = await _render((canvas) => _paintLyric(
              canvas,
              layout,
              active: active,
              switchState: state,
            ));
        _expectPixelsClose(actual, expected);
        expect(
            layout.metrics.single.activeTextPainter.text, same(originalSpan));
      }
    });
  }

  test('selection supplies the base color below a partial highlight', () async {
    final layout = _layout(_style(), words: true);
    const progress = 48.0;
    final expected = await _coloredCoverage(
        _text,
        (x, _) => x < progress
            ? const Color(0xFF00FF00)
            : layout.style.selectedColor);
    final actual = await _render((canvas) => _paintLyric(
          canvas,
          layout,
          progress: progress,
          selecting: true,
        ));
    _expectPixelsClose(actual, expected);
  });

  test('stable selection colors reuse spans and reset when selection ends',
      () async {
    final layout = _layout(_style(highlightColor: null));
    final metric = layout.metrics.single;
    final expected = await _render((canvas) => _paintLyric(canvas, layout));
    await _render((canvas) => _paintLyric(canvas, layout, selecting: true));
    final selectedSpan = metric.activeTextPainter.text;
    await _render((canvas) => _paintLyric(canvas, layout, selecting: true));
    expect(metric.activeTextPainter.text, same(selectedSpan));
    final actual = await _render((canvas) => _paintLyric(canvas, layout));
    _expectPixelsClose(actual, expected);
    final restoredSpan = metric.activeTextPainter.text;
    await _render((canvas) => _paintLyric(canvas, layout));
    expect(metric.activeTextPainter.text, same(restoredSpan));
  });

  test('translation color stays cached and resets after leaving active line',
      () async {
    final style = _style(highlightColor: null).copyWith(
      translationStyle:
          const TextStyle(fontFamily: 'Ahem', fontSize: 16, color: Colors.blue),
      translationActiveColor: Colors.green,
      selectedTranslationColor: Colors.orange,
    );
    final layout = LyricLayout.compute(
        LyricModel(lines: [
          LyricLine(start: Duration.zero, text: _text, translation: 'BB'),
        ]),
        style,
        _size);
    addTearDown(layout.dispose);
    final metric = layout.metrics.single;
    final expected =
        await _render((canvas) => _paintLyric(canvas, layout, active: false));
    await _render((canvas) => _paintLyric(canvas, layout));
    final activeSpan = metric.translationTextPainter.text;
    await _render((canvas) => _paintLyric(canvas, layout));
    expect(metric.translationTextPainter.text, same(activeSpan));
    expect((activeSpan! as TextSpan).style!.color, Colors.green);
    await _render((canvas) => _paintLyric(canvas, layout, selecting: true));
    expect((metric.translationTextPainter.text! as TextSpan).style!.color,
        Colors.orange);
    final actual =
        await _render((canvas) => _paintLyric(canvas, layout, active: false));
    _expectPixelsClose(actual, expected);
  });

  test('zero progress and absent highlight retain ordinary text rendering',
      () async {
    final baseLayout = _layout(_style(highlightColor: null));
    final wordLayout = _layout(_style(), words: true);
    final expected = await _render((canvas) =>
        baseLayout.metrics.single.activeTextPainter.paint(canvas, Offset.zero));
    for (final layout in [baseLayout, wordLayout]) {
      final actual = await _render((canvas) => _paintLyric(canvas, layout));
      _expectPixelsClose(actual, expected);
    }
  });
}
