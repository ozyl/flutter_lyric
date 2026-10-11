import 'dart:typed_data';
import 'package:flutter_lyric/src/rendering/resolved_preset.dart';
import 'test_support.dart';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/src/rendering/lyric_layout.dart';
import 'package:flutter_lyric/src/rendering/lyric_painter.dart';
import 'package:flutter_lyric/src/rendering/line_transition.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = Size(180, 100);
const _offset = Offset(8.35, 8.65);
const _text = 'AAAA';

LyricPreset _style({
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
  return LyricPresets.centered.copyWith(
    textStyle: textStyle,
    activeTextStyle: textStyle,
    padding: EdgeInsets.zero,
    highlight: gradient != null
        ? LyricHighlight.gradient(gradient, tailFadeWidth: fadeWidth)
        : highlightColor == null
            ? const LyricHighlight.none()
            : LyricHighlight.solid(highlightColor, tailFadeWidth: fadeWidth),
    lineTransition: animate
        ? const LyricLineTransition()
        : const LyricLineTransition.none(),
    contentAlignment: LyricContentAlignment.start,
    textAlign: TextAlign.left,
  );
}

LyricLayout _layout(LyricPreset style,
    {String text = _text, bool words = false}) {
  final layout = LyricLayout.compute(
    LyricDocument(lines: [
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
    ResolvedPreset(style),
    _size,
  );
  addTearDown(layout.dispose);
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
  final image = await picture.toImage(
    (_size.width * scale).ceil(),
    (_size.height * scale).ceil(),
  );
  final bytes = await image.toByteData();
  disposeNative(image);
  disposeNative(picture);
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
    activeHighlightWidth: progress,
    switchState: switchState ??
        LyricLineSwitchState(
          exitAnimationValue: 1,
          enterAnimationValue: 1,
          exitIndex: -1,
          enterIndex: -1,
        ),
    isSelecting: selecting,
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
  double scale = 1,
}) async {
  final reference = _layout(_style(baseColor: Colors.white), text: text);
  final coverage = await _render(
      (canvas) =>
          reference.metrics.single.activeTextPainter.paint(canvas, Offset.zero),
      scale: scale);
  final result = Uint8List(coverage.length);
  final imageWidth = (_size.width * scale).ceil();
  for (var i = 0; i < coverage.length; i += 4) {
    final pixel = i ~/ 4;
    final x = (pixel % imageWidth + 0.5) / scale - _offset.dx;
    final y = (pixel ~/ imageWidth + 0.5) / scale - _offset.dy;
    final color = colorAt(x, y);
    final alpha = channel(color, 'a') * coverage[i + 3] / 255;
    final remaining = channel(background, 'a') * (1 - alpha);
    result[i] =
        ((channel(color, 'r') * alpha + channel(background, 'r') * remaining) *
                255)
            .round();
    result[i + 1] =
        ((channel(color, 'g') * alpha + channel(background, 'g') * remaining) *
                255)
            .round();
    result[i + 2] =
        ((channel(color, 'b') * alpha + channel(background, 'b') * remaining) *
                255)
            .round();
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

  for (final active in [true, false]) {
    test('opacity restyles preserve ${active ? 'active' : 'exit'} mask pixels',
        () async {
      const highlight = Color(0x8000FF00);
      var layout = _layout(_style(highlightColor: highlight, animate: true));
      final state = LyricLineSwitchState(
        enterIndex: -1,
        exitIndex: active ? -1 : 0,
        enterAnimationValue: 1,
        exitAnimationValue: active ? 1 : 0.5,
      );
      // Initialize the mask by painting before any opacity changes.
      await _render((canvas) =>
          _paintLyric(canvas, layout, active: active, switchState: state));
      for (final alpha in [0.0, 0.35, 1.0, 0.65]) {
        final base = withAlphaValue(Colors.red, alpha);
        layout = layout.restyle(
            ResolvedPreset(_style(
                baseColor: base, highlightColor: highlight, animate: true)),
            _size);
        final expected = await _coloredCoverage(
            _text,
            (_, __) => Color.alphaBlend(
                withAlphaValue(
                    highlight, channel(highlight, 'a') * (active ? 1 : 0.5)),
                base));
        final actual = await _render((canvas) =>
            _paintLyric(canvas, layout, active: active, switchState: state));
        _expectPixelsClose(actual, expected);
      }
    });
  }

  test('word progress and fractional fade boundary have no seam', () async {
    const base = Color(0x40FF0000);
    const highlight = Color(0xFF00FF00);
    const fadeWidth = 24.0;
    final layout = _layout(_style(fadeWidth: fadeWidth), words: true);
    // Exercise the start, solid/fade join, and completion of a syllable.
    for (final progress in [8.0, 60.35, 120.0]) {
      final expected = await _coloredCoverage(_text, (x, _) {
        final opacity = ((progress - x) / fadeWidth).clamp(0.0, 1.0);
        return Color.alphaBlend(withAlphaValue(highlight, opacity), base);
      });
      final actual = await _render(
        (canvas) => _paintLyric(canvas, layout, progress: progress),
      );
      _expectPixelsClose(actual, expected);
    }
  });

  test('opaque base retains one glyph edge under translucent moving highlight',
      () async {
    const base = Color(0xFF8542D0);
    const highlight = Color(0x8000FF00);
    const fadeWidth = 24.0;
    const text = 'AAAA\nAAAA';
    final layout = _layout(
        _style(
            baseColor: base, highlightColor: highlight, fadeWidth: fadeWidth),
        text: text,
        words: true);
    final rows = layout.metrics.single.activeMetrics;
    final rowBoundary = rows[1].baseline - rows[1].ascent;
    for (final scale in [1.0, 1.5, 2.75]) {
      for (final progress in [8.0, 60.35, 104.0, 156.35, 216.0]) {
        for (final background in [
          Colors.transparent,
          Colors.black,
          Colors.white
        ]) {
          final expected = await _coloredCoverage(text, (x, y) {
            final rowOffset = y < rowBoundary ? 0 : rows.first.width;
            final opacity =
                ((progress - rowOffset - x) / fadeWidth).clamp(0.0, 1.0);
            return Color.alphaBlend(
                withAlphaValue(highlight, channel(highlight, 'a') * opacity),
                base);
          }, background: background, scale: scale);
          final actual = await _render(
              (canvas) => _paintLyric(canvas, layout, progress: progress),
              background: background,
              scale: scale);
          _expectPixelsClose(actual, expected);
        }
      }
    }
  });

  test('gradient with varying alpha agrees with grouped colors at scaled edges',
      () async {
    const gradient = LinearGradient(
      colors: [Color(0x3068BC21), Color(0xC03B21E0), Color(0x8087A52C)],
      stops: [0, 0.35, 1],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      transform: GradientRotation(0.3),
      tileMode: TileMode.mirror,
    );
    for (final base in [
      Colors.transparent,
      const Color(0x40BA3812),
      const Color(0xFFBA3812)
    ]) {
      final layout = _layout(_style(baseColor: base, gradient: gradient),
          text: 'AAAA\nAAAA');
      final metric = layout.metrics.single;
      final mask = metric.activeMaskPainter;
      final bounds =
          (Offset.zero & mask.size).inflate(mask.preferredLineHeight);
      for (final scale in [1.0, 1.5, 2.75]) {
        final expected = await _render((canvas) {
          // Reference the original two-layer color-group composition. In
          // particular, interpolation of varying alpha must precede blending.
          canvas.saveLayer(bounds, Paint());
          mask.paint(canvas, Offset.zero);
          canvas.saveLayer(bounds, Paint()..blendMode = BlendMode.srcIn);
          canvas.drawRect(bounds, Paint()..color = base);
          for (final row in metric.activeMetrics) {
            final top = row.baseline - row.ascent;
            final bottom = top + row.ascent + row.descent;
            final shaderRect =
                Rect.fromLTRB(row.left - 2, top, row.left + row.width, bottom);
            canvas.drawRect(
                Rect.fromLTRB(
                    bounds.left,
                    row == metric.activeMetrics.first ? bounds.top : top,
                    bounds.right,
                    row == metric.activeMetrics.last ? bounds.bottom : bottom),
                Paint()
                  ..isAntiAlias = false
                  ..shader = gradient.createShader(shaderRect));
          }
          canvas.restore();
          canvas.restore();
        }, scale: scale);
        final actual = await _render((canvas) => _paintLyric(canvas, layout),
            scale: scale);
        _expectPixelsClose(actual, expected);
      }
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
        return Color.alphaBlend(withAlphaValue(highlight, opacity), base);
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
          (_, __) => Color.alphaBlend(withAlphaValue(highlight, opacity), base),
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
            : layout.style.selectedTextColor);
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
      translationTextStyle:
          const TextStyle(fontFamily: 'Ahem', fontSize: 16, color: Colors.blue),
      activeTranslationTextStyle: const TextStyle(color: Colors.green),
      selectedTranslationTextColor: Colors.orange,
    );
    final layout = LyricLayout.compute(
        LyricDocument(lines: [
          LyricLine(start: Duration.zero, text: _text, translation: 'BB'),
        ]),
        ResolvedPreset(style),
        _size);
    addTearDown(layout.dispose);
    final metric = layout.metrics.single;
    final expected =
        await _render((canvas) => _paintLyric(canvas, layout, active: false));
    await _render((canvas) => _paintLyric(canvas, layout));
    final activeSpan = metric.activeTranslationTextPainter.text;
    await _render((canvas) => _paintLyric(canvas, layout));
    expect(metric.activeTranslationTextPainter.text, same(activeSpan));
    expect((activeSpan! as TextSpan).style!.color, Colors.green);
    await _render((canvas) => _paintLyric(canvas, layout, selecting: true));
    expect((metric.activeTranslationTextPainter.text! as TextSpan).style!.color,
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
