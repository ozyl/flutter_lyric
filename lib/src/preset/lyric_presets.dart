import 'package:flutter/widgets.dart';
import 'lyric_effects.dart';
import 'lyric_preset.dart';

/// Complete starting points. Customize them with [LyricPreset.copyWith].
abstract class LyricPresets {
  static const LyricPreset centered = LyricPreset(
    textStyle: TextStyle(fontSize: 14, color: Color(0xB3FFFFFF)),
    activeTextStyle: TextStyle(fontSize: 18, color: Color(0x99FFFFFF)),
    activeTranslationTextStyle: TextStyle(color: Color(0xFFFFFFFF)),
    selectedTextColor: Color(0xFFFFFFFF),
    selectedTranslationTextColor: Color(0xFFFFFFFF),
    highlight: LyricHighlight.solid(Color(0xFFFFFFFF), tailFadeWidth: 24),
  );

  static const LyricPreset leading = LyricPreset(
    textStyle: TextStyle(fontSize: 14, color: Color(0xB3FFFFFF)),
    activeTextStyle: TextStyle(
        fontSize: 20, color: Color(0x99FFFFFF), fontWeight: FontWeight.w600),
    activeTranslationTextStyle: TextStyle(color: Color(0xFFFFFFFF)),
    selectedTextColor: Color(0xFFFFFFFF),
    selectedTranslationTextColor: Color(0xFFFFFFFF),
    textAlign: TextAlign.start,
    contentAlignment: LyricContentAlignment.start,
    activeAnchor: LyricAnchor.fraction(0.3, target: LyricAnchorTarget.mainText),
    selectionAnchor:
        LyricAnchor.fraction(0.5, target: LyricAnchorTarget.mainText),
    highlight: LyricHighlight.gradient(
        LinearGradient(colors: [Color(0xFF3BB2B8), Color(0xFF42E695)]),
        tailFadeWidth: 24),
  );

  /// Displays one lyric entry (including wrapping and translation).
  static const LyricPreset singleLine = LyricPreset(
    displayMode: LyricDisplayMode.activeLine,
    textStyle: TextStyle(fontSize: 14, color: Color(0xB3FFFFFF)),
    activeTextStyle: TextStyle(
        fontSize: 24, color: Color(0x99FFFFFF), fontWeight: FontWeight.w600),
    activeTranslationTextStyle: TextStyle(color: Color(0xFFFFFFFF)),
    highlight: LyricHighlight.solid(Color(0xFFFFFFFF), tailFadeWidth: 24),
    lineSpacing: 0,
    edgeFade: LyricEdgeFade.none(),
    scrollAnimation: LyricScrollAnimation.none(),
    interactive: false,
    selectionSnapMode: LyricSelectionSnapMode.none,
    resumeDelay: null,
  );
}
