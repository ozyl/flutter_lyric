import 'package:flutter_lyric/core/lyric_parse.dart' show LrcParser;

abstract class LrcToQrcUtil {
  /// [totalDuration]歌词总时长 可选传
  /// [lastDuration]最后一行歌词时长 可选传
  static String convert(
    String lrc, {
    Duration? totalDuration,
    Duration? lastDuration,
  }) {
    assert(
      totalDuration != null || lastDuration != null,
      'totalDuration or lastDuration must be provided',
    );
    final tags = <String>[];
    final entries = <_LrcEntry>[];

    for (final line in lrc.split('\n')) {
      // 标签
      final tag = RegExp(r'^\[(\D*?):(.*?)\]').firstMatch(line);
      if (tag != null) {
        tags.add(line);
        continue;
      }

      final parsed = LrcParser.extractLine(line);
      if (parsed == null) continue;
      if (parsed.text.trim().isEmpty) continue;

      for (final d in parsed.durations) {
        entries.add(_LrcEntry(start: d, text: parsed.text.trim()));
      }
    }

    if (entries.isEmpty) return lrc;

    entries.sort((a, b) => a.start.compareTo(b.start));

    final buffer = StringBuffer();
    for (final t in tags) {
      buffer.writeln(t);
    }

    for (var i = 0; i < entries.length; i++) {
      final current = entries[i];
      Duration duration;

      if (i + 1 < entries.length) {
        duration = entries[i + 1].start - current.start;
      } else {
        duration = lastDuration ?? (totalDuration! - current.start);
        if (duration < Duration.zero) {
          duration = Duration.zero;
        }
      }

      buffer.writeln(
        '[${current.start.inMilliseconds},${duration.inMilliseconds}]'
        '${current.text}'
        '(${current.start.inMilliseconds},${duration.inMilliseconds})',
      );
    }

    return buffer.toString().trim();
  }
}

class _LrcEntry {
  final Duration start;
  final String text;

  _LrcEntry({required this.start, required this.text});
}
