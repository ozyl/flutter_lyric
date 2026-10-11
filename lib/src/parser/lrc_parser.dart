import '../model/lyric_document.dart' show LyricDocument, LyricLine;

import 'lrc_line.dart';
import 'lyric_parser.dart' show LyricParser;
import 'parser_utils.dart';

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
      final tagInfo = extractLyricTag(line);
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
