import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_lyric/core/lyric_model.dart';
import 'package:flutter_lyric/core/lyric_style.dart';
import 'package:flutter_lyric/render/lyric_layout.dart';
import 'package:flutter_lyric/widgets/mixins/lyric_line_switch_mixin.dart';

const _debugLyric = false;

/// Frame values consumed directly by the painter, without rebuilding widgets.
class LyricPaintState {
  final ValueListenable<int> playIndex;
  final ValueListenable<double> scrollY;
  final ValueListenable<double> activeHighlightWidth;
  final ValueListenable<LyricLineSwitchState> switchState;
  final ValueListenable<bool> isSelecting;
  late final Listenable repaint = Listenable.merge([
    playIndex,
    scrollY,
    activeHighlightWidth,
    switchState,
    isSelecting,
  ]);

  LyricPaintState({
    required this.playIndex,
    required this.scrollY,
    required this.activeHighlightWidth,
    required this.switchState,
    required this.isSelecting,
  });
}

class LyricPainter extends CustomPainter {
  final LyricLayout layout;
  final int _playIndex;
  final double _scrollY;
  final double _activeHighlightWidth;
  final LyricLineSwitchState? _switchState;
  final bool _isSelecting;
  final LyricPaintState? _state;
  int get playIndex => _state?.playIndex.value ?? _playIndex;
  double get scrollY => _state?.scrollY.value ?? _scrollY;
  double get activeHighlightWidth =>
      _state?.activeHighlightWidth.value ?? _activeHighlightWidth;
  LyricLineSwitchState get switchState =>
      _state?.switchState.value ?? _switchState!;
  bool get isSelecting => _state?.isSelecting.value ?? _isSelecting;
  final LyricStyle style;
  final void Function(int) onAnchorIndexChange;
  final void Function(Map<int, Rect>) onShowLineRectsChange;

  LyricPainter({
    required this.layout,
    required int playIndex,
    required double scrollY,
    required this.onAnchorIndexChange,
    required double activeHighlightWidth,
    required LyricLineSwitchState switchState,
    required bool isSelecting,
    required this.onShowLineRectsChange,
    required this.style,
  })  : _playIndex = playIndex,
        _scrollY = scrollY,
        _activeHighlightWidth = activeHighlightWidth,
        _switchState = switchState,
        _isSelecting = isSelecting,
        _state = null;

  LyricPainter.listenable({
    required this.layout,
    required LyricPaintState state,
    required this.onAnchorIndexChange,
    required this.onShowLineRectsChange,
    required this.style,
  })  : _state = state,
        _playIndex = 0,
        _scrollY = 0,
        _activeHighlightWidth = 0,
        _switchState = null,
        _isSelecting = false,
        super(repaint: state.repaint);

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
    final firstLine = layout.lineAtOffset(scrollY, playIndex);
    final selectedIndex = layout.lineAtOffset(
        scrollY + selectionPosition, playIndex,
        bottomExtension: lineGap / 2);
    if (selectedIndex < metrics.length) {
      onAnchorIndexChange(selectedIndex);
    }
    var totalTranslateY = layout.lineTop(firstLine, playIndex) - scrollY;
    canvas.translate(0, totalTranslateY);
    final showLineRects = <int, Rect>{};
    final contentHorizontal = layoutStyle.contentPadding.horizontal;
    final activeLineOnly = style.activeLineOnly;

    for (var i = firstLine; i < metrics.length; i++) {
      final isActive = i == playIndex;
      final lineHeight = layout.getLineHeight(isActive, i);
      totalTranslateY += lineHeight;
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

  void _drawHighlightColors(
    Canvas canvas,
    List<ui.LineMetrics> metrics,
    Rect bounds, {
    double highlightTotalWidth = 0,
    double animationOpacity = 1.0,
    Color? baseColor,
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

    final baseStyle =
        isActive ? layoutStyle.activeStyle : layoutStyle.textStyle;
    final targetColor = _resolveColor(baseStyle, layoutStyle.selectedColor,
        isSelecting, isInAnchorArea, animatedMainColor);
    final hasHighlight = layoutStyle.activeHighlightColor != null ||
        layoutStyle.activeHighlightGradient != null;
    final isExiting = index == switchState.exitIndex &&
        switchState.exitAnimationValue < 1 &&
        style.enableSwitchAnimation;
    final highlightWidth = isActive && metric.words?.isNotEmpty == true
        ? activeHighlightWidth
        : double.infinity;
    final drawHighlighted = hasHighlight &&
        (isActive || isExiting) &&
        highlightOpacity > 0 &&
        highlightWidth > 0;
    final needsRestyle =
        !drawHighlighted && targetColor != oldSpan.style!.color;

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
      final tPainter = metric.translationTextPainter;
      final tOldSpan = tPainter.text! as TextSpan;

      Color? animatedTranslationColor;
      if (style.enableSwitchAnimation) {
        final normalTransColor = layoutStyle.translationStyle.color;
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
          ? (layoutStyle.translationActiveColor ??
              layoutStyle.translationStyle.color)
          : layoutStyle.translationStyle.color;
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
        switchState != oldDelegate.switchState ||
        isSelecting != oldDelegate.isSelecting ||
        style != oldDelegate.style ||
        _state != oldDelegate._state;
    return shouldRepaint;
  }
}
