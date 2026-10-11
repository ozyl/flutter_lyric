import '../model/lyric_document.dart' show LyricDocument;

import 'lyric_parser.dart' show LyricParser;

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
