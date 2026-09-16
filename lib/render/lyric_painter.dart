import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_lyric/core/lyric_model.dart';
import 'package:flutter_lyric/core/lyric_style.dart';
import 'package:flutter_lyric/render/lyric_layout.dart';
import 'package:flutter_lyric/widgets/mixins/lyric_line_switch_mixin.dart';

const _debugLyric = false;
const _highlightPad = 2.0;
const _descenderFoot = 8.0;

/// 每行着色带的整数 Y 边界，长度为行数+1。相邻行共用边界，不重叠；
/// 每行下沿至少盖住 descent 再加字脚下伸，避免 y/g/p 漏脚。
List<double> _highlightBandYs(
  List<Rect> tights,
  double painterHeight,
  double overflow,
  double pad,
) {
  if (tights.isEmpty) return const <double>[0, 0];
  final n = tights.length;
  final ys = List<double>.filled(n + 1, 0);
  ys[0] = (tights.first.top - pad).floorToDouble();
  for (var i = 1; i < n; i++) {
    ys[i] = tights[i].top.roundToDouble();
  }
  var lastBottom = tights.last.bottom;
  if (painterHeight > lastBottom) lastBottom = painterHeight;
  ys[n] = (lastBottom + overflow + _descenderFoot).ceilToDouble();
  return ys;
}

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

  bool get hasHighlightPaint =>
      layout.style.activeHighlightColor != null ||
      layout.style.activeHighlightGradient != null;

  /// 只画一层不透明字形当遮罩，再用 srcIn 分别填高亮色和未唱到的正文色。
  /// 高亮色走遮罩自身的覆盖率，不吃 activeStyle 的透明度；全程一层字形，没有 srcOver 毛刺。
  /// 返回 false 时调用方应改画普通正文。
  bool drawHighlight(
    Canvas canvas,
    TextPainter maskPainter,
    List<ui.LineMetrics> metrics, {
    required Color baseColor,
    double highlightTotalWidth = 0,
    double animationOpacity = 1.0,
  }) {
    if (highlightTotalWidth <= 0 || animationOpacity <= 0) return false;
    final activeHighlightColor = layout.style.activeHighlightColor;
    final activeHighlightGradient = layout.style.activeHighlightGradient;
    if (activeHighlightColor == null && activeHighlightGradient == null) {
      return false;
    }

    final highlightFullMode = highlightTotalWidth == double.infinity;

    final grad = activeHighlightGradient ??
        LinearGradient(colors: [activeHighlightColor!, activeHighlightColor]);

    // 切换动画期间把高亮色插值到正文色，避免单独降 alpha 把字形挖空
    final opColors = animationOpacity < 1.0
        ? grad.colors
            .map((c) => Color.lerp(baseColor, c, animationOpacity)!)
            .toList()
        : grad.colors;

    final extraFadeWidth = style.activeHighlightExtraFadeWidth;
    final fadeEndColor = baseColor;

    const pad = _highlightPad;
    final overflow = maskPainter.preferredLineHeight;
    final lineMetrics = metrics;
    final segments = <_HighlightSegment>[];
    final unsungRects = <Rect>[];

    ui.Shader highlightShader(Rect rect) => LinearGradient(
          colors: opColors,
          stops: grad.stops,
          begin: grad.begin,
          end: grad.end,
          tileMode: grad.tileMode,
          transform: grad.transform,
        ).createShader(rect);

    // 渐变只按这一行的字形盒子映射，每行都从 begin 色重新开始。
    Rect tightLineRect(ui.LineMetrics line) => Rect.fromLTRB(
          line.left - pad,
          line.baseline - line.ascent,
          line.left + line.width + pad,
          line.baseline + line.descent,
        );

    final tights = [for (final line in lineMetrics) tightLineRect(line)];
    final bandYs = _highlightBandYs(
      tights,
      maskPainter.height,
      overflow,
      pad,
    );

    // 相邻行共用整数边界；每行再往下盖一点字脚（落在行距空档里，dest.a=0，不会把半透明乘两次）。
    Rect coverBand(int i, double left, double right) {
      final top = bandYs[i];
      var bottom = bandYs[i + 1];
      final footBottom = (tights[i].bottom + 4).ceilToDouble();
      if (footBottom > bottom) bottom = footBottom;
      return Rect.fromLTRB(
        left,
        top,
        right,
        bottom > top ? bottom : top + 1,
      );
    }

    var accWidth = 0.0;
    for (var i = 0; i < lineMetrics.length; i++) {
      final line = lineMetrics[i];
      final tight = tights[i];
      final left = tight.left.floorToDouble();
      final right = tight.right.ceilToDouble();
      if (highlightFullMode) {
        segments.add(_HighlightSegment(
            coverBand(i, left, right), highlightShader(tight)));
        accWidth += line.width;
        continue;
      }

      final fadeEnd = highlightTotalWidth - accWidth;
      if (fadeEnd <= 0) {
        unsungRects.add(coverBand(i, left, right));
        accWidth += line.width;
        continue;
      }

      final fadeWidth = extraFadeWidth > 0 ? extraFadeWidth : 0.0;
      final fadeStart = fadeEnd - fadeWidth;
      final solidEnd = fadeWidth > 0 ? fadeStart : fadeEnd;

      var xSolid = (line.left + solidEnd.clamp(0.0, line.width)).roundToDouble();
      var xFade = (line.left + fadeEnd.clamp(0.0, line.width)).roundToDouble();
      if (xSolid < left) xSolid = left;
      if (xFade < xSolid) xFade = xSolid;
      if (xFade > right) xFade = right;

      if (xSolid > left) {
        segments.add(_HighlightSegment(
            coverBand(i, left, xSolid), highlightShader(tight)));
      }

      if (fadeWidth > 0 && xFade > xSolid) {
        final fadeTight = Rect.fromLTRB(xSolid, tight.top, xFade, tight.bottom);
        segments.add(
          _HighlightSegment(
            coverBand(i, xSolid, xFade),
            LinearGradient(colors: [opColors.last, fadeEndColor])
                .createShader(fadeTight),
          ),
        );
      }

      if (xFade < right) {
        unsungRects.add(coverBand(i, xFade, right));
      }

      accWidth += line.width;
    }

    if (segments.isEmpty) return false;

    _drawMaskedHighlightSegments(
      canvas,
      maskPainter,
      segments,
      unsungRects,
      baseColor,
    );
    return true;
  }

  void _drawMaskedHighlightSegments(
    Canvas canvas,
    TextPainter maskPainter,
    List<_HighlightSegment> segments,
    List<Rect> unsungRects,
    Color baseColor,
  ) {
    var bounds = Rect.fromLTWH(0, 0, maskPainter.width, maskPainter.height);
    for (final segment in segments) {
      bounds = bounds.expandToInclude(segment.rect);
    }
    for (final rect in unsungRects) {
      bounds = bounds.expandToInclude(rect);
    }
    // Impeller 上 saveLayer 会裁掉字形下伸，按行高外扩
    canvas.saveLayer(
        bounds.inflate(maskPainter.preferredLineHeight + _descenderFoot),
        Paint());
    maskPainter.paint(canvas, Offset.zero);
    final paint = Paint()
      ..blendMode = BlendMode.srcIn
      ..isAntiAlias = false;
    for (final segment in segments) {
      paint
        ..shader = segment.shader
        ..color = const Color(0xFFFFFFFF);
      canvas.drawRect(segment.rect, paint);
    }
    if (unsungRects.isNotEmpty) {
      paint
        ..shader = null
        ..color = baseColor;
      for (final rect in unsungRects) {
        canvas.drawRect(rect, paint);
      }
    }
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

    final isExiting = index == switchState.exitIndex &&
        switchState.exitAnimationValue < 1 &&
        style.enableSwitchAnimation;
    final highlightMetrics = isActive
        ? metric.activeMetrics
        : (isExiting ? metric.metrics : null);
    final maskPainter =
        isActive ? metric.activeMaskPainter : metric.textMaskPainter;
    final highlightWidth = isActive && metric.words?.isNotEmpty == true
        ? activeHighlightWidth
        : double.infinity;
    final wantsHighlight = highlightMetrics != null &&
        hasHighlightPaint &&
        highlightOpacity > 0 &&
        highlightWidth > 0;

    if (!wantsHighlight && needsRestyle) {
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
    final paintedHighlight = wantsHighlight &&
        drawHighlight(
          canvas,
          maskPainter,
          highlightMetrics!,
          baseColor: targetColor,
          highlightTotalWidth: highlightWidth,
          animationOpacity: highlightOpacity,
        );
    if (!paintedHighlight) {
      painter.paint(canvas, Offset.zero);
    }
    if (!wantsHighlight && needsRestyle) {
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
        switchState != oldDelegate.switchState;
    return shouldRepaint;
  }
}
