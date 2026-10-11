import 'package:flutter/widgets.dart';
import '../preset/lyric_preset.dart';

/// Ambient values are resolved once per dependency change, never per frame.
class ResolvedPreset {
  final LyricPreset preset;
  final TextStyle textStyle;
  final TextStyle activeTextStyle;
  final TextStyle translationTextStyle;
  final TextStyle activeTranslationTextStyle;
  final EdgeInsets padding;
  final TextDirection direction;
  final double textScaleFactor;
  final Locale? locale;

  ResolvedPreset(this.preset,
      {TextStyle ambient = const TextStyle(color: Color(0xFF000000)),
      this.direction = TextDirection.ltr,
      this.textScaleFactor = 1,
      this.locale})
      : textStyle = ambient.merge(preset.textStyle),
        activeTextStyle =
            ambient.merge(preset.textStyle).merge(preset.activeTextStyle),
        translationTextStyle =
            ambient.merge(preset.textStyle).merge(preset.translationTextStyle),
        activeTranslationTextStyle = ambient
            .merge(preset.textStyle)
            .merge(preset.translationTextStyle)
            .merge(preset.activeTranslationTextStyle),
        padding = preset.padding.resolve(direction);

  Color get selectedTextColor =>
      preset.selectedTextColor ??
      activeTextStyle.color ??
      activeTextStyle.foreground?.color ??
      const Color(0xFF000000);
  Color get selectedTranslationTextColor =>
      preset.selectedTranslationTextColor ??
      activeTranslationTextStyle.color ??
      activeTranslationTextStyle.foreground?.color ??
      const Color(0xFF000000);

  bool needsTextLayout(ResolvedPreset old) {
    if (direction != old.direction ||
        textScaleFactor != old.textScaleFactor ||
        locale != old.locale ||
        preset.textAlign != old.preset.textAlign) return true;
    final current = [
      textStyle,
      activeTextStyle,
      translationTextStyle,
      activeTranslationTextStyle
    ];
    final previous = [
      old.textStyle,
      old.activeTextStyle,
      old.translationTextStyle,
      old.activeTranslationTextStyle
    ];
    return List.generate(
            current.length, (i) => current[i].compareTo(previous[i]))
        .any((value) => value == RenderComparison.layout);
  }

  bool sameTextPaint(ResolvedPreset old) =>
      textStyle == old.textStyle &&
      activeTextStyle == old.activeTextStyle &&
      translationTextStyle == old.translationTextStyle &&
      activeTranslationTextStyle == old.activeTranslationTextStyle;
}
