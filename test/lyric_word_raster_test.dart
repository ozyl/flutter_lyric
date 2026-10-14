import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/src/rendering/lyric_word_layout.dart';
import 'package:flutter_lyric/src/rendering/lyric_word_painter.dart';
import 'package:flutter_lyric/src/rendering/lyric_word_raster.dart';
import 'apple_music_test_support.dart' as apple;
import 'lyric_word_compositing_test.dart' as pixels;
import 'test_support.dart' as support;

class _CountingCanvas implements Canvas {
  int images = 0;
  int layers = 0;
  @override
  void drawImageRect(
      ui.Image image, Rect source, Rect destination, Paint paint) {
    images++;
  }

  @override
  void saveLayer(Rect? bounds, Paint paint) => layers++;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FailingImageCanvas extends _CountingCanvas {
  int imageAttempts = 0;
  int saveDepth = 0;

  @override
  void save() => saveDepth++;
  @override
  void saveLayer(Rect? bounds, Paint paint) {
    super.saveLayer(bounds, paint);
    saveDepth++;
  }

  @override
  void restore() {
    saveDepth--;
    expect(saveDepth, greaterThanOrEqualTo(0));
  }

  @override
  void drawImageRect(
      ui.Image image, Rect source, Rect destination, Paint paint) {
    imageAttempts++;
    throw Exception('Simulated deferred image rasterization failure');
  }
}

bool _syncImagesSupported() {
  final recorder = ui.PictureRecorder();
  Canvas(recorder);
  final picture = recorder.endRecording();
  try {
    support.disposeNative((picture as dynamic).toImageSync(1, 1));
    return true;
  } on NoSuchMethodError {
    return false;
  } finally {
    support.disposeNative(picture);
  }
}

void _expectDisposed(ui.Image image) {
  try {
    expect((image as dynamic).debugDisposed, isTrue);
  } on NoSuchMethodError {
    // Native disposal inspection is unavailable on older Flutter engines.
  }
}

LyricWordLine _line(String text, {double fontSize = 24}) => LyricWordLine(
    LyricLine(start: Duration.zero, text: text),
    ResolvedWordStyle(
        text: TextStyle(fontFamily: 'Ahem', fontSize: fontSize),
        translation: const TextStyle(),
        direction: TextDirection.ltr,
        textAlign: TextAlign.start,
        textScale: 1,
        locale: null,
        effects: const LyricWordEffects(),
        translationSpacing: 0),
    10000,
    const Duration(seconds: 1));

LyricDocument _document(String text, {String? timedText}) =>
    LyricDocument(lines: [
      LyricLine(start: Duration.zero, text: text, words: [
        LyricWord(
            text: timedText ?? text,
            start: Duration.zero,
            end: const Duration(seconds: 1)),
      ]),
    ]);

Future<Uint8List> _render(WidgetTester tester, void Function(Canvas) paint,
    double scale, Offset origin) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..scale(scale)
    ..translate(origin.dx, origin.dy);
  paint(canvas);
  final picture = recorder.endRecording();
  final result = await tester.runAsync(() async {
    final image =
        await picture.toImage((400 * scale).ceil(), (300 * scale).ceil());
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    support.disposeNative(image);
    return data!.buffer.asUint8List();
  });
  support.disposeNative(picture);
  return result!;
}

void _expectAlphaCeiling(
    Uint8List image, Color foreground, Color background, String context) {
  var maximum = 0;
  for (var index = 3; index < image.length; index += 4) {
    maximum = math.max(maximum, image[index]);
  }
  // Compute source-over independently: legacy Color.alphaBlend truncates its
  // integer alpha, while the engine rounds the final shader result to 8 bits.
  final foregroundAlpha = support.channel(foreground, 'a');
  final alpha = foregroundAlpha +
      support.channel(background, 'a') * (1 - foregroundAlpha);
  expect(maximum, lessThanOrEqualTo((alpha * 255).ceil()),
      reason: '$context, glyph coverage must not be applied twice');
}

void _expectSolidColor(Uint8List image, Color color, String context) {
  var greatestError = 0.0;
  final channels = [
    support.channel(color, 'r'),
    support.channel(color, 'g'),
    support.channel(color, 'b'),
  ];
  for (var index = 0; index < image.length; index += 4) {
    for (var channel = 0; channel < 3; channel++) {
      // rawRgba is premultiplied. Check even the faintest edge pixels against
      // the intended solid hue, without unpremultiplying low alpha to 8 bits.
      greatestError = math.max(
          greatestError,
          (image[index + channel] - channels[channel] * image[index + 3])
              .abs());
    }
  }
  expect(greatestError, lessThanOrEqualTo(2),
      reason: '$context, glyph edges retain the intended solid color');
}

// A cached glyph retains its local raster phase while paragraphs rasterize at
// the current canvas phase. At a fractional origin, inspect retained coverage
// and physical position separately from the aligned, exact pixel comparison.
void _expectResampledCoverage(
    Uint8List actual,
    Uint8List expected,
    LyricWordLine line,
    double scale,
    Offset origin,
    double pop,
    double Function(int) lift,
    String context) {
  final width = (400 * scale).ceil();
  final height = (300 * scale).ceil();
  final rows = line.text.computeLineMetrics();
  final boundaries = <int>[
    0,
    for (var row = 0; row < rows.length - 1; row++)
      (((rows[row].baseline +
                          rows[row].descent +
                          rows[row + 1].baseline -
                          rows[row + 1].ascent) /
                      2 +
                  origin.dy -
                  pop) *
              scale)
          .round(),
    height,
  ];
  for (var row = 0; row < boundaries.length - 1; row++) {
    var actualMass = 0.0, expectedMass = 0.0;
    var actualX = 0.0, expectedX = 0.0;
    var actualY = 0.0, expectedY = 0.0;
    for (var y = math.max(0, boundaries[row]);
        y < math.min(height, boundaries[row + 1]);
        y++) {
      for (var x = 0; x < width; x++) {
        final index = (y * width + x) * 4;
        final a = actual[index + 3] / 255;
        final e = expected[index + 3] / 255;
        actualMass += a;
        expectedMass += e;
        actualX += x * a;
        expectedX += x * e;
        actualY += y * a;
        expectedY += y * e;
      }
    }
    if (expectedMass == 0) {
      expect(actualMass, 0, reason: '$context, transparent row $row');
      continue;
    }
    // The low-DPR edge phase changes covered area by at most 2.5%, and
    // the coverage center stays within one physical pixel in each direction.
    expect(actualMass, closeTo(expectedMass, expectedMass * .025 + 1),
        reason: '$context, row $row alpha coverage');
    expect(actualX / actualMass, closeTo(expectedX / expectedMass, 1),
        reason: '$context, row $row horizontal centroid');
    expect(actualY / actualMass, closeTo(expectedY / expectedMass, 1),
        reason: '$context, row $row vertical centroid');
  }

  bool interior(Uint8List image, int x, int y) {
    final center = (y * width + x) * 4;
    if (image[center + 3] < 20) return false;
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final nearby = ((y + dy) * width + x + dx) * 4;
        for (var channel = 0; channel < 4; channel++) {
          if ((image[nearby + channel] - image[center + channel]).abs() > 1) {
            return false;
          }
        }
      }
    }
    return true;
  }

  // Check premultiplied colors only inside individual glyph slices, away from
  // their independently moving edges and the highlight's varying tail.
  var checked = 0;
  for (final character in line.characters) {
    for (final clip in character.clips) {
      final rect = Rect.fromLTRB(
              (clip.left + origin.dx) * scale,
              (clip.top + origin.dy - lift(character.ordinal)) * scale,
              (clip.right + origin.dx) * scale,
              (clip.bottom + origin.dy - lift(character.ordinal)) * scale)
          .deflate(2);
      for (var y = math.max(1, rect.top.ceil());
          y < math.min(height - 1, rect.bottom.floor());
          y++) {
        for (var x = math.max(1, rect.left.ceil());
            x < math.min(width - 1, rect.right.floor());
            x++) {
          if (!interior(actual, x, y) || !interior(expected, x, y)) continue;
          final index = (y * width + x) * 4;
          for (var channel = 0; channel < 4; channel++) {
            final a = actual[index + channel];
            final e = expected[index + channel];
            expect(a, closeTo(e, 2),
                reason: '$context, glyph interior at ($x, $y)');
          }
          checked++;
        }
      }
    }
  }
  if (scale > 1 && expected.any((channel) => channel != 0)) {
    expect(checked, greaterThan(0), reason: '$context, interior samples');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'raster cache reuses images, bounds memory, and disposes evicted entries',
      () {
    final cache = LyricWordRasterCache();
    addTearDown(cache.clear);
    final lines = List.generate(6, (i) => _line('ABCD $i'));
    addTearDown(() => lines.forEach((line) => line.dispose()));
    final first = cache.get(lines[0], 1);
    if (!_syncImagesSupported()) {
      expect(first, isNull);
      expect(cache.debugBytes, 0);
      return;
    }
    expect(first, isNotNull);
    expect(cache.get(lines[0], 1), same(first));
    final second = cache.get(lines[1], 1)!;
    cache.get(lines[2], 1);
    cache.get(lines[3], 1);
    // Reading the first image makes the second one the least recently used.
    expect(cache.get(lines[0], 1), same(first));
    cache.get(lines[4], 1);
    expect(cache.debugEntryCount, LyricWordRasterCache.maxEntries);
    expect(
        cache.debugBytes, inInclusiveRange(1, LyricWordRasterCache.maxBytes));
    _expectDisposed(second.image);
    expect(cache.get(lines[0], 1), same(first));
    final beforeDprChange = first!;
    final larger = cache.get(lines[0], 2)!;
    expect(larger, isNot(same(beforeDprChange)));
    expect(larger.bytes, greaterThan(beforeDprChange.bytes));
    expect(cache.debugEntryCount, 1);
    _expectDisposed(beforeDprChange.image);
    cache.clear();
    expect(cache.debugEntryCount, 0);
    expect(cache.debugBytes, 0);
    _expectDisposed(larger.image);
  });

  test('oversized and invalid requests fall back without retaining images', () {
    final cache = LyricWordRasterCache();
    addTearDown(cache.clear);
    final normal = _line('ABCD');
    final oversized = _line('A', fontSize: 2500);
    addTearDown(normal.dispose);
    addTearDown(oversized.dispose);
    for (final ratio in [0.0, -1.0, double.nan, double.infinity]) {
      expect(cache.get(normal, ratio), isNull);
    }
    expect(cache.get(oversized, 3), isNull);
    expect(cache.get(oversized, 3), isNull);
    expect(cache.debugEntryCount, 0);
    expect(cache.debugBytes, 0);
    final raster = cache.get(normal, 1);
    if (!_syncImagesSupported()) return;
    expect(raster, isNotNull);
    cache.reject(normal);
    expect(cache.get(normal, 1), isNull);
    expect(cache.debugEntryCount, 0);
    expect(cache.debugBytes, 0);
    _expectDisposed(raster!.image);
    cache.clear();
    expect(cache.get(normal, 1), isNotNull);
  });

  testWidgets(
      'uniform characters use cached images; partial tails stay layered',
      (tester) async {
    final controller = LyricController(document: _document('ABCD EFGH IJKL'));
    addTearDown(controller.dispose);
    final cache = LyricWordRasterCache();
    addTearDown(cache.clear);
    await tester.pumpWidget(apple.host(controller,
        style: apple.quiet.copyWith(characterFloatAmplitude: 1.4)));
    final state = apple.session(tester);
    final line = state.layout!.wordLine(0, true);
    final count = line.characters.where((c) => c.clips.isNotEmpty).length;
    for (final position in [0, 1000, 500]) {
      controller.setPosition(Duration(milliseconds: position));
      final optimized = _CountingCanvas();
      LyricWordPainter(state, rasterCache: cache)
          .paint(optimized, line, 0, .65);
      final fallback = _CountingCanvas();
      LyricWordPainter(state).paint(fallback, line, 0, .65);
      expect(fallback.images, 0);
      expect(fallback.layers, count);
      if (_syncImagesSupported()) {
        expect(optimized.images + optimized.layers, count);
        if (position == 500) {
          expect(optimized.layers, greaterThan(0));
          expect(optimized.layers, lessThan(count));
          expect(optimized.images, greaterThan(0));
        } else {
          expect(optimized.images, count);
          expect(optimized.layers, 0);
        }
      } else {
        expect(optimized.layers, count);
        expect(optimized.images, 0);
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('failed image draw rejects the atlas and balances fallback saves',
      (tester) async {
    final controller = LyricController(document: _document('ABCD'));
    addTearDown(controller.dispose);
    final cache = LyricWordRasterCache();
    addTearDown(cache.clear);
    await tester.pumpWidget(apple.host(controller,
        style: apple.quiet.copyWith(characterFloatAmplitude: 1.4)));
    final state = apple.session(tester);
    final line = state.layout!.wordLine(0, true);
    final count = line.characters.where((c) => c.clips.isNotEmpty).length;
    final canvas = _FailingImageCanvas();
    for (var frame = 1; frame <= 2; frame++) {
      LyricWordPainter(state, rasterCache: cache).paint(canvas, line, 0, 1);
      expect(canvas.imageAttempts, _syncImagesSupported() ? 1 : 0);
      expect(canvas.layers, count * frame);
      expect(canvas.saveDepth, 0);
      expect(cache.debugEntryCount, 0);
      expect(cache.debugBytes, 0);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('72 wrapped characters at DPR 3 fit the raster budget',
      (tester) async {
    final text = List.filled(6, 'ABCD EFGH I ').join();
    expect(text.characters.length, 72);
    final controller = LyricController(document: _document(text));
    addTearDown(controller.dispose);
    await tester.pumpWidget(support.host(controller,
        preset: LyricPresets.appleMusic, size: const Size(400, 360)));
    final state = support.session(tester);
    final line = state.layout!.wordLine(0, true);
    final cache = LyricWordRasterCache();
    addTearDown(cache.clear);
    final canvas = _CountingCanvas();
    LyricWordPainter(state, rasterCache: cache, pixelRatio: 3)
        .paint(canvas, line, 0, 1);
    if (_syncImagesSupported()) {
      expect(canvas.images,
          line.characters.where((c) => c.clips.isNotEmpty).length);
      expect(canvas.layers, 0);
      expect(cache.debugEntryCount, 1);
      expect(
          cache.debugBytes, lessThanOrEqualTo(LyricWordRasterCache.maxBytes));
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final highlight in [
    const LyricHighlight.none(),
    const LyricHighlight.gradient(
        LinearGradient(colors: [Color(0xFFCC2233), Color(0xFF3344DD)])),
  ]) {
    testWidgets(
        'unsupported highlight retains paragraph float: ${highlight.enabled ? 'gradient' : 'disabled'}',
        (tester) async {
      final controller = LyricController(document: _document('ABCD'));
      addTearDown(controller.dispose);
      final cache = LyricWordRasterCache();
      addTearDown(cache.clear);
      await tester.pumpWidget(apple.host(controller,
          style: apple.quiet.copyWith(
              characterFloatAmplitude: 1.4,
              characterFloatMode: LyricFloatMode.all,
              highlight: highlight)));
      final state = apple.session(tester);
      final line = state.layout!.wordLine(0, true);
      final canvas = _CountingCanvas();
      LyricWordPainter(state, rasterCache: cache).paint(canvas, line, 0, 1);
      expect(canvas.images, 0);
      expect(canvas.layers, greaterThanOrEqualTo(line.characters.length));
      expect(cache.debugEntryCount, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('unmatched characters keep their paragraph rendering',
      (tester) async {
    final controller = LyricController(
        document: _document('ABCD EFGH', timedText: 'ABCD'),
        initialPosition: const Duration(seconds: 1));
    addTearDown(controller.dispose);
    final cache = LyricWordRasterCache();
    addTearDown(cache.clear);
    await tester.pumpWidget(apple.host(controller,
        style: apple.quiet.copyWith(characterFloatAmplitude: 1.4)));
    final state = apple.session(tester);
    final line = state.layout!.wordLine(0, true);
    final canvas = _CountingCanvas();
    LyricWordPainter(state, rasterCache: cache).paint(canvas, line, 0, 1);
    final characters = line.characters.where((c) => c.clips.isNotEmpty);
    if (_syncImagesSupported()) {
      expect(canvas.layers, characters.where((c) => c.segment == null).length);
      expect(canvas.images, characters.where((c) => c.segment != null).length);
    } else {
      expect(canvas.layers, characters.length);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('view refreshes DPR and releases stale layout/font/style atlases',
      (tester) async {
    final controller = LyricController(document: _document('ABCD EFGH'));
    addTearDown(controller.dispose);
    var preset = LyricPresets.appleMusic;
    Future<void> show(double dpr, {double width = 400}) =>
        tester.pumpWidget(MediaQuery(
            data: MediaQueryData(devicePixelRatio: dpr),
            child: support.host(controller,
                preset: preset, size: Size(width, 360))));
    await show(1);
    final state = support.session(tester);
    final firstLayout = state.layout!;
    final cache = state.wordRasterCache;
    final line = firstLayout.wordLine(0, true);
    final first = cache.get(line, 1);
    await show(2);
    expect(state.layout, same(firstLayout));
    expect(state.devicePixelRatio, 2);
    if (_syncImagesSupported()) {
      expect(cache.debugEntryCount, 1);
      _expectDisposed(first!.image);
    }
    await show(2, width: 240);
    expect(state.layout, isNot(same(firstLayout)));
    final resized = state.layout!;
    state.fontsChanged();
    expect(cache.debugEntryCount, 0);
    await tester.pump();
    expect(state.layout, isNot(same(resized)));
    final beforeStyle = state.layout!.wordLine(0, true);
    preset = preset.copyWith(
        textStyle: preset.textStyle.copyWith(color: const Color(0x55336699)));
    await show(2, width: 240);
    expect(state.layout!.wordLine(0, true), isNot(same(beforeStyle)));
    controller.loadDocument(_document('NEW LYRICS'));
    expect(cache.debugEntryCount, 0);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(cache.debugEntryCount, 0);
    expect(cache.debugBytes, 0);
  });

  for (final text in ['ABCD EFGH IJKL MNOP', 'אבגד אבגד אבגד אבגד']) {
    testWidgets('cached slices retain wrapped subpixel coverage: $text',
        (tester) async {
      final controller = LyricController(document: _document(text));
      addTearDown(controller.dispose);
      for (final base in [
        const Color(0x00000000),
        const Color(0x70408020),
      ]) {
        await tester.pumpWidget(apple.host(controller,
            style: apple.quiet.copyWith(
                textStyle: TextStyle(
                    fontFamily: 'Ahem',
                    fontSize: 27.5,
                    height: 1.25,
                    color: base),
                inactiveScale: 1,
                wordLift: 2.5,
                characterFloatAmplitude: 2.7,
                highlight: const LyricHighlight.solid(Color(0xB0EEAA55),
                    tailFadeWidth: 17.3))));
        await tester.pump(const Duration(milliseconds: 1370));
        final state = apple.session(tester);
        final line = state.layout!.wordLine(0, true);
        expect(line.text.computeLineMetrics().length, greaterThan(1));
        for (final scale in [1.0, 2.75]) {
          final cache = LyricWordRasterCache();
          addTearDown(cache.clear);
          for (final origin in [
            Offset(32 / scale, 36 / scale),
            const Offset(32.35, 36.65),
          ]) {
            for (final position in [0, 351, 1000]) {
              controller.setPosition(Duration(milliseconds: position));
              final actual = await _render(
                  tester,
                  (canvas) => LyricWordPainter(state,
                          baseColor: base,
                          rasterCache: cache,
                          pixelRatio: scale)
                      .paint(canvas, line, 0, .65),
                  scale,
                  origin);
              final expected = await _render(
                  tester,
                  (canvas) => LyricWordPainter(state, baseColor: base)
                      .paint(canvas, line, 0, .65),
                  scale,
                  origin);
              final context =
                  '$text, base=$base, position=$position, scale=$scale';
              final foreground = support.withAlphaValue(const Color(0xB0EEAA55),
                  support.channel(const Color(0xB0EEAA55), 'a') * .65);
              final active = Color.alphaBlend(foreground, base);
              _expectAlphaCeiling(actual, foreground, base, context);
              if (position == 0 ||
                  position == 1000 ||
                  support.channel(base, 'a') == 0) {
                _expectSolidColor(
                    actual, position == 0 ? base : active, context);
              }
              if (origin == const Offset(32.35, 36.65)) {
                final pop = state.wordPopLift(0, line.segments.single);
                _expectResampledCoverage(
                    actual,
                    expected,
                    line,
                    scale,
                    origin,
                    pop,
                    (ordinal) => pop + state.characterFloatLift(0, ordinal),
                    context);
              } else {
                pixels.expectCoverage(actual, expected, context);
              }
            }
          }
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
