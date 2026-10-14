import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/src/view/lyric_view_session.dart';
import 'package:flutter_lyric/src/rendering/lyric_viewport.dart';
import 'package:flutter_lyric/src/rendering/lyric_layout.dart';
import 'package:flutter_lyric/src/rendering/lyric_word_layout.dart';
import 'package:flutter_lyric/src/rendering/resolved_preset.dart';
import 'test_support.dart' as support;

const quiet = AppleMusicLyricStyle(
  textStyle:
      TextStyle(fontFamily: 'Ahem', fontSize: 24, color: Color(0x66808080)),
  translationTextStyle: TextStyle(fontFamily: 'Ahem', fontSize: 12),
  lineAnimation: LyricAnimation(duration: Duration.zero),
  scrollAnimation: LyricScrollAnimation.none(),
  edgeFade: LyricEdgeFade.none(),
  waveAmplitude: 0,
  maxLineLag: 0,
  wordLift: 0,
  characterFloatAmplitude: 0,
  maxBlurSigma: 0,
  selectionSnapMode: LyricSelectionSnapMode.none,
  resumeDelay: null,
);

// Count explicit offscreen surfaces without invoking the host raster backend.
class LayerCountingCanvas implements Canvas {
  int layers = 0;
  @override
  void saveLayer(Rect? bounds, Paint paint) => layers++;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

LyricViewSession session(WidgetTester tester) => tester
    .renderObject<RenderLyricViewport>(find.byType(LyricViewport).first)
    .session;

Widget host(LyricController controller,
        {AppleMusicLyricStyle style = quiet,
        ValueChanged<LyricLineDetails>? onTap,
        bool reduced = false,
        bool enabled = true,
        Object? id,
        bool compare = false,
        ValueChanged<LyricLineDetails?>? onSelection,
        double textScale = 1,
        TextDirection direction = TextDirection.ltr}) =>
    MediaQuery(
      data: MediaQueryData(
          disableAnimations: reduced,
          // ignore: deprecated_member_use
          textScaleFactor: textScale),
      child: Directionality(
          textDirection: direction,
          child: Center(
            child: SizedBox(
                width: 400,
                height: 360,
                child: TickerMode(
                  enabled: enabled,
                  child: Row(children: [
                    Expanded(
                        child: AppleMusicLyricView(
                            controller: controller,
                            style: style,
                            viewId: id,
                            onLineTap: onTap,
                            onSelectionChanged: onSelection)),
                    if (compare)
                      Expanded(
                          child: LyricView(
                              controller: controller,
                              viewId: 'ordinary',
                              preset: support.quietPreset)),
                  ]),
                )),
          )),
    );

// Preserve the original Apple regression assertions against the shared layout.
LyricLayout appleLayout(
        LyricDocument document, AppleMusicLyricStyle style, double width) =>
    LyricLayout.compute(
        document, ResolvedPreset(style.toPreset()), Size(width, 360));

extension AppleLayoutAssertions on LyricLayout {
  List<LyricWordLine> get lines =>
      List.generate(metrics.length, (i) => wordLine(i + firstIndex, true));
  double get height => contentHeight(-1);
  double offsetFor(int index, LyricAnchor anchor, double height) =>
      lineTop(index, -1) +
      anchorOffsetY(index, true, anchor.target) -
      anchor.resolve(height);
}
