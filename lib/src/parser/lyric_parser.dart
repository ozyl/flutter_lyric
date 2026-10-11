import '../model/lyric_document.dart' show LyricDocument;

import 'fallback_parser.dart';
import 'lrc_parser.dart';
import 'qrc_parser.dart';
import 'yrc_parser.dart';

export '../model/pair.dart' show Pair;
export 'fallback_parser.dart' show FallbackParser;
export 'lrc_line.dart' show LrcLine;
export 'lrc_parser.dart' show LrcParser;
export 'qrc_parser.dart' show QrcParser;
export 'yrc_parser.dart' show YrcParser;

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
}
