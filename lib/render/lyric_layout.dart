import 'package:flutter/rendering.dart';
import 'package:flutter_lyric/core/lyric_model.dart';
import 'package:flutter_lyric/core/lyric_style.dart';

class LyricLayout {
  final List<LineMetrics> metrics;
  final LyricStyle style;
  final Size viewSize;
  final double selectionAnchorPosition;
  final double activeAnchorPosition;

  LyricLayout copyWith(LyricStyle style) {
    return LyricLayout._internal(
      metrics,
      style,
      viewSize,
      selectionAnchorPosition,
      activeAnchorPosition,
    );
  }

  @override
  String toString() {
    return 'LyricLayout(metrics: $metrics, style: $style)';
  }

  double lineOffsetY(int index, int activeIndex, double anchorPosition,
      MainAxisAlignment alignment) {
    double indexStartY = 0;
    for (var i = 0; i < metrics.length; i++) {
      final lineHeight = getLineHeight(i == activeIndex, i);
      if (i >= index) {
        final anchorOffset =
            anchorOffsetY(i, activeIndex == i, lineHeight, alignment);
        indexStartY += anchorOffset;
        break;
      }
      indexStartY += lineHeight + style.lineGap;
    }

    if (anchorPosition < indexStartY + style.contentPadding.top) {
      return indexStartY - anchorPosition;
    }
    return -style.contentPadding.top;
  }

  // 用于修正Anchor对齐的偏移量
  double anchorAdjustmentOffsetY(int index, int activeIndex) {
    final isHighlight = index == activeIndex;
    final lineHeight = getLineHeight(isHighlight, index);
    var anchorOffset =
        anchorOffsetY(index, isHighlight, lineHeight, style.selectionAlignment);
    return (lineHeight / 2 - anchorOffset);
  }

  double anchorOffsetY(
    int index,
    bool isHighlight,
    double? lineHeight,
    MainAxisAlignment? alignment,
  ) {
    if (metrics.isEmpty || index < 0 || index >= metrics.length) return 0;
    final lh = lineHeight ?? getLineHeight(isHighlight, index);
    final hasTranslation = metrics[index].translationHeight > 0;
    final align = hasTranslation
        ? (alignment ?? style.selectionAlignment)
        : MainAxisAlignment.start;
    final currentLine = metrics[index];
    final activeHeight =
        isHighlight ? currentLine.activeHeight : currentLine.height;
    if (align == MainAxisAlignment.start) {
      return activeHeight / 2;
    } else if (align == MainAxisAlignment.end) {
      return activeHeight +
          style.translationLineGap +
          currentLine.translationHeight / 2;
    } else if (align == MainAxisAlignment.center) {
      return lh / 2;
    }
    return 0;
  }

  double getLineHeight(bool isHighlight, int index) {
    if (metrics.isEmpty || index < 0 || index >= metrics.length) return 0;
    final mainHeight =
        isHighlight ? metrics[index].activeHeight : metrics[index].height;
    if (metrics[index].translationHeight == 0) {
      return mainHeight;
    }
    return mainHeight +
        metrics[index].translationHeight +
        style.translationLineGap;
  }

  double contentHeight(int highlightIndex) {
    double totalHeight = 0;
    for (var i = 0; i < metrics.length; i++) {
      totalHeight += getLineHeight(i == highlightIndex, i);
      if (i < metrics.length - 1) {
        totalHeight += style.lineGap;
      }
    }
    return totalHeight + style.contentPadding.vertical;
  }

  LyricLayout._internal(
    this.metrics,
    this.style,
    this.viewSize,
    this.selectionAnchorPosition,
    this.activeAnchorPosition,
  );

  factory LyricLayout.updatePainters(
    LyricLayout layout,
  ) {
    final lineMetrics = <LineMetrics>[];
    for (var line in layout.metrics) {
      line.textPainter.markNeedsLayout();
      line.activeTextPainter.markNeedsLayout();
      line.translationTextPainter.markNeedsLayout();
      line.textPainter.layout(maxWidth: layout.viewSize.width);
      line.activeTextPainter.layout(maxWidth: layout.viewSize.width);
      final hasTranslation = line.translationTextPainter.text != null;
      if (hasTranslation) {
        line.translationTextPainter.layout(maxWidth: layout.viewSize.width);
      }
      line.words;
      final words = _calcWordMetrics(line.line, line.textPainter,
          line.activeTextPainter, line.translationTextPainter);
      lineMetrics.add(line.copyWith(
        height: line.textPainter.height,
        width: line.textPainter.width,
        activeWidth: line.activeTextPainter.width,
        activeHeight: line.activeTextPainter.height,
        translationWidth:
            hasTranslation ? line.translationTextPainter.width : 0,
        translationHeight:
            hasTranslation ? line.translationTextPainter.height : 0,
        activeMetrics: line.activeTextPainter.computeLineMetrics(),
        metrics: line.textPainter.computeLineMetrics(),
        words: words,
      ));
    }
    return LyricLayout._internal(
      layout.metrics,
      layout.style,
      layout.viewSize,
      layout.selectionAnchorPosition,
      layout.activeAnchorPosition,
    );
  }

  static List<WordMetrics>? _calcWordMetrics(
      LyricLine line,
      TextPainter textPainter,
      TextPainter activeTextPainter,
      TextPainter translationTextPainter) {
    var currentOffset = 0;
    final words = line.words?.map((word) {
      // 从当前位置开始查找单词，确保按顺序匹配
      final wordStart = line.text.indexOf(word.text, currentOffset);
      if (wordStart == -1) {
        // 如果找不到单词，使用默认值
        return WordMetrics(
          word: word,
          width: 0,
          height: textPainter.height,
          highlightWidth: 0,
          highlightHeight: activeTextPainter.height,
        );
      }
      final wordEnd = wordStart + word.text.length;
      // 更新当前位置，为下一个单词查找做准备
      currentOffset = wordEnd;

      // 使用 textPainter 获取普通样式的文本框
      final textSelection =
          TextSelection(baseOffset: wordStart, extentOffset: wordEnd);
      final textBoxes = textPainter.getBoxesForSelection(textSelection);
      var tWidth = 0.0;
      var tHeight = 0.0;
      calcWordSize(List<TextBox> boxs) {
        tWidth = 0.0;
        tHeight = 0.0;
        var h = 0;
        for (var box in boxs) {
          final rect = box.toRect();
          tWidth += rect.width;
          if (rect.height > h) {
            tHeight = rect.height;
          }
        }
      }

      calcWordSize(textBoxes);
      final width = tWidth;
      final wordHeight = tHeight;

      // 使用 activeTextPainter 获取高亮样式的文本框
      final activeBoxes = activeTextPainter.getBoxesForSelection(textSelection);
      calcWordSize(activeBoxes);
      final highlightWidth = tWidth;
      final wordHighlightHeight = tHeight;

      return WordMetrics(
        word: word,
        width: width,
        height: wordHeight,
        highlightWidth: highlightWidth,
        highlightHeight: wordHighlightHeight,
      );
    }).toList();
    return words;
  }

  factory LyricLayout.compute(
    LyricModel model,
    LyricStyle style,
    Size viewSize,
  ) {
    final maxWidth = viewSize.width;
    final lineMetrics = <LineMetrics>[];
    for (var line in model.lines) {
      final textPainter = TextPainter(
        textAlign: style.lineTextAlign,
        textDirection: TextDirection.ltr,
      );
      final activeTextPainter = TextPainter(
        textAlign: style.lineTextAlign,
        textDirection: TextDirection.ltr,
      );
      final translationTextPainter = TextPainter(
        textAlign: style.lineTextAlign,
        textDirection: TextDirection.ltr,
      );
      textPainter.text = TextSpan(text: line.text, style: style.textStyle);
      textPainter.layout(maxWidth: maxWidth);

      final metrics = textPainter.computeLineMetrics();
      final height = textPainter.height;
      final width = textPainter.width;

      activeTextPainter.text =
          TextSpan(text: line.text, style: style.activeStyle);
      activeTextPainter.layout(maxWidth: maxWidth);
      final activceLineMetrics = activeTextPainter.computeLineMetrics();
      final highlightWidth = activeTextPainter.width;
      final highlightHeight = activeTextPainter.height;

      double translationWidth = 0;
      double translationHeight = 0;

      if (line.translation != null) {
        translationTextPainter.text = TextSpan(
          text: line.translation,
          style: style.translationStyle,
        );
        translationTextPainter.layout(maxWidth: maxWidth);
        translationWidth = translationTextPainter.width;
        translationHeight = translationTextPainter.height;
      }
      final words = _calcWordMetrics(
          line, textPainter, activeTextPainter, translationTextPainter);
      lineMetrics.add(
        LineMetrics(
          line: line,
          height: height,
          width: width,
          activeWidth: highlightWidth,
          activeHeight: highlightHeight,
          translationWidth: translationWidth,
          translationHeight: translationHeight,
          activeMetrics: activceLineMetrics,
          metrics: metrics,
          words: words,
          textPainter: textPainter,
          activeTextPainter: activeTextPainter,
          translationTextPainter: translationTextPainter,
        ),
      );
    }
    return LyricLayout._internal(
      lineMetrics,
      style,
      viewSize,
      style.calcSelectionAnchorPosition(viewSize.height),
      style.calcActiveAnchorPosition(viewSize.height),
    );
  }
}
