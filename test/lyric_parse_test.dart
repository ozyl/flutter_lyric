import 'package:flutter_lyric/src/parser/lyric_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LrcParser colon timestamp format', () {
    test('isMatch accepts dot and colon fractional separators', () {
      const dotFormat = '[00:00.00] 作词\n[00:00.29] 作曲';
      const colonFormat = '[00:00:58]「おはよ」\n[00:01:20]朝だって';

      expect(LrcParser().canParse(dotFormat), isTrue);
      expect(LrcParser().canParse(colonFormat), isTrue);
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
      final model = LrcParser().parse(lyric);
      expect(model.lines.length, 4);
      expect(model.lines[0].start.inMilliseconds, 0);
      expect(model.lines[1].start.inMilliseconds, 580);
      expect(model.lines[2].start.inMilliseconds, 1200);
      expect(model.lines[3].start.inMilliseconds, 7790);
    });

    test('parseRaw matches translation by colon timestamp', () {
      const mainLyric = '[00:00:58]「おはよ」';
      const translationLyric = '[00:00:58]「早上好」';

      final model = LrcParser().parse(
        mainLyric,
        translationLyric: translationLyric,
      );

      expect(model.lines.single.translation, '「早上好」');
    });
  });

  group('YrcParser', () {
    const yrcLine =
        '[54260,3090](54260,900,0)Stop (55160,480,0)and (55640,1710,0)stare';
    const qrcLine =
        '[126,3253]Doctor (126,1037)actor (1163,479)lawyer (1642,479)or (2121,399)a (2520,191)singer(2711,668)';
    const qrcXml = '''
<?xml version="1.0" encoding="utf-8"?>
<QrcInfos>
<Lyric_1 LyricType="1" LyricContent="[ti:Be what you wanna be]
[126,3253]Doctor (126,1037)actor (1163,479)lawyer (1642,479)or (2121,399)a (2520,191)singer(2711,668)
"/>
</QrcInfos>
''';

    test('isMatch distinguishes YRC from QRC and LRC', () {
      expect(YrcParser().canParse(yrcLine), isTrue);
      expect(YrcParser().canParse(qrcLine), isFalse);
      expect(YrcParser().canParse('[00:54.260]Stop and stare'), isFalse);
      expect(QrcParser().canParse(yrcLine), isFalse);
      expect(QrcParser().canParse(qrcLine), isTrue);
    });

    test('parseRaw extracts syllable times and keeps spaces', () {
      final model = YrcParser().parse(yrcLine);
      expect(model.lines, hasLength(1));
      final line = model.lines.single;
      expect(line.start.inMilliseconds, 54260);
      expect(line.end!.inMilliseconds, 57350);
      expect(line.text, 'Stop and stare');
      expect(line.words, hasLength(3));
      expect(line.words![0].text, 'Stop ');
      expect(line.words![0].start.inMilliseconds, 54260);
      expect(line.words![0].end!.inMilliseconds, 55160);
      expect(line.words![1].text, 'and ');
      expect(line.words![1].start.inMilliseconds, 55160);
      expect(line.words![1].end!.inMilliseconds, 55640);
      expect(line.words![2].text, 'stare');
      expect(line.words![2].start.inMilliseconds, 55640);
      expect(line.words![2].end!.inMilliseconds, 57350);
    });

    test('parseRaw joins Netease JSON credit header', () {
      const lyric =
          '{"t":0,"c":[{"tx":"作词: "},{"tx":"Brent Kutzle"}]}\n$yrcLine';
      final model = YrcParser().parse(lyric);
      expect(model.lines, hasLength(2));
      expect(model.lines[0].start.inMilliseconds, 0);
      expect(model.lines[0].text, '作词: Brent Kutzle');
      expect(model.lines[0].words, isNull);
      expect(model.lines[1].text, 'Stop and stare');
    });

    test('parseRaw matches LRC translation by line start', () {
      const translation = '[00:54.260]停下注视';
      final model = YrcParser().parse(
        yrcLine,
        translationLyric: translation,
      );
      expect(model.lines.single.translation, '停下注视');
    });

    test('LyricParser.autoDetect auto-selects YrcParser', () {
      const lyric =
          '{"t":0,"c":[{"tx":"作词: "},{"tx":"Brent Kutzle"}]}\n$yrcLine';
      final model = LyricParser.autoDetect(lyric);
      expect(model.lines, hasLength(2));
      expect(model.lines[1].words, hasLength(3));
    });

    test('LyricParser.autoDetect still handles QRC XML', () {
      final model = LyricParser.autoDetect(qrcXml);
      expect(model.lines, isNotEmpty);
      expect(model.lines.last.text, 'Doctor actor lawyer or a singer');
      expect(model.lines.last.words, isNotEmpty);
    });
  });
}
