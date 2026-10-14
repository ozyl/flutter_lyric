import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'lyric_effects.dart';

/// Reusable line changes, independent of scrolling, word effects and colors.
///
/// All list transitions retain readable inactive rows. [cinematic] fades them
/// out completely and is intended for [LyricDisplayMode.activeLine]. Retiming
/// with [LyricLineTransition.copyWith] preserves each path and its bounds.
abstract class LyricLineTransitions {
  static const none = LyricLineTransition.none();
  static const classic = LyricLineTransition();
  static const fade = LyricLineTransition.effects([LyricLineEffect.fade(.5)]);
  static const scale =
      LyricLineTransition.effects([LyricLineEffect.scale(.88)]);
  static const slide = LyricLineTransition.effects([
    LyricLineEffect.slide(Offset(24, 8)),
  ]);
  static const blur = LyricLineTransition.effects([LyricLineEffect.blur(3)]);
  static const slideFade = LyricLineTransition.effects([
    LyricLineEffect.slide(Offset(24, 8)),
    LyricLineEffect.fade(.5),
  ]);
  static const appleMusic = LyricLineTransition.effects([
    LyricLineEffect.scale(.92),
    LyricLineEffect.fade(.45),
  ]);

  /// A quiet upward entrance, suited to spacious reading layouts.
  static const rise = LyricLineTransition.effects([
    LyricLineEffect.slide(Offset(0, 10)),
    LyricLineEffect.scale(.96),
    LyricLineEffect.fade(.6),
  ],
      enterDuration: Duration(milliseconds: 600),
      exitDuration: Duration(milliseconds: 400));

  /// Horizontal movement leads the reveal, like a page sliding into place.
  static const paper = LyricLineTransition.custom(
    _paper,
    effects: [LyricLineEffect.slide(Offset(36, 0)), LyricLineEffect.fade(.5)],
    maxDisplacement: 40,
    maxBlurSigma: 0,
    enterDuration: Duration(milliseconds: 650),
    exitDuration: Duration(milliseconds: 400),
    enterCurve: Curves.linear,
    exitCurve: Curves.linear,
  );

  /// Overshoots the active size, then settles with a smaller second bounce.
  static const spring = LyricLineTransition.custom(
    _spring,
    effects: [LyricLineEffect.scale(.88), LyricLineEffect.fade(.55)],
    maxDisplacement: 12,
    maxBlurSigma: 0,
    maxScale: 1.12,
    enterDuration: Duration(milliseconds: 700),
    exitDuration: Duration(milliseconds: 350),
    enterCurve: Curves.linear,
    exitCurve: Curves.linear,
  );

  /// Incoming and outgoing lines sweep along opposite two-dimensional arcs.
  static const orbit = LyricLineTransition.custom(
    _orbit,
    effects: [LyricLineEffect.scale(.95), LyricLineEffect.fade(.55)],
    maxDisplacement: 32,
    maxBlurSigma: 0,
    enterDuration: Duration(milliseconds: 800),
    exitDuration: Duration(milliseconds: 600),
    enterCurve: Curves.linear,
    exitCurve: Curves.linear,
  );

  /// Three diminishing lateral swings; adjacent lines swing in opposite phases.
  static const pendulum = LyricLineTransition.custom(
    _pendulum,
    effects: [LyricLineEffect.scale(.94), LyricLineEffect.fade(.55)],
    maxDisplacement: 32,
    maxBlurSigma: 0,
    enterDuration: Duration(milliseconds: 1050),
    exitDuration: Duration(milliseconds: 700),
    enterCurve: Curves.linear,
    exitCurve: Curves.linear,
  );

  /// An oversized, defocused line settles into a sharp active plane.
  static const zoom = LyricLineTransition.effects([
    LyricLineEffect.scale(1.08),
    LyricLineEffect.blur(1.8),
    LyricLineEffect.fade(.5),
  ],
      enterDuration: Duration(milliseconds: 650),
      exitDuration: Duration(milliseconds: 450));

  /// Three short horizontal movements separated by holds, preserving row gaps.
  static const step = LyricLineTransition.custom(
    _step,
    effects: [LyricLineEffect.slide(Offset(12, 0)), LyricLineEffect.fade(.55)],
    maxDisplacement: 12,
    maxBlurSigma: 0,
    enterDuration: Duration(milliseconds: 450),
    exitDuration: Duration(milliseconds: 300),
    enterCurve: Curves.linear,
    exitCurve: Curves.linear,
  );

  /// A slow diagonal drift, reversing direction on departure.
  static const drift = LyricLineTransition.custom(
    _drift,
    effects: [LyricLineEffect.scale(.96), LyricLineEffect.fade(.5)],
    maxDisplacement: 20,
    maxBlurSigma: 0,
    enterDuration: Duration(milliseconds: 1100),
    exitDuration: Duration(milliseconds: 900),
    enterCurve: Curves.linear,
    exitCurve: Curves.linear,
  );

  /// Single-line dissolve: focus arrives before the new line becomes opaque.
  /// Do not use in a list unless invisible inactive lines are intentional.
  static const cinematic = LyricLineTransition.custom(
    _cinematic,
    effects: [
      LyricLineEffect.scale(1.04),
      LyricLineEffect.slide(Offset(0, 8)),
      LyricLineEffect.fade(0),
      LyricLineEffect.blur(4),
    ],
    maxDisplacement: 8,
    maxBlurSigma: 4,
    maxScale: 1.04,
    enterDuration: Duration(milliseconds: 800),
    exitDuration: Duration(milliseconds: 650),
    enterCurve: Curves.linear,
    exitCurve: Curves.linear,
  );

  /// The same focus dissolve as [cinematic], keeping neighboring rows readable.
  static const focus = LyricLineTransition.custom(
    _cinematic,
    effects: [
      LyricLineEffect.scale(1.04),
      LyricLineEffect.slide(Offset(0, 8)),
      LyricLineEffect.fade(.45),
      LyricLineEffect.blur(4),
    ],
    maxDisplacement: 8,
    maxBlurSigma: 4,
    maxScale: 1.04,
    enterDuration: Duration(milliseconds: 800),
    exitDuration: Duration(milliseconds: 650),
    enterCurve: Curves.linear,
    exitCurve: Curves.linear,
  );
}

LyricLineVisualState _base(LyricLineTransitionContext c) =>
    LyricLineVisualState.lerp(c.from, c.to,
        Curves.easeOutCubic.transform(c.progress.clamp(0.0, 1.0).toDouble()));

// The renderer also pins endpoints. Keeping the resolvers exact makes direct
// sampling useful for previews and preserves captured states during retargeting.
LyricLineVisualState? _endpoint(LyricLineTransitionContext c) =>
    c.progress <= 0 ? c.from : (c.progress >= 1 ? c.to : null);

double _amount(LyricLineTransitionContext c) =>
    (c.to.activity - c.from.activity).abs();

LyricLineVisualState _move(LyricLineVisualState base, Offset offset,
        {double scale = 0, double? opacity}) =>
    LyricLineVisualState(
        offset: base.offset + offset,
        scale: base.scale + scale,
        opacity: opacity ?? base.opacity,
        blurSigma: base.blurSigma,
        activity: base.activity);

LyricLineVisualState _paper(LyricLineTransitionContext c) {
  final endpoint = _endpoint(c);
  if (endpoint != null) return endpoint;
  final base = _base(c);
  final reveal = c.entering
      ? Curves.easeIn.transform(c.progress)
      : Curves.easeOut.transform(c.progress);
  return _move(
      base, Offset(0, -5 * math.sin(math.pi * c.progress) * _amount(c)),
      opacity: c.from.opacity + (c.to.opacity - c.from.opacity) * reveal);
}

LyricLineVisualState _spring(LyricLineTransitionContext c) {
  final endpoint = _endpoint(c);
  if (endpoint != null) return endpoint;
  final t = c.progress;
  final strength = _amount(c) * (c.entering ? 1 : .25);
  return _move(_base(c), Offset(0, -12 * math.sin(math.pi * t) * strength),
      scale: .12 * math.sin(2 * math.pi * t) * math.pow(1 - t, 1.2) * strength);
}

LyricLineVisualState _orbit(LyricLineTransitionContext c) {
  final endpoint = _endpoint(c);
  if (endpoint != null) return endpoint;
  final t = c.progress;
  final direction = c.entering ? 1.0 : -1.0;
  return _move(
      _base(c),
      Offset(26 * math.sin(math.pi * t) * direction,
              -12 * math.sin(2 * math.pi * t)) *
          _amount(c));
}

LyricLineVisualState _pendulum(LyricLineTransitionContext c) {
  final endpoint = _endpoint(c);
  if (endpoint != null) return endpoint;
  final t = c.progress;
  final direction = c.index.isEven ? 1.0 : -1.0;
  return _move(
      _base(c),
      Offset(30 * math.exp(-2 * t) * math.sin(3 * math.pi * t) * direction,
              -5 * math.sin(math.pi * t)) *
          _amount(c));
}

LyricLineVisualState _step(LyricLineTransitionContext c) {
  final endpoint = _endpoint(c);
  if (endpoint != null) return endpoint;
  final segment = c.progress * 3;
  final local = ((segment - segment.floor()) / .6).clamp(0.0, 1.0).toDouble();
  // Analytical easing avoids Cubic's solver tolerance at the short holds.
  final remaining = 1 - local;
  final t = (segment.floor() + 1 - remaining * remaining * remaining) / 3;
  return LyricLineVisualState.lerp(c.from, c.to, t);
}

LyricLineVisualState _drift(LyricLineTransitionContext c) {
  final endpoint = _endpoint(c);
  if (endpoint != null) return endpoint;
  final wave = math.sin(math.pi * c.progress) * _amount(c);
  return _move(_base(c), Offset((c.entering ? 14 : -14) * wave, -10 * wave));
}

LyricLineVisualState _cinematic(LyricLineTransitionContext c) {
  final endpoint = _endpoint(c);
  if (endpoint != null) return endpoint;
  final reveal = Curves.easeInOut.transform(c.progress);
  return _move(_base(c), Offset.zero,
      opacity: c.from.opacity + (c.to.opacity - c.from.opacity) * reveal);
}
