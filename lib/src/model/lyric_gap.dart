import 'lyric_document.dart';
import '../preset/lyric_countdown.dart';

/// A silent interval identified by timing or an explicit vocal-start hint.
/// Never estimates singing duration from text.
class LyricGap {
  final Duration start;
  final Duration end;
  final int nextIndex;
  final bool isIntro;

  /// A provider supplied the first vocal start, allowing intro credit time
  /// from zero to that start to contribute to the countdown budget.
  final bool hasVocalStart;
  const LyricGap(this.start, this.end, this.nextIndex, this.isIntro,
      {this.hasVocalStart = false});

  bool isEnabledBy(LyricCountdown config) =>
      config.enabled &&
      config.dotDuration > Duration.zero &&
      end - start >= config.dotDuration;

  Duration displayStart(LyricCountdown config) {
    final from = end - config.dotDuration - config.breathDuration;
    return from < start ? start : from;
  }

  double dotProgress(Duration position, LyricCountdown config) =>
      (1 - (end - position).inMicroseconds / config.dotDuration.inMicroseconds)
          .clamp(0.0, 1.0)
          .toDouble();
}

class LyricGapTimeline {
  final List<LyricGap> gaps;
  LyricGapTimeline(LyricDocument? document) : gaps = _findGaps(document);

  static bool _hasText(LyricLine line) =>
      line.text.trim().isNotEmpty ||
      (line.translation?.trim().isNotEmpty ?? false) ||
      (line.words?.any((word) => word.text.trim().isNotEmpty) ?? false);

  static List<LyricGap> _findGaps(LyricDocument? document) {
    final lines = document?.lines ?? const <LyricLine>[];
    var firstIndex = 0;
    final vocalStart = document?.vocalStart;
    if (vocalStart != null) {
      // Prefer an exact match so a credit immediately before the vocal is
      // never mistaken for it by the compatibility tolerance below.
      firstIndex = lines
          .indexWhere((line) => line.start == vocalStart && _hasText(line));
      // LRC exports can truncate millisecond starts to centiseconds. Locate
      // that same first sung line without mistaking it for an intro credit.
      if (firstIndex < 0) {
        final earliestStart = vocalStart - const Duration(milliseconds: 9);
        firstIndex = lines.indexWhere(
            (line) => line.start >= earliestStart && _hasText(line));
      }
      if (firstIndex < 0) return const [];
    }
    // Unknown durations last until the next strictly later timestamp. A blank
    // LRC entry can therefore mark silence without truncating explicit ends.
    final nextStarts = List<Duration?>.filled(lines.length, null);
    Duration? next;
    for (var i = lines.length - 1; i >= 0; i--) {
      if (i + 1 < lines.length && lines[i + 1].start > lines[i].start) {
        next = lines[i + 1].start;
      }
      nextStarts[i] = next;
    }
    final result = <LyricGap>[];
    // Credits describe the intro, not singing. Their starts and ends must not
    // shorten an explicitly identified intro or affect countdown eligibility.
    var occupiedUntil = Duration.zero;
    var hadLyrics = false;
    for (var i = firstIndex; i < lines.length; i++) {
      final line = lines[i];
      if (!_hasText(line)) continue;
      if (line.start > occupiedUntil) {
        result.add(LyricGap(occupiedUntil, line.start, i, !hadLyrics,
            hasVocalStart: !hadLyrics && vocalStart != null));
      }
      hadLyrics = true;
      var end = line.end;
      if (end == null || end < line.start) {
        final words = line.words;
        end = null;
        if (words != null && words.isNotEmpty) {
          var complete = true;
          for (final word in words) {
            final wordEnd = word.end;
            if (wordEnd == null || wordEnd < word.start) {
              complete = false;
              break;
            }
            if (end == null || wordEnd > end) end = wordEnd;
          }
          if (!complete || (end != null && end < line.start)) end = null;
        }
        end ??= nextStarts[i] ?? line.start;
      }
      if (end > occupiedUntil) occupiedUntil = end;
    }
    return result;
  }

  LyricGap? at(Duration position, LyricCountdown config) {
    if (!config.enabled) return null;
    var low = 0;
    var high = gaps.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (gaps[mid].end <= position) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    if (low == gaps.length) return null;
    final gap = gaps[low];
    if (!gap.isEnabledBy(config) || position < gap.displayStart(config)) {
      return null;
    }
    return gap;
  }
}
