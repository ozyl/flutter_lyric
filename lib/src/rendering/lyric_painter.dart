import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../compat/painting.dart';
import '../preset/lyric_effects.dart';
import 'lyric_layout.dart';
import 'line_metrics.dart';
import 'line_transition.dart';
import 'resolved_preset.dart';

/// Pure Canvas renderer: geometry/selection callbacks never run during paint.
class LyricPainter {
  final LyricLayout layout;
  final int playIndex;
  final double scrollY;
  final double activeHighlightWidth;
  final LyricLineSwitchState switchState;
  final bool isSelecting;
  final int? selectedIndex;
  ResolvedPreset get style => layout.style;

  LyricPainter(
      {required this.layout,
      required this.playIndex,
      required this.scrollY,
      required this.activeHighlightWidth,
      this.switchState = const LyricLineSwitchState(),
      this.isSelecting = false,
      this.selectedIndex});

  static TextStyle recolor(TextStyle style, Color color) =>
      style.foreground == null
          ? style.copyWith(color: color)
          : style.copyWith(foreground: Paint()..color = color);

  void paint(Canvas canvas, Size size) {
    final first = layout.lineAtOffset(scrollY, playIndex);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(style.padding.left, 0);
    final innerSize = Size(layout.contentWidth, size.height);
    for (var i = first; i < layout.firstIndex + layout.metrics.length; i++) {
      final y = layout.lineTop(i, playIndex) - scrollY;
      if (y >= size.height) break;
      canvas.save();
      canvas.translate(0, y);
      drawLine(canvas, layout.metric(i), innerSize, i, selectedIndex == i);
      canvas.restore();
    }
    canvas.restore();
  }

  void _drawHighlightColors(
    Canvas canvas,
    List<ui.LineMetrics> metrics,
    Rect bounds, {
    double highlightTotalWidth = 0,
    double animationOpacity = 1.0,
    Color? baseColor,
  }) {
    if (highlightTotalWidth < 0 || animationOpacity <= 0) return;
    final activeHighlightColor = style.preset.highlight.color;
    final activeHighlightGradient = style.preset.highlight.gradient;
    if (activeHighlightColor == null && activeHighlightGradient == null) {
      return;
    }

    final highlightFullMode = highlightTotalWidth == double.infinity;
    var accWidth = 0.0;

    final grad = activeHighlightGradient ??
        LinearGradient(colors: [activeHighlightColor!, activeHighlightColor]);

    final opColors = animationOpacity < 1.0
        ? grad.colors
            .map((c) => colorWithOpacity(
                c, (colorOpacity(c) * animationOpacity).clamp(0.0, 1.0)))
            .toList()
        : grad.colors;

    final extraFadeWidth = style.preset.highlight.tailFadeWidth;
    final fadeEndColor = colorWithOpacity(opColors.last, 0);

    const pad = 2;
    // These rectangles only supply colors; the text mask supplies all glyph
    // antialiasing. AA on adjoining solid/fade rectangles would leave a seam.
    final paint = Paint()
      ..isAntiAlias = false
      ..blendMode = baseColor == null ? BlendMode.srcOver : BlendMode.srcIn
      ..colorFilter = baseColor == null
          ? null
          : ColorFilter.mode(baseColor, BlendMode.dstOver);
    // dstOver places the constant base behind each shader sample *before*
    // srcIn applies neutral glyph coverage. This preserves arbitrary alpha
    // without another offscreen color group. Each pixel must be colored once;
    // fill only the gaps and the unhighlighted suffixes with the base below.
    final basePaint = Paint()
      ..isAntiAlias = false
      ..color = baseColor ?? Colors.transparent
      ..blendMode = BlendMode.srcIn;
    var remainingTop = bounds.top;
    var remainingLeft = bounds.left;
    void drawBase(Rect rect) {
      if (baseColor != null && !rect.isEmpty) canvas.drawRect(rect, basePaint);
    }

    void drawSegment(Rect rect, ui.Shader shader) {
      paint.shader = shader;
      canvas.drawRect(rect, paint);
      remainingLeft = rect.right;
    }

    for (var line in metrics) {
      final top = line.baseline - line.ascent;
      final height = line.ascent + line.descent;
      // Extend the outside edges beyond the glyph coverage. Keep wrapped rows
      // adjacent so their color fields cannot overlap each other.
      final paintTop = line == metrics.first ? bounds.top : top;
      final paintBottom = line == metrics.last ? bounds.bottom : top + height;
      final fadeEnd = highlightTotalWidth - accWidth;
      if (!highlightFullMode && fadeEnd <= 0) break;
      drawBase(
          Rect.fromLTRB(bounds.left, remainingTop, bounds.right, paintTop));
      remainingTop = paintBottom;
      remainingLeft = bounds.left;
      if (highlightFullMode) {
        final rect = Rect.fromLTWH(
          line.left - pad,
          line.baseline - line.ascent,
          line.width + pad,
          line.ascent + line.descent,
        );
        drawSegment(
          Rect.fromLTRB(bounds.left, paintTop, bounds.right, paintBottom),
          LinearGradient(
            colors: opColors,
            stops: grad.stops,
            begin: grad.begin,
            end: grad.end,
            tileMode: grad.tileMode,
            transform: grad.transform,
          ).createShader(rect),
        );
        accWidth += line.width;
        continue;
      }

      final fadeWidth = extraFadeWidth > 0 ? extraFadeWidth : 0.0;
      final fadeStart = fadeEnd - fadeWidth;
      final solidEnd = fadeWidth > 0 ? fadeStart : fadeEnd;

      if (solidEnd > 0) {
        final solidRect = Rect.fromLTRB(
          line.left - pad,
          top,
          line.left + solidEnd.clamp(0.0, line.width),
          top + height,
        );
        drawSegment(
          Rect.fromLTRB(
            bounds.left,
            paintTop,
            solidEnd >= line.width ? bounds.right : solidRect.right,
            paintBottom,
          ),
          LinearGradient(
            colors: opColors,
            stops: grad.stops,
            begin: grad.begin,
            end: grad.end,
            tileMode: grad.tileMode,
            transform: grad.transform,
          ).createShader(solidRect),
        );
      }

      if (fadeWidth > 0 && fadeStart < line.width) {
        final fadeRect = Rect.fromLTRB(
          line.left + fadeStart,
          top,
          line.left + fadeEnd,
          top + height,
        );
        drawSegment(
          Rect.fromLTRB(
            fadeStart <= 0 ? bounds.left : fadeRect.left,
            paintTop,
            fadeEnd >= line.width ? bounds.right : fadeRect.right,
            paintBottom,
          ),
          LinearGradient(colors: [opColors.last, fadeEndColor])
              .createShader(fadeRect),
        );
      }

      drawBase(
          Rect.fromLTRB(remainingLeft, paintTop, bounds.right, paintBottom));

      accWidth += line.width;

      if (highlightTotalWidth <= accWidth) break;
    }
    drawBase(
        Rect.fromLTRB(bounds.left, remainingTop, bounds.right, bounds.bottom));
  }

  void _drawHighlightedText(
    Canvas canvas,
    TextPainter maskPainter,
    List<ui.LineMetrics> metrics,
    Color baseColor, {
    required double highlightTotalWidth,
    required double animationOpacity,
  }) {
    // Rasterize the glyph coverage once. Compose base/highlight colors before
    // applying that coverage, otherwise srcOver blends the AA edge twice and
    // leaves a base-colored fringe. An opaque mask also keeps highlight alpha
    // independent of the active text alpha (issue #41).
    // Bound the offscreen surfaces to this paragraph, allowing for glyph
    // overhang and antialiasing beyond the typographic line metrics.
    final bounds = (Offset.zero & maskPainter.size)
        .inflate(maskPainter.preferredLineHeight);
    canvas.saveLayer(bounds, Paint());
    maskPainter.paint(canvas, Offset.zero);
    // Unusual line metrics can overlap vertically. Keep group composition in
    // that case because independently replacing overlapping color fields would
    // apply coverage twice. Compare the same edges used by drawSegment.
    var nonOverlapping = true;
    for (var i = 1; i < metrics.length; i++) {
      final previous = metrics[i - 1];
      if (metrics[i].baseline - metrics[i].ascent <
          previous.baseline -
              previous.ascent +
              (previous.ascent + previous.descent)) {
        nonOverlapping = false;
        break;
      }
    }
    if (nonOverlapping) {
      _drawHighlightColors(canvas, metrics, bounds,
          highlightTotalWidth: highlightTotalWidth,
          animationOpacity: animationOpacity,
          baseColor: baseColor);
      canvas.restore();
      return;
    }
    canvas.saveLayer(bounds, Paint()..blendMode = BlendMode.srcIn);
    canvas.drawRect(bounds, Paint()..color = baseColor);
    _drawHighlightColors(canvas, metrics, bounds,
        highlightTotalWidth: highlightTotalWidth,
        animationOpacity: animationOpacity);
    canvas.restore();
    canvas.restore();
  }

  double handleSwitchAnimation(
    Canvas canvas,
    LineMetrics metric,
    int index,
    LyricLineSwitchState switchState,
    TextPainter painter,
    Size size,
  ) {
    if (style.preset.lineTransition.enabled != true) return 0;
    double calcTranslateX(double contentWidth) {
      var transX = 0.0;
      if (style.preset.contentAlignment == LyricContentAlignment.center) {
        transX = contentWidth / 2;
      } else if (style.preset.contentAlignment == LyricContentAlignment.end) {
        transX = contentWidth;
      }
      return transX;
    }

    final transX = calcTranslateX(painter.width);
    if (index == switchState.enterIndex) {
      final enterAnimationValue = switchState.enterAnimationValue;
      final fromHeight = metric.height;
      final toHeight = metric.activeHeight;
      final transY = toHeight;
      canvas.translate(transX, transY);
      canvas.scale(
          1 - ((toHeight - fromHeight) / toHeight) * (1 - enterAnimationValue));
      canvas.translate(-transX, -transY);
    }
    // EXIT
    if (index == switchState.exitIndex) {
      final exitAnimationValue = switchState.exitAnimationValue;
      final fromHeight = metric.activeHeight;
      final toHeight = metric.height;
      final transY = 0.0;
      canvas.translate(transX, transY);
      final scale =
          ((fromHeight - toHeight) / fromHeight) * (1 - exitAnimationValue);
      canvas.scale(1 + scale);
      canvas.translate(-transX, -transY);
      return toHeight * scale;
    }
    return 0;
  }

  Color _resolveColor(TextStyle baseStyle, Color selectColor, bool isSelecting,
      bool isInAnchorArea, Color? customColor) {
    if (isSelecting && isInAnchorArea) return selectColor;
    return customColor ??
        baseStyle.color ??
        baseStyle.foreground?.color ??
        const Color(0xFF000000);
  }

  void drawLine(
    Canvas canvas,
    LineMetrics metric,
    Size size,
    int index,
    bool isInAnchorArea,
  ) {
    final isActive = playIndex == index;

    final painter = isActive ? metric.activeTextPainter : metric.textPainter;
    final oldSpan = painter.text! as TextSpan;

    double highlightOpacity = 1.0;
    Color? animatedMainColor;
    if (style.preset.lineTransition.enabled) {
      final normalColor = style.textStyle.color;
      final activeColor = style.activeTextStyle.color;

      if (index == switchState.enterIndex) {
        animatedMainColor = Color.lerp(
            normalColor, activeColor, switchState.enterAnimationValue);
        highlightOpacity = switchState.enterAnimationValue;
      } else if (index == switchState.exitIndex) {
        animatedMainColor = Color.lerp(
            activeColor, normalColor, switchState.exitAnimationValue);
        highlightOpacity = 1.0 - switchState.exitAnimationValue;
      }
    }

    final baseStyle = isActive ? style.activeTextStyle : style.textStyle;
    final targetColor = _resolveColor(baseStyle, style.selectedTextColor,
        isSelecting, isInAnchorArea, animatedMainColor);
    final hasHighlight = style.preset.highlight.color != null ||
        style.preset.highlight.gradient != null;
    final isExiting = index == switchState.exitIndex &&
        switchState.exitAnimationValue < 1 &&
        style.preset.lineTransition.enabled;
    final highlightWidth = isActive && metric.words?.isNotEmpty == true
        ? activeHighlightWidth
        : double.infinity;
    final drawHighlighted = hasHighlight &&
        (isActive || isExiting) &&
        highlightOpacity > 0 &&
        highlightWidth > 0;
    final needsRestyle = !drawHighlighted &&
        targetColor !=
            (oldSpan.style!.color ?? oldSpan.style!.foreground?.color);

    if (needsRestyle) {
      painter.text = TextSpan(
        text: oldSpan.text,
        style: recolor(oldSpan.style!, targetColor),
      );
      if (paintChangesNeedLayout) painter.layout(maxWidth: layout.contentWidth);
    }
    canvas.save();
    canvas.translate(contentOffsetX(painter.width, size.width), 0);
    final switchOffset = handleSwitchAnimation(
        canvas, metric, index, switchState, painter, size);
    if (drawHighlighted) {
      _drawHighlightedText(
        canvas,
        isActive ? metric.activeMaskPainter : metric.textMaskPainter,
        isActive ? metric.activeMetrics : metric.metrics,
        targetColor,
        highlightTotalWidth: highlightWidth,
        animationOpacity: highlightOpacity,
      );
    } else {
      painter.paint(canvas, Offset.zero);
    }
    // Keep the last painted color. Restoring the span here invalidates Flutter's
    // paragraph cache, even when the next frame uses exactly the same color.
    canvas.restore();
    final mainHeight = isActive ? metric.activeHeight : metric.height;
    if (metric.line.translation?.isNotEmpty == true) {
      final tPainter = isActive
          ? metric.activeTranslationTextPainter
          : metric.translationTextPainter;
      final tOldSpan = tPainter.text! as TextSpan;

      Color? animatedTranslationColor;
      if (style.preset.lineTransition.enabled) {
        final normalTransColor = style.translationTextStyle.color;
        final activeTransColor =
            style.activeTranslationTextStyle.color ?? normalTransColor;

        if (index == switchState.enterIndex) {
          animatedTranslationColor = Color.lerp(normalTransColor,
              activeTransColor, switchState.enterAnimationValue);
        } else if (index == switchState.exitIndex) {
          animatedTranslationColor = Color.lerp(activeTransColor,
              normalTransColor, switchState.exitAnimationValue);
        }
      }

      final tBaseColor = isActive
          ? (style.activeTranslationTextStyle.color ??
              style.translationTextStyle.color)
          : style.translationTextStyle.color;
      final tTargetColor = _resolveColor(
          recolor(tOldSpan.style!, tBaseColor ?? const Color(0xFF000000)),
          style.selectedTranslationTextColor,
          isSelecting,
          isInAnchorArea,
          animatedTranslationColor);
      final tNeedsRestyle = tTargetColor !=
          (tOldSpan.style!.color ?? tOldSpan.style!.foreground?.color);

      if (tNeedsRestyle) {
        tPainter.text = TextSpan(
          text: tOldSpan.text,
          style: recolor(tOldSpan.style!, tTargetColor),
        );
        if (paintChangesNeedLayout) {
          tPainter.layout(maxWidth: layout.contentWidth);
        }
      }
      canvas.save();
      canvas.translate(contentOffsetX(tPainter.width, size.width), 0);
      canvas.translate(0, switchOffset);
      tPainter.paint(
          canvas, Offset(0, mainHeight + style.preset.translationSpacing));
      canvas.translate(0, -switchOffset);
      canvas.restore();
    }
  }

  double contentOffsetX(double contentWidth, double containerWidth) {
    switch (style.preset.contentAlignment) {
      case LyricContentAlignment.start:
        return style.direction == TextDirection.ltr
            ? 0
            : containerWidth - contentWidth;
      case LyricContentAlignment.end:
        return style.direction == TextDirection.ltr
            ? containerWidth - contentWidth
            : 0;
      case LyricContentAlignment.center:
        return (containerWidth - contentWidth) / 2;
    }
  }
}
