import 'package:flutter_lyric/lyrics_reader_model.dart';

abstract class LyricsParse {
  String lyric;

  LyricsParse(this.lyric);

  List<LyricsLineModel> parseLines({bool isMain: true});

  bool isOK() => true;
}
