import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lyrics_reader/lyric_helper.dart';
import 'package:lyrics_reader/lyric_ui/lyric_ui.dart';
import 'package:lyrics_reader/lyrics_log.dart';
import 'package:lyrics_reader/lyrics_reader_model.dart';

class LyricsReaderPaint extends ChangeNotifier implements CustomPainter {
  LyricsReaderModel? model;

  LyricUI lyricUI;

  LyricsReaderPaint(this.model, this.lyricUI);

  ///高亮混合笔
  var lightBlendPaint = Paint()
    ..color = Colors.green
    ..isAntiAlias = true;

  var linePaint = TextPainter(
    textDirection: TextDirection.ltr,
  );

  var playingIndex = 0;

  double _lyricOffset = 0;

  set lyricOffset(double offset) {
    if (checkOffset(offset)) {
      _lyricOffset = offset;
      refresh();
    }
  }

  double totalHeight = 0;

  var cachePlayingIndex = -1;

  clearCache(){
    cachePlayingIndex = -1;
  }

  bool checkOffset(double? offset) {
    if (offset == null) return false;

    calculateTotalHeight();

    if (offset >= maxOffset && offset <= 0) {
      return true;
    } else {
      if (offset <= maxOffset && offset > _lyricOffset) {
        return true;
      }
    }
    LyricsLog.logD("越界取消偏移 可偏移：${maxOffset} 目标偏移：$offset 当前：${_lyricOffset} ");
    return false;
  }

  void calculateTotalHeight() {
    ///缓存下，避免多余计算
    if (cachePlayingIndex != playingIndex) {
      cachePlayingIndex = playingIndex;
      var lyrics = model?.lyrics??[];
      double lastLineSpace = 0;
      //最大偏移量不包含最后一行
      if(lyrics.isNotEmpty) {
        lyrics = lyrics.sublist(0,lyrics.length-1);
        lastLineSpace = LyricHelper.getLineSpaceHeight(lyrics.last, lyricUI,excludeInline: true);
      }
      totalHeight =
          -LyricHelper.getTotalHeight(lyrics, playingIndex, lyricUI) +
              (model?.firstCenterOffset(playingIndex,lyricUI)??0)
      - (model?.lastCenterOffset(playingIndex,lyricUI)??0)
      - lastLineSpace;
    }
  }

  double get baseOffset =>
      lyricUI.halfSizeLimit() ? mSize.height * (0.5 - lyricUI.getPlayingLineBias()) : 0;

  double get maxOffset {
    calculateTotalHeight();
    return baseOffset + totalHeight;
  }

  double get lyricOffset => _lyricOffset;

  refresh() {
    notifyListeners();
  }

  var _centerLyricIndex = 0;
  set centerLyricIndex(int value){
    _centerLyricIndex = value;
    centerLyricIndexChangeCall?.call(value);
  }

  int get centerLyricIndex => _centerLyricIndex;

  Function(int)? centerLyricIndexChangeCall=null;

  Size mSize = Size.zero;

  ///给外部C位位置
  var centerY = 0.0;

  @override
  bool? hitTest(Offset position) => null;

  @override
  void paint(Canvas canvas, Size size) {
    //全局尺寸信息
    mSize = size;
    //溢出裁剪
    canvas.clipRect(Rect.fromLTRB(0, 0, size.width, size.height));
    centerY = size.height * lyricUI.getPlayingLineBias();
    var drawOffset = centerY + _lyricOffset;
    var lyrics = model?.lyrics ?? [];
    drawOffset -= model?.firstCenterOffset(playingIndex,lyricUI)??0;
    for (var i = 0; i < lyrics.length; i++) {
      var element = lyrics[i];
      var lineHeight = drawLine(i, drawOffset, canvas, element);
      var nextOffset = drawOffset + lineHeight;
      if(centerY>drawOffset && centerY<nextOffset){
        if(i!=centerLyricIndex){
          centerLyricIndex = i;
          LyricsLog.logD("drawOffset:$drawOffset next:$nextOffset center:$centerY  当前行是：${i} 文本：${element.mainText} ");
        }
      }
      drawOffset = nextOffset;
    }
  }

  double drawLine(
      int i, double drawOffset, Canvas canvas, LyricsLineModel element) {
    //空行直接返回
    if (!element.hasMain && !element.hasExt) {
      return lyricUI.getBlankLineHeight();
    }
    return _drwaOtherLyricLine(canvas, drawOffset, element, i == playingIndex);
  }

  ///绘制其他歌词行
  ///返回造成的偏移量值
  double _drwaOtherLyricLine(
      Canvas canvas, double drawOffsetY, LyricsLineModel element, bool isPlay) {
    var mainTextStyle = isPlay
        ? lyricUI.getPlayingMainTextStyle()
        : lyricUI.getOtherMainTextStyle();
    var extTextStyle = isPlay
        ? lyricUI.getPlayingExtTextStyle()
        : lyricUI.getOtherExtTextStyle();
    //该行行高
    double otherLineHeight = 0;
    //第一行不加行间距
    if ((model?.lyrics.indexOf(element) ?? -1) != 0) {
      otherLineHeight += lyricUI.getLineSpace();
    }
    if (element.hasMain) {
      otherLineHeight += drawText(canvas, element.mainText, mainTextStyle,
          drawOffsetY + otherLineHeight);
    }
    if (element.hasExt) {
      //有主歌词时才加内间距
      if (element.hasMain) {
        otherLineHeight += lyricUI.getInlineSpace();
      }
      var extOffsetY = drawOffsetY + otherLineHeight;
      otherLineHeight +=
          drawText(canvas, element.extText, extTextStyle, extOffsetY);
    }
    return otherLineHeight;
  }

  ///绘制文本并返回行高度
  double drawText(
      Canvas canvas, String? text, TextStyle style, double offsetY) {
    double lineHeight = getTextHeight(text, style);
    if (offsetY < 0 - lineHeight || offsetY > mSize.height) {
      return lineHeight;
    }
    linePaint.paint(canvas, Offset(getLineOffsetX(linePaint), offsetY));
    return lineHeight;
  }

  /// 获取文本高度
  double getTextHeight(String? text, TextStyle style, {Size? size}) {
    if (text == null) text = "";
    linePaint.textAlign = lyricUI.getLyricTextAligin();
    linePaint
      ..text = TextSpan(text: text, style: style.copyWith(height: 1))
      ..layout(maxWidth: (size ?? mSize).width);
    return linePaint.height;
  }

  ///获取行绘制横向坐标
  double getLineOffsetX(TextPainter textPainter) {
    switch (lyricUI.getLyricHorizontalAlign()) {
      case LyricAligin.LEFT:
        return 0;
      case LyricAligin.CENTER:
        return (mSize.width - textPainter.width) / 2;
      case LyricAligin.RIGHT:
        return mSize.width - textPainter.width;
      default:
        return (mSize.width - textPainter.width) / 2;
    }
  }

  @override
  SemanticsBuilderCallback? get semanticsBuilder => null;

  @override
  bool shouldRebuildSemantics(covariant CustomPainter oldDelegate) {
    return shouldRepaint(oldDelegate);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
