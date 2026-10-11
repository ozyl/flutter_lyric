import 'package:flutter/rendering.dart';
import 'package:flutter_lyric/core/lyric_model.dart';
import 'package:flutter_lyric/core/lyric_style.dart';

class LyricLayout {
  final List<LineMetrics> metrics;
  final LyricStyle style;
  final Size viewSize;
  final double selectionAnchorPosition;
  final double activeAnchorPosition;

  // Normal line starts including gaps. Only the active line changes height,
  // so its delta can be applied without rebuilding this index on every seek.
  late final List<double> _lineStarts = _computeLineStarts();

  List<double> _computeLineStarts() {
    final starts = <double>[0];
    for (var i = 0; i < metrics.length; i++) {
      starts.add(starts.last + getLineHeight(false, i) + style.lineGap);
    }
    return starts;
  }

  double _activeHeightDelta(int activeIndex) {
    if (activeIndex < 0 || activeIndex >= metrics.length) return 0;
    return metrics[activeIndex].activeHeight - metrics[activeIndex].height;
  }

  double lineTop(int index, int activeIndex) {
    return _lineStarts[index] +
        (activeIndex >= 0 && activeIndex < index
            ? _activeHeightDelta(activeIndex)
            : 0);
  }

  /// First line whose bottom (plus [bottomExtension]) reaches [offset].
  /// Returns metrics.length when the offset is beyond the last line.
  int lineAtOffset(double offset, int activeIndex,
      {double bottomExtension = 0}) {
    var low = 0;
    var high = metrics.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      final bottom = lineTop(mid, activeIndex) +
          getLineHeight(mid == activeIndex, mid) +
          bottomExtension;
      if (bottom < offset) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  LyricLayout copyWith(LyricStyle style) {
    return LyricLayout._internal(
      metrics,
      style,
      viewSize,
      style.calcSelectionAnchorPosition(viewSize.height),
      style.calcActiveAnchorPosition(viewSize.height),
    );
  }

  /// Releases the native paragraphs owned by this layout. Copies share painters;
  /// dispose them only when replacing the text layout or unmounting the view.
  void dispose() {
    for (final line in metrics) {
      line.dispose();
    }
  }

  @override
  String toString() {
    return 'LyricLayout(metrics: $metrics, style: $style)';
  }

  double lineOffsetY(int index, int activeIndex, double anchorPosition,
      MainAxisAlignment alignment) {
    final target = index.clamp(0, metrics.length);
    final indexStartY = lineTop(target, activeIndex) +
        anchorOffsetY(target, activeIndex == target, null, alignment);

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
    final totalHeight = _lineStarts.last +
        _activeHeightDelta(highlightIndex) -
        (metrics.isEmpty ? 0 : style.lineGap);
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
    for (final line in layout.metrics) {
      line.relayout(layout.viewSize.width);
    }
    // Font changes invalidate the prefix index as well as per-line geometry.
    return layout.copyWith(layout.style);
  }

  static TextPainter createHighlightMaskPainter(
    TextPainter sourcePainter,
    double maxWidth,
  ) =>
      LineMetrics.createHighlightMaskPainter(sourcePainter, maxWidth);

  static TextSpan buildHighlightMaskTextSpan(TextSpan source) =>
      LineMetrics.buildHighlightMaskTextSpan(source);

  factory LyricLayout.compute(
    LyricModel model,
    LyricStyle style,
    Size viewSize,
  ) {
    final maxWidth = viewSize.width;
    final lineMetrics = <LineMetrics>[];
    for (final line in model.lines) {
      final textPainter = TextPainter(
        text: TextSpan(text: line.text, style: style.textStyle),
        textAlign: style.lineTextAlign,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);
      final translationTextPainter = TextPainter(
        textAlign: style.lineTextAlign,
        textDirection: TextDirection.ltr,
      );
      if (line.translation != null) {
        translationTextPainter.text = TextSpan(
          text: line.translation,
          style: style.translationStyle,
        );
        translationTextPainter.layout(maxWidth: maxWidth);
      }
      lineMetrics.add(LineMetrics.lazy(
        line: line,
        textPainter: textPainter,
        translationTextPainter: translationTextPainter,
        activeStyle: style.activeStyle,
        maxWidth: maxWidth,
      ));
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
