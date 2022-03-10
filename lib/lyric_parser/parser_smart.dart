import 'package:lyrics_reader/lyric_parser/lyrics_parse.dart';
import 'package:lyrics_reader/lyric_parser/parser_lrc.dart';
import 'package:lyrics_reader/lyric_parser/parser_qrc.dart';
import 'package:lyrics_reader/lyrics_reader_model.dart';


class ParserSmart extends LyricsParse{
  ParserSmart(String lyric) : super(lyric);


  @override
  List<LyricsLineModel> parseLines({bool isMain:true}) {
    var qrc = ParserQrc(lyric);
    if(qrc.isOK()){
      return qrc.parseLines(isMain: isMain);
    }
    return ParserLrc(lyric).parseLines(isMain: isMain);
  }
}