import 'package:flutter/painting.dart';
import 'value.dart';

/// Physical order in which dots dim; independent of content alignment.
enum LyricCountdownDirection { startToEnd, leftToRight, rightToLeft }

/// Optional countdown before the first lyric and between timed lyric lines.
/// Times are measured on the offset-corrected lyric timeline.
class LyricCountdown extends PresetValue {
  final bool enabled;

  /// Number of dots sharing [dotDuration] equally.
  final int dotCount;

  /// Total duration of sequential fading, ending at the next lyric.
  /// A gap shorter than this duration never displays dots. Must be positive.
  final Duration dotDuration;

  /// Maximum breathing time before fading. Uses only time left over after
  /// reserving [dotDuration], and never extends beyond the available gap.
  final Duration breathDuration;
  final LyricCountdownDirection direction;

  final double dotSize;
  final double dotSpacing;
  final Color? color;
  final Color? inactiveColor;

  /// Reserved height for the dots, excluding [spacing].
  final double height;
  final double spacing;

  const LyricCountdown({
    this.enabled = true,
    this.dotCount = 3,
    this.dotDuration = const Duration(seconds: 3),
    this.breathDuration = Duration.zero,
    this.direction = LyricCountdownDirection.startToEnd,
    this.dotSize = 8,
    this.dotSpacing = 8,
    this.color,
    this.inactiveColor,
    this.height = 24,
    this.spacing = 16,
  })  : assert(dotCount > 0),
        assert(dotSize > 0 && dotSize < double.infinity),
        assert(dotSpacing >= 0 && dotSpacing < double.infinity),
        assert(height > 0 && height < double.infinity),
        assert(spacing >= 0 && spacing < double.infinity);

  const LyricCountdown.none() : this(enabled: false);

  LyricCountdown copyWith({
    bool? enabled,
    int? dotCount,
    Duration? dotDuration,
    Duration? breathDuration,
    LyricCountdownDirection? direction,
    double? dotSize,
    double? dotSpacing,
    Color? color,
    bool clearColor = false,
    Color? inactiveColor,
    bool clearInactiveColor = false,
    double? height,
    double? spacing,
  }) {
    if ((clearColor && color != null) ||
        (clearInactiveColor && inactiveColor != null)) {
      throw ArgumentError('Cannot set and clear a countdown field together.');
    }
    return LyricCountdown(
      enabled: enabled ?? this.enabled,
      dotCount: dotCount ?? this.dotCount,
      dotDuration: dotDuration ?? this.dotDuration,
      breathDuration: breathDuration ?? this.breathDuration,
      direction: direction ?? this.direction,
      dotSize: dotSize ?? this.dotSize,
      dotSpacing: dotSpacing ?? this.dotSpacing,
      color: clearColor ? null : (color ?? this.color),
      inactiveColor:
          clearInactiveColor ? null : (inactiveColor ?? this.inactiveColor),
      height: height ?? this.height,
      spacing: spacing ?? this.spacing,
    );
  }

  @override
  List<Object?> get values => [
        enabled,
        dotCount,
        dotDuration,
        breathDuration,
        direction,
        dotSize,
        dotSpacing,
        color,
        inactiveColor,
        height,
        spacing,
      ];
}
