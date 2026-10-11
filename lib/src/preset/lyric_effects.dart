import 'package:flutter/widgets.dart';
import 'value.dart';

enum LyricDisplayMode { scrollable, activeLine }

enum LyricContentAlignment { start, center, end }

enum LyricSelectionSnapMode { none, afterScroll, onDragPause }

enum LyricAnchorTarget { mainText, translationText, lineCenter }

/// Vertical position in the viewport and the part of a lyric aligned to it.
class LyricAnchor extends PresetValue {
  final double position;
  final bool isFraction;
  final LyricAnchorTarget target;

  const LyricAnchor.fraction(this.position,
      {this.target = LyricAnchorTarget.lineCenter})
      : isFraction = true,
        assert(position >= 0 && position <= 1);
  const LyricAnchor.pixels(this.position,
      {this.target = LyricAnchorTarget.lineCenter})
      : isFraction = false,
        assert(position >= 0 && position < double.infinity);

  double resolve(double height) => isFraction ? height * position : position;

  @override
  List<Object?> get values => [position, isFraction, target];
}

/// The played portion of a line. A gradient and a solid color are exclusive.
class LyricHighlight extends PresetValue {
  final Color? color;
  final LinearGradient? gradient;
  final double tailFadeWidth;
  bool get enabled => color != null || gradient != null;

  const LyricHighlight.none()
      : color = null,
        gradient = null,
        tailFadeWidth = 0;
  const LyricHighlight.solid(Color value, {this.tailFadeWidth = 0})
      : color = value,
        gradient = null,
        assert(tailFadeWidth >= 0 && tailFadeWidth < double.infinity);
  const LyricHighlight.gradient(LinearGradient value, {this.tailFadeWidth = 0})
      : gradient = value,
        color = null,
        assert(tailFadeWidth >= 0 && tailFadeWidth < double.infinity);

  @override
  List<Object?> get values => [color, gradient, tailFadeWidth];
}

/// Top/bottom fade distances. Overlapping fades are reduced proportionally.
class LyricEdgeFade extends PresetValue {
  final double top;
  final double bottom;
  final bool isFraction;
  final bool enabled;

  const LyricEdgeFade.none()
      : top = 0,
        bottom = 0,
        isFraction = false,
        enabled = false;
  const LyricEdgeFade.pixels({this.top = 0, this.bottom = 0})
      : isFraction = false,
        enabled = true,
        assert(top >= 0 && top < double.infinity),
        assert(bottom >= 0 && bottom < double.infinity);
  const LyricEdgeFade.fraction({this.top = 0, this.bottom = 0})
      : isFraction = true,
        enabled = true,
        assert(top >= 0 && top <= 1),
        assert(bottom >= 0 && bottom <= 1);

  List<double> resolve(double height) {
    if (!enabled || height <= 0) return const [0, 0];
    var t = isFraction ? top : top / height;
    var b = isFraction ? bottom : bottom / height;
    final total = t + b;
    if (total > 1) {
      t /= total;
      b /= total;
    }
    return [t, b];
  }

  @override
  List<Object?> get values => [top, bottom, isFraction, enabled];
}

class LyricAnimation extends PresetValue {
  final Duration duration;
  final Curve curve;
  const LyricAnimation(
      {required this.duration, this.curve = Curves.easeOutCubic});
  @override
  List<Object?> get values => [duration, curve];
}

typedef LyricScrollAnimationResolver = LyricAnimation Function(double distance);

/// Resolves a scroll animation from an absolute distance in logical pixels.
class LyricScrollAnimation extends PresetValue {
  final Duration duration;
  final Curve curve;
  final Map<double, Duration> durations;
  final LyricScrollAnimationResolver? resolver;

  const LyricScrollAnimation.none()
      : duration = Duration.zero,
        curve = Curves.linear,
        durations = const {},
        resolver = null;
  const LyricScrollAnimation.fixed({
    this.duration = const Duration(milliseconds: 240),
    this.curve = Curves.easeOutCubic,
  })  : durations = const {},
        resolver = null;

  factory LyricScrollAnimation.byDistance({
    required Map<double, Duration> durations,
    Duration duration = const Duration(milliseconds: 240),
    Curve curve = Curves.easeOutCubic,
  }) {
    if (duration.isNegative ||
        durations.entries.any((entry) =>
            !entry.key.isFinite || entry.key < 0 || entry.value.isNegative)) {
      throw ArgumentError(
          'Distances and durations must be finite and non-negative.');
    }
    final keys = durations.keys.toList()..sort();
    return LyricScrollAnimation._(duration, curve,
        Map.unmodifiable({for (final key in keys) key: durations[key]!}));
  }
  const LyricScrollAnimation._(this.duration, this.curve, this.durations)
      : resolver = null;
  const LyricScrollAnimation.custom(LyricScrollAnimationResolver value)
      : resolver = value,
        duration = Duration.zero,
        curve = Curves.linear,
        durations = const {};

  LyricAnimation resolve(double distance) {
    if (!distance.isFinite || distance < 0) throw ArgumentError.value(distance);
    if (resolver != null) {
      final result = resolver!(distance);
      if (result.duration.isNegative)
        throw ArgumentError('Negative scroll duration.');
      return result;
    }
    if (duration.isNegative) throw ArgumentError('Negative scroll duration.');
    var result = duration;
    for (final entry in durations.entries) {
      if (distance < entry.key) break;
      result = entry.value;
    }
    return LyricAnimation(duration: result, curve: curve);
  }

  @override
  List<Object?> get values => [
        duration,
        curve,
        resolver,
        for (final entry in durations.entries) ...[entry.key, entry.value]
      ];
}

class LyricLineTransition extends PresetValue {
  final bool enabled;
  final Duration enterDuration;
  final Duration exitDuration;
  final Curve enterCurve;
  final Curve exitCurve;

  const LyricLineTransition({
    this.enterDuration = const Duration(milliseconds: 200),
    this.exitDuration = const Duration(milliseconds: 200),
    this.enterCurve = Curves.easeIn,
    this.exitCurve = Curves.easeOut,
  }) : enabled = true;
  const LyricLineTransition.none()
      : enabled = false,
        enterDuration = Duration.zero,
        exitDuration = Duration.zero,
        enterCurve = Curves.linear,
        exitCurve = Curves.linear;

  @override
  List<Object?> get values =>
      [enabled, enterDuration, exitDuration, enterCurve, exitCurve];
}
