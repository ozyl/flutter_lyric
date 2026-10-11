import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/src/rendering/edge_fade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_support.dart';

class _Content extends CustomPainter {
  const _Content();
  @override
  void paint(Canvas canvas, Size size) {
    // Overlapping translucent content and overhang expose accidental clipping
    // and differences between group masking and per-element opacity.
    canvas.drawRect(const Rect.fromLTWH(-8, -8, 76, 96),
        Paint()..color = const Color(0x608842CC));
    canvas.drawCircle(const Offset(32.35, 38.65), 38,
        Paint()..color = const Color(0xC0E84863));
  }

  @override
  bool shouldRepaint(_Content oldDelegate) => false;
}

void main() {
  test('fade shader is reused until its bounds or style change', () {
    final mask = EdgeFade();
    const fade = LyricEdgeFade.pixels(top: 20, bottom: 20);
    const bounds = Rect.fromLTWH(0, 0, 60, 80);
    final shader = mask.shader(bounds, fade);
    expect(mask.shader(bounds, fade), same(shader));
    expect(mask.shader(const Rect.fromLTWH(0, 0, 90, 80), fade),
        isNot(same(shader)));
    expect(mask.shader(bounds, const LyricEdgeFade.fraction(top: .4)),
        isNot(same(shader)));
  });
  for (final range in [
    const LyricEdgeFade.pixels(top: 0, bottom: 0),
    const LyricEdgeFade.fraction(top: 0, bottom: 0.25),
    const LyricEdgeFade.pixels(top: 20, bottom: 0),
    const LyricEdgeFade.pixels(top: 20, bottom: 20),
    const LyricEdgeFade.fraction(top: 0.8, bottom: 0.8),
  ]) {
    testWidgets('mask preserves pixels at ${range.top}/${range.bottom}',
        (tester) async {
      Future<Uint8List> snapshot(bool reference) async {
        final key = GlobalKey();
        const content = CustomPaint(size: Size(60, 80), painter: _Content());
        final Widget masked;
        if (reference) {
          var top = range.isFraction ? range.top : range.top / 80;
          var bottom = range.isFraction ? range.bottom : range.bottom / 80;
          if (top + bottom > 1) {
            final total = top + bottom;
            top /= total;
            bottom /= total;
          }
          masked = ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: const [
                      Colors.transparent,
                      Colors.black,
                      Colors.black,
                      Colors.transparent
                    ],
                    stops: [0, top, 1 - bottom, 1],
                  ).createShader(bounds),
              child: content);
        } else {
          masked =
              LyricEdgeMask(fade: range, cache: EdgeFade(), child: content);
        }
        await tester.pumpWidget(Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
              child: RepaintBoundary(
            key: key,
            child: Padding(
                padding: const EdgeInsets.all(12.35),
                child: SizedBox(width: 60, height: 80, child: masked)),
          )),
        ));
        return (await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1.5);
          final data = await image.toByteData();
          disposeNative(image);
          return data!.buffer.asUint8List();
        }))!;
      }

      final reference = await snapshot(true);
      final actual = await snapshot(false);
      var different = 0;
      var maxDifference = 0;
      var firstDifference = -1;
      for (var i = 0; i < actual.length; i++) {
        final delta = (actual[i] - reference[i]).abs();
        if (delta > 2) {
          different++;
          if (firstDifference < 0) firstDifference = i;
          if (delta > maxDifference) maxDifference = delta;
        }
      }
      expect(different, 0,
          reason: '$different channels, max $maxDifference, '
              'first byte $firstDifference');
    });
  }
}
