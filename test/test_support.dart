import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/src/rendering/lyric_viewport.dart';
import 'package:flutter_lyric/src/view/lyric_view_session.dart';

// Test resource disposal and independent pixel math on both Flutter generations.
void disposeNative(dynamic object) {
  try {
    object.dispose();
  } on NoSuchMethodError {/* Flutter 2 GC ownership. */}
}

final bool _floatColors = _detectFloatColors();
bool _detectFloatColors() {
  try {
    (const Color(0xFFFFFFFF) as dynamic).withValues(alpha: 1.0);
    return true;
  } on NoSuchMethodError {
    return false;
  }
}

double channel(Color color, String name) {
  if (_floatColors) {
    final dynamic value = color;
    switch (name) {
      case 'a':
        return value.a as double;
      case 'r':
        return value.r as double;
      case 'g':
        return value.g as double;
      default:
        return value.b as double;
    }
  }
  // ignore: deprecated_member_use
  final packed = color.value;
  final shift = name == 'a'
      ? 24
      : name == 'r'
          ? 16
          : name == 'g'
              ? 8
              : 0;
  return ((packed >> shift) & 255) / 255;
}

Color withAlphaValue(Color color, double alpha) => _floatColors
    ? (color as dynamic).withValues(alpha: alpha) as Color
    : color.withAlpha((alpha * 255).round());

// Paint stores colors at engine precision; allow one channel step when
// comparing a recorded Canvas color with a framework Color.
Matcher colorCloseTo(Color expected) => predicate<Color>(
    (actual) => ['a', 'r', 'g', 'b'].every((name) =>
        (channel(actual, name) - channel(expected, name)).abs() <= 1 / 255),
    'color close to $expected');

LyricViewSession session(WidgetTester tester, {int at = 0}) => tester
    .renderObject<RenderLyricViewport>(find.byType(LyricViewport).at(at))
    .session;

class PaintedDot {
  final Offset center;
  final double radius;
  final Color color;
  const PaintedDot(this.center, this.radius, this.color);
}

// Flutter 2 does not export the modern `paints` matcher. Record the viewport's
// Canvas calls directly so the same assertions exercise both SDK generations.
class _DotRecordingCanvas implements Canvas {
  final List<PaintedDot> dots = [];
  @override
  void drawCircle(Offset center, double radius, Paint paint) =>
      dots.add(PaintedDot(center, radius, paint.color));
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _DotPaintingContext implements PaintingContext {
  _DotPaintingContext(this.canvas);
  @override
  final Canvas canvas;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Inspect the actual viewport display list, including active-line intros
/// where there is no lyric paragraph to paint.
List<PaintedDot> countdownDots(WidgetTester tester, {int at = 0}) {
  final canvas = _DotRecordingCanvas();
  tester
      .renderObject<RenderLyricViewport>(find.byType(LyricViewport).at(at))
      .paint(_DotPaintingContext(canvas), Offset.zero);
  return canvas.dots;
}

Widget host(LyricController controller,
        {LyricPreset? preset,
        ValueChanged<LyricLineDetails>? onLineTap,
        ValueChanged<LyricLineDetails?>? onSelectionChanged,
        ValueChanged<bool>? onFollowChanged,
        Object? viewId,
        TextDirection direction = TextDirection.ltr,
        Size size = const Size(400, 240)}) =>
    Directionality(
      textDirection: direction,
      child: Center(
          child: SizedBox.fromSize(
              size: size,
              child: LyricView(
                  controller: controller,
                  preset: preset,
                  viewId: viewId,
                  onLineTap: onLineTap,
                  onSelectionChanged: onSelectionChanged,
                  onFollowChanged: onFollowChanged))),
    );

LyricDocument lines({int count = 30, Duration offset = Duration.zero}) =>
    LyricDocument(
        offset: offset,
        lines: List.generate(
            count,
            (i) => LyricLine(
                    start: Duration(seconds: i),
                    text: 'Line $i',
                    translation: 'Translation $i',
                    words: [
                      LyricWord(
                          text: 'Line $i',
                          start: Duration(seconds: i),
                          end: Duration(seconds: i + 1))
                    ])));

const quietPreset = LyricPreset(
  countdown: LyricCountdown.none(),
  textStyle:
      TextStyle(fontFamily: 'Ahem', fontSize: 14, color: Color(0xFF808080)),
  activeTextStyle: TextStyle(fontSize: 18, color: Color(0xFFFFFFFF)),
  lineTransition: LyricLineTransition.none(),
  scrollAnimation: LyricScrollAnimation.none(),
  edgeFade: LyricEdgeFade.none(),
  resumeDelay: null,
  selectionSnapMode: LyricSelectionSnapMode.none,
);
