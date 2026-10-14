import 'dart:math' as math;
import 'package:flutter/painting.dart';
import '../compat/painting.dart';
import '../preset/lyric_countdown.dart';
import '../preset/lyric_effects.dart';
import 'resolved_preset.dart';

/// Playback and viewport geometry consumed only by the Canvas renderer.
class LyricCountdownFrame {
  final int nextIndex;
  final Duration gapStart;
  final Duration gapEnd;
  final Duration displayStart;
  final Duration position;
  final bool isIntro;
  final Rect rect;
  final double dotProgress;

  const LyricCountdownFrame({
    required this.nextIndex,
    required this.gapStart,
    required this.gapEnd,
    required this.displayStart,
    required this.position,
    required this.isIntro,
    required this.rect,
    required this.dotProgress,
  });

  Duration get remaining => gapEnd - position;
  double get progress => ((position - displayStart).inMicroseconds /
          (gapEnd - displayStart).inMicroseconds)
      .clamp(0.0, 1.0)
      .toDouble();
}

/// Draws countdown dots in the lyric viewport without building Widgets.
class LyricCountdownPainter {
  final ResolvedPreset style;
  final LyricCountdownFrame frame;
  final bool animate;

  const LyricCountdownPainter(this.style, this.frame, {this.animate = true});

  void paint(Canvas canvas, Size size) {
    final rect = frame.rect;
    if (rect.isEmpty || !rect.overlaps(Offset.zero & size)) return;
    final config = style.preset.countdown;
    final active = config.color ??
        style.activeTextStyle.color ??
        style.activeTextStyle.foreground?.color ??
        const Color(0xFFFFFFFF);
    final inactive = config.inactiveColor ??
        colorWithOpacity(active, colorOpacity(active) * .2);
    final waiting = frame.remaining - config.dotDuration;
    var breath = 0.0;
    if (animate &&
        config.breathDuration > Duration.zero &&
        waiting > Duration.zero) {
      // The playback clock freezes on pause and returns every dot to its full
      // size and brightness at the boundary before sequential fading starts.
      final phase = (waiting.inMicroseconds % 1600000) / 1600000;
      breath = (1 - math.cos(phase * math.pi * 2)) / 2;
    }
    final lit =
        colorWithOpacity(active, colorOpacity(active) * (1 - .35 * breath));
    final width = config.dotCount * config.dotSize +
        (config.dotCount - 1) * config.dotSpacing;
    final scale = math.min(
        1.0, math.min(rect.width / width, rect.height / config.dotSize));
    final alignment = style.preset.contentAlignment;
    final left = rect.left +
        (rect.width - width * scale) *
            (alignment == LyricContentAlignment.center
                ? .5
                : (alignment == LyricContentAlignment.start) ==
                        (style.direction == TextDirection.ltr)
                    ? 0
                    : 1);
    final ltr = config.direction == LyricCountdownDirection.leftToRight ||
        (config.direction == LyricCountdownDirection.startToEnd &&
            style.direction == TextDirection.ltr);
    final radius = config.dotSize / 2 * scale * (1 - .14 * breath);
    final paint = Paint();
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var i = 0; i < config.dotCount; i++) {
      final column = ltr ? i : config.dotCount - 1 - i;
      paint.color = Color.lerp(lit, inactive,
          (frame.dotProgress * config.dotCount - i).clamp(0.0, 1.0))!;
      canvas.drawCircle(
          Offset(
              left +
                  (column * (config.dotSize + config.dotSpacing) +
                          config.dotSize / 2) *
                      scale,
              rect.center.dy),
          radius,
          paint);
    }
    canvas.restore();
  }
}
