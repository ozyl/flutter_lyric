import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_lyric/core/lyric_model.dart';
import 'package:flutter_lyric/core/lyric_style.dart';
import 'package:flutter_lyric/render/lyric_layout.dart';
import 'package:flutter_lyric/widgets/mixins/lyric_line_switch_mixin.dart';

const _debugLyric = false;

class _HighlightSegment {
  final Rect rect;
  final ui.Shader shader;

  _HighlightSegment(this.rect, this.shader);
}

class LyricPainter extends CustomPainter {
  final LyricLayout layout;
  final int playIndex;
  final double scrollY;
  final double activeHighlightWidth;
  final LyricLineSwitchState switchState;
  final bool isSelecting;
  final LyricStyle style;
  final void Function(int) onAnchorIndexChange;
  final void Function(Map<int, Rect>) onShowLineRectsChange;

  LyricPainter({
    required this.layout,
    required this.playIndex,
    required this.scrollY,
    required this.onAnchorIndexChange,
    required this.activeHighlightWidth,
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

  void drawHighlight(
    Canvas canvas,
    Size size,
    TextPainter maskPainter,
    List<ui.LineMetrics> metrics, {
    double highlightTotalWidth = 0,
    double animationOpacity = 1.0,
  }) {
    if (highlightTotalWidth < 0 || animationOpacity <= 0) return;
    final activeHighlightColor = layout.style.activeHighlightColor;
    final activeHighlightGradient = layout.style.activeHighlightGradient;
    if (activeHighlightColor == null && activeHighlightGradient == null) {
      return;
    }

    final highlightFullMode = highlightTotalWidth == double.infinity;
    var accWidth = 0.0;

    final grad = activeHighlightGradient ??
        LinearGradient(colors: [activeHighlightColor!, activeHighlightColor]);

    final opColors = animationOpacity < 1.0
        ? grad.colors
            .map((c) =>
                c.withValues(alpha: (c.a * animationOpacity).clamp(0.0, 1.0)))
            .toList()
        : grad.colors;

    final extraFadeWidth = style.activeHighlightExtraFadeWidth;
    final fadeEndColor = opColors.last.withValues(alpha: 0);

    const pad = 2;
    final segments = <_HighlightSegment>[];
    Rect? layerBounds;

    void addSegment(Rect rect, ui.Shader shader) {
      segments.add(_HighlightSegment(rect, shader));
      layerBounds =
          layerBounds == null ? rect : layerBounds!.expandToInclude(rect);
    }

    for (var line in metrics) {
      if (highlightFullMode) {
        final rect = Rect.fromLTWH(
          line.left - pad,
          line.baseline - line.ascent,
          line.width + pad,
          line.ascent + line.descent,
        );
        addSegment(
          rect,
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

      final fadeEnd = highlightTotalWidth - accWidth;
      if (fadeEnd <= 0) break;

      final top = line.baseline - line.ascent;
      final height = line.ascent + line.descent;
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
        addSegment(
          solidRect,
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
        addSegment(
          fadeRect,
          LinearGradient(colors: [opColors.last, fadeEndColor])
              .createShader(fadeRect),
        );
      }

      accWidth += line.width;

      if (highlightTotalWidth <= accWidth) break;
    }

    if (segments.isNotEmpty && layerBounds != null) {
      _drawMaskedHighlightSegments(
        canvas,
        maskPainter,
        layerBounds!,
        segments,
      );
    }
  }

  void _drawMaskedHighlightSegments(
    Canvas canvas,
    TextPainter maskPainter,
    Rect bounds,
    List<_HighlightSegment> segments,
  ) {
    canvas.save();
    canvas.clipRect(bounds);
    canvas.saveLayer(bounds, Paint());
    final paint = Paint();
    for (final segment in segments) {
      paint.shader = segment.shader;
      canvas.drawRect(segment.rect, paint);
    }
    canvas.saveLayer(bounds, Paint()..blendMode = BlendMode.dstIn);
    maskPainter.paint(canvas, Offset.zero);
    canvas.restore();
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

  void drawLine(
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
    if (needsRestyle) {
      painter.text = oldSpan;
    }
    if (isActive) {
      drawHighlight(
          canvas, size, metric.activeMaskPainter, metric.activeMetrics,
          highlightTotalWidth: metric.words?.isNotEmpty == true
              ? activeHighlightWidth
              : double.infinity,
          animationOpacity: highlightOpacity);
    } else if (index == switchState.exitIndex &&
        switchState.exitAnimationValue < 1 &&
        style.enableSwitchAnimation) {
      drawHighlight(canvas, size, metric.textMaskPainter, metric.metrics,
          highlightTotalWidth: double.infinity,
          animationOpacity: highlightOpacity);
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
        switchState != oldDelegate.switchState;
    return shouldRepaint;
  }
}
