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
  final double height;
  final double width;
  final double activeWidth;
  final double activeHeight;
  final double translationWidth;
  final double translationHeight;
  final List<ui.LineMetrics> activeMetrics;
  final List<ui.LineMetrics> metrics;
  final TextPainter textPainter;
  final TextPainter activeTextPainter;
  final TextPainter translationTextPainter;

  final List<WordMetrics>? words;

  LineMetrics({
    required this.line,
    required this.height,
    this.words,
    required this.width,
    required this.activeWidth,
    required this.activeHeight,
    required this.translationWidth,
    required this.translationHeight,
    required this.activeMetrics,
    required this.metrics,
    required this.textPainter,
    required this.activeTextPainter,
    required this.translationTextPainter,
  });

  @override
  String toString() {
    return 'LineMetrics(line: $line, height: $height, width: $width, highlightWidth: $activeWidth, highlightHeight: $activeHeight, translationWidth: $translationWidth, translationHeight: $translationHeight, words: $words)';
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
