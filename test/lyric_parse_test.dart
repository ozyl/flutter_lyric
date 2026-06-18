import 'package:flutter_lyric/core/lyric_parse.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LrcParser colon timestamp format', () {
    test('isMatch accepts dot and colon fractional separators', () {
      const dotFormat = '[00:00.00] 作词\n[00:00.29] 作曲';
      const colonFormat = '[00:00:58]「おはよ」\n[00:01:20]朝だって';

      expect(LrcParser().isMatch(dotFormat), isTrue);
      expect(LrcParser().isMatch(colonFormat), isTrue);
    });

    test('extractLine parses dot format timestamps', () {
      final line = LrcParser.extractLine('[00:00.29] 作曲');
      expect(line, isNotNull);
      expect(line!.durations.single.inMilliseconds, 290);
      expect(line.text, ' 作曲');
    });

    test('extractLine parses colon format timestamps (Netease)', () {
      final line = LrcParser.extractLine('[00:00:58]「おはよ」');
      expect(line, isNotNull);
      expect(line!.durations.single.inMilliseconds, 580);
      expect(line.text, '「おはよ」');
    });

    test('extractLine parses centiseconds with colon separator', () {
      final line = LrcParser.extractLine('[00:07:79]間に合いそうにない');
      expect(line, isNotNull);
      expect(line!.durations.single.inMilliseconds, 7790);
    });

    test('parseRaw handles mixed dot and colon lyrics', () {
      const lyric = '''
[00:00.00] 作词
[00:00:58]「おはよ」
[00:01:20]朝だって
[00:07:79]間に合いそうにない
''';
      final model = LrcParser().parseRaw(lyric);
      expect(model.lines.length, 4);
      expect(model.lines[0].start.inMilliseconds, 0);
      expect(model.lines[1].start.inMilliseconds, 580);
      expect(model.lines[2].start.inMilliseconds, 1200);
      expect(model.lines[3].start.inMilliseconds, 7790);
    });

    test('parseRaw matches translation by colon timestamp', () {
      const mainLyric = '[00:00:58]「おはよ」';
      const translationLyric = '[00:00:58]「早上好」';

      final model = LrcParser().parseRaw(
        mainLyric,
        translationLyric: translationLyric,
      );

      expect(model.lines.single.translation, '「早上好」');
    });
  });
}
