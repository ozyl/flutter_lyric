import 'package:lyrics_reader/lyric_parser/lyrics_parse.dart';
import 'package:lyrics_reader/lyrics_reader.dart';

import 'lyric_parser/parser_smart.dart';
import 'lyrics_reader_model.dart';

/// lyric Util
/// support Simple format、Enhanced format
class LyricsModelBuilder {
  final MAX_VALUE = 9999999999;

  var _lyricModel = LyricsReaderModel();

  reset() {
    _lyricModel = LyricsReaderModel();
  }

  List<LyricsLineModel>? mainLines;
  List<LyricsLineModel>? extLines;


  static LyricsModelBuilder creat() => LyricsModelBuilder._();

  LyricsModelBuilder bindLyricToMain(String lyric, [LyricsParse? parser]) {
    mainLines = (parser??ParserSmart(lyric)).parseLines();
    return this;
  }

  LyricsModelBuilder bindLyricToExt(String lyric,[LyricsParse? parser]) {
    extLines = (parser??ParserSmart(lyric)).parseLines(isMain: false);
    return this;
  }

  _setLyric(List<LyricsLineModel>? lineList, {isMain = true}) {
    if(lineList==null)return;
    //下一行的开始时间则为上一行的结束时间，若无则MAX
    for (int i = 0; i < lineList.length; i++) {
      try {
        lineList[i].endTime = lineList[i + 1].startTime;
      } catch (e) {
        //越界异常时直接MAX
        lineList[i].endTime = MAX_VALUE;
      }
    }
    if (isMain) {
      _lyricModel.lyrics.clear();
      _lyricModel.lyrics.addAll(lineList);
    } else {
      //扩展歌词对应行
      for (var mainLine in _lyricModel.lyrics) {
        var extLine = lineList.firstWhere(
            (extLine) =>
                mainLine.startTime == extLine.startTime &&
                mainLine.endTime == extLine.endTime, orElse: () {
          return LyricsLineModel();
        });
        mainLine.extText = extLine.extText;
      }
    }
  }

  LyricsReaderModel getModel() {
    _setLyric(mainLines, isMain: true);
    _setLyric(extLines, isMain: false);

    return _lyricModel;
  }

  LyricsModelBuilder._();
}
