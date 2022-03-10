import 'package:flutter_lyric/lyric_parser/lyrics_parse.dart';
import 'package:flutter_lyric/lyrics_log.dart';
import 'package:flutter_lyric/lyrics_reader_model.dart';

class ParserLrc extends LyricsParse{

  RegExp pattern = RegExp(r"\[\d{2}:\d{2}.\d{2,3}]");

  ///匹配普通格式内容
  ///eg:[00:03.47] -> 00:03.47
  RegExp valuePattern = RegExp(r"(?<=\[)\d{2}:\d{2}.\d{2,3}(?=\])");

  ParserLrc(String lyric) : super(lyric);

  @override
  List<LyricsLineModel> parseLines({bool isMain:true}) {
    //读每一行
    var lines = lyric.split("\n");
    if (lines.isEmpty) {
      LyricsLog.logD("未解析到歌词");
      return [];
    }
    List<LyricsLineModel> lineList =[];
    lines.forEach((line) {
      //匹配time
      var time = pattern.stringMatch(line);
      if (time == null) {
        //没有匹配到直接返回
        //TODO 歌曲相关信息暂不处理
        LyricsLog.logD("忽略未匹配到Time：$line");
        return;
      }
      //移除time，拿到真实歌词
      var realLyrics = line.replaceFirst(pattern, "");
      //转时间戳
      var ts = timeTagToTS(time);
      LyricsLog.logD("匹配time:$time($ts) 真实歌词：$realLyrics");
      var lineModel = LyricsLineModel()..startTime=ts;
      if(realLyrics=="//"){
        LyricsLog.logD("移除无效字符：//");
        realLyrics = "";
      }
      if(isMain){
        lineModel.mainText = realLyrics;
      }else{
        lineModel.extText = realLyrics;
      }
      lineList.add(lineModel);
    });
    return lineList;
  }

  int? timeTagToTS(String timeTag) {
    if (timeTag.trim().isEmpty) {
      return null;
    }
    //通过正则取出value
    var value = valuePattern.stringMatch(timeTag) ?? "";
    if (value.isEmpty) {
      LyricsLog.logW("未拿到时间值：$timeTag");
      return null;
    }
    var timeArray = value.split(".");
    var padZero = 3 - timeArray.last.length;
    var millsceconds = timeArray.last.padRight(padZero, "0");
    //避免出现奇葩
    if (millsceconds.length > 3) {
      millsceconds = millsceconds.substring(0, 3);
    }
    var minAndSecArray = timeArray.first.split(":");
    return Duration(
        minutes: int.parse(minAndSecArray.first),
        seconds: int.parse(minAndSecArray.last),
        milliseconds: int.parse(millsceconds))
        .inMilliseconds;
  }
}