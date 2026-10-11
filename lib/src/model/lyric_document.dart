import '../parser/lyric_parser.dart';

/// Immutable, time-ordered lyrics. Times use the lyric timeline; [offset] is
/// added to the player's position before looking up the active line.
class LyricDocument {
  final Map<String, String> tags;
  final List<LyricLine> lines;
  final Duration offset;

  LyricDocument({
    required List<LyricLine> lines,
    Map<String, String> tags = const {},
    Duration? offset,
  })  : tags = Map.unmodifiable(tags),
        lines = _ordered(lines),
        offset = offset ??
            Duration(milliseconds: int.tryParse(tags['offset'] ?? '') ?? 0);

  factory LyricDocument.parse(String text,
      {String? translation, LyricParser? parser}) {
    return parser == null
        ? LyricParser.autoDetect(text, translationLyric: translation)
        : parser.parse(text, translationLyric: translation);
  }

  static List<LyricLine> _ordered(List<LyricLine> lines) {
    final indexed = lines.asMap().entries.toList()
      ..sort((a, b) {
        final order = a.value.start.compareTo(b.value.start);
        return order == 0 ? a.key.compareTo(b.key) : order;
      });
    return List.unmodifiable(indexed.map((entry) => entry.value));
  }

  LyricDocument copyWith({
    List<LyricLine>? lines,
    Map<String, String>? tags,
    Duration? offset,
  }) =>
      LyricDocument(
        lines: lines ?? this.lines,
        tags: tags ?? this.tags,
        offset: offset ?? this.offset,
      );

  String get title => tags['ti'] ?? '';
  String get artist => tags['ar'] ?? '';
  String get album => tags['al'] ?? '';
  String get by => tags['by'] ?? '';

  @override
  String toString() => 'LyricDocument(${lines.length} lines, offset: $offset)';
}

/// One lyric entry; it may wrap visually and may contain a translation.
class LyricLine {
  final Duration start;
  final Duration? end;
  final String text;
  final String? translation;
  final List<LyricWord>? words;

  LyricLine({
    required this.start,
    required this.text,
    this.end,
    this.translation,
    List<LyricWord>? words,
  }) : words = words == null ? null : List.unmodifiable(words);

  @override
  String toString() => 'LyricLine(start: $start, text: $text)';
}

/// A timed word or syllable. Both times are relative to the complete document.
class LyricWord {
  final String text;
  final Duration start;
  final Duration? end;

  const LyricWord({required this.text, required this.start, this.end});

  @override
  String toString() => 'LyricWord($text, $start–$end)';
}

/// Internal parser result for an LRC metadata tag.
class LyricTag {
  final String tag;
  final String value;
  const LyricTag({required this.tag, required this.value});
}
