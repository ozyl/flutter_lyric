import 'dart:convert';

import '../model/lyric_document.dart' show LyricDocument, LyricLine, LyricWord;

import 'lrc_parser.dart';
import 'lyric_parser.dart' show LyricParser;
import 'parser_utils.dart';

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
      final tagInfo = extractLyricTag(line);
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
