import 'dart:convert';

import 'package:flutter_lyric/src/model/lyric_document.dart'
    show LyricDocument, LyricLine, LyricWord, LyricTag;

abstract class LyricParser {
  bool canParse(String mainLyric);

  static LyricDocument autoDetect(
    String mainLyric, {
    String? translationLyric,
    List<LyricParser>? parsers,
  }) {
    return (parsers ??
            [LrcParser(), YrcParser(), QrcParser(), FallbackParser()])
        .firstWhere((parser) => parser.canParse(mainLyric))
        .parse(mainLyric, translationLyric: translationLyric);
  }

  /// 解析主歌词，可选传入副歌词文本
  LyricDocument parse(String mainLyric, {String? translationLyric});

  /// 解析标签，返回 Map，不是标签返回 null
  LyricTag? _extractTag(String line) {
    final match = RegExp(r'^\[(\D*?):(.*?)\]').firstMatch(line);
    if (match == null) return null;
    return LyricTag(tag: match.group(1)!, value: match.group(2)!);
  }
}

class LrcLine {
  final List<Duration> durations;
  final String text;
  LrcLine({
    required this.durations,
    required this.text,
  });

  @override
  String toString() {
    return 'LrcLine(durations: $durations, text: $text)';
  }
}

class Pair<T, U> {
  final T first;
  final U second;
  Pair({required this.first, required this.second});
  @override
  String toString() {
    return 'Pair(first: $first, second: $second)';
  }
}

class LrcParser extends LyricParser {
  @override
  bool canParse(String mainLyric) {
    return RegExp(
      r'^\[(\d{1,}):(\d{2})(?:[.:](\d{1,}))?\]',
      multiLine: true,
    ).hasMatch(mainLyric);
  }

  @override
  LyricDocument parse(String mainLyric, {String? translationLyric}) {
    final idTags = <String, String>{};
    final lines = <LyricLine>[];
    // 提取翻译歌词
    var translationMap = extractTranslationMap(translationLyric);
    for (var line in mainLyric.split('\n')) {
      // 提取标签内容
      final tagInfo = _extractTag(line);
      if (tagInfo != null) {
        final tag = tagInfo;
        idTags[tag.tag] = tag.value;
        continue;
      }
      final lineInfo = extractLine(line);
      if (lineInfo != null) {
        final lrcLine = lineInfo;
        for (var duration in lrcLine.durations) {
          lines.add(
            LyricLine(
              start: duration,
              text: lrcLine.text,
              translation: translationMap[duration.inMilliseconds],
            ),
          );
        }
      }
    }
    return LyricDocument(lines: lines, tags: idTags);
  }

  static Map<int, String> extractTranslationMap(String? translationLyric) {
    // 提取翻译歌词
    var translationMap = <int, String>{};
    for (var line in translationLyric?.split('\n') ?? []) {
      final lineInfo = LrcParser.extractLine(line);
      if (lineInfo != null) {
        final lrcLine = lineInfo;
        //剔除无效歌词
        if (['', '//'].contains(lrcLine.text)) continue;
        for (var duration in lrcLine.durations) {
          translationMap[duration.inMilliseconds] = lrcLine.text;
        }
      }
    }
    return translationMap;
  }

  static String? findTranslation(
      Map<int, String> translationMap, int ms, int tolerance) {
    var t = translationMap[ms];
    if (t != null) {
      return t;
    }
    for (var i = 1; i <= tolerance; i++) {
      if (translationMap[ms - i] != null) {
        return translationMap[ms - i];
      }
      if (translationMap[ms + i] != null) {
        return translationMap[ms + i];
      }
    }
    return null;
  }

  static LrcLine? extractLine(String line) {
    final regexp = RegExp(
      r'\[(\d{1,}):(\d{2})(?:[.:](\d{1,}))?\]',
      multiLine: true,
    );
    final matches = regexp.allMatches(line);
    if (matches.isEmpty) return null;
    final durations = <Duration>[];
    for (var match in matches) {
      final minutes = match.group(1);
      final seconds = match.group(2);
      var milliseconds = match.group(3) ?? '0';
      if (milliseconds.length > 3) {
        milliseconds = milliseconds.substring(0, 3);
      }
      Duration duration = Duration(
        minutes: int.parse(minutes!),
        seconds: int.parse(seconds!),
        milliseconds: int.parse(milliseconds.padRight(3, '0')),
      );
      durations.add(duration);
      line = line.replaceAll(match.group(0)!, '');
    }
    return LrcLine(durations: durations, text: line);
  }
}

class YrcParser extends LyricParser {
  static final _syllable = RegExp(r'\((\d+),(\d+),\d+\)([^(]*)');
  static final _lineHeader = RegExp(r'^\[(\d+),(\d+)\](.*)$');

  @override
  bool canParse(String mainLyric) {
    return _syllable.hasMatch(mainLyric);
  }

  @override
  LyricDocument parse(String mainLyric, {String? translationLyric}) {
    final idTags = <String, String>{};
    final translationMap = LrcParser.extractTranslationMap(translationLyric);
    final lines = <LyricLine>[];
    for (final line in mainLyric.split('\n')) {
      final tagInfo = _extractTag(line);
      if (tagInfo != null) {
        idTags[tagInfo.tag] = tagInfo.value;
        continue;
      }
      final jsonLine = _extractJsonLine(line, translationMap);
      if (jsonLine != null) {
        lines.add(jsonLine);
        continue;
      }
      final timedLine = _extractTimedLine(line, translationMap);
      if (timedLine != null) {
        lines.add(timedLine);
      }
    }
    return LyricDocument(lines: lines, tags: idTags);
  }

  LyricLine? _extractJsonLine(
    String line,
    Map<int, String> translationMap,
  ) {
    final trimmed = line.trimLeft();
    if (!trimmed.startsWith('{')) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) return null;
      final t = decoded['t'];
      final c = decoded['c'];
      if (t is! num || c is! List) return null;
      final text = c
          .whereType<Map<String, dynamic>>()
          .map((item) => item['tx'])
          .whereType<String>()
          .join();
      if (text.isEmpty) return null;
      final start = Duration(milliseconds: t.toInt());
      return LyricLine(
        start: start,
        text: text,
        translation: LrcParser.findTranslation(
          translationMap,
          start.inMilliseconds,
          10,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  LyricLine? _extractTimedLine(
    String line,
    Map<int, String> translationMap,
  ) {
    final header = _lineHeader.firstMatch(line);
    if (header == null) return null;
    final startMs = int.parse(header.group(1)!);
    final durationMs = int.parse(header.group(2)!);
    final rest = header.group(3)!;
    final words = <LyricWord>[];
    final text = StringBuffer();
    for (final match in _syllable.allMatches(rest)) {
      final wordStart = Duration(milliseconds: int.parse(match.group(1)!));
      final wordDur = Duration(milliseconds: int.parse(match.group(2)!));
      final wordText = match.group(3)!;
      text.write(wordText);
      words.add(LyricWord(
        text: wordText,
        start: wordStart,
        end: wordStart + wordDur,
      ));
    }
    if (words.isEmpty) return null;
    final start = Duration(milliseconds: startMs);
    return LyricLine(
      start: start,
      end: start + Duration(milliseconds: durationMs),
      text: text.toString(),
      words: words,
      translation: LrcParser.findTranslation(
        translationMap,
        start.inMilliseconds,
        10,
      ),
    );
  }
}

class QrcParser extends LyricParser {
  @override
  bool canParse(String mainLyric) {
    if (YrcParser._syllable.hasMatch(mainLyric)) return false;
    return RegExp(
      r'^\[\d{1,},(\d{1,})?\]',
      multiLine: true,
    ).hasMatch(mainLyric);
  }

  @override
  LyricDocument parse(String mainLyric, {String? translationLyric}) {
    final idTags = <String, String>{};
    final match = RegExp(r'LyricContent=([\s\S]*)"\/>').firstMatch(mainLyric);

    // 提取翻译歌词
    var translationMap = LrcParser.extractTranslationMap(translationLyric);

    final lyricContent = match?.group(1) ?? mainLyric;
    final lineRegExp = RegExp(r'(\[\d+,\d+\])?(.*?)(\(\d+,\d+\))');
    final lines = <LyricLine>[];
    for (var line in lyricContent.split('\n')) {
      // 提取标签内容
      final tagInfo = _extractTag(line);
      if (tagInfo != null) {
        final tag = tagInfo;
        idTags[tag.tag] = tag.value;
        continue;
      }
      Duration startTime = Duration.zero;
      Duration endTime = Duration.zero;
      String text = '';
      final matchs = lineRegExp.allMatches(line);
      if (matchs.isEmpty) continue;
      final words = <LyricWord>[];
      for (var match in matchs) {
        final totalTime = match.group(1);
        if (totalTime?.isNotEmpty ?? false) {
          final time = extractTime(totalTime!);
          startTime = time.first;
          endTime = time.first + time.second;
        }
        final wordText = match.group(2) ?? '';
        text += wordText;

        final time = extractTime(match.group(3)!);
        words.add(LyricWord(
            text: wordText, start: time.first, end: time.first + time.second));
      }
      LyricLine lyricLine = LyricLine(
        start: startTime,
        end: endTime,
        text: text,
        words: words,
        translation: LrcParser.findTranslation(
            translationMap, startTime.inMilliseconds, 10),
      );
      lines.add(lyricLine);
    }
    return LyricDocument(lines: lines, tags: idTags);
  }

  Pair<Duration, Duration> extractTime(String time) {
    final timeRegExp = RegExp(r'.(\d+),(\d+).');
    final timeMatch = timeRegExp.firstMatch(time);
    final start = timeMatch!.group(1)!;
    final duration = timeMatch.group(2)!;
    return Pair(
        first: Duration(milliseconds: int.parse(start)),
        second: Duration(milliseconds: int.parse(duration)));
  }
}

class FallbackParser extends LyricParser {
  @override
  bool canParse(String mainLyric) {
    return true;
  }

  @override
  LyricDocument parse(String mainLyric, {String? translationLyric}) {
    return LyricDocument(lines: []);
  }
}
