import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import '../model/lyric_document.dart';
import '../preset/lyric_effects.dart';
import 'line_metrics.dart';
import 'resolved_preset.dart';

/// Geometry and paragraph ownership for one view. Active-only layouts allocate
/// one entry; scrollable layouts measure normal paragraphs and defer highlights.
class LyricLayout {
  final List<LineMetrics> metrics;
  final ResolvedPreset style;
  final Size viewSize;
  final int firstIndex;
  late final List<double> _starts = _computeStarts();

  LyricLayout._(this.metrics, this.style, this.viewSize, this.firstIndex);

  factory LyricLayout.compute(
      LyricDocument document, ResolvedPreset style, Size viewSize,
      {int? onlyIndex}) {
    final lines =
        onlyIndex == null ? document.lines : [document.lines[onlyIndex]];
    final width = math.max(0.0, viewSize.width - style.padding.horizontal);
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

    return LyricLayout._(
        lines
            .map((line) => LineMetrics.lazy(
                  line: line,
                  textPainter: painter(line.text, style.textStyle),
                  translationTextPainter: painter(
                      line.translation?.isEmpty == true
                          ? null
                          : line.translation,
                      style.translationTextStyle),
                  activeStyle: style.activeTextStyle,
                  activeTranslationStyle: style.activeTranslationTextStyle,
                  maxWidth: width,
                ))
            .toList(),
        style,
        viewSize,
        onlyIndex ?? 0);
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

  double _delta(int active) => contains(active)
      ? getLineHeight(true, active) - getLineHeight(false, active)
      : 0;
  double lineTop(int index, int active) =>
      _starts[localIndex(index)] +
      (contains(active) && active < index ? _delta(active) : 0);
  double getLineHeight(bool active, int index) {
    if (!contains(index)) return 0;
    final line = metric(index);
    final main = active ? line.activeHeight : line.height;
    final translation =
        active ? line.activeTranslationHeight : line.translationHeight;
    return main +
        (translation == 0 ? 0 : translation + style.preset.translationSpacing);
  }

  double anchorOffsetY(int index, bool active, LyricAnchorTarget target) {
    final line = metric(index);
    final main = active ? line.activeHeight : line.height;
    final translation =
        active ? line.activeTranslationHeight : line.translationHeight;
    if (translation == 0 || target == LyricAnchorTarget.mainText) {
      return main / 2;
    }
    if (target == LyricAnchorTarget.translationText) {
      return main + style.preset.translationSpacing + translation / 2;
    }
    return getLineHeight(active, index) / 2;
  }

  double lineOffsetY(int index, int active, LyricAnchor anchor) =>
      lineTop(index, active) +
      anchorOffsetY(index, index == active, anchor.target) -
      anchor.resolve(viewSize.height);
  double contentHeight(int active) =>
      _starts.last +
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
            textStyle: next.textStyle,
            activeStyle: next.activeTextStyle,
            translationStyle: next.translationTextStyle,
            activeTranslationStyle: next.activeTranslationTextStyle);
      }
    }
    return LyricLayout._(metrics, next, size, firstIndex);
  }

  void dispose() {
    for (final line in metrics) {
      line.dispose();
    }
  }
}
