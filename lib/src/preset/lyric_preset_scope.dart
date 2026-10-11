import 'package:flutter/widgets.dart';
import 'lyric_preset.dart';
import 'lyric_presets.dart';

/// Supplies a complete preset to descendant views. Explicit view presets
/// replace it; use [of] and copyWith for deliberate partial overrides.
class LyricPresetScope extends InheritedWidget {
  final LyricPreset preset;
  const LyricPresetScope(
      {Key? key, required this.preset, required Widget child})
      : super(key: key, child: child);

  static LyricPreset of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LyricPresetScope>()?.preset ??
      LyricPresets.aurora;

  @override
  bool updateShouldNotify(LyricPresetScope oldWidget) =>
      preset != oldWidget.preset;
}
