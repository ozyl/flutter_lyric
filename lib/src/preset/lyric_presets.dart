import 'package:flutter/widgets.dart';
import 'lyric_effects.dart';
import 'lyric_preset.dart';

/// Complete lyric styles for dark surfaces, shared with the example studio.
///
/// Customize any style with [LyricPreset.copyWith]. Backgrounds, audio playback
/// and selection controls belong to the application, not the preset.
abstract class LyricPresets {
  /// Moss / 苔原: leading text, soft green highlighting and generous spacing.
  ///
  /// The main text of the active entry rests at 40% of the viewport height.
  static const LyricPreset moss = LyricPreset(
    textStyle: TextStyle(fontSize: 23, color: Color(0x66FFFFFF), height: 1.35),
    activeTextStyle: TextStyle(
        fontSize: 30,
        color: Color(0x88FFFFFF),
        fontWeight: FontWeight.w600,
        height: 1.35),
    translationTextStyle:
        TextStyle(fontSize: 12, color: Color(0x66FFFFFF), height: 1.5),
    activeTranslationTextStyle:
        TextStyle(fontSize: 13, color: Color(0xCCFFFFFF), height: 1.5),
    selectedTextColor: Color(0xFFFFFFFF),
    selectedTranslationTextColor: Color(0xFFFFFFFF),
    textAlign: TextAlign.start,
    contentAlignment: LyricContentAlignment.start,
    padding: EdgeInsets.symmetric(horizontal: 28),
    lineSpacing: 26,
    translationSpacing: 9,
    activeAnchor: LyricAnchor.fraction(.4, target: LyricAnchorTarget.mainText),
    selectionAnchor:
        LyricAnchor.fraction(.5, target: LyricAnchorTarget.mainText),
    highlight: LyricHighlight.solid(Color(0xFFD5EDAD), tailFadeWidth: 28),
    edgeFade: LyricEdgeFade.fraction(top: .12, bottom: .2),
    scrollAnimation:
        LyricScrollAnimation.fixed(duration: Duration(milliseconds: 550)),
  );

  /// Aurora / 极光: centered text with a mint-to-lilac word highlight.
  ///
  /// The main text stays at the middle of the viewport, with soft edge fades.
  /// This is also the default when neither a view nor a scope sets a preset.
  static const LyricPreset aurora = LyricPreset(
    textStyle: TextStyle(fontSize: 23, color: Color(0x66FFFFFF), height: 1.35),
    activeTextStyle: TextStyle(
        fontSize: 28,
        color: Color(0x88FFFFFF),
        fontWeight: FontWeight.w600,
        height: 1.35),
    translationTextStyle:
        TextStyle(fontSize: 12, color: Color(0x66FFFFFF), height: 1.5),
    activeTranslationTextStyle:
        TextStyle(fontSize: 13, color: Color(0xCCFFFFFF), height: 1.5),
    selectedTextColor: Color(0xFFFFFFFF),
    selectedTranslationTextColor: Color(0xFFFFFFFF),
    padding: EdgeInsets.symmetric(horizontal: 28),
    lineSpacing: 26,
    translationSpacing: 9,
    activeAnchor: LyricAnchor.fraction(.5, target: LyricAnchorTarget.mainText),
    selectionAnchor:
        LyricAnchor.fraction(.5, target: LyricAnchorTarget.mainText),
    highlight: LyricHighlight.gradient(
        LinearGradient(colors: [Color(0xFF80F4D4), Color(0xFFB3A1FF)]),
        tailFadeWidth: 42),
    edgeFade: LyricEdgeFade.fraction(top: .12, bottom: .2),
    scrollAnimation:
        LyricScrollAnimation.fixed(duration: Duration(milliseconds: 550)),
  );

  /// Cinema / 银幕: one centered entry with warm highlighting and a subtitle.
  ///
  /// Supports wrapping and translation. Scrolling, edge fades and user
  /// interaction are off; changing entries retains the normal line transition.
  static const LyricPreset cinema = LyricPreset(
    displayMode: LyricDisplayMode.activeLine,
    textStyle: TextStyle(fontSize: 14, color: Color(0xB3FFFFFF)),
    activeTextStyle: TextStyle(
        fontSize: 32,
        color: Color(0x80FFFFFF),
        fontWeight: FontWeight.w500,
        height: 1.5),
    translationTextStyle: TextStyle(fontSize: 14, color: Color(0x99FFFFFF)),
    activeTranslationTextStyle: TextStyle(color: Color(0xFFFFFFFF)),
    padding: EdgeInsets.symmetric(horizontal: 28),
    translationSpacing: 18,
    highlight: LyricHighlight.solid(Color(0xFFE9D9B4), tailFadeWidth: 36),
    lineSpacing: 0,
    edgeFade: LyricEdgeFade.none(),
    scrollAnimation: LyricScrollAnimation.none(),
    interactive: false,
    selectionSnapMode: LyricSelectionSnapMode.none,
    resumeDelay: null,
  );
}
