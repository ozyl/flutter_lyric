import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_lyric/core/lyric_style.dart';
import 'package:flutter_lyric/core/lyric_styles.dart';
import 'package:flutter_lyric/widgets/mixins/lyric_mask_mixin.dart';
import 'package:flutter_test/flutter_test.dart';

class _Mask extends StatefulWidget {
  final FadeRange range;
  final Widget child;
  const _Mask({required this.range, required this.child});
  @override
  State<_Mask> createState() => _MaskState();
}

class _MaskState extends State<_Mask> with LyricMaskMixin {
  @override
  LyricStyle get style =>
      LyricStyles.default1.copyWith(fadeRange: widget.range);
  @override
  Size get lyricSize => const Size(60, 80);
  @override
  Widget build(BuildContext context) => wrapMaskIfNeed(widget.child);
}

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
  testWidgets('fade shader is reused until its bounds or style change',
      (tester) async {
    Future<ShaderMask> mask(FadeRange range) async {
      await tester.pumpWidget(Directionality(
          textDirection: TextDirection.ltr,
          child: _Mask(
              range: range, child: const SizedBox(width: 60, height: 80))));
      return tester.widget<ShaderMask>(find.byType(ShaderMask));
    }

    const bounds = Rect.fromLTWH(0, 0, 60, 80);
    final original = await mask(FadeRange(top: 20, bottom: 20));
    final shader = original.shaderCallback(bounds);
    expect(original.shaderCallback(bounds), same(shader));
    final resized = original.shaderCallback(const Rect.fromLTWH(0, 0, 90, 80));
    expect(resized, isNot(same(shader)));
    expect(original.shaderCallback(const Rect.fromLTWH(0, 0, 90, 80)),
        same(resized));
    final changed = await mask(FadeRange(top: 0.4, bottom: 0.3));
    expect(changed.shaderCallback(bounds), isNot(same(shader)));
  });
  for (final range in [
    FadeRange(top: 0, bottom: 0),
    FadeRange(top: -1, bottom: -1),
    FadeRange(top: 0, bottom: 0.25),
    FadeRange(top: 20, bottom: 0),
    FadeRange(top: 20, bottom: 0.25),
    FadeRange(top: 0.8, bottom: 0.8),
  ]) {
    testWidgets('mask preserves pixels at ${range.top}/${range.bottom}',
        (tester) async {
      Future<Uint8List> snapshot(bool reference) async {
        final key = GlobalKey();
        const content = CustomPaint(size: Size(60, 80), painter: _Content());
        final Widget masked;
        if (reference) {
          final top =
              (range.top > 1 ? range.top / 80 : range.top).clamp(0.0, 1.0);
          final bottom = (range.bottom > 1 ? range.bottom / 80 : range.bottom)
              .clamp(0.0, 1.0);
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
          masked = _Mask(range: range, child: content);
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
          image.dispose();
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
