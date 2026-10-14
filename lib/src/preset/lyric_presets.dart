import 'package:flutter/widgets.dart';
import 'lyric_effects.dart';
import 'lyric_countdown.dart';
import 'lyric_preset.dart';
import 'lyric_line_transitions.dart';

/// Complete lyric styles for dark surfaces, shared with the example studio.
///
/// Customize any style with [LyricPreset.copyWith]. Backgrounds, audio playback
/// and selection controls belong to the application, not the preset.
abstract class LyricPresets {
  /// Fixed wrapping, delayed row motion, distance blur and timed word lift.
  static const LyricPreset appleMusic = LyricPreset(
    countdown: LyricCountdown(
        dotSize: 10,
        dotSpacing: 10,
        height: 32,
        spacing: 24,
        color: Color(0xFFFFFFFF),
        breathDuration: Duration(milliseconds: 1600)),
    layoutMode: LyricLayoutMode.fixed,
    translationInheritsTextStyle: false,
    textStyle: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: Color(0x99FFFFFF)),
    activeTextStyle: TextStyle(),
    translationTextStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: Color(0xB3FFFFFF)),
    textAlign: TextAlign.start,
    contentAlignment: LyricContentAlignment.start,
    padding: EdgeInsets.symmetric(horizontal: 24),
    lineSpacing: 24,
    translationSpacing: 8,
    activeAnchor: LyricAnchor.fraction(.38, target: LyricAnchorTarget.mainText),
    selectionAnchor:
        LyricAnchor.fraction(.38, target: LyricAnchorTarget.mainText),
    highlight: LyricHighlight.solid(Color(0xFFFFFFFF), tailFadeWidth: 16),
    edgeFade: LyricEdgeFade.fraction(top: .1, bottom: .15),
    scrollAnimation:
        LyricScrollAnimation.fixed(duration: Duration(milliseconds: 500)),
    lineTransition: LyricLineTransitions.appleMusic,
    lineMotion: LyricLineMotion(
        delay: Duration(milliseconds: 35),
        maxDelay: Duration(milliseconds: 140),
        waveDuration: Duration(milliseconds: 600),
        waveAmplitude: 12,
        maxLag: 64),
    wordEffects:
        LyricWordEffects(lift: 2.5, floatAmplitude: 1.4, simulateTiming: true),
    distanceBlur: LyricDistanceBlur(maxSigma: 4, whenBrowsing: false),
    jumpScrollThreshold: 1,
    selectionSnapMode: LyricSelectionSnapMode.none,
  );

  /// Moss / 苔原: leading text, soft green highlighting and generous spacing.
  ///
  /// The main text of the active entry rests at 40% of the viewport height.
  static const LyricPreset moss = LyricPreset(
    countdown: LyricCountdown(
        dotSize: 8,
        dotSpacing: 10,
        height: 30,
        spacing: 26,
        color: Color(0xFFD5EDAD),
        breathDuration: Duration(milliseconds: 1600)),
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
    lineTransition: LyricLineTransitions.rise,
  );

  /// Aurora / 极光: centered text with a mint-to-lilac word highlight.
  ///
  /// The main text stays at the middle of the viewport, with soft edge fades.
  /// This is also the default when neither a view nor a scope sets a preset.
  static const LyricPreset aurora = LyricPreset(
    countdown: LyricCountdown(
        dotSize: 8,
        dotSpacing: 12,
        height: 28,
        spacing: 26,
        color: Color(0xFF90E9EE),
        breathDuration: Duration(milliseconds: 1600)),
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
    lineTransition: LyricLineTransitions.orbit,
  );

  /// Cascade / 瀑布: staggered rows that settle in three distinct steps.
  static const LyricPreset cascade = LyricPreset(
    countdown: LyricCountdown(
        dotSize: 8,
        dotSpacing: 10,
        height: 28,
        spacing: 28,
        color: Color(0xFF9BDCEB),
        breathDuration: Duration(milliseconds: 1200)),
    layoutMode: LyricLayoutMode.fixed,
    textStyle: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: Color(0x80FFFFFF)),
    activeTextStyle: TextStyle(),
    translationTextStyle: TextStyle(fontSize: 13, color: Color(0x99FFFFFF)),
    textAlign: TextAlign.start,
    contentAlignment: LyricContentAlignment.start,
    padding: EdgeInsets.symmetric(horizontal: 28),
    lineSpacing: 28,
    translationSpacing: 9,
    activeAnchor: LyricAnchor.fraction(.38, target: LyricAnchorTarget.mainText),
    highlight: LyricHighlight.solid(Color(0xFF9BDCEB), tailFadeWidth: 28),
    edgeFade: LyricEdgeFade.fraction(top: .12, bottom: .2),
    scrollAnimation:
        LyricScrollAnimation.fixed(duration: Duration(milliseconds: 700)),
    lineTransition: LyricLineTransitions.step,
    lineMotion: LyricLineMotion(
        delay: Duration(milliseconds: 65),
        maxDelay: Duration(milliseconds: 260),
        maxLag: 90),
    jumpScrollThreshold: 1,
  );

  /// Pulse / 跃动: spring overshoot with brisk word lift, without floating.
  static const LyricPreset pulse = LyricPreset(
    countdown: LyricCountdown(
        dotSize: 10,
        dotSpacing: 8,
        height: 30,
        spacing: 30,
        color: Color(0xFFFFBE98),
        breathDuration: Duration(milliseconds: 800)),
    layoutMode: LyricLayoutMode.fixed,
    textStyle: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: Color(0x80FFFFFF)),
    activeTextStyle: TextStyle(),
    translationTextStyle: TextStyle(fontSize: 13, color: Color(0x99FFFFFF)),
    padding: EdgeInsets.symmetric(horizontal: 28),
    lineSpacing: 30,
    translationSpacing: 9,
    highlight: LyricHighlight.solid(Color(0xFFFFBE98), tailFadeWidth: 16),
    edgeFade: LyricEdgeFade.fraction(top: .12, bottom: .2),
    scrollAnimation:
        LyricScrollAnimation.fixed(duration: Duration(milliseconds: 320)),
    lineTransition: LyricLineTransitions.spring,
    wordEffects: LyricWordEffects(
        lift: 5,
        liftDuration: Duration(milliseconds: 180),
        simulateTiming: true),
    jumpScrollThreshold: 1,
  );

  /// Drift / 浮游: diagonal line drift, slow character float and spacious rows.
  static const LyricPreset drift = LyricPreset(
    countdown: LyricCountdown(
        dotSize: 7,
        dotSpacing: 14,
        height: 26,
        spacing: 44,
        color: Color(0xFFD6D3FC),
        breathDuration: Duration(milliseconds: 2400)),
    layoutMode: LyricLayoutMode.fixed,
    textStyle: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: Color(0x80FFFFFF)),
    activeTextStyle: TextStyle(),
    translationTextStyle: TextStyle(fontSize: 13, color: Color(0x99FFFFFF)),
    padding: EdgeInsets.symmetric(horizontal: 28),
    lineSpacing: 44,
    translationSpacing: 9,
    highlight: LyricHighlight.solid(Color(0xFFD6D3FC), tailFadeWidth: 42),
    edgeFade: LyricEdgeFade.fraction(top: .25, bottom: .3),
    scrollAnimation: LyricScrollAnimation.fixed(
        duration: Duration(milliseconds: 1100), curve: Curves.easeInOutCubic),
    lineTransition: LyricLineTransitions.drift,
    wordEffects: LyricWordEffects(
        floatAmplitude: 2,
        floatPeriod: Duration(milliseconds: 7200),
        floatStagger: Duration(milliseconds: 240)),
    jumpScrollThreshold: 1,
  );

  /// Cinema / 银幕: one centered entry with warm highlighting and a subtitle.
  ///
  /// Supports wrapping and translation. Scrolling, edge fades and user
  /// interaction are off; entries dissolve through a soft focus pull.
  static const LyricPreset cinema = LyricPreset(
    countdown: LyricCountdown(
        dotSize: 6,
        dotSpacing: 12,
        height: 32,
        spacing: 0,
        color: Color(0xFFE9D9B4),
        breathDuration: Duration(milliseconds: 1600)),
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
    lineTransition: LyricLineTransitions.cinematic,
    interactive: false,
    selectionSnapMode: LyricSelectionSnapMode.none,
    resumeDelay: null,
  );
}
