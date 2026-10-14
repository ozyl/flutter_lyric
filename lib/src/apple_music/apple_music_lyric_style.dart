import 'package:flutter/widgets.dart';
import '../preset/lyric_effects.dart';
import '../preset/value.dart';
import '../preset/lyric_preset.dart';
import '../preset/lyric_presets.dart';
import '../view/lyric_details.dart';

/// Compatibility style for the unified LyricView Apple Music experience.
///
/// Text is measured at [textStyle]'s full size. Inactive paragraphs scale down
/// without changing wrapping. Distances are logical pixels; blur uses sigma.
/// Set wordLift/characterFloatAmplitude/maxBlurSigma/waveAmplitude/maxLineLag
/// to zero to disable those effects, inactiveScale to one to disable scaling,
/// and animation durations
/// to zero for immediate transitions. No animation clock advances playback.
class AppleMusicLyricStyle extends PresetValue {
  final TextStyle textStyle;
  final TextStyle translationTextStyle;
  final TextAlign textAlign;
  final LyricContentAlignment contentAlignment;
  final EdgeInsetsGeometry padding;
  final double lineSpacing;
  final double translationSpacing;
  final LyricAnchor activeAnchor;
  final LyricAnchor selectionAnchor;
  final LyricHighlight highlight;
  final LyricEdgeFade edgeFade;
  final double inactiveScale;
  final double inactiveOpacity;
  final double maxBlurSigma;
  final double blurSigmaPerLine;

  /// Whether distance blur remains enabled while browsing selected lyrics.
  /// Defaults to false to keep all lines crisp until playback following resumes,
  /// including while dragging, scrolling and resting on a selection.
  final bool blurWhenBrowsing;

  /// Word Pop: held lift in logical pixels, triggered by a timed word's start.
  /// Rises to this height and holds until the line becomes inactive.
  /// Set to zero to disable the rise without disabling Character Float.
  final double wordLift;

  /// Time to reach the held height, independent of the highlight duration.
  /// Zero disables the pop. Its clock follows playback, including pauses/seeks.
  final Duration wordPopDuration;

  /// Character Float: maximum +/- drift per grapheme around the Word Pop
  /// position, in logical pixels. Does not change the held lift height.
  /// Uses a view-local clock, including while playback is paused. Zero disables.
  final double characterFloatAmplitude;

  /// Nominal drift cycle around the raised position; zero disables Float.
  final Duration characterFloatPeriod;

  /// Continuous phase delay between neighboring graphemes in reading order.
  final Duration characterFloatStagger;

  /// Defaults to highlighted characters. Use [LyricFloatMode.all] to also
  /// float unplayed text or text with highlighting disabled.
  final LyricFloatMode characterFloatMode;
  final bool simulateWordTiming;
  final LyricAnimation lineAnimation;

  /// Animation for programmatic scrolling within one viewport height.
  /// Longer distances jump immediately without stagger or residual line lag.
  final LyricScrollAnimation scrollAnimation;
  final Duration waveDelay;
  final Duration maxWaveDelay;
  final Duration waveDuration;
  final double waveAmplitude;
  final double maxLineLag;
  final bool interactive;
  final LyricSelectionSnapMode selectionSnapMode;
  final Duration selectionSnapDelay;
  final Duration? resumeDelay;
  final bool resumeOnTap;
  final WidgetBuilder? emptyBuilder;
  final LyricSelectionBuilder? selectionBackgroundBuilder;
  final LyricSelectionBuilder? selectionForegroundBuilder;

  const AppleMusicLyricStyle({
    this.textStyle = const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: Color(0x99FFFFFF)),
    this.translationTextStyle = const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: Color(0xB3FFFFFF)),
    this.textAlign = TextAlign.start,
    this.contentAlignment = LyricContentAlignment.start,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
    this.lineSpacing = 24,
    this.translationSpacing = 8,
    this.activeAnchor =
        const LyricAnchor.fraction(.38, target: LyricAnchorTarget.mainText),
    this.selectionAnchor =
        const LyricAnchor.fraction(.38, target: LyricAnchorTarget.mainText),
    this.highlight =
        const LyricHighlight.solid(Color(0xFFFFFFFF), tailFadeWidth: 16),
    this.edgeFade = const LyricEdgeFade.fraction(top: .1, bottom: .15),
    this.inactiveScale = .92,
    this.inactiveOpacity = .45,
    this.maxBlurSigma = 4,
    this.blurSigmaPerLine = 1,
    this.blurWhenBrowsing = false,
    this.wordLift = 2.5,
    this.wordPopDuration = const Duration(milliseconds: 900),
    this.characterFloatAmplitude = 1.4,
    this.characterFloatPeriod = const Duration(milliseconds: 6000),
    this.characterFloatStagger = const Duration(milliseconds: 180),
    this.characterFloatMode = LyricFloatMode.highlighted,
    this.simulateWordTiming = true,
    this.lineAnimation =
        const LyricAnimation(duration: Duration(milliseconds: 250)),
    this.scrollAnimation =
        const LyricScrollAnimation.fixed(duration: Duration(milliseconds: 500)),
    this.waveDelay = const Duration(milliseconds: 35),
    this.maxWaveDelay = const Duration(milliseconds: 140),
    this.waveDuration = const Duration(milliseconds: 600),
    this.waveAmplitude = 12,
    this.maxLineLag = 64,
    this.interactive = true,
    this.selectionSnapMode = LyricSelectionSnapMode.none,
    this.selectionSnapDelay = const Duration(milliseconds: 320),
    this.resumeDelay = const Duration(seconds: 3),
    this.resumeOnTap = true,
    this.emptyBuilder,
    this.selectionBackgroundBuilder,
    this.selectionForegroundBuilder,
  })  : assert(inactiveScale > 0 && inactiveScale <= 1),
        assert(inactiveOpacity >= 0 && inactiveOpacity <= 1),
        assert(lineSpacing >= 0 && lineSpacing < double.infinity),
        assert(translationSpacing >= 0 && translationSpacing < double.infinity),
        assert(maxBlurSigma >= 0 && maxBlurSigma < double.infinity),
        assert(blurSigmaPerLine >= 0 && blurSigmaPerLine < double.infinity),
        assert(wordLift >= 0 && wordLift < double.infinity),
        assert(characterFloatAmplitude >= 0 &&
            characterFloatAmplitude < double.infinity),
        assert(waveAmplitude >= 0 && waveAmplitude < double.infinity),
        assert(maxLineLag >= 0 && maxLineLag < double.infinity);

  /// Null keeps the current value; use a clear flag to remove nullable fields.
  AppleMusicLyricStyle copyWith({
    TextStyle? textStyle,
    TextStyle? translationTextStyle,
    TextAlign? textAlign,
    LyricContentAlignment? contentAlignment,
    EdgeInsetsGeometry? padding,
    double? lineSpacing,
    double? translationSpacing,
    LyricAnchor? activeAnchor,
    LyricAnchor? selectionAnchor,
    LyricHighlight? highlight,
    LyricEdgeFade? edgeFade,
    double? inactiveScale,
    double? inactiveOpacity,
    double? maxBlurSigma,
    double? blurSigmaPerLine,
    bool? blurWhenBrowsing,
    double? wordLift,
    Duration? wordPopDuration,
    double? characterFloatAmplitude,
    Duration? characterFloatPeriod,
    Duration? characterFloatStagger,
    LyricFloatMode? characterFloatMode,
    bool? simulateWordTiming,
    LyricAnimation? lineAnimation,
    LyricScrollAnimation? scrollAnimation,
    Duration? waveDelay,
    Duration? maxWaveDelay,
    Duration? waveDuration,
    double? waveAmplitude,
    double? maxLineLag,
    bool? interactive,
    LyricSelectionSnapMode? selectionSnapMode,
    Duration? selectionSnapDelay,
    Duration? resumeDelay,
    bool? resumeOnTap,
    WidgetBuilder? emptyBuilder,
    LyricSelectionBuilder? selectionBackgroundBuilder,
    LyricSelectionBuilder? selectionForegroundBuilder,
    bool clearResumeDelay = false,
    bool clearEmptyBuilder = false,
    bool clearSelectionBackgroundBuilder = false,
    bool clearSelectionForegroundBuilder = false,
  }) {
    if (clearResumeDelay && resumeDelay != null) {
      throw ArgumentError('Cannot set and clear resumeDelay together.');
    }
    if (clearEmptyBuilder && emptyBuilder != null) {
      throw ArgumentError('Cannot set and clear emptyBuilder together.');
    }
    if (clearSelectionBackgroundBuilder && selectionBackgroundBuilder != null) {
      throw ArgumentError(
          'Cannot set and clear selectionBackgroundBuilder together.');
    }
    if (clearSelectionForegroundBuilder && selectionForegroundBuilder != null) {
      throw ArgumentError(
          'Cannot set and clear selectionForegroundBuilder together.');
    }
    return AppleMusicLyricStyle(
      textStyle: textStyle ?? this.textStyle,
      translationTextStyle: translationTextStyle ?? this.translationTextStyle,
      textAlign: textAlign ?? this.textAlign,
      contentAlignment: contentAlignment ?? this.contentAlignment,
      padding: padding ?? this.padding,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      translationSpacing: translationSpacing ?? this.translationSpacing,
      activeAnchor: activeAnchor ?? this.activeAnchor,
      selectionAnchor: selectionAnchor ?? this.selectionAnchor,
      highlight: highlight ?? this.highlight,
      edgeFade: edgeFade ?? this.edgeFade,
      inactiveScale: inactiveScale ?? this.inactiveScale,
      inactiveOpacity: inactiveOpacity ?? this.inactiveOpacity,
      maxBlurSigma: maxBlurSigma ?? this.maxBlurSigma,
      blurSigmaPerLine: blurSigmaPerLine ?? this.blurSigmaPerLine,
      blurWhenBrowsing: blurWhenBrowsing ?? this.blurWhenBrowsing,
      wordLift: wordLift ?? this.wordLift,
      wordPopDuration: wordPopDuration ?? this.wordPopDuration,
      characterFloatAmplitude:
          characterFloatAmplitude ?? this.characterFloatAmplitude,
      characterFloatPeriod: characterFloatPeriod ?? this.characterFloatPeriod,
      characterFloatStagger:
          characterFloatStagger ?? this.characterFloatStagger,
      characterFloatMode: characterFloatMode ?? this.characterFloatMode,
      simulateWordTiming: simulateWordTiming ?? this.simulateWordTiming,
      lineAnimation: lineAnimation ?? this.lineAnimation,
      scrollAnimation: scrollAnimation ?? this.scrollAnimation,
      waveDelay: waveDelay ?? this.waveDelay,
      maxWaveDelay: maxWaveDelay ?? this.maxWaveDelay,
      waveDuration: waveDuration ?? this.waveDuration,
      waveAmplitude: waveAmplitude ?? this.waveAmplitude,
      maxLineLag: maxLineLag ?? this.maxLineLag,
      interactive: interactive ?? this.interactive,
      selectionSnapMode: selectionSnapMode ?? this.selectionSnapMode,
      selectionSnapDelay: selectionSnapDelay ?? this.selectionSnapDelay,
      resumeDelay: clearResumeDelay ? null : (resumeDelay ?? this.resumeDelay),
      resumeOnTap: resumeOnTap ?? this.resumeOnTap,
      emptyBuilder:
          clearEmptyBuilder ? null : (emptyBuilder ?? this.emptyBuilder),
      selectionBackgroundBuilder: clearSelectionBackgroundBuilder
          ? null
          : (selectionBackgroundBuilder ?? this.selectionBackgroundBuilder),
      selectionForegroundBuilder: clearSelectionForegroundBuilder
          ? null
          : (selectionForegroundBuilder ?? this.selectionForegroundBuilder),
    );
  }

  @override
  List<Object?> get values => [
        textStyle,
        translationTextStyle,
        textAlign,
        contentAlignment,
        padding,
        lineSpacing,
        translationSpacing,
        activeAnchor,
        selectionAnchor,
        highlight,
        edgeFade,
        inactiveScale,
        inactiveOpacity,
        maxBlurSigma,
        blurSigmaPerLine,
        blurWhenBrowsing,
        wordLift,
        wordPopDuration,
        characterFloatAmplitude,
        characterFloatPeriod,
        characterFloatStagger,
        characterFloatMode,
        simulateWordTiming,
        lineAnimation,
        scrollAnimation,
        waveDelay,
        maxWaveDelay,
        waveDuration,
        waveAmplitude,
        maxLineLag,
        interactive,
        selectionSnapMode,
        selectionSnapDelay,
        resumeDelay,
        resumeOnTap,
        emptyBuilder,
        selectionBackgroundBuilder,
        selectionForegroundBuilder,
      ];

  /// Converts the legacy style to the same four effect layers used by LyricView.
  LyricPreset toPreset() => LyricPreset(
      countdown: LyricPresets.appleMusic.countdown.copyWith(
          color: highlight.color ?? textStyle.color, spacing: lineSpacing),
      layoutMode: LyricLayoutMode.fixed,
      textStyle: textStyle,
      activeTextStyle: const TextStyle(),
      translationTextStyle: translationTextStyle,
      translationInheritsTextStyle: false,
      textAlign: textAlign,
      contentAlignment: contentAlignment,
      padding: padding,
      lineSpacing: lineSpacing,
      translationSpacing: translationSpacing,
      activeAnchor: activeAnchor,
      selectionAnchor: selectionAnchor,
      highlight: highlight,
      edgeFade: edgeFade,
      scrollAnimation: scrollAnimation,
      lineTransition: LyricLineTransition.effects([
        LyricLineEffect.scale(inactiveScale),
        LyricLineEffect.fade(inactiveOpacity)
      ],
          enterDuration: lineAnimation.duration,
          exitDuration: lineAnimation.duration,
          enterCurve: lineAnimation.curve,
          exitCurve: lineAnimation.curve),
      lineMotion: LyricLineMotion(
          delay: waveDelay,
          maxDelay: maxWaveDelay,
          waveDuration: waveDuration,
          waveAmplitude: waveAmplitude,
          maxLag: maxLineLag),
      wordEffects: LyricWordEffects(
          lift: wordLift,
          liftDuration: wordPopDuration,
          floatAmplitude: characterFloatAmplitude,
          floatPeriod: characterFloatPeriod,
          floatStagger: characterFloatStagger,
          floatMode: characterFloatMode,
          simulateTiming: simulateWordTiming),
      distanceBlur: LyricDistanceBlur(
          maxSigma: maxBlurSigma,
          sigmaPerLine: blurSigmaPerLine,
          whenBrowsing: blurWhenBrowsing),
      jumpScrollThreshold: 1,
      interactive: interactive,
      selectionSnapMode: selectionSnapMode,
      selectionSnapDelay: selectionSnapDelay,
      resumeDelay: resumeDelay,
      resumeOnTap: resumeOnTap,
      emptyBuilder: emptyBuilder,
      selectionBackgroundBuilder: selectionBackgroundBuilder,
      selectionForegroundBuilder: selectionForegroundBuilder);

  /// Fixed headroom for both additive effects; never changes during playback.
  double get textMotionExtent => wordLift + characterFloatAmplitude;
}
