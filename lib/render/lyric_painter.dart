import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_lyric/core/lyric_model.dart';
import 'package:flutter_lyric/core/lyric_style.dart';
import 'package:flutter_lyric/render/lyric_layout.dart';
import 'package:flutter_lyric/widgets/mixins/lyric_line_switch_mixin.dart';

const _debugLyric = false;

/// 逐字高亮时单字向上弹起的最大位移（逻辑像素，负值表示向上）。
const _kLyricCharPopUpOffset = 3.0;

class LyricPainter extends CustomPainter {
  final LyricLayout layout;
  final int playIndex;
  final double scrollY;
  final double activeHighlightWidth;
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

  drawHighlight(
    Canvas canvas,
    Size size,
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

    final Paint paint = Paint()
      ..blendMode =
          animationOpacity < 1.0 ? BlendMode.srcATop : BlendMode.srcIn;

    final grad = activeHighlightGradient ??
        LinearGradient(colors: [activeHighlightColor!, activeHighlightColor]);

    final opColors = animationOpacity < 1.0
        ? grad.colors
            .map((c) =>
                c.withValues(alpha: (c.a * animationOpacity).clamp(0.0, 1.0)))
            .toList()
        : grad.colors;

    final extraFadeWidth = style.activeHighlightExtraFadeWidth;
    Color? fadeEndColor;
    if (extraFadeWidth > 0) {
      final baseEndColor = style.activeStyle.color ?? grad.colors.last;
      fadeEndColor = baseEndColor.withValues(
          alpha: (baseEndColor.a * animationOpacity).clamp(0.0, 1.0));
    }

    const pad = 2;

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
        top - _kLyricCharPopUpOffset,
        lineDrawWidth + pad,
        height + _kLyricCharPopUpOffset * 2,
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

  /// 网易云式逐字上弹：高亮扫过该字时向上偏移，最大 [maxUp]（逻辑像素）。
  static double _charHighlightPopDy({
    required double localHighlightInWord,
    required int charIndexInWord,
    required List<Rect> charRects,
    // 你需要从外部传入一个“当前字符开始播放动画的时间进度”或者通过 logic 计算
    // 如果没有外部 Timer，我们可以根据 localHighlightInWord 模拟一个触发
    double maxUp = 10,
  }) {
    if (charRects.isEmpty) return 0;

    // 1. 获取当前字符的触发阈值（比如扫描线到达字符宽度的 20% 时触发）
    double triggerX = 0;
    for (var i = 0; i < charIndexInWord; i++) {
      triggerX += charRects[i].width;
    }
    // 稍微提前一点触发，视觉感官更好
    triggerX += charRects[charIndexInWord].width * 0.2;

    // 2. 计算“超出距离”
    double overDistance = localHighlightInWord - triggerX;

    // 3. 将距离转化为一个“固定步长”的虚拟时间
    // 假设我们希望在扫描线扫过 50 像素的时间内完成动画
    // 这样即便语速不同，只要这一段位移发生，动画就会执行
    const double animationDurationWindow = 150.0;

    if (overDistance <= 0) return 0;
    if (overDistance >= animationDurationWindow) return 0; // 动画结束，收回

    // 4. 归一化进度 (0.0 -> 1.0)
    double t = overDistance / animationDurationWindow;

    // 5. 使用更平滑的曲线
    // Curves.easeInOut 或简单的 sin
    double curve = math.sin(t * math.pi);

    return -maxUp * curve;
  }

  void _paintTextUtf16Range(
    Canvas canvas,
    LineMetrics metric,
    TextPainter charPainter,
    TextStyle spanStyle,
    int startUtf16,
    int endUtf16, {
    required double Function(Rect charRect) dyForChar,
  }) {
    if (startUtf16 >= endUtf16) return;
    final lineText = metric.line.text;
    var offset = startUtf16;
    final slice = lineText.substring(startUtf16, endUtf16);
    for (final g in slice.characters) {
      final next = offset + g.length;
      final boxes = metric.activeTextPainter.getBoxesForSelection(
        TextSelection(baseOffset: offset, extentOffset: next),
      );
      if (boxes.isNotEmpty) {
        final r = boxes.first.toRect();
        charPainter.text = TextSpan(text: g, style: spanStyle);
        charPainter.layout();
        final dy = dyForChar(r);
        charPainter.paint(canvas, Offset(r.left, r.top + dy));
      }
      offset = next;
    }
  }

  /// 按词绘制当前行主歌词：词间空隙无位移；词内单字按 [highlightTotalWidth] 做上弹。
  void _paintActiveLineWithWordPop(
    Canvas canvas,
    LineMetrics metric,
    TextPainter charPainter,
    TextStyle spanStyle,
    double highlightTotalWidth,
  ) {
    final lineText = metric.line.text;
    final words = metric.line.words!;
    final wordMetrics = metric.words!;
    var accWordHighlight = 0.0;
    var currentOffset = 0;

    for (var wi = 0; wi < words.length; wi++) {
      final word = words[wi];
      final wm = wordMetrics[wi];
      final wordStart = lineText.indexOf(word.text, currentOffset);

      if (wordStart == -1) {
        accWordHighlight += wm.highlightWidth;
        continue;
      }

      if (wordStart > currentOffset) {
        _paintTextUtf16Range(
          canvas,
          metric,
          charPainter,
          spanStyle,
          currentOffset,
          wordStart,
          dyForChar: (_) => 0,
        );
      }

      final local = highlightTotalWidth - accWordHighlight;
      final graphemes = word.text.characters.toList();
      for (var j = 0; j < graphemes.length; j++) {
        if (j >= wm.charRects.length) break;
        final charRect = wm.charRects[j];
        final dy = _charHighlightPopDy(
          localHighlightInWord: local,
          charRects: wm.charRects,
          charIndexInWord: j,
          maxUp: _kLyricCharPopUpOffset,
        );
        charPainter.text = TextSpan(text: graphemes[j], style: spanStyle);
        charPainter.layout();
        charPainter.paint(canvas, Offset(charRect.left, charRect.top + dy));
      }

      currentOffset = wordStart + word.text.length;
      accWordHighlight += wm.highlightWidth;
    }

    if (currentOffset < lineText.length) {
      _paintTextUtf16Range(
        canvas,
        metric,
        charPainter,
        spanStyle,
        currentOffset,
        lineText.length,
        dyForChar: (_) => 0,
      );
    }
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
    // painter.paint(canvas, Offset.zero);

    ///start
    if (isActive &&
        metric.words?.isNotEmpty == true &&
        metric.line.words?.isNotEmpty == true) {
      final spanStyle = (painter.text! as TextSpan).style ?? oldSpan.style;
      final charPainter = TextPainter(
        textDirection: painter.textDirection,
        textAlign: TextAlign.left,
        textScaler: painter.textScaler,
        locale: painter.locale,
        strutStyle: painter.strutStyle,
      );
      _paintActiveLineWithWordPop(
        canvas,
        metric,
        charPainter,
        spanStyle!,
        activeHighlightWidth,
      );
    } else {
      painter.paint(canvas, Offset.zero);
    }

    ///end
    if (needsRestyle) {
      painter.text = oldSpan;
    }
    if (isActive) {
      drawHighlight(canvas, size, metric.activeMetrics,
          highlightTotalWidth: metric.words?.isNotEmpty == true
              ? activeHighlightWidth
              : double.infinity,
          animationOpacity: highlightOpacity);
    } else if (index == switchState.exitIndex &&
        switchState.exitAnimationValue < 1 &&
        style.enableSwitchAnimation) {
      drawHighlight(canvas, size, metric.metrics,
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
