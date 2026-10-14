import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import '../compat/painting.dart';
import '../model/lyric_document.dart';
import '../preset/lyric_effects.dart';

/// Cached shaped word/grapheme slices, allocated only for painted effects.
class ResolvedWordStyle {
  final TextStyle text;
  final TextStyle translation;
  final TextDirection direction;
  final TextAlign textAlign;
  final double textScale;
  final Locale? locale;
  final LyricWordEffects effects;
  final double translationSpacing;
  const ResolvedWordStyle(
      {required this.text,
      required this.translation,
      required this.direction,
      required this.textAlign,
      required this.textScale,
      required this.locale,
      required this.effects,
      required this.translationSpacing});
}

class LyricWordSegment {
  final int startOffset;
  final int endOffset;
  final Duration start;
  final Duration end;
  final List<ui.TextBox> boxes;
  final List<Rect> clips;
  late final Path clipPath = _pathFor(clips);
  late final Rect bounds = _boundsFor(clips);
  late final double highlightWidth =
      boxes.fold<double>(0, (sum, box) => sum + box.right - box.left);
  LyricWordSegment(this.startOffset, this.endOffset, this.start, this.end,
      this.boxes, this.clips);

  double progress(Duration position) => position < start
      ? 0
      : end <= start
          ? 1
          : ((position - start).inMicroseconds / (end - start).inMicroseconds)
              .clamp(0.0, 1.0);
}

class LyricWordLine {
  final LyricLine source;
  final ResolvedWordStyle style;
  final double width;
  final Duration? inferredEnd;
  late final TextPainter text;
  final bool _ownsParagraphs;
  TextPainter? translation;
  TextPainter? _mask;
  List<LyricWordSegment>? _segments;
  List<LyricWordCharacter>? _characters;
  late final _LyricWordClips _clipGeometry = _LyricWordClips(text, source.text);
  late final Rect paintBounds =
      (Offset.zero & text.size).inflate(text.preferredLineHeight);
  late final Path wordCutouts = _cutouts(segments.map((s) => s.clips));
  late final Path characterCutouts = _cutouts(characters.map((c) => c.clips));
  late final double height;
  late final double translationY;

  LyricWordLine(this.source, this.style, this.width, this.inferredEnd,
      {TextPainter? paragraph, TextPainter? translationParagraph})
      : _ownsParagraphs = paragraph == null {
    text = paragraph ?? _painter(source.text, style.text);
    if (source.translation?.isNotEmpty == true) {
      translation = translationParagraph ??
          _painter(source.translation!, style.translation);
    }
    translationY = style.effects.extent +
        text.height +
        // Float can move below the resting baseline, even with Word Pop off.
        style.effects.floatAmplitude +
        (translation == null ? 0 : style.translationSpacing);
    height = translationY + (translation?.height ?? 0);
  }

  TextPainter _painter(String content, TextStyle textStyle) => TextPainter(
        text: TextSpan(text: content, style: textStyle),
        textDirection: style.direction,
        textAlign: style.textAlign,
        // ignore: deprecated_member_use
        textScaleFactor: style.textScale,
        locale: style.locale,
      )..layout(maxWidth: width);

  TextPainter get mask => _mask ??= _painter(
      source.text,
      style.text
          .copyWith(foreground: Paint()..color = const Color(0xFFFFFFFF)));

  bool get debugSegmentsComputed => _segments != null;
  bool get debugMaskComputed => _mask != null;
  bool get debugCharactersComputed => _characters != null;
  List<LyricWordSegment> get segments => _segments ??= _computeSegments();
  List<LyricWordCharacter> get characters =>
      _characters ??= _computeCharacters();

  Path _cutouts(Iterable<List<Rect>> slices) {
    final path = Path()..fillType = PathFillType.evenOdd;
    path.addRect(paintBounds);
    for (final clips in slices) {
      for (final clip in clips) {
        path.addRect(clip);
      }
    }
    return path;
  }

  List<LyricWordCharacter> _computeCharacters() {
    final result = <LyricWordCharacter>[];
    final timing = segments;
    var offset = 0;
    var segmentIndex = 0;
    for (final cluster in source.text.characters) {
      final end = offset + cluster.length;
      while (segmentIndex < timing.length &&
          timing[segmentIndex].endOffset <= offset) {
        segmentIndex++;
      }
      final segment = segmentIndex < timing.length &&
              timing[segmentIndex].startOffset <= offset &&
              timing[segmentIndex].endOffset >= end
          ? timing[segmentIndex]
          : null;
      // Simulated timing and character-timed formats already measured this
      // exact shaped slice. Larger timed words still need per-character boxes.
      final clips = segment != null &&
              segment.startOffset == offset &&
              segment.endOffset == end
          ? segment.clips
          : text
              .getBoxesForSelection(
                  TextSelection(baseOffset: offset, extentOffset: end))
              .map(_clipGeometry.clipFor)
              .toList();
      result
          .add(LyricWordCharacter(result.length, offset, end, clips, segment));
      offset = end;
    }
    return result;
  }

  List<LyricWordSegment> _computeSegments() {
    final result = <LyricWordSegment>[];
    void add(int begin, int end, Duration start, Duration finish) {
      final boxes = text.getBoxesForSelection(
          TextSelection(baseOffset: begin, extentOffset: end));
      result.add(LyricWordSegment(begin, end, start, finish, boxes,
          boxes.map(_clipGeometry.clipFor).toList()));
    }

    final words = source.words;
    if (words != null && words.isNotEmpty) {
      var offset = 0;
      for (var i = 0; i < words.length; i++) {
        final word = words[i];
        if (word.text.isEmpty) continue;
        final begin = source.text.indexOf(word.text, offset);
        if (begin < 0) continue;
        offset = begin + word.text.length;
        final next = i + 1 < words.length ? words[i + 1].start : inferredEnd;
        final end = word.end ?? next ?? word.start;
        add(begin, offset, word.start, end < word.start ? word.start : end);
      }
    } else if (style.effects.simulateTiming &&
        inferredEnd != null &&
        inferredEnd! > source.start) {
      final clusters = source.text.characters.toList();
      final duration = (inferredEnd! - source.start).inMicroseconds;
      var offset = 0;
      for (var i = 0; i < clusters.length; i++) {
        final end = offset + clusters[i].length;
        add(
            offset,
            end,
            source.start +
                Duration(microseconds: duration * i ~/ clusters.length),
            source.start +
                Duration(microseconds: duration * (i + 1) ~/ clusters.length));
        offset = end;
      }
    }
    return result;
  }

  void dispose() {
    if (_ownsParagraphs) {
      disposeTextPainter(text);
      if (translation != null) disposeTextPainter(translation!);
    }
    if (_mask != null) disposeTextPainter(_mask!);
  }
}

/// A grapheme keeps emoji/combining marks together while retaining the original
/// shaped paragraph. Several characters may share a single timed word.
class LyricWordCharacter {
  final int ordinal;
  final int startOffset;
  final int endOffset;
  final List<Rect> clips;
  final LyricWordSegment? segment;
  late final Path clipPath = _pathFor(clips);
  late final Rect bounds = _boundsFor(clips);
  LyricWordCharacter(
      this.ordinal, this.startOffset, this.endOffset, this.clips, this.segment);

  // Cache this slice's ranges in the word's highlight reading order. This
  // keeps wrapped/RTL words aligned with the painter without reshaping text.
  late final List<_HighlightSpan> _highlightSpans = _computeHighlightSpans();

  List<_HighlightSpan> _computeHighlightSpans() {
    final word = segment;
    if (word == null) return const [];
    final result = <_HighlightSpan>[];
    var offset = 0.0;
    for (var i = 0; i < word.boxes.length; i++) {
      final box = word.boxes[i];
      final width = box.right - box.left;
      for (final clip in clips) {
        if (!word.clips[i].overlaps(clip)) continue;
        final left = math.max(box.left, clip.left);
        final right = math.min(box.right, clip.right);
        if (right <= left) continue;
        final rtl = box.direction == TextDirection.rtl;
        result.add(_HighlightSpan(
            offset + (rtl ? box.right - right : left - box.left),
            offset + (rtl ? box.right - left : right - box.left)));
      }
      offset += width;
    }
    return result;
  }

  /// Smoothly engages float as the highlight (including its tail) crosses
  /// this grapheme. Unmatched characters in a timed line remain still.
  double highlightProgress(Duration position, double tailFadeWidth) {
    final word = segment;
    if (word == null) return 0;
    final progress = word.progress(position);
    if (progress <= 0) return 0;
    if (progress >= 1) return 1;
    final front = progress * (word.highlightWidth + tailFadeWidth);
    var amount = 0.0, width = 0.0;
    for (final span in _highlightSpans) {
      final extent = span.end - span.start;
      final t =
          ((front - span.start) / (extent + tailFadeWidth)).clamp(0.0, 1.0);
      amount += extent * t * t * (3 - 2 * t);
      width += extent;
    }
    return width > 0 ? amount / width : 0;
  }
}

class _HighlightSpan {
  final double start;
  final double end;
  const _HighlightSpan(this.start, this.end);
}

Path _pathFor(List<Rect> clips) {
  final path = Path();
  for (final clip in clips) {
    path.addRect(clip);
  }
  return path;
}

Rect _boundsFor(List<Rect> clips) =>
    clips.isEmpty ? Rect.zero : clips.reduce((a, b) => a.expandToInclude(b));

class _LyricWordClips {
  final TextPainter text;
  final List<ui.LineMetrics> rows;
  final List<ui.TextBox> fullBoxes;
  late final List<Rect> _rowClips = _computeRowClips();
  _LyricWordClips(this.text, String content)
      : rows = text.computeLineMetrics(),
        fullBoxes = text.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: content.length));

  int rowFor(ui.TextBox box) {
    var nearest = 0;
    var distance = double.infinity;
    for (var i = 0; i < rows.length; i++) {
      final center = rows[i].baseline + (rows[i].descent - rows[i].ascent) / 2;
      final d = ((box.top + box.bottom) / 2 - center).abs();
      if (d < distance) {
        nearest = i;
        distance = d;
      }
    }
    return nearest;
  }

  List<Rect> _computeRowClips() {
    final lefts = List<double>.filled(rows.length, double.infinity);
    final rights = List<double>.filled(rows.length, double.negativeInfinity);
    for (final box in fullBoxes) {
      final row = rowFor(box);
      lefts[row] = math.min(lefts[row], box.left);
      rights[row] = math.max(rights[row], box.right);
    }
    final pad = text.preferredLineHeight;
    return List<Rect>.generate(rows.length, (row) {
      // Shared non-antialiased boundaries preserve glyph coverage/overhang.
      final top = row == 0
          ? -pad
          : (rows[row - 1].baseline +
                  rows[row - 1].descent +
                  rows[row].baseline -
                  rows[row].ascent) /
              2;
      final bottom = row == rows.length - 1
          ? text.height + pad
          : (rows[row].baseline +
                  rows[row].descent +
                  rows[row + 1].baseline -
                  rows[row + 1].ascent) /
              2;
      return Rect.fromLTRB(lefts[row], top, rights[row], bottom);
    });
  }

  Rect clipFor(ui.TextBox box) {
    final pad = text.preferredLineHeight;
    if (rows.isEmpty) return box.toRect().inflate(pad);
    final row = _rowClips[rowFor(box)];
    // Include the current box as before, even for shaping runs that were not
    // present in the full selection (or rows containing only a line break).
    final left = math.min(box.left, row.left);
    final right = math.max(box.right, row.right);
    return Rect.fromLTRB(box.left <= left ? left - pad : box.left, row.top,
        box.right >= right ? right + pad : box.right, row.bottom);
  }
}
