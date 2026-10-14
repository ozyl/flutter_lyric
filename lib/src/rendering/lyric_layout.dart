import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import '../model/lyric_document.dart';
import '../preset/lyric_effects.dart';
import 'line_metrics.dart';
import 'resolved_preset.dart';
import 'lyric_word_layout.dart';

/// Geometry and paragraph ownership for one view. Active-only layouts allocate
/// one entry; scrollable layouts measure normal paragraphs and defer highlights.
class LyricLayout {
  final List<LineMetrics> metrics;
  ResolvedPreset style;
  final Size viewSize;
  final int firstIndex;
  final Map<int, Duration?> _ends;

  /// The visible countdown row before its next lyric. Hidden countdowns do not
  /// contribute to lyric positions or content height.
  List<int> countdownIndices = const [];
  double countdownExtent = 0;
  late final List<double> _starts = _computeStarts();

  LyricLayout._(
      this.metrics, this.style, this.viewSize, this.firstIndex, this._ends);

  factory LyricLayout.compute(
      LyricDocument document, ResolvedPreset style, Size viewSize,
      {int? onlyIndex}) {
    final lines =
        onlyIndex == null ? document.lines : [document.lines[onlyIndex]];
    final width = math.max(0.0, viewSize.width - style.padding.horizontal);
    final fixed = style.preset.layoutMode == LyricLayoutMode.fixed;
    TextPainter painter(String? text, TextStyle textStyle) {
      final result = TextPainter(
        text: text == null ? null : TextSpan(text: text, style: textStyle),
        textAlign: style.preset.textAlign, textDirection: style.direction,
        // ignore: deprecated_member_use
        textScaleFactor: style.textScaleFactor, locale: style.locale,
      );
      // Empty primary entries still occupy one line (e.g. an instrumental gap).
      if (text != null) {
        result.layout(maxWidth: width);
      }
      return result;
    }

    final ends = <int, Duration?>{};
    Duration? next;
    if (onlyIndex != null) {
      var low = onlyIndex + 1;
      var high = document.lines.length;
      while (low < high) {
        final middle = low + ((high - low) >> 1);
        if (document.lines[middle].start <= document.lines[onlyIndex].start) {
          low = middle + 1;
        } else {
          high = middle;
        }
      }
      if (low < document.lines.length) next = document.lines[low].start;
    }
    for (var i = onlyIndex ?? document.lines.length - 1;
        i >= (onlyIndex ?? 0);
        i--) {
      if (i + 1 < document.lines.length &&
          document.lines[i + 1].start > document.lines[i].start) {
        next = document.lines[i + 1].start;
      }
      final line = document.lines[i];
      ends[i] = line.end != null && line.end! > line.start ? line.end : next;
    }
    return LyricLayout._(
        lines
            .map((line) => LineMetrics.lazy(
                  line: line,
                  textPainter: painter(line.text,
                      fixed ? style.activeTextStyle : style.textStyle),
                  translationTextPainter: painter(
                      line.translation?.isEmpty == true
                          ? null
                          : line.translation,
                      fixed
                          ? style.activeTranslationTextStyle
                          : style.translationTextStyle),
                  activeStyle: style.activeTextStyle,
                  activeTranslationStyle: style.activeTranslationTextStyle,
                  maxWidth: width,
                ))
            .toList(),
        style,
        viewSize,
        onlyIndex ?? 0,
        ends);
  }

  double get contentWidth =>
      math.max(0, viewSize.width - style.padding.horizontal);
  int localIndex(int index) => index - firstIndex;
  bool contains(int index) =>
      index >= firstIndex && index < firstIndex + metrics.length;
  LineMetrics metric(int index) => metrics[localIndex(index)];
  List<double> _computeStarts() {
    final result = <double>[0];
    for (var i = 0; i < metrics.length; i++) {
      result.add(result.last +
          getLineHeight(false, i + firstIndex) +
          style.preset.lineSpacing);
    }
    return result;
  }

  double _delta(int active) => !fixed && contains(active)
      ? getLineHeight(true, active) - getLineHeight(false, active)
      : 0;
  int _countdownsBefore(int index) {
    var low = 0;
    var high = countdownIndices.length;
    while (low < high) {
      final middle = low + ((high - low) >> 1);
      if (countdownIndices[middle] <= index) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }

  double lineTop(int index, int active) =>
      _starts[localIndex(index)] +
      _countdownsBefore(index) * countdownExtent +
      (contains(active) && active < index ? _delta(active) : 0);

  double countdownTop(int nextIndex, int active) =>
      lineTop(nextIndex, active) - countdownExtent;
  late final double maxNormalHeight = metrics.fold<double>(
      0,
      (height, metric) => math.max(
          height,
          metric.height +
              metric.translationHeight +
              style.preset.translationSpacing +
              headroom +
              style.preset.wordEffects.floatAmplitude));
  bool get fixed => style.preset.layoutMode == LyricLayoutMode.fixed;
  double get headroom => style.preset.wordEffects.extent;
  LyricWordLine wordLine(int index, bool active) => metric(index).wordLine(
      ResolvedWordStyle(
          text: active || fixed ? style.activeTextStyle : style.textStyle,
          translation: active || fixed
              ? style.activeTranslationTextStyle
              : style.translationTextStyle,
          direction: style.direction,
          textAlign: style.preset.textAlign,
          textScale: style.textScaleFactor,
          locale: style.locale,
          effects: style.preset.wordEffects,
          translationSpacing: style.preset.translationSpacing),
      _ends[index],
      active || fixed);

  double getLineHeight(bool active, int index) {
    if (!contains(index)) return 0;
    final line = metric(index);
    final main = active ? line.activeHeight : line.height;
    final translation =
        active ? line.activeTranslationHeight : line.translationHeight;
    return headroom +
        style.preset.wordEffects.floatAmplitude +
        main +
        (translation == 0 ? 0 : translation + style.preset.translationSpacing);
  }

  double anchorOffsetY(int index, bool active, LyricAnchorTarget target) {
    final line = metric(index);
    final main = active ? line.activeHeight : line.height;
    final translation =
        active ? line.activeTranslationHeight : line.translationHeight;
    if (translation == 0 || target == LyricAnchorTarget.mainText) {
      return headroom + main / 2;
    }
    if (target == LyricAnchorTarget.translationText) {
      return headroom +
          style.preset.wordEffects.floatAmplitude +
          main +
          style.preset.translationSpacing +
          translation / 2;
    }
    return getLineHeight(active, index) / 2;
  }

  double lineOffsetY(int index, int active, LyricAnchor anchor) =>
      lineTop(index, active) +
      anchorOffsetY(index, index == active, anchor.target) -
      anchor.resolve(viewSize.height);
  double contentHeight(int active) =>
      _starts.last +
      countdownIndices.length * countdownExtent +
      _delta(active) -
      (metrics.isEmpty ? 0 : style.preset.lineSpacing);

  /// First intersecting entry, using a binary search over normal line prefixes.
  int lineAtOffset(double offset, int active, {double bottomExtension = 0}) {
    var low = firstIndex;
    var high = firstIndex + metrics.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (lineTop(mid, active) +
              getLineHeight(mid == active, mid) +
              bottomExtension <
          offset) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  int closestToAnchor(double scrollY, int active, LyricAnchor anchor) {
    final point = scrollY + anchor.resolve(viewSize.height);
    var low = firstIndex;
    var high = firstIndex + metrics.length;
    double center(int i) =>
        lineTop(i, active) + anchorOffsetY(i, i == active, anchor.target);
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (center(mid) < point) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    if (low == firstIndex) return low;
    if (low == firstIndex + metrics.length) return low - 1;
    return point - center(low - 1) <= center(low) - point ? low - 1 : low;
  }

  LyricLayout restyle(ResolvedPreset next, Size size) {
    if (!next.sameTextPaint(style)) {
      for (final line in metrics) {
        line.updatePaintStyles(
            textStyle: fixed ? next.activeTextStyle : next.textStyle,
            activeStyle: next.activeTextStyle,
            translationStyle: fixed
                ? next.activeTranslationTextStyle
                : next.translationTextStyle,
            activeTranslationStyle: next.activeTranslationTextStyle);
      }
    }
    if (fixed &&
        size == viewSize &&
        style.padding == next.padding &&
        style.preset.lineSpacing == next.preset.lineSpacing &&
        style.preset.translationSpacing == next.preset.translationSpacing) {
      style = next;
      return this;
    }
    return LyricLayout._(metrics, next, size, firstIndex, _ends);
  }

  void dispose() {
    for (final line in metrics) {
      line.dispose();
    }
  }
}
