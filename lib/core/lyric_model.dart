import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// 整首歌词
class LyricModel {
  final Map<String, String> idTags;
  final List<LyricLine> lines;
  LyricModel({Map<String, String>? tags, required this.lines})
      : idTags = tags ?? {};

  LyricModel copyWith(Map<String, String>? tags, List<LyricLine>? lines) {
    return LyricModel(tags: tags ?? idTags, lines: lines ?? this.lines);
  }

  @override
  String toString() {
    return 'LyricModel(idTags: $idTags, lines: $lines)';
  }

  String get title => idTags['ti'] ?? '';
  String get artist => idTags['ar'] ?? '';
  String get album => idTags['al'] ?? '';
  String get by => idTags['by'] ?? '';
  int get offset => int.tryParse(idTags['offset'] ?? '0') ?? 0;
}

/// 单行歌词
class LyricLine {
  final Duration start; // 行开始时间
  final Duration? end; // 行结束时间，可选
  final String text; // 行文本
  final List<LyricWord>? words; // 可选：逐字高亮信息
  // 可选副歌词字段
  final String? translation; // 翻译

  LyricLine({
    required this.start,
    this.end,
    required this.text,
    this.translation,
    this.words,
  });

  @override
  String toString() {
    return 'LyricLine(start: $start, end: $end, text: $text, translation: $translation, words: $words)';
  }
}

/// 单词/逐字信息
class LyricWord {
  final String text; // 单词/字文本
  final Duration start; // 相对于整首歌的起始时间
  final Duration? end; // 相对于整首歌的结束时间

  LyricWord({required this.text, required this.start, this.end});

  @override
  String toString() {
    return 'LyricWord(text: $text, start: $start, end: $end)';
  }
}

// 单行测量结果
class LineMetrics {
  final LyricLine line;
  final TextPainter textPainter;
  final TextPainter translationTextPainter;
  TextPainter? _activeTextPainter;
  TextPainter? _textMaskPainter;
  TextPainter? _activeMaskPainter;
  double? _height, _width, _activeWidth, _activeHeight;
  double? _translationWidth, _translationHeight;
  List<ui.LineMetrics>? _activeMetrics, _metrics;
  List<WordMetrics>? _words;
  bool _wordsComputed = true;
  bool _disposed = false;
  double? _maxWidth;
  TextStyle? _activeStyle;

  double get height => _height ??= textPainter.height;
  double get width => _width ??= textPainter.width;
  double get activeWidth => _activeWidth ??= activeTextPainter.width;
  double get activeHeight => _activeHeight ??= activeTextPainter.height;
  double get translationWidth => _translationWidth ??=
      translationTextPainter.text == null ? 0 : translationTextPainter.width;
  double get translationHeight => _translationHeight ??=
      translationTextPainter.text == null ? 0 : translationTextPainter.height;
  List<ui.LineMetrics> get metrics =>
      _metrics ??= textPainter.computeLineMetrics();
  List<ui.LineMetrics> get activeMetrics =>
      _activeMetrics ??= activeTextPainter.computeLineMetrics();

  TextPainter get activeTextPainter {
    assert(!_disposed);
    return _activeTextPainter ??= (TextPainter(
      text: TextSpan(text: line.text, style: _activeStyle),
      textAlign: textPainter.textAlign,
      textDirection: textPainter.textDirection,
    )..layout(maxWidth: _maxWidth!));
  }

  TextPainter get textMaskPainter {
    assert(!_disposed);
    return _textMaskPainter ??=
        createHighlightMaskPainter(textPainter, _maxWidth!);
  }

  TextPainter get activeMaskPainter {
    assert(!_disposed);
    return _activeMaskPainter ??=
        createHighlightMaskPainter(activeTextPainter, _maxWidth!);
  }

  List<WordMetrics>? get words {
    assert(!_disposed);
    if (!_wordsComputed) {
      _words = _calcWordMetrics();
      _wordsComputed = true;
    }
    return _words;
  }

  Iterable<TextPainter> get _initializedPainters sync* {
    yield textPainter;
    yield translationTextPainter;
    if (_activeTextPainter != null) yield _activeTextPainter!;
    if (_textMaskPainter != null) yield _textMaskPainter!;
    if (_activeMaskPainter != null) yield _activeMaskPainter!;
  }

  @visibleForTesting
  int get debugPainterCount => _initializedPainters.length;

  @visibleForTesting
  bool get debugWordMetricsComputed => _wordsComputed;

  LineMetrics({
    required this.line,
    required double height,
    List<WordMetrics>? words,
    required double width,
    required double activeWidth,
    required double activeHeight,
    required double translationWidth,
    required double translationHeight,
    required List<ui.LineMetrics> activeMetrics,
    required List<ui.LineMetrics> metrics,
    required this.textPainter,
    required TextPainter activeTextPainter,
    required TextPainter textMaskPainter,
    required TextPainter activeMaskPainter,
    required this.translationTextPainter,
  })  : _height = height,
        _width = width,
        _activeWidth = activeWidth,
        _activeHeight = activeHeight,
        _translationWidth = translationWidth,
        _translationHeight = translationHeight,
        _activeMetrics = activeMetrics,
        _metrics = metrics,
        _words = words,
        _activeTextPainter = activeTextPainter,
        _textMaskPainter = textMaskPainter,
        _activeMaskPainter = activeMaskPainter;

  /// Normal and translation painters have already been laid out for exact
  /// scrolling geometry. Everything used only for highlighting is cached on
  /// first access, so offscreen lines need no active/mask paragraphs or boxes.
  LineMetrics.lazy({
    required this.line,
    required this.textPainter,
    required this.translationTextPainter,
    required TextStyle activeStyle,
    required double maxWidth,
  })  : _activeStyle = activeStyle,
        _maxWidth = maxWidth,
        _wordsComputed = false;

  /// Changes paint-only styles without initializing deferred paragraphs.
  void updatePaintStyles({
    required TextStyle textStyle,
    required TextStyle activeStyle,
    required TextStyle translationStyle,
  }) {
    textPainter.text = TextSpan(text: line.text, style: textStyle);
    _activeStyle = activeStyle;
    _activeTextPainter?.text = TextSpan(text: line.text, style: activeStyle);
    _textMaskPainter?.text =
        buildHighlightMaskTextSpan(TextSpan(text: line.text, style: textStyle));
    _activeMaskPainter?.text = buildHighlightMaskTextSpan(
        TextSpan(text: line.text, style: activeStyle));
    if (line.translation != null) {
      translationTextPainter.text =
          TextSpan(text: line.translation, style: translationStyle);
    }
  }

  /// Re-measures initialized paragraphs after a system font change. Deferred
  /// paragraphs will pick up the current fonts when first accessed.
  void relayout(double maxWidth) {
    _maxWidth = maxWidth;
    for (final painter in _initializedPainters) {
      painter.markNeedsLayout();
      if (painter.text != null) painter.layout(maxWidth: maxWidth);
    }
    _height = _width = _activeHeight = _activeWidth = null;
    _translationHeight = _translationWidth = null;
    _metrics = _activeMetrics = null;
    _words = null;
    _wordsComputed = false;
  }

  /// Releases only initialized resources, without creating deferred painters.
  void dispose() {
    if (_disposed) return;
    for (final painter in _initializedPainters) {
      painter.dispose();
    }
    _disposed = true;
  }

  static TextPainter createHighlightMaskPainter(
      TextPainter sourcePainter, double maxWidth) {
    return TextPainter(
      text: buildHighlightMaskTextSpan(sourcePainter.text! as TextSpan),
      textAlign: sourcePainter.textAlign,
      textDirection: sourcePainter.textDirection,
    )..layout(maxWidth: maxWidth);
  }

  static TextSpan buildHighlightMaskTextSpan(TextSpan source) {
    return TextSpan(
      text: source.text,
      children: source.children?.map((child) {
        return child is TextSpan ? buildHighlightMaskTextSpan(child) : child;
      }).toList(),
      // Neutral coverage avoids color-dependent glyph antialiasing.
      style: source.style?.copyWith(color: const Color(0xFFFFFFFF)),
    );
  }

  List<WordMetrics>? _calcWordMetrics() {
    var currentOffset = 0;
    return line.words?.map((word) {
      final wordStart = line.text.indexOf(word.text, currentOffset);
      if (wordStart == -1) {
        return WordMetrics(
          word: word,
          width: 0,
          height: height,
          highlightWidth: 0,
          highlightHeight: activeHeight,
        );
      }
      final wordEnd = wordStart + word.text.length;
      currentOffset = wordEnd;
      final selection =
          TextSelection(baseOffset: wordStart, extentOffset: wordEnd);
      Size wordSize(TextPainter painter) {
        var width = 0.0;
        var height = 0.0;
        for (final box in painter.getBoxesForSelection(selection)) {
          width += box.right - box.left;
          final boxHeight = box.bottom - box.top;
          if (boxHeight > height) height = boxHeight;
        }
        return Size(width, height);
      }

      final normal = wordSize(textPainter);
      final active = wordSize(activeTextPainter);
      return WordMetrics(
        word: word,
        width: normal.width,
        height: normal.height,
        highlightWidth: active.width,
        highlightHeight: active.height,
      );
    }).toList();
  }

  @override
  String toString() {
    // Diagnostics must not initialize deferred paragraphs or word bounds.
    return 'LineMetrics(line: $line, height: $_height, width: $_width, highlightWidth: $_activeWidth, highlightHeight: $_activeHeight, translationWidth: $_translationWidth, translationHeight: $_translationHeight, words: $_words)';
  }

  LineMetrics copyWith({
    LyricLine? line,
    double? height,
    double? width,
    double? activeWidth,
    double? activeHeight,
    double? translationWidth,
    double? translationHeight,
    List<ui.LineMetrics>? activeMetrics,
    List<ui.LineMetrics>? metrics,
    TextPainter? textPainter,
    TextPainter? activeTextPainter,
    TextPainter? textMaskPainter,
    TextPainter? activeMaskPainter,
    TextPainter? translationTextPainter,
    List<WordMetrics>? words,
  }) {
    return LineMetrics(
      line: line ?? this.line,
      height: height ?? this.height,
      width: width ?? this.width,
      activeWidth: activeWidth ?? this.activeWidth,
      activeHeight: activeHeight ?? this.activeHeight,
      translationWidth: translationWidth ?? this.translationWidth,
      translationHeight: translationHeight ?? this.translationHeight,
      activeMetrics: activeMetrics ?? this.activeMetrics,
      metrics: metrics ?? this.metrics,
      textPainter: textPainter ?? this.textPainter,
      activeTextPainter: activeTextPainter ?? this.activeTextPainter,
      textMaskPainter: textMaskPainter ?? this.textMaskPainter,
      activeMaskPainter: activeMaskPainter ?? this.activeMaskPainter,
      translationTextPainter:
          translationTextPainter ?? this.translationTextPainter,
      words: words ?? this.words,
    );
  }
}

class WordMetrics {
  final double width;
  final double height;
  final LyricWord word;
  final double highlightWidth;
  final double highlightHeight;

  WordMetrics({
    required this.word,
    required this.width,
    required this.height,
    required this.highlightWidth,
    required this.highlightHeight,
  });

  @override
  String toString() {
    return 'WordMetrics(word: $word, width: $width, height: $height, highlightWidth: $highlightWidth, highlightHeight: $highlightHeight)';
  }
}

class LyricTag {
  final String tag;
  final String value;

  LyricTag({required this.tag, required this.value});
}
