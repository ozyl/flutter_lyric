import 'dart:math' as math;
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
      if (result.duration.isNegative) {
        throw ArgumentError('Negative scroll duration.');
      }
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

/// Dual style preserves separate active/inactive wrapping. Fixed measures at
/// the active style and changes only paint transforms during playback.
enum LyricLayoutMode { dualStyle, fixed }

/// A paint transform, in logical pixels. Scale is applied around the content
/// alignment pivot, then offset; opacity and blur apply to the entire entry.
class LyricLineVisualState extends PresetValue {
  final Offset offset;
  final double scale;
  final double opacity;
  final double blurSigma;
  final double activity;
  const LyricLineVisualState(
      {this.offset = Offset.zero,
      this.scale = 1,
      this.opacity = 1,
      this.blurSigma = 0,
      this.activity = 0});

  static LyricLineVisualState lerp(
          LyricLineVisualState a, LyricLineVisualState b, double t) =>
      LyricLineVisualState(
          offset: Offset.lerp(a.offset, b.offset, t)!,
          scale: a.scale + (b.scale - a.scale) * t,
          opacity: a.opacity + (b.opacity - a.opacity) * t,
          blurSigma: a.blurSigma + (b.blurSigma - a.blurSigma) * t,
          activity: a.activity + (b.activity - a.activity) * t);

  @override
  List<Object?> get values => [offset, scale, opacity, blurSigma, activity];
}

/// Context for a pure custom transition. Return [from] at progress zero and
/// [to] at progress one. The library captures the returned state on interruption.
/// Do not perform I/O, update playback or mutate widgets from the resolver.
class LyricLineTransitionContext {
  final double progress;
  final LyricLineVisualState from;
  final LyricLineVisualState to;
  final int index;
  final int activeIndex;
  final int previousActiveIndex;
  final bool entering;
  final Rect lineRect;
  final Size viewportSize;
  const LyricLineTransitionContext(
      {required this.progress,
      required this.from,
      required this.to,
      required this.index,
      required this.activeIndex,
      required this.previousActiveIndex,
      required this.entering,
      required this.lineRect,
      required this.viewportSize});
}

typedef LyricLineTransitionResolver = LyricLineVisualState Function(
    LyricLineTransitionContext context);

/// Inactive-state modifiers. Composition adds offsets, multiplies scale and
/// opacity, and combines Gaussian blur by sqrt(sum(sigma²)), independent of order.
class LyricLineEffect extends PresetValue {
  final Offset offset;
  final double scale;
  final double opacity;
  final double blurSigma;
  const LyricLineEffect.slide(this.offset)
      : scale = 1,
        opacity = 1,
        blurSigma = 0;
  const LyricLineEffect.scale(double value)
      : scale = value,
        offset = Offset.zero,
        opacity = 1,
        blurSigma = 0,
        assert(value > 0 && value < double.infinity);
  const LyricLineEffect.fade(double value)
      : opacity = value,
        offset = Offset.zero,
        scale = 1,
        blurSigma = 0,
        assert(value >= 0 && value <= 1);
  const LyricLineEffect.blur(double value)
      : blurSigma = value,
        offset = Offset.zero,
        scale = 1,
        opacity = 1,
        assert(value >= 0 && value < double.infinity);
  @override
  List<Object?> get values => [offset, scale, opacity, blurSigma];
}

class LyricLineTransition extends PresetValue {
  final bool enabled;
  final Duration enterDuration;
  final Duration exitDuration;
  final Curve enterCurve;
  final Curve exitCurve;
  final List<LyricLineEffect> effects;
  final LyricLineTransitionResolver? resolver;

  /// Bounds for custom output, including endpoints; enforced before rendering.
  final double maxDisplacement;
  final double maxBlurSigma;
  final double maxScale;

  /// Retains the original dual-style size transition for existing presets.
  final bool legacyScale;

  const LyricLineTransition({
    this.enterDuration = const Duration(milliseconds: 200),
    this.exitDuration = const Duration(milliseconds: 200),
    this.enterCurve = Curves.easeIn,
    this.exitCurve = Curves.easeOut,
  })  : enabled = true,
        effects = const [],
        resolver = null,
        maxDisplacement = 0,
        maxBlurSigma = 0,
        maxScale = 1,
        legacyScale = true;

  const LyricLineTransition.none()
      : enabled = false,
        enterDuration = Duration.zero,
        exitDuration = Duration.zero,
        enterCurve = Curves.linear,
        exitCurve = Curves.linear,
        effects = const [],
        resolver = null,
        maxDisplacement = 0,
        maxBlurSigma = 0,
        maxScale = 1,
        legacyScale = false;

  /// Pass an immutable list when using the const constructor.
  const LyricLineTransition.effects(
    this.effects, {
    this.enterDuration = const Duration(milliseconds: 250),
    this.exitDuration = const Duration(milliseconds: 250),
    this.enterCurve = Curves.easeOutCubic,
    this.exitCurve = Curves.easeOutCubic,
  })  : enabled = true,
        resolver = null,
        maxDisplacement = 0,
        maxBlurSigma = 0,
        maxScale = 1,
        legacyScale = false;

  const LyricLineTransition.custom(
    this.resolver, {
    required this.maxDisplacement,
    required this.maxBlurSigma,
    this.maxScale = 1,
    this.effects = const [],
    this.enterDuration = const Duration(milliseconds: 250),
    this.exitDuration = const Duration(milliseconds: 250),
    this.enterCurve = Curves.easeOutCubic,
    this.exitCurve = Curves.easeOutCubic,
  })  : enabled = true,
        legacyScale = false,
        assert(maxDisplacement >= 0 && maxDisplacement < double.infinity),
        assert(maxBlurSigma >= 0 && maxBlurSigma < double.infinity),
        assert(maxScale > 0 && maxScale < double.infinity);

  LyricLineVisualState state(bool active) {
    var offset = Offset.zero;
    var scale = 1.0, opacity = 1.0, variance = 0.0;
    if (enabled && !active) {
      for (final effect in effects) {
        offset += effect.offset;
        scale *= effect.scale;
        opacity *= effect.opacity;
        variance += effect.blurSigma * effect.blurSigma;
      }
    }
    return LyricLineVisualState(
        offset: offset,
        scale: scale,
        opacity: opacity,
        blurSigma: math.sqrt(variance),
        activity: active ? 1 : 0);
  }

  double get displacementBound => math.max(maxDisplacement,
      effects.fold<double>(0, (sum, e) => sum + e.offset.distance));
  double get blurBound => math.max(maxBlurSigma, state(false).blurSigma);
  double get scaleBound => math.max(maxScale, math.max(1, state(false).scale));

  /// Changes timing without discarding built-in composition or custom code.
  LyricLineTransition copyWith(
      {Duration? enterDuration,
      Duration? exitDuration,
      Curve? enterCurve,
      Curve? exitCurve}) {
    if (!enabled) return this;
    if (legacyScale) {
      return LyricLineTransition(
          enterDuration: enterDuration ?? this.enterDuration,
          exitDuration: exitDuration ?? this.exitDuration,
          enterCurve: enterCurve ?? this.enterCurve,
          exitCurve: exitCurve ?? this.exitCurve);
    }
    return LyricLineTransition.custom(resolver,
        effects: effects,
        maxDisplacement: maxDisplacement,
        maxBlurSigma: maxBlurSigma,
        maxScale: maxScale,
        enterDuration: enterDuration ?? this.enterDuration,
        exitDuration: exitDuration ?? this.exitDuration,
        enterCurve: enterCurve ?? this.enterCurve,
        exitCurve: exitCurve ?? this.exitCurve);
  }

  @override
  List<Object?> get values => [
        enabled,
        enterDuration,
        exitDuration,
        enterCurve,
        exitCurve,
        legacyScale,
        resolver,
        maxDisplacement,
        maxBlurSigma,
        maxScale,
        ...effects
      ];
}

/// Relative row movement layered over list scrolling. Zero lag/delay is
/// synchronous; lag with a delay staggers rows; amplitude adds a damped wave.
class LyricLineMotion extends PresetValue {
  final Duration delay;
  final Duration maxDelay;
  final Duration waveDuration;
  final double waveAmplitude;
  final double maxLag;
  const LyricLineMotion(
      {this.delay = Duration.zero,
      this.maxDelay = Duration.zero,
      this.waveDuration = Duration.zero,
      this.waveAmplitude = 0,
      this.maxLag = 0})
      : assert(waveAmplitude >= 0 && waveAmplitude < double.infinity),
        assert(maxLag >= 0 && maxLag < double.infinity);
  @override
  List<Object?> get values =>
      [delay, maxDelay, waveDuration, waveAmplitude, maxLag];
}

/// Which characters in an active line receive continuous float motion.
enum LyricFloatMode {
  /// Float only where the highlight has reached, easing in with its progress.
  highlighted,

  /// Float all characters, including unplayed text and disabled highlights.
  all,
}

class LyricWordEffects extends PresetValue {
  final double lift;
  final Duration liftDuration;
  final double floatAmplitude;
  final Duration floatPeriod;
  final Duration floatStagger;
  final LyricFloatMode floatMode;
  final bool simulateTiming;
  const LyricWordEffects(
      {this.lift = 0,
      this.liftDuration = const Duration(milliseconds: 900),
      this.floatAmplitude = 0,
      this.floatPeriod = const Duration(milliseconds: 6000),
      this.floatStagger = const Duration(milliseconds: 180),
      this.floatMode = LyricFloatMode.highlighted,
      this.simulateTiming = false})
      : assert(lift >= 0 && lift < double.infinity),
        assert(floatAmplitude >= 0 && floatAmplitude < double.infinity);
  double get extent => lift + floatAmplitude;
  bool get enabled => lift > 0 || floatAmplitude > 0 || simulateTiming;
  @override
  List<Object?> get values => [
        lift,
        liftDuration,
        floatAmplitude,
        floatPeriod,
        floatStagger,
        floatMode,
        simulateTiming
      ];
}

class LyricDistanceBlur extends PresetValue {
  final double maxSigma;
  final double sigmaPerLine;
  final bool whenBrowsing;
  const LyricDistanceBlur(
      {this.maxSigma = 0, this.sigmaPerLine = 1, this.whenBrowsing = true})
      : assert(maxSigma >= 0 && maxSigma < double.infinity),
        assert(sigmaPerLine >= 0 && sigmaPerLine < double.infinity);
  @override
  List<Object?> get values => [maxSigma, sigmaPerLine, whenBrowsing];
}
