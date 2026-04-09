import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_lyric/core/lyric_model.dart';
import 'package:flutter_lyric/core/lyric_style.dart';
import 'package:flutter_lyric/render/lyric_layout.dart';
import 'package:flutter_lyric/widgets/mixins/lyric_line_switch_mixin.dart';

const _debugLyric = false;

class LyricPainter extends CustomPainter {
  final LyricLayout layout;
  final int playIndex;
  final double scrollY;
  final double activeHighlightWidth;
  final double charAnimationCenter;
  final LyricLineSwitchState switchState;
  final bool isSelecting;
  final LyricStyle style;
  final Function(
    int,
  ) onAnchorIndexChange;
  final Function(
    Map<int, Rect>,
  ) onShowLineRectsChange;

  LyricPainter({
    required this.layout,
    required this.playIndex,
    required this.scrollY,
    required this.onAnchorIndexChange,
    required this.activeHighlightWidth,
    this.charAnimationCenter = -1.0,
    required this.switchState,
    required this.isSelecting,
    required this.onShowLineRectsChange,
    required this.style,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final layoutStyle = layout.style;
    final lineGap = layoutStyle.lineGap;
    final metrics = layout.metrics;

    if (!_debugLyric) {
      canvas.clipRect(Rect.fromLTRB(-layoutStyle.contentPadding.left, 0,
          size.width + layoutStyle.contentPadding.right, size.height));
    }

    final selectionPosition = layout.selectionAnchorPosition;
    if (_debugLyric) {
      final activePosition = layout.activeAnchorPosition;
      final debugPaint = Paint()..color = layoutStyle.selectedColor;
      canvas.drawLine(
        Offset(0, selectionPosition),
        Offset(size.width, selectionPosition),
        debugPaint,
      );
      canvas.drawLine(
        Offset(0, activePosition),
        Offset(size.width, activePosition),
        debugPaint,
      );
    }
    var totalTranslateY = -scrollY;
    canvas.translate(0, -scrollY);
    var selectedIndex = -1;
    final showLineRects = <int, Rect>{};
    final halfLineGap = lineGap / 2;
    final contentHorizontal = layoutStyle.contentPadding.horizontal;
    final activeLineOnly = style.activeLineOnly;

    for (var i = 0; i < metrics.length; i++) {
      final isActive = i == playIndex;
      final lineHeight = layout.getLineHeight(isActive, i);
      totalTranslateY += lineHeight;
      if ((totalTranslateY + halfLineGap) >= selectionPosition &&
          selectedIndex == -1) {
        selectedIndex = i;
        onAnchorIndexChange(i);
      }
      if (totalTranslateY - lineHeight >= size.height) {
        break;
      }
      if (totalTranslateY > 0) {
        showLineRects[i] = Rect.fromLTWH(0, totalTranslateY - lineHeight,
            size.width + contentHorizontal, lineHeight);
        if (!activeLineOnly || isActive) {
          drawLine(canvas, metrics[i], size, i, selectedIndex == i);
        }
      }
      totalTranslateY += lineGap;
      if (_debugLyric) {
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, lineHeight),
            Paint()..color = Colors.purple.withAlpha(50));
      }
      canvas.translate(0, lineHeight + lineGap);
    }
    onShowLineRectsChange(showLineRects);
  }

  /// 计算单字矩形与逐行推进高亮区域的交集（与 [drawHighlight] 条带逻辑一致）。
  Rect? _highlightRectForChar(
    Rect charRect,
    List<ui.LineMetrics> metrics,
    double highlightTotalWidth,
  ) {
    if (highlightTotalWidth < 0) return null;
    if (highlightTotalWidth == double.infinity) {
      return charRect;
    }
    var accWidth = 0.0;
    for (final line in metrics) {
      final top = line.baseline - line.ascent;
      final bottom = top + line.ascent + line.descent;
      final overlapsV = charRect.top < bottom && charRect.bottom > top;
      if (!overlapsV) {
        accWidth += line.width;
        continue;
      }
      final remain = highlightTotalWidth - accWidth;
      if (remain <= 0) return null;
      final lineDrawWidth = remain < line.width ? remain : line.width;
      final hlLeft = line.left;
      final hlRight = line.left + lineDrawWidth;
      final ix1 = math.max(charRect.left, hlLeft);
      final ix2 = math.min(charRect.right, hlRight);
      if (ix2 <= ix1) return null;
      final iy1 = math.max(charRect.top, top);
      final iy2 = math.min(charRect.bottom, bottom);
      if (iy2 <= iy1) return null;
      return Rect.fromLTRB(ix1, iy1, ix2, iy2);
    }
    return null;
  }

  drawHighlight(
    Canvas canvas,
    Size size,
    List<ui.LineMetrics> metrics, {
    double highlightTotalWidth = 0,
    double animationOpacity = 1.0,
    LineMetrics? charAnimLineMetric,
    TextPainter? charAnimPainter,
    double charAnimCenter = -1.0,
  }) {
    if (highlightTotalWidth < 0 || animationOpacity <= 0) return;

    final activeHighlightColor = layout.style.activeHighlightColor;
    final activeHighlightGradient = layout.style.activeHighlightGradient;
    final hasHighlight =
        activeHighlightColor != null || activeHighlightGradient != null;

    final hasCharAnim = style.enableCharAnimation &&
        charAnimLineMetric?.allCharRects?.isNotEmpty == true &&
        charAnimPainter != null &&
        charAnimCenter >= 0;

    if (!hasHighlight && !hasCharAnim) return;

    final Paint paint = Paint()
      ..blendMode =
          animationOpacity < 1.0 ? BlendMode.srcATop : BlendMode.srcIn;

    LinearGradient? grad;
    List<Color>? opColors;
    Color? fadeEndColor;
    const pad = 2;

    if (hasHighlight) {
      grad = activeHighlightGradient ??
          LinearGradient(
              colors: [activeHighlightColor!, activeHighlightColor]);
      opColors = animationOpacity < 1.0
          ? grad.colors
              .map((c) =>
                  c.withValues(alpha: (c.a * animationOpacity).clamp(0.0, 1.0)))
              .toList()
          : grad.colors;

      final extraFadeWidth = style.activeHighlightExtraFadeWidth;
      if (extraFadeWidth > 0) {
        final baseEndColor = style.activeStyle.color ?? grad.colors.last;
        fadeEndColor = baseEndColor.withValues(
            alpha: (baseEndColor.a * animationOpacity).clamp(0.0, 1.0));
      }

      final highlightFullMode = highlightTotalWidth == double.infinity;
      var accWidth = 0.0;

      for (var line in metrics) {
        double lineDrawWidth;
        bool isFullLine;

        if (highlightFullMode) {
          isFullLine = true;
          lineDrawWidth = line.width;
        } else {
          final remain = highlightTotalWidth - accWidth;
          if (remain <= 0) break;

          lineDrawWidth = remain < line.width ? remain : line.width;
          isFullLine = remain >= line.width;
        }

        final top = line.baseline - line.ascent;
        final height = line.ascent + line.descent;

        final rect = Rect.fromLTWH(
          line.left - pad,
          top,
          lineDrawWidth + pad,
          height,
        );

        if (extraFadeWidth > 0) {
          final fadeRect = Rect.fromLTWH(
              rect.left + rect.width, rect.top, extraFadeWidth, rect.height);
          paint.shader = LinearGradient(colors: [opColors.last, fadeEndColor!])
              .createShader(fadeRect);
          canvas.drawRect(fadeRect, paint);
        }

        paint.shader = LinearGradient(
          colors: opColors,
          stops: grad.stops,
          begin: grad.begin,
          end: grad.end,
          tileMode: grad.tileMode,
          transform: grad.transform,
        ).createShader(rect);
        canvas.drawRect(rect, paint);
        accWidth += line.width;

        if (!isFullLine) break;
      }
    }

    if (!hasCharAnim || grad == null || opColors == null) {
      if (hasCharAnim && charAnimPainter != null) {
        _drawCharAnimationOnly(canvas, charAnimLineMetric!, charAnimCenter,
            charAnimPainter);
      }
      return;
    }

    final waveK = style.charAnimationWaveK;
    final maxScale = style.charAnimationMaxScale;
    final maxOffsetY = style.charAnimationMaxOffsetY;
    final allCharRects = charAnimLineMetric!.allCharRects!;
    final animPainter = charAnimPainter!;

    for (int i = 0; i < allCharRects.length; i++) {
      final d = i - charAnimCenter;
      final weight = math.exp(-d * d * waveK);
      if (weight < 0.01) continue;

      final scale = 1.0 + maxScale * weight;
      final offsetY = maxOffsetY * math.sin(weight * math.pi);

      final rect = allCharRects[i];
      final cx = rect.center.dx;
      final cy = rect.center.dy;
      final inflate = rect.height * 0.5;

      canvas.save();
      canvas.clipRect(rect.inflate(inflate));
      canvas.translate(cx, cy);
      canvas.scale(scale);
      canvas.translate(0, offsetY);
      canvas.translate(-cx, -cy);
      animPainter.paint(canvas, Offset.zero);

      final hlRect =
          _highlightRectForChar(rect, metrics, highlightTotalWidth);
      if (hlRect != null) {
        paint.shader = LinearGradient(
          colors: opColors,
          stops: grad.stops,
          begin: grad.begin,
          end: grad.end,
          tileMode: grad.tileMode,
          transform: grad.transform,
        ).createShader(hlRect);
        canvas.drawRect(hlRect, paint);
      }
      canvas.restore();
    }
  }

  void _drawCharAnimationOnly(
    Canvas canvas,
    LineMetrics metric,
    double center,
    TextPainter painter,
  ) {
    final allCharRects = metric.allCharRects;
    if (allCharRects == null || allCharRects.isEmpty || center < 0) return;

    final waveK = style.charAnimationWaveK;
    final maxScale = style.charAnimationMaxScale;
    final maxOffsetY = style.charAnimationMaxOffsetY;

    for (int i = 0; i < allCharRects.length; i++) {
      final d = i - center;
      final weight = math.exp(-d * d * waveK);
      if (weight < 0.01) continue;

      final scale = 1.0 + maxScale * weight;
      final offsetY = maxOffsetY * math.sin(weight * math.pi);

      final rect = allCharRects[i];
      final cx = rect.center.dx;
      final cy = rect.center.dy;
      final inflate = rect.height * 0.5;

      canvas.save();
      canvas.clipRect(rect.inflate(inflate));
      canvas.translate(cx, cy);
      canvas.scale(scale);
      canvas.translate(0, offsetY);
      canvas.translate(-cx, -cy);
      painter.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  double handleSwitchAnimation(
    Canvas canvas,
    LineMetrics metric,
    int index,
    LyricLineSwitchState switchState,
    TextPainter painter,
    Size size,
  ) {
    if (layout.style.enableSwitchAnimation != true) return 0;
    double calcTranslateX(double contentWidth) {
      var transX = 0.0;
      if (layout.style.contentAlignment == CrossAxisAlignment.center) {
        transX = contentWidth / 2;
      } else if (layout.style.contentAlignment == CrossAxisAlignment.end) {
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
    return customColor ?? baseStyle.color!;
  }

  drawLine(
    Canvas canvas,
    LineMetrics metric,
    Size size,
    int index,
    bool isInAnchorArea,
  ) {
    final isActive = playIndex == index;
    final layoutStyle = layout.style;

    final painter = isActive ? metric.activeTextPainter : metric.textPainter;
    final oldSpan = painter.text! as TextSpan;

    double highlightOpacity = 1.0;
    Color? animatedMainColor;
    if (style.enableSwitchAnimation) {
      final normalColor = layoutStyle.textStyle.color;
      final activeColor = layoutStyle.activeStyle.color;

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

    final targetColor = _resolveColor(oldSpan.style!, layoutStyle.selectedColor,
        isSelecting, isInAnchorArea, animatedMainColor);
    final needsRestyle = targetColor != oldSpan.style!.color;

    if (needsRestyle) {
      painter.text = TextSpan(
        text: oldSpan.text,
        style: oldSpan.style!.copyWith(color: targetColor),
      );
    }
    canvas.save();
    canvas.translate(calcContentAliginOffset(painter.width, size.width), 0);
    if (_debugLyric) {
      canvas.drawRect(
          Rect.fromLTWH(0, 0, painter.width, painter.height),
          Paint()
            ..color = !isActive
                ? Colors.blue.withAlpha(50)
                : Colors.red.withAlpha(50));
    }
    final switchOffset = handleSwitchAnimation(
        canvas, metric, index, switchState, painter, size);
    painter.paint(canvas, Offset.zero);
    if (isActive) {
      drawHighlight(
        canvas,
        size,
        metric.activeMetrics,
        highlightTotalWidth: metric.words?.isNotEmpty == true
            ? activeHighlightWidth
            : double.infinity,
        animationOpacity: highlightOpacity,
        charAnimLineMetric: metric,
        charAnimPainter: painter,
        charAnimCenter: charAnimationCenter,
      );
    } else if (index == switchState.exitIndex &&
        switchState.exitAnimationValue < 1 &&
        style.enableSwitchAnimation) {
      drawHighlight(canvas, size, metric.metrics,
          highlightTotalWidth: double.infinity,
          animationOpacity: highlightOpacity);
    }
    if (needsRestyle) {
      painter.text = oldSpan;
    }
    canvas.restore();
    final mainHeight = isActive ? metric.activeHeight : metric.height;
    if (metric.line.translation?.isNotEmpty == true) {
      final tPainter = metric.translationTextPainter;
      final tOldSpan = tPainter.text! as TextSpan;

      Color? animatedTranslationColor;
      if (style.enableSwitchAnimation) {
        final normalTransColor =
            tOldSpan.style!.color ?? layoutStyle.translationStyle.color;
        final activeTransColor =
            layoutStyle.translationActiveColor ?? normalTransColor;

        if (index == switchState.enterIndex) {
          animatedTranslationColor = Color.lerp(normalTransColor,
              activeTransColor, switchState.enterAnimationValue);
        } else if (index == switchState.exitIndex) {
          animatedTranslationColor = Color.lerp(activeTransColor,
              normalTransColor, switchState.exitAnimationValue);
        }
      }

      final tBaseColor = isActive
          ? (layoutStyle.translationActiveColor ?? tOldSpan.style!.color)
          : tOldSpan.style!.color;
      final tTargetColor = _resolveColor(
          tOldSpan.style!.copyWith(color: tBaseColor),
          layoutStyle.selectedTranslationColor,
          isSelecting,
          isInAnchorArea,
          animatedTranslationColor);
      final tNeedsRestyle = tTargetColor != tOldSpan.style!.color;

      if (tNeedsRestyle) {
        tPainter.text = TextSpan(
          text: tOldSpan.text,
          style: tOldSpan.style!.copyWith(color: tTargetColor),
        );
      }
      canvas.save();
      canvas.translate(calcContentAliginOffset(tPainter.width, size.width), 0);
      canvas.translate(0, switchOffset);
      try {
        tPainter.paint(
          canvas,
          Offset(0, mainHeight + layoutStyle.translationLineGap),
        );
      } catch (_) {
        // 避免系统字体变更触发 assert(debugSize == size);
      }
      if (tNeedsRestyle) {
        tPainter.text = tOldSpan;
      }
      canvas.translate(0, -switchOffset);
      canvas.restore();
    }
  }

  double calcContentAliginOffset(double contentWidth, double containerWidth) {
    switch (layout.style.contentAlignment) {
      case CrossAxisAlignment.start:
        return 0;
      case CrossAxisAlignment.end:
        return containerWidth - contentWidth;
      case CrossAxisAlignment.center:
        return (containerWidth - contentWidth) / 2;
      default:
        return 0;
    }
  }

  @override
  bool shouldRepaint(covariant LyricPainter oldDelegate) {
    final shouldRepaint = layout != oldDelegate.layout ||
        playIndex != oldDelegate.playIndex ||
        scrollY != oldDelegate.scrollY ||
        activeHighlightWidth != oldDelegate.activeHighlightWidth ||
        charAnimationCenter != oldDelegate.charAnimationCenter ||
        switchState != oldDelegate.switchState;
    return shouldRepaint;
  }
}
