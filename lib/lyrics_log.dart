import 'dart:developer';

class LyricsLog{

  static var lyricEnableLog = false;

  static final _defaultTag = "LyricReader->";

  static logD(Object? obj){
    _log(_defaultTag, obj);
  }

  static logW(Object? obj){
    _log(_defaultTag+"♦️WARN♦️->", obj);
  }

  static _log(String tag,Object? obj){
    if(lyricEnableLog)
    log(tag + obj.toString());
  }
}


