
import 'package:flutter/cupertino.dart';
import 'package:flutter_lyric/lyric_helper.dart';
import 'package:flutter_lyric/lyric_ui/lyric_ui.dart';
import 'package:collection/collection.dart';

///lyric model
class LyricsReaderModel {
  List<LyricsLineModel> lyrics = [];

  getCurrentLine(double progress) {
    for (var i = 0; i < lyrics.length; i++) {
      var element = lyrics[i];
      if (progress >= (element.startTime ?? 0) &&
          progress < (element.endTime ?? 0)) {
        return i;
      }
    }
    return 0;
  }

  double computeScroll(int toLine, int playLine, LyricUI ui) {
    if (toLine == 0) return 0;
    var targetLine = lyrics[toLine];
    double offset = 0;
    if (!targetLine.hasExt && !targetLine.hasMain) {
      offset += ui.getBlankLineHeight() + ui.getLineSpace();
    } else {
      offset += ui.getLineSpace();
      offset += LyricHelper.centerOffset(
          targetLine, toLine == playLine, ui, playLine);
    }
    //需要特殊处理往上偏移的第一行
    return -LyricHelper.getTotalHeight(
            lyrics.sublist(0, toLine), playLine, ui) +
        firstCenterOffset(playLine, ui) -
        offset;
  }

  double firstCenterOffset(int playIndex, LyricUI lyricUI) {
    return LyricHelper.centerOffset(
        lyrics.firstOrNull, playIndex == 0, lyricUI, playIndex);
  }

  double lastCenterOffset(int playIndex, LyricUI lyricUI) {
    return LyricHelper.centerOffset(
        lyrics.lastOrNull, playIndex == lyrics.length - 1, lyricUI, playIndex);
  }
}

///lyric line model
class LyricsLineModel {
  String? mainText;
  String? extText;
  int? startTime;
  int? endTime;

  //绘制信息
  LyricDrawInfo? drawInfo;

  bool get hasExt => extText?.isNotEmpty == true;

  bool get hasMain => mainText?.isNotEmpty == true;
}

///lyric draw model
class LyricDrawInfo {
  double get otherMainTextHeight => otherMainTextPainter?.height ?? 0;
  double get otherExtTextHeight => otherExtTextPainter?.height ?? 0;
  double get playingMainTextHeight => playingMainTextPainter?.height ?? 0;
  double get playingExtTextHeight => playingExtTextPainter?.height ?? 0;
  TextPainter? otherMainTextPainter;
  TextPainter? otherExtTextPainter;
  TextPainter? playingMainTextPainter;
  TextPainter? playingExtTextPainter;
  List<LyricInlineDrawInfo> inlineDrawList=[];
}

class LyricInlineDrawInfo{
  int number=0;
  String text="";
  double width =0;
  double height =0;
  Offset startOffset=Offset.zero;
}
