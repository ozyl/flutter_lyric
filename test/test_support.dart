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

LyricViewSession session(WidgetTester tester, {int at = 0}) => tester
    .renderObject<RenderLyricViewport>(find.byType(LyricViewport).at(at))
    .session;

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
  textStyle:
      TextStyle(fontFamily: 'Ahem', fontSize: 14, color: Color(0xFF808080)),
  activeTextStyle: TextStyle(fontSize: 18, color: Color(0xFFFFFFFF)),
  lineTransition: LyricLineTransition.none(),
  scrollAnimation: LyricScrollAnimation.none(),
  edgeFade: LyricEdgeFade.none(),
  resumeDelay: null,
  selectionSnapMode: LyricSelectionSnapMode.none,
);
