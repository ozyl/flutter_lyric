import 'package:flutter/widgets.dart';
import '../view/lyric_details.dart';
import 'lyric_effects.dart';
import 'lyric_countdown.dart';
import 'value.dart';

/// An immutable, reusable lyric experience: appearance, motion, interaction
/// and presentation builders. Constructing a preset starts from library
/// defaults; use [copyWith] to customize an existing or inherited preset.
class LyricPreset extends PresetValue {
  // Display
  final LyricDisplayMode displayMode;

  // Text
  final TextStyle textStyle;
  final TextStyle activeTextStyle;
  final TextStyle translationTextStyle;
  final bool translationInheritsTextStyle;
  final TextStyle activeTranslationTextStyle;
  final Color? selectedTextColor;
  final Color? selectedTranslationTextColor;

  // Layout
  final TextAlign textAlign;
  final LyricContentAlignment contentAlignment;
  final EdgeInsetsGeometry padding;
  final double lineSpacing;
  final double translationSpacing;

  // Anchors
  final LyricAnchor activeAnchor;
  final LyricAnchor selectionAnchor;

  // Effects
  final LyricHighlight highlight;
  final LyricEdgeFade edgeFade;
  final LyricCountdown countdown;

  // Animation
  final LyricScrollAnimation scrollAnimation;
  final LyricLineTransition lineTransition;

  final LyricLayoutMode layoutMode;
  final LyricLineMotion lineMotion;
  final LyricWordEffects wordEffects;
  final LyricDistanceBlur distanceBlur;

  /// Null animates any distance. Otherwise jump beyond this many view heights.
  final double? jumpScrollThreshold;

  // Interaction
  final bool interactive;
  final LyricSelectionSnapMode selectionSnapMode;
  final Duration selectionSnapDelay;
  final Duration? resumeDelay;
  final bool resumeOnTap;

  // Reusable presentation
  final WidgetBuilder? emptyBuilder;
  final LyricSelectionBuilder? selectionBackgroundBuilder;
  final LyricSelectionBuilder? selectionForegroundBuilder;

  const LyricPreset({
    this.displayMode = LyricDisplayMode.scrollable,
    this.textStyle = const TextStyle(fontSize: 14),
    this.activeTextStyle = const TextStyle(fontSize: 18),
    this.translationInheritsTextStyle = true,
    this.translationTextStyle = const TextStyle(fontSize: 12),
    this.activeTranslationTextStyle = const TextStyle(),
    this.selectedTextColor,
    this.selectedTranslationTextColor,
    this.textAlign = TextAlign.center,
    this.contentAlignment = LyricContentAlignment.center,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.lineSpacing = 20,
    this.translationSpacing = 5,
    this.activeAnchor = const LyricAnchor.fraction(0.5),
    this.selectionAnchor = const LyricAnchor.fraction(0.5),
    this.highlight = const LyricHighlight.none(),
    this.edgeFade = const LyricEdgeFade.pixels(top: 32, bottom: 32),
    this.countdown = const LyricCountdown(),
    this.scrollAnimation = const LyricScrollAnimation.fixed(),
    this.lineTransition = const LyricLineTransition(),
    this.layoutMode = LyricLayoutMode.dualStyle,
    this.lineMotion = const LyricLineMotion(),
    this.wordEffects = const LyricWordEffects(),
    this.distanceBlur = const LyricDistanceBlur(),
    this.jumpScrollThreshold,
    this.interactive = true,
    this.selectionSnapMode = LyricSelectionSnapMode.afterScroll,
    this.selectionSnapDelay = const Duration(milliseconds: 320),
    this.resumeDelay = const Duration(seconds: 3),
    this.resumeOnTap = true,
    this.emptyBuilder,
    this.selectionBackgroundBuilder,
    this.selectionForegroundBuilder,
  })  : assert(lineSpacing >= 0 && lineSpacing < double.infinity),
        assert(translationSpacing >= 0 && translationSpacing < double.infinity);

  /// Null arguments keep their current value. Clear nullable fields with the
  /// corresponding clear flag. Supplying both a value and its clear flag fails.
  LyricPreset copyWith({
    LyricDisplayMode? displayMode,
    TextStyle? textStyle,
    TextStyle? activeTextStyle,
    TextStyle? translationTextStyle,
    bool? translationInheritsTextStyle,
    TextStyle? activeTranslationTextStyle,
    Color? selectedTextColor,
    Color? selectedTranslationTextColor,
    TextAlign? textAlign,
    LyricContentAlignment? contentAlignment,
    EdgeInsetsGeometry? padding,
    double? lineSpacing,
    double? translationSpacing,
    LyricAnchor? activeAnchor,
    LyricAnchor? selectionAnchor,
    LyricHighlight? highlight,
    LyricEdgeFade? edgeFade,
    LyricCountdown? countdown,
    LyricScrollAnimation? scrollAnimation,
    LyricLineTransition? lineTransition,
    LyricLayoutMode? layoutMode,
    LyricLineMotion? lineMotion,
    LyricWordEffects? wordEffects,
    LyricDistanceBlur? distanceBlur,
    double? jumpScrollThreshold,
    bool clearJumpScrollThreshold = false,
    bool? interactive,
    LyricSelectionSnapMode? selectionSnapMode,
    Duration? selectionSnapDelay,
    Duration? resumeDelay,
    bool? resumeOnTap,
    WidgetBuilder? emptyBuilder,
    LyricSelectionBuilder? selectionBackgroundBuilder,
    LyricSelectionBuilder? selectionForegroundBuilder,
    bool clearSelectedTextColor = false,
    bool clearSelectedTranslationTextColor = false,
    bool clearResumeDelay = false,
    bool clearEmptyBuilder = false,
    bool clearSelectionBackgroundBuilder = false,
    bool clearSelectionForegroundBuilder = false,
  }) {
    if (clearJumpScrollThreshold && jumpScrollThreshold != null) {
      throw ArgumentError('Cannot set and clear jumpScrollThreshold together.');
    }
    if (clearSelectedTextColor && selectedTextColor != null) {
      throw ArgumentError('Cannot set and clear selectedTextColor together.');
    }
    if (clearSelectedTranslationTextColor &&
        selectedTranslationTextColor != null) {
      throw ArgumentError(
          'Cannot set and clear selectedTranslationTextColor together.');
    }
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
    return LyricPreset(
      displayMode: displayMode ?? this.displayMode,
      textStyle: textStyle ?? this.textStyle,
      activeTextStyle: activeTextStyle ?? this.activeTextStyle,
      translationTextStyle: translationTextStyle ?? this.translationTextStyle,
      translationInheritsTextStyle:
          translationInheritsTextStyle ?? this.translationInheritsTextStyle,
      activeTranslationTextStyle:
          activeTranslationTextStyle ?? this.activeTranslationTextStyle,
      selectedTextColor: clearSelectedTextColor
          ? null
          : (selectedTextColor ?? this.selectedTextColor),
      selectedTranslationTextColor: clearSelectedTranslationTextColor
          ? null
          : (selectedTranslationTextColor ?? this.selectedTranslationTextColor),
      textAlign: textAlign ?? this.textAlign,
      contentAlignment: contentAlignment ?? this.contentAlignment,
      padding: padding ?? this.padding,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      translationSpacing: translationSpacing ?? this.translationSpacing,
      activeAnchor: activeAnchor ?? this.activeAnchor,
      selectionAnchor: selectionAnchor ?? this.selectionAnchor,
      highlight: highlight ?? this.highlight,
      edgeFade: edgeFade ?? this.edgeFade,
      countdown: countdown ?? this.countdown,
      scrollAnimation: scrollAnimation ?? this.scrollAnimation,
      lineTransition: lineTransition ?? this.lineTransition,
      layoutMode: layoutMode ?? this.layoutMode,
      lineMotion: lineMotion ?? this.lineMotion,
      wordEffects: wordEffects ?? this.wordEffects,
      distanceBlur: distanceBlur ?? this.distanceBlur,
      jumpScrollThreshold: clearJumpScrollThreshold
          ? null
          : (jumpScrollThreshold ?? this.jumpScrollThreshold),
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
        displayMode,
        textStyle,
        activeTextStyle,
        translationTextStyle,
        translationInheritsTextStyle,
        activeTranslationTextStyle,
        selectedTextColor,
        selectedTranslationTextColor,
        textAlign,
        contentAlignment,
        padding,
        lineSpacing,
        translationSpacing,
        activeAnchor,
        selectionAnchor,
        highlight,
        edgeFade,
        countdown,
        scrollAnimation,
        lineTransition,
        layoutMode,
        lineMotion,
        wordEffects,
        distanceBlur,
        jumpScrollThreshold,
        interactive,
        selectionSnapMode,
        selectionSnapDelay,
        resumeDelay,
        resumeOnTap,
        emptyBuilder,
        selectionBackgroundBuilder,
        selectionForegroundBuilder,
      ];

  @override
  String toString() =>
      'LyricPreset($displayMode, $contentAlignment, interactive: $interactive)';
}
