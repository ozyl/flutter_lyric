import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'lyric.dart';

class LyricPainter extends CustomPainter with ChangeNotifier {
  //歌词列表
  List<Lyric> lyrics;

  //翻译/音译歌词列表
  List<Lyric> subLyrics;

  //歌词画笔数组
  List<TextPainter> lyricTextPaints = [];

  //翻译/音译歌词画笔数组
  List<TextPainter> subLyricTextPaints = [];

  //画布大小
  Size canvasSize = Size.zero;

  //字体最大宽度
  double lyricMaxWidth;

  //歌词间距
  double lyricGapValue;

  //歌词间距
  double subLyricGapValue;

  //歌词总长度
  double totalHeight = 0;

  //通过偏移量控制歌词滑动
  static double _offset = 0;

  set offset(value) {
    _offset = value;
    notifyListeners();
  }

  //歌词位置
  int currentLyricIndex = 0;

  //老的动画控制器
  static AnimationController _animationController;

  //老的上一行位置
  static int _oldCurrentLyricIndex;

  //因空行高度与非空行高度不一致，存一个非空行的位置，绘制时使用
  var notEmptyLyricIndex = 0;

  //歌词位置
  int notEmptySubLyricIndex = 0;

  //歌词行高度
  double _subLyricHeight = 0;

  //歌词样式
  TextStyle lyricTextStyle;

  //翻译/音译歌词样式
  TextStyle subLyricTextStyle;

  //当前歌词样式
  TextStyle currLyricTextStyle;

  LyricPainter(this.lyrics,
      {List<Lyric> remarkLyrics,
      double currDuration,
      TickerProvider vsync,
      TextStyle lyricStyle,
      TextStyle remarkStyle,
      TextStyle currLyricStyle,
      this.lyricGapValue,
      this.subLyricGapValue,
      this.lyricMaxWidth})
      : this.lyricTextStyle =
            lyricStyle ?? TextStyle(color: Colors.grey, fontSize: 13),
        this.subLyricTextStyle =
            remarkStyle ?? TextStyle(color: Colors.black, fontSize: 14),
        this.currLyricTextStyle =
            currLyricStyle ?? TextStyle(color: Colors.red, fontSize: 20),
        this.subLyrics = remarkLyrics {
    //歌词转画笔
    lyricTextPaints.addAll(lyrics
        .map(
          (l) => TextPainter(
              text: TextSpan(text: l.lyric, style: lyricTextStyle),
              textDirection: TextDirection.ltr),
        )
        .toList());

    //翻译/音译歌词转画笔
    if (subLyrics != null && subLyrics.isNotEmpty) {
      subLyricTextPaints.addAll(subLyrics
          .map((l) => TextPainter(
              text: TextSpan(text: l.lyric, style: subLyricTextStyle),
              textDirection: TextDirection.ltr))
          .toList());
      //因空行高度与非空行高度不一致，先存一个非空行的位置
      notEmptySubLyricIndex = getNotEmptyLineHeight(subLyrics);
      //计算默认歌词高度
      subLyricTextPaints[notEmptySubLyricIndex]
        ..layout(maxWidth: lyricMaxWidth);
      _subLyricHeight = subLyricTextPaints[notEmptySubLyricIndex].height;
    }

    currentLyricIndex = findLyricIndexByDuration(currDuration ?? 0, lyrics);
    if (currentLyricIndex == 0 || vsync == null) {
      offset = -computeScrollY(currentLyricIndex);
    } else {
      animationScrollY(currentLyricIndex, vsync);
    }
  }

  ///因空行高度与非空行高度不一致，获取非空行的位置
  int getNotEmptyLineHeight(List<Lyric> lyrics) =>
      lyrics.indexOf(lyrics.firstWhere((lyric) => lyric.lyric.trim().isNotEmpty,
          orElse: () => lyrics.first));

  animationScrollY(currentLyricIndex, TickerProvider tickerProvider) {
    if (currentLyricIndex != 0 && currentLyricIndex != _oldCurrentLyricIndex) {
      if (_animationController != null) {
        _animationController.stop();
      }
      _animationController = AnimationController(
          vsync: tickerProvider, duration: Duration(milliseconds: 200))
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _animationController.dispose();
            _animationController = null;
          }
        });
      // 计算上一行偏移量
      var previousRowOffset = computeScrollY(currentLyricIndex - 1);
      // 计算当前行偏移量
      var currentRowOffset = computeScrollY(currentLyricIndex);
      // 起始为上一行，结束点为当前行
      Animation animation =
          Tween<double>(begin: previousRowOffset, end: currentRowOffset)
              .animate(_animationController);
      _animationController.addListener(() {
        offset = -animation.value;
      });
      _animationController.forward();
    }
    _oldCurrentLyricIndex = currentLyricIndex;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvasSize = size;

    //初始化歌词的Y坐标在正中央
    lyricTextPaints[currentLyricIndex]
      //设置歌词
      ..text = TextSpan(
          text: lyrics[currentLyricIndex].lyric, style: currLyricTextStyle)
      ..layout(maxWidth: lyricMaxWidth);
    var currentLyricY = _offset +
        size.height / 2 -
        lyricTextPaints[currentLyricIndex].height / 2;

    //遍历歌词进行绘制
    for (int lyricIndex = 0; lyricIndex < lyrics.length; lyricIndex++) {
      var currentLyricTextPaint = lyricTextPaints[lyricIndex];

      var currentLyric = lyrics[lyricIndex];
      //仅绘制在屏幕内的歌词
      if (currentLyricY < size.height && currentLyricY > 0) {
        //绘制歌词到画布
        currentLyricTextPaint
          //设置歌词
          ..text = TextSpan(
              text: currentLyric.lyric,
              style: currentLyricIndex == lyricIndex
                  ? currLyricTextStyle
                  : lyricTextStyle)
          //计算文本宽高
          ..layout(maxWidth: lyricMaxWidth)
          //绘制 offset=横向居中
          ..paint(
              canvas,
              Offset((size.width - currentLyricTextPaint.width) / 2,
                  currentLyricY));
      }
      currentLyricTextPaint..layout(maxWidth: lyricMaxWidth);
      var currentLyricHeight = currentLyricTextPaint.height;
      //当前歌词结束后调整下次开始绘制歌词的y坐标
      currentLyricY += currentLyricHeight + lyricGapValue;
      //如果有翻译歌词时,寻找该行歌词以后的翻译歌词
      if (subLyrics != null) {
        List<Lyric> remarkLyrics = subLyrics
            .where((subLyric) =>
                subLyric.startTime >= currentLyric.startTime &&
                subLyric.endTime <= currentLyric.endTime)
            .toList();
        remarkLyrics.forEach((remarkLyric) {
          //获取位置
          var subIndex = subLyrics.indexOf(remarkLyric);

          //仅绘制在屏幕内的歌词
          if (currentLyricY < size.height && currentLyricY > 0) {
            subLyricTextPaints[subIndex] //设置歌词
              ..text =
                  TextSpan(text: remarkLyric.lyric, style: subLyricTextStyle)
              //计算文本宽高
              ..layout(maxWidth: lyricMaxWidth)
              //绘制 offset=横向居中
              ..paint(
                  canvas,
                  Offset((size.width - subLyricTextPaints[subIndex].width) / 2,
                      currentLyricY));
          }
          //当前歌词结束后调整下次开始绘制歌词的y坐标
          currentLyricY += _subLyricHeight + subLyricGapValue;
        });
      }
    }
  }

  @override
  bool shouldRepaint(LyricPainter oldDelegate) {
    //当歌词进度发生变化时重新绘制
    return oldDelegate.currentLyricIndex != currentLyricIndex;
  }

  //根据当前时长获取歌词位置
  int findLyricIndexByDuration(double curDuration, List<Lyric> lyrics) {
    for (int i = 0; i < lyrics.length; i++) {
      if (curDuration >= lyrics[i].startTime.inMilliseconds &&
          curDuration <= lyrics[i].endTime.inMilliseconds) {
        return i;
      }
    }
    return 0;
  }

  /// 计算传入行和第一行的偏移量
  double computeScrollY(int curLine) {
    double totalHeight = 0;
    for (var i = 0; i < curLine; i++) {
      var currPaint = lyricTextPaints[i];
      currPaint.layout(maxWidth: lyricMaxWidth);
      totalHeight += currPaint.height + lyricGapValue;
    }
    if (subLyrics != null) {
      //增加 当前行之前的翻译歌词的偏移量
      var list = subLyrics
          .where((subLyric) => subLyric.endTime <= lyrics[curLine].endTime)
          .toList();
      totalHeight += list.length * (subLyricGapValue + _subLyricHeight);
    }
    return totalHeight;
  }
}
