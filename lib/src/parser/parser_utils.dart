import '../model/lyric_document.dart' show LyricTag;

/// 解析标签，不是标签返回 null。
LyricTag? extractLyricTag(String line) {
  final match = RegExp(r'^\[(\D*?):(.*?)\]').firstMatch(line);
  if (match == null) return null;
  return LyricTag(tag: match.group(1)!, value: match.group(2)!);
}
