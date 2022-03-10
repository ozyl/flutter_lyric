import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lyrics_reader/lyric_ui/lyric_ui.dart';
import 'package:lyrics_reader/lyric_ui/ui_netease.dart';
import 'package:lyrics_reader/lyrics_reader_model.dart';
import 'package:lyrics_reader/lyrics_reader_paint.dart';

typedef SelectLineBuilder = Widget Function(int,VoidCallback);

class LyricsReader extends StatefulWidget {
  final Size size;
  final LyricsReaderModel? model;
  final LyricUI ui;
  final double position;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final SelectLineBuilder? selectLineBuilder;

  @override
  State<StatefulWidget> createState() => LyricReaderState();

  LyricsReader(
      {this.position = 0,
      this.model,
      this.padding,
      this.size = Size.infinite,
      this.selectLineBuilder,
      LyricUI? lyricUi,
      this.onTap})
      : ui = lyricUi ?? UINetease();
}

class LyricReaderState extends State<LyricsReader>
    with TickerProviderStateMixin {
  late LyricsReaderPaint lyricPaint;

  StreamController<int> centerLyricIndexStream = StreamController.broadcast();
  AnimationController? _flingController;
  AnimationController? _lineController;

  var mSize = Size.infinite;

  var isDrag = false;

  /// 等待恢复
  var isWait = false;

  ///缓存下lineIndex避免重复获取
  var cacheLine = -1;

  BoxConstraints? cacheBox;

  @override
  void initState() {
    super.initState();
    lyricPaint = LyricsReaderPaint(widget.model, widget.ui)..centerLyricIndexChangeCall = (index){
      centerLyricIndexStream.add(index);
    };
  }

  var isShowSelectLineWidget = false;

  void setSelectLine(bool isShow) {
    if (!mounted) return;
    setState(() {
      isShowSelectLineWidget = isShow;
    });
  }

  @override
  void didUpdateWidget(covariant LyricsReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.size.toString() != widget.size.toString() ||
        oldWidget.model != widget.model ||
        oldWidget.ui != widget.ui) {
      lyricPaint.model = widget.model;
      lyricPaint.lyricUI = widget.ui;
      handleSize();
      scrollToPlayLine();
    }

    if (oldWidget.position != widget.position) {
      selectLine(widget.model?.getCurrentLine(widget.position) ?? 0);
      if (cacheLine != lyricPaint.playingIndex) {
        cacheLine = lyricPaint.playingIndex;
        scrollToPlayLine();
      }
    }
  }

  void scrollToPlayLine() {
    safeLyricOffset(widget.model?.computeScroll(
            lyricPaint.playingIndex, lyricPaint.playingIndex, widget.ui) ??
        0);
  }

  void selectLine(int line) {
    lyricPaint.playingIndex = line;
  }

  safeLyricOffset(double offset) {
    if (isDrag || isWait) return;
    if (_flingController?.isAnimating == true) return;
    realUpdateOffset(offset);
  }

  void realUpdateOffset(double offset) {
    if (widget.ui.enableLineAnimation()) {
      animationOffset(offset);
    } else {
      lyricPaint.lyricOffset = offset;
    }
  }

  void animationOffset(double offset) {
    disposeLine();
    _lineController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    var animate = Tween<double>(
      begin: lyricPaint.lyricOffset,
      end: offset,
    ).chain(CurveTween(curve: Curves.easeInOut)).animate(_lineController!)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          disposeLine();
        }
      });
    animate
      ..addListener(() {
        var value = animate.value;
        lyricPaint.lyricOffset = value.clamp(lyricPaint.maxOffset, 0);
      });
    _lineController?.forward();
  }

  refreshLyricHeight(Size size) {
    lyricPaint.clearCache();
    widget.model?.lyrics.forEach((element) {
      element.drawInfo = LyricDrawInfo()
        ..playingExtTextHeight = lyricPaint.getTextHeight(
            element.extText, widget.ui.getPlayingExtTextStyle(), size: size)
        ..playingMainTextHeight = lyricPaint.getTextHeight(
            element.mainText, widget.ui.getPlayingMainTextStyle(), size: size)
        ..otherExtTextHeight = lyricPaint.getTextHeight(
            element.extText, widget.ui.getOtherExtTextStyle(), size: size)
        ..otherMainTextHeight = lyricPaint.getTextHeight(
            element.mainText, widget.ui.getOtherMainTextStyle(),
            size: size);
    });
  }

  handleSize() {
    mSize = widget.size;
    if (mSize.width == double.infinity) {
      mSize = Size(MediaQuery.of(context).size.width, mSize.height);
    }
    if (mSize.height == double.infinity) {
      mSize = Size(mSize.width, mSize.width);
    }
    if (cacheBox != null) {
      if (cacheBox!.maxWidth != double.infinity) {
        mSize = Size(min(cacheBox!.maxWidth, mSize.width), mSize.height);
      }
      if (cacheBox!.maxHeight != double.infinity) {
        mSize = Size(mSize.width, min(cacheBox!.maxHeight, mSize.height));
      }
    }
    refreshLyricHeight(mSize);
  }

  @override
  Widget build(BuildContext context) {
    return buildTouchReader(Stack(
      children: [
        buildReaderWidget(),
        if (widget.selectLineBuilder != null &&
            isShowSelectLineWidget &&
            lyricPaint.centerY != 0)
          buildSelectLineWidget()
      ],
    ));
  }

  Positioned buildSelectLineWidget() {
    return Positioned(
      child: Container(
        height: lyricPaint.centerY * 2,
        child: Center(
          child: StreamBuilder<int>(
            stream: centerLyricIndexStream.stream,
            builder: (context, snapshot) {
              var centerIndex = snapshot.data??0;
              return widget.selectLineBuilder!.call(
                  lyricPaint.model?.lyrics[centerIndex].startTime ??
                      0,(){
                setSelectLine(false);
                disposeFiling();
                disposeSelectLineDelay();
              });
            }
          ),
        ),
      ),
      top: 0,
      left: 0,
      right: 0,
    );
  }

  Container buildReaderWidget() {
    return Container(
      padding: widget.padding ?? EdgeInsets.zero,
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (c, box) {
          if (cacheBox?.toString() != box.toString()) {
            cacheBox = box;
            handleSize();
          }
          return CustomPaint(
            painter: lyricPaint,
            size: mSize,
          );
        },
      ),
    );
  }

  Widget buildTouchReader(child) {
    return GestureDetector(
      onVerticalDragEnd: handleDragEnd,
      onTap: widget.onTap,
      onTapDown: (event) {
        disposeSelectLineDelay();
        disposeFiling();
        isDrag = true;
      },
      onTapUp: (event) {
        isDrag = false;
        resumeSelectLineOffset();
      },
      onVerticalDragStart: (event) {
        disposeFiling();
        disposeSelectLineDelay();
        setSelectLine(true);
      },
      onVerticalDragUpdate: (event) =>
          {lyricPaint.lyricOffset += event.primaryDelta ?? 0},
      child: child,
    );
  }

  handleDragEnd(DragEndDetails event) {
    isDrag = false;
    _flingController = AnimationController.unbounded(
        vsync: this)
      ..addListener(() {
        if (_flingController == null) return;
        var flingOffset = _flingController!.value;
        lyricPaint.lyricOffset = flingOffset.clamp(lyricPaint.maxOffset, 0);
        if (!lyricPaint.checkOffset(flingOffset)) {
          disposeFiling();
          resumeSelectLineOffset();
          return;
        }
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed) {
          disposeFiling();
          resumeSelectLineOffset();
        }
      })
      ..animateWith(ClampingScrollSimulation(
        position: lyricPaint.lyricOffset,
        velocity: event.primaryVelocity ?? 0,
      ));
  }

  Timer? waitTimer;

  resumeSelectLineOffset() {
    isWait = true;
    var waitSecond = 0;
    waitTimer?.cancel();
    waitTimer = new Timer.periodic(Duration(milliseconds: 100), (timer) {
      waitSecond += 100;
      if (waitSecond == 400) {
        realUpdateOffset(widget.model?.computeScroll(
                lyricPaint.centerLyricIndex,
                lyricPaint.playingIndex,
                widget.ui) ??
            0);
        return;
      }
      if (waitSecond == 3000) {
        disposeSelectLineDelay();
        setSelectLine(false);
        scrollToPlayLine();
      }
    });
  }

  disposeSelectLineDelay() {
    isWait = false;
    waitTimer?.cancel();
  }

  disposeFiling() {
    _flingController?.dispose();
    _flingController = null;
  }

  disposeLine() {
    _lineController?.dispose();
    _lineController = null;
  }

  @override
  void dispose() {
    disposeSelectLineDelay();
    disposeFiling();
    disposeLine();
    centerLyricIndexStream.close();
    super.dispose();
  }
}
